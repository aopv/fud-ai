import Foundation

enum ServingAmountExpression {
    static func evaluate(_ expression: String, locale: Locale = .current) -> Double? {
        var parser = Parser(expression: expression, locale: locale)
        guard let value = parser.parse(), value.isFinite else { return nil }
        return value
    }

    static func appending(_ operation: Character, to expression: String) -> String {
        guard isOperator(operation) else { return expression }
        var trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return expression }

        if let last = trimmed.last, isOperator(last) {
            trimmed.removeLast()
        }
        return trimmed + String(operation)
    }

    static func containsOperation(_ expression: String) -> Bool {
        expression.enumerated().contains { index, character in
            isOperator(character) && index > 0
        }
    }

    private static func isOperator(_ character: Character) -> Bool {
        "+-−*×/÷".contains(character)
    }

    private struct Parser {
        private let characters: [Character]
        private let decimalSeparators: Set<Character>
        private var index = 0

        init(expression: String, locale: Locale) {
            self.characters = Array(
                expression
                    .replacingOccurrences(of: "−", with: "-")
                    .replacingOccurrences(of: "×", with: "*")
                    .replacingOccurrences(of: "÷", with: "/")
            )
            var separators: Set<Character> = ["."]
            if let separator = locale.decimalSeparator?.first {
                separators.insert(separator)
            }
            self.decimalSeparators = separators
        }

        mutating func parse() -> Double? {
            skipWhitespace()
            guard index < characters.count, let value = parseExpression() else { return nil }
            skipWhitespace()
            return index == characters.count ? value : nil
        }

        private mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while true {
                skipWhitespace()
                guard let operation = peek(), operation == "+" || operation == "-" else { return value }
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = operation == "+" ? value + rhs : value - rhs
            }
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }
            while true {
                skipWhitespace()
                guard let operation = peek(), operation == "*" || operation == "/" else { return value }
                index += 1
                guard let rhs = parseFactor() else { return nil }
                if operation == "/" {
                    guard abs(rhs) > .ulpOfOne else { return nil }
                    value /= rhs
                } else {
                    value *= rhs
                }
            }
        }

        private mutating func parseFactor() -> Double? {
            skipWhitespace()
            if peek() == "+" {
                index += 1
                return parseFactor()
            }
            if peek() == "-" {
                index += 1
                return parseFactor().map { -$0 }
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            skipWhitespace()
            let start = index
            var foundDigit = false
            var foundSeparator = false
            var normalized = ""

            while let character = peek() {
                if character.isNumber {
                    foundDigit = true
                    normalized.append(character)
                    index += 1
                } else if decimalSeparators.contains(character), !foundSeparator {
                    foundSeparator = true
                    normalized.append(".")
                    index += 1
                } else {
                    break
                }
            }

            guard foundDigit, index > start else { return nil }
            return Double(normalized)
        }

        private mutating func skipWhitespace() {
            while let character = peek(), character.isWhitespace {
                index += 1
            }
        }

        private func peek() -> Character? {
            characters.indices.contains(index) ? characters[index] : nil
        }
    }
}
