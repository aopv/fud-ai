import Foundation
import Testing
@testable import calorietracker

struct ServingUnitEditorTests {

    // MARK: - C locale (period decimal)

    @Test func cLocale_simpleInteger() {
        #expect(ServingUnitEditor.parseDecimal("5") == 5)
    }

    @Test func cLocale_simpleDecimal() {
        #expect(ServingUnitEditor.parseDecimal("0.5") == 0.5)
    }

    @Test func cLocale_wholeWithDecimal() {
        #expect(ServingUnitEditor.parseDecimal("1.5") == 1.5)
    }

    @Test func cLocale_largeNumber() {
        #expect(ServingUnitEditor.parseDecimal("1000") == 1000)
    }

    @Test func cLocale_numberWithGroupingSeparator() {
        // "1.000" in C locale → period is decimal → 1.0
        #expect(ServingUnitEditor.parseDecimal("1.000") == 1.0)
    }

    @Test func cLocale_trailingZeros() {
        #expect(ServingUnitEditor.parseDecimal("0.500") == 0.5)
    }

    @Test func cLocale_negative() {
        #expect(ServingUnitEditor.parseDecimal("-2.5") == -2.5)
    }

    // MARK: - Comma-decimal locale (de_DE)

    @Test func deLocale_simpleCommaDecimal() {
        let deLocale = Locale(identifier: "de_DE")
        #expect(ServingUnitEditor.parseDecimal("0,5", locale: deLocale) == 0.5)
    }

    @Test func deLocale_wholeWithComma() {
        #expect(ServingUnitEditor.parseDecimal("1,5", locale: Locale(identifier: "de_DE")) == 1.5)
    }

    @Test func deLocale_periodStillWorks() {
        // C-locale fallback catches period-decimal in any locale
        #expect(ServingUnitEditor.parseDecimal("0.5", locale: Locale(identifier: "de_DE")) == 0.5)
    }

    // MARK: - French locale (fr_FR)

    @Test func frLocale_commaDecimal() {
        #expect(ServingUnitEditor.parseDecimal("1,5", locale: Locale(identifier: "fr_FR")) == 1.5)
    }

    // MARK: - Invalid inputs

    @Test func invalid_empty() {
        #expect(ServingUnitEditor.parseDecimal("") == nil)
    }

    @Test func invalid_text() {
        #expect(ServingUnitEditor.parseDecimal("abc") == nil)
    }

    @Test func invalid_emoji() {
        #expect(ServingUnitEditor.parseDecimal("🍕") == nil)
    }

    @Test func invalid_wrongLocaleSeparator() {
        // "," is not a decimal separator in en_US
        #expect(ServingUnitEditor.parseDecimal("0,5", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func invalid_multipleDecimalSeparators() {
        #expect(ServingUnitEditor.parseDecimal("1.2.3", locale: Locale(identifier: "en_US")) == nil)
        #expect(ServingUnitEditor.parseDecimal("1,2,3", locale: Locale(identifier: "de_DE")) == nil)
    }

    // MARK: - Optional manual nutrition

    @Test func manualNutrition_blankRemainsUnknown() {
        #expect(ManualEntryInput.optionalNutritionValue("", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func manualNutrition_acceptsLocalizedDecimal() {
        #expect(ManualEntryInput.optionalNutritionValue("7.5", locale: Locale(identifier: "en_US")) == 7.5)
        #expect(ManualEntryInput.optionalNutritionValue("7,5", locale: Locale(identifier: "de_DE")) == 7.5)
    }

    @Test func manualNutrition_rejectsNegativeAndInvalidValues() {
        #expect(ManualEntryInput.optionalNutritionValue("-1", locale: Locale(identifier: "en_US")) == nil)
        #expect(ManualEntryInput.optionalNutritionValue("fiber", locale: Locale(identifier: "en_US")) == nil)
    }

}
