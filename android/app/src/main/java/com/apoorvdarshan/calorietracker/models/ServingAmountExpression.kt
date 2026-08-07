package com.apoorvdarshan.calorietracker.models

import java.text.DecimalFormatSymbols
import java.util.Locale

object ServingAmountExpression {
    fun evaluate(expression: String, locale: Locale = Locale.getDefault()): Double? {
        val value = Parser(expression, locale).parse() ?: return null
        return value.takeIf { it.isFinite() }
    }

    fun appendOperator(expression: String, operator: Char): String {
        if (!isOperator(operator)) return expression
        val trimmed = expression.trim()
        if (trimmed.isEmpty()) return expression
        return if (isOperator(trimmed.last())) trimmed.dropLast(1) + operator else trimmed + operator
    }

    fun containsOperation(expression: String): Boolean =
        expression.withIndex().any { (index, character) -> index > 0 && isOperator(character) }

    private fun isOperator(character: Char): Boolean = character in "+-−*×/÷"

    private class Parser(expression: String, locale: Locale) {
        private val input = expression
            .replace('−', '-')
            .replace('×', '*')
            .replace('÷', '/')
        private val decimalSeparators = buildSet {
            add('.')
            add(DecimalFormatSymbols.getInstance(locale).decimalSeparator)
        }
        private var index = 0

        fun parse(): Double? {
            skipWhitespace()
            if (index >= input.length) return null
            val value = parseExpression() ?: return null
            skipWhitespace()
            return value.takeIf { index == input.length }
        }

        private fun parseExpression(): Double? {
            var value = parseTerm() ?: return null
            while (true) {
                skipWhitespace()
                val operation = peek()
                if (operation != '+' && operation != '-') return value
                index += 1
                val rhs = parseTerm() ?: return null
                value = if (operation == '+') value + rhs else value - rhs
            }
        }

        private fun parseTerm(): Double? {
            var value = parseFactor() ?: return null
            while (true) {
                skipWhitespace()
                val operation = peek()
                if (operation != '*' && operation != '/') return value
                index += 1
                val rhs = parseFactor() ?: return null
                if (operation == '/') {
                    if (kotlin.math.abs(rhs) <= Math.ulp(1.0)) return null
                    value /= rhs
                } else {
                    value *= rhs
                }
            }
        }

        private fun parseFactor(): Double? {
            skipWhitespace()
            if (peek() == '+') {
                index += 1
                return parseFactor()
            }
            if (peek() == '-') {
                index += 1
                return parseFactor()?.let { -it }
            }
            return parseNumber()
        }

        private fun parseNumber(): Double? {
            skipWhitespace()
            val start = index
            var foundDigit = false
            var foundSeparator = false
            val normalized = StringBuilder()

            while (true) {
                val character = peek() ?: break
                when {
                    character.isDigit() -> {
                        foundDigit = true
                        normalized.append(character)
                        index += 1
                    }
                    character in decimalSeparators && !foundSeparator -> {
                        foundSeparator = true
                        normalized.append('.')
                        index += 1
                    }
                    else -> break
                }
            }

            if (!foundDigit || index == start) return null
            return normalized.toString().toDoubleOrNull()
        }

        private fun skipWhitespace() {
            while (peek()?.isWhitespace() == true) index += 1
        }

        private fun peek(): Char? = input.getOrNull(index)
    }
}
