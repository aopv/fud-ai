package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable

enum class HomeTopNutrient(
    val storageKey: String,
    val displayName: String,
    val unit: String
) {
    PROTEIN("protein", "Protein", "g"),
    CARBS("carbs", "Carbs", "g"),
    FAT("fat", "Fat", "g"),
    FIBER("fiber", "Fiber", "g"),
    SUGAR("sugar", "Sugar", "g"),
    ADDED_SUGAR("addedSugar", "Added Sugar", "g"),
    SATURATED_FAT("saturatedFat", "Sat Fat", "g"),
    CHOLESTEROL("cholesterol", "Cholesterol", "mg"),
    SODIUM("sodium", "Sodium", "mg"),
    POTASSIUM("potassium", "Potassium", "mg"),
    TRANS_FAT("transFat", "Trans Fat", "g"),
    CALCIUM("calcium", "Calcium", "mg"),
    IRON("iron", "Iron", "mg"),
    MAGNESIUM("magnesium", "Magnesium", "mg"),
    ZINC("zinc", "Zinc", "mg"),
    VITAMIN_A("vitaminA", "Vit A", "mcg"),
    VITAMIN_C("vitaminC", "Vit C", "mg"),
    VITAMIN_D("vitaminD", "Vit D", "mcg"),
    VITAMIN_B12("vitaminB12", "B12", "mcg"),
    VITAMIN_E("vitaminE", "Vit E", "mg"),
    VITAMIN_K("vitaminK", "Vit K", "mcg"),
    FOLATE("folate", "Folate", "mcg"),
    OMEGA3("omega3", "Omega", "g");

    fun current(entries: List<FoodEntry>): Double = when (this) {
        PROTEIN -> entries.sumOf { it.protein }
        CARBS -> entries.sumOf { it.carbs }
        FAT -> entries.sumOf { it.fat }
        FIBER -> entries.sumOf { it.fiber ?: 0.0 }
        SUGAR -> entries.sumOf { it.sugar ?: 0.0 }
        ADDED_SUGAR -> entries.sumOf { it.addedSugar ?: 0.0 }
        SATURATED_FAT -> entries.sumOf { it.saturatedFat ?: 0.0 }
        CHOLESTEROL -> entries.sumOf { it.cholesterol ?: 0.0 }
        SODIUM -> entries.sumOf { it.sodium ?: 0.0 }
        POTASSIUM -> entries.sumOf { it.potassium ?: 0.0 }
        TRANS_FAT -> entries.sumOf { it.transFat ?: 0.0 }
        CALCIUM -> entries.sumOf { it.calcium ?: 0.0 }
        IRON -> entries.sumOf { it.iron ?: 0.0 }
        MAGNESIUM -> entries.sumOf { it.magnesium ?: 0.0 }
        ZINC -> entries.sumOf { it.zinc ?: 0.0 }
        VITAMIN_A -> entries.sumOf { it.vitaminA ?: 0.0 }
        VITAMIN_C -> entries.sumOf { it.vitaminC ?: 0.0 }
        VITAMIN_D -> entries.sumOf { it.vitaminD ?: 0.0 }
        VITAMIN_B12 -> entries.sumOf { it.vitaminB12 ?: 0.0 }
        VITAMIN_E -> entries.sumOf { it.vitaminE ?: 0.0 }
        VITAMIN_K -> entries.sumOf { it.vitaminK ?: 0.0 }
        FOLATE -> entries.sumOf { it.folate ?: 0.0 }
        OMEGA3 -> entries.sumOf { it.omega3 ?: 0.0 }
    }

    fun goal(profile: UserProfile?, optionalGoals: OptionalNutrientGoals): Int = when (this) {
        PROTEIN -> profile?.effectiveProtein ?: 150
        CARBS -> profile?.effectiveCarbs ?: 220
        FAT -> profile?.effectiveFat ?: 70
        FIBER -> optionalGoals.fiber
        SUGAR -> optionalGoals.sugar
        ADDED_SUGAR -> optionalGoals.addedSugar
        SATURATED_FAT -> optionalGoals.saturatedFat
        CHOLESTEROL -> optionalGoals.cholesterol
        SODIUM -> optionalGoals.sodium
        POTASSIUM -> optionalGoals.potassium
        TRANS_FAT -> optionalGoals.transFat
        CALCIUM -> optionalGoals.calcium
        IRON -> optionalGoals.iron
        MAGNESIUM -> optionalGoals.magnesium
        ZINC -> optionalGoals.zinc
        VITAMIN_A -> optionalGoals.vitaminA
        VITAMIN_C -> optionalGoals.vitaminC
        VITAMIN_D -> optionalGoals.vitaminD
        VITAMIN_B12 -> optionalGoals.vitaminB12
        VITAMIN_E -> optionalGoals.vitaminE
        VITAMIN_K -> optionalGoals.vitaminK
        FOLATE -> optionalGoals.folate
        OMEGA3 -> optionalGoals.omega3
    }

    companion object {
        val DefaultSelection = listOf(PROTEIN, CARBS, FAT, FIBER)
        val DefaultStorageValue = DefaultSelection.joinToString(",") { it.storageKey }

        fun fromStorage(raw: String?): List<HomeTopNutrient> {
            val selected = raw
                ?.split(",")
                ?.mapNotNull { part ->
                    val key = part.trim()
                    values().firstOrNull { it.storageKey == key || it.name == key }
                }
                .orEmpty()
            return normalized(selected)
        }

        fun toStorage(selection: List<HomeTopNutrient>): String =
            normalized(selection).joinToString(",") { it.storageKey }

        fun normalized(selection: List<HomeTopNutrient>): List<HomeTopNutrient> =
            (selection.distinct() + DefaultSelection)
                .distinct()
                .take(4)
    }
}

