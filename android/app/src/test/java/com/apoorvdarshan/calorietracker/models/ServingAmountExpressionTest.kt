package com.apoorvdarshan.calorietracker.models

import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ServingAmountExpressionTest {
    @Test
    fun evaluatesCommonServingAdjustments() {
        assertEquals(70.0, ServingAmountExpression.evaluate("50+20")!!, 0.0)
        assertEquals(165.0, ServingAmountExpression.evaluate("200−35")!!, 0.0)
        assertEquals(160.0, ServingAmountExpression.evaluate("80×2")!!, 0.0)
        assertEquals(100.0, ServingAmountExpression.evaluate("300÷3")!!, 0.0)
    }

    @Test
    fun usesStandardOperatorPrecedence() {
        assertEquals(90.0, ServingAmountExpression.evaluate("50+20×2")!!, 0.0)
    }

    @Test
    fun acceptsLocalizedDecimals() {
        assertEquals(2.0, ServingAmountExpression.evaluate("1,5+0,5", Locale.GERMANY)!!, 0.0)
        assertEquals(1.75, ServingAmountExpression.evaluate("1.5+0.25", Locale.US)!!, 0.0)
    }

    @Test
    fun rejectsIncompleteAndUnsafeExpressions() {
        assertNull(ServingAmountExpression.evaluate("50+"))
        assertNull(ServingAmountExpression.evaluate("50÷0"))
        assertNull(ServingAmountExpression.evaluate("food+20"))
    }

    @Test
    fun operatorButtonsReplaceAnIncompleteOperator() {
        assertEquals("50+", ServingAmountExpression.appendOperator("50", '+'))
        assertEquals("50×", ServingAmountExpression.appendOperator("50+", '×'))
    }
}
