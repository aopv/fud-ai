import Testing
@testable import calorietracker

struct ServingUnitFallbackTests {
    @Test func validNonemptyObjectArrayDoesNotRequireFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"slice","quantity":2,"grams_per_unit":60}]"#)
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.count == 1)
        #expect(analysis.servingUnitOptions.first?.unit == "slice")
        #expect(analysis.servingUnitOptions.first?.quantity == 2)
        #expect(analysis.servingUnitOptions.first?.gramsPerUnit == 60)
    }

    @Test func numericOneQuantityRemainsValid() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"piece","quantity":1,"grams_per_unit":120}]"#)
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.first?.quantity == 1)
    }

    @Test func numericOneGramsPerUnitRemainsValid() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"ml","quantity":120,"grams_per_unit":1}]"#)
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.first?.gramsPerUnit == 1)
    }

    @Test func validEmptyArrayDoesNotRequireFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(from: foodJSON(unitOptions: "[]"))

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func legacyObjectArrayAliasDoesNotRequireFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(
                unitOptions: #"[{"unit":"piece","quantity":2,"grams_per_unit":60}]"#,
                fieldName: "serving_unit_options"
            )
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.first?.unit == "piece")
    }

    @Test func legacyCamelCaseGramsPerUnitDoesNotRequireFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"slice","quantity":2,"gramsPerUnit":60}]"#)
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.first?.gramsPerUnit == 60)
    }

    @Test func stringArrayRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"["slice"]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func missingFieldRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(from: foodJSON(unitOptions: nil))

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func incompleteObjectRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"slice","grams_per_unit":120}]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func booleanQuantityRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"piece","quantity":true,"grams_per_unit":120}]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func booleanGramsPerUnitRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"piece","quantity":1,"grams_per_unit":false}]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func inconsistentServingWeightRequiresFallback() throws {
        let analysis = try GeminiService.parseFoodAnalysis(
            from: foodJSON(unitOptions: #"[{"unit":"slice","quantity":2,"grams_per_unit":40}]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func nutritionLabelValidEmptyDoesNotRequireFallback() throws {
        let analysis = try GeminiService.parseNutritionLabel(
            from: nutritionLabelJSON(unitOptions: "[]")
        )

        #expect(!analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    @Test func nutritionLabelStringArrayRequiresFallback() throws {
        let analysis = try GeminiService.parseNutritionLabel(
            from: nutritionLabelJSON(unitOptions: #"["slice"]"#)
        )

        #expect(analysis.requiresServingUnitFallback)
        #expect(analysis.servingUnitOptions.isEmpty)
    }

    private func foodJSON(unitOptions: String?, fieldName: String = "unit_options") -> String {
        let unitOptionsField = unitOptions.map { ",\"\(fieldName)\":\($0)" } ?? ""
        return """
        {"name":"Pizza","calories":240,"protein":10,"carbs":32,"fat":8,"serving_size_grams":120\(unitOptionsField)}
        """
    }

    private func nutritionLabelJSON(unitOptions: String) -> String {
        """
        {"name":"Pizza","calories_per_100g":200,"protein_per_100g":8,"carbs_per_100g":27,"fat_per_100g":7,"serving_size_grams":120,"unit_options":\(unitOptions)}
        """
    }
}