enum class OptionalNutrient(
    val displayName: String,
    val unit: String,
    val defaultGoal: Int
) {
    SUGAR("Sugar", "g", 50),
    ADDED_SUGAR("Added Sugar", "g", 25),
    FIBER("Fiber", "g", 30),
    SATURATED_FAT("Saturated Fat", "g", 20),
    CHOLESTEROL("Cholesterol", "mg", 300),
    SODIUM("Sodium", "mg", 2300),
    POTASSIUM("Potassium", "mg", 3500),
    TRANS_FAT("Trans Fat", "g", 0),
    CALCIUM("Calcium", "mg", 1000),
    IRON("Iron", "mg", 18),
    MAGNESIUM("Magnesium", "mg", 400),
    ZINC("Zinc", "mg", 11),
    VITAMIN_A("Vitamin A", "mcg", 900),
    VITAMIN_C("Vitamin C", "mg", 90),
    VITAMIN_D("Vitamin D", "mcg", 20),
    VITAMIN_B12("Vitamin B12", "mcg", 3),
    VITAMIN_E("Vitamin E", "mg", 15),
    VITAMIN_K("Vitamin K", "mcg", 120),
    FOLATE("Folate", "mcg", 400),
    OMEGA3("Omega-3", "g", 2)
}

@Serializable
data class OptionalNutrientGoals(
    val sugar: Int = OptionalNutrient.SUGAR.defaultGoal,
    val addedSugar: Int = OptionalNutrient.ADDED_SUGAR.defaultGoal,
    val fiber: Int = OptionalNutrient.FIBER.defaultGoal,
    val saturatedFat: Int = OptionalNutrient.SATURATED_FAT.defaultGoal,
    val cholesterol: Int = OptionalNutrient.CHOLESTEROL.defaultGoal,
    val sodium: Int = OptionalNutrient.SODIUM.defaultGoal,
    val potassium: Int = OptionalNutrient.POTASSIUM.defaultGoal,
    val transFat: Int = OptionalNutrient.TRANS_FAT.defaultGoal,
    val calcium: Int = OptionalNutrient.CALCIUM.defaultGoal,
    val iron: Int = OptionalNutrient.IRON.defaultGoal,
    val magnesium: Int = OptionalNutrient.MAGNESIUM.defaultGoal,
    val zinc: Int = OptionalNutrient.ZINC.defaultGoal,
    val vitaminA: Int = OptionalNutrient.VITAMIN_A.defaultGoal,
    val vitaminC: Int = OptionalNutrient.VITAMIN_C.defaultGoal,
    val vitaminD: Int = OptionalNutrient.VITAMIN_D.defaultGoal,
    val vitaminB12: Int = OptionalNutrient.VITAMIN_B12.defaultGoal,
    val vitaminE: Int = OptionalNutrient.VITAMIN_E.defaultGoal,
    val vitaminK: Int = OptionalNutrient.VITAMIN_K.defaultGoal,
    val folate: Int = OptionalNutrient.FOLATE.defaultGoal,
    val omega3: Int = OptionalNutrient.OMEGA3.defaultGoal
) {
    fun valueFor(nutrient: OptionalNutrient): Int = when (nutrient) {
        OptionalNutrient.SUGAR -> sugar
        OptionalNutrient.ADDED_SUGAR -> addedSugar
        OptionalNutrient.FIBER -> fiber
        OptionalNutrient.SATURATED_FAT -> saturatedFat
        OptionalNutrient.CHOLESTEROL -> cholesterol
        OptionalNutrient.SODIUM -> sodium
        OptionalNutrient.POTASSIUM -> potassium
        OptionalNutrient.TRANS_FAT -> transFat
        OptionalNutrient.CALCIUM -> calcium
        OptionalNutrient.IRON -> iron
        OptionalNutrient.MAGNESIUM -> magnesium
        OptionalNutrient.ZINC -> zinc
        OptionalNutrient.VITAMIN_A -> vitaminA
        OptionalNutrient.VITAMIN_C -> vitaminC
        OptionalNutrient.VITAMIN_D -> vitaminD
        OptionalNutrient.VITAMIN_B12 -> vitaminB12
        OptionalNutrient.VITAMIN_E -> vitaminE
        OptionalNutrient.VITAMIN_K -> vitaminK
        OptionalNutrient.FOLATE -> folate
        OptionalNutrient.OMEGA3 -> omega3
    }

    fun withValue(nutrient: OptionalNutrient, value: Int): OptionalNutrientGoals {
        val safe = value.coerceAtLeast(0)
        return when (nutrient) {
            OptionalNutrient.SUGAR -> copy(sugar = safe)
            OptionalNutrient.ADDED_SUGAR -> copy(addedSugar = safe)
            OptionalNutrient.FIBER -> copy(fiber = safe)
            OptionalNutrient.SATURATED_FAT -> copy(saturatedFat = safe)
            OptionalNutrient.CHOLESTEROL -> copy(cholesterol = safe)
            OptionalNutrient.SODIUM -> copy(sodium = safe)
            OptionalNutrient.POTASSIUM -> copy(potassium = safe)
            OptionalNutrient.TRANS_FAT -> copy(transFat = safe)
            OptionalNutrient.CALCIUM -> copy(calcium = safe)
            OptionalNutrient.IRON -> copy(iron = safe)
            OptionalNutrient.MAGNESIUM -> copy(magnesium = safe)
            OptionalNutrient.ZINC -> copy(zinc = safe)
            OptionalNutrient.VITAMIN_A -> copy(vitaminA = safe)
            OptionalNutrient.VITAMIN_C -> copy(vitaminC = safe)
            OptionalNutrient.VITAMIN_D -> copy(vitaminD = safe)
            OptionalNutrient.VITAMIN_B12 -> copy(vitaminB12 = safe)
            OptionalNutrient.VITAMIN_E -> copy(vitaminE = safe)
            OptionalNutrient.VITAMIN_K -> copy(vitaminK = safe)
            OptionalNutrient.FOLATE -> copy(folate = safe)
            OptionalNutrient.OMEGA3 -> copy(omega3 = safe)
        }
    }

    companion object {
        val Default = OptionalNutrientGoals()
    }
}
