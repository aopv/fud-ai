package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
data class FoodEntry(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val calories: Int,
    val protein: Double,
    val carbs: Double,
    val fat: Double,
    @Serializable(with = InstantSerializer::class)
    val timestamp: Instant = Instant.now(),
    /** Filename (not path) under filesDir/fudai-food-images/ where the JPEG lives. */
    val imageFilename: String? = null,
    /** Ordered photos after the primary image. Kept separate so galleries and AI
     * reprocessing can use the original files instead of a stitched composite. */
    val additionalImageFilenames: List<String> = emptyList(),
    val emoji: String? = null,
    val source: FoodSource,
    val mealType: MealType = MealType.OTHER,
    val sugar: Double? = null,
    val addedSugar: Double? = null,
    val fiber: Double? = null,
    val saturatedFat: Double? = null,
    val monounsaturatedFat: Double? = null,
    val polyunsaturatedFat: Double? = null,
    val cholesterol: Double? = null,
    val sodium: Double? = null,
    val potassium: Double? = null,
    val transFat: Double? = null,
    val calcium: Double? = null,
    val iron: Double? = null,
    val magnesium: Double? = null,
    val zinc: Double? = null,
    val vitaminA: Double? = null,
    val vitaminC: Double? = null,
    val vitaminD: Double? = null,
    val vitaminB12: Double? = null,
    val vitaminE: Double? = null,
    val vitaminK: Double? = null,
    val folate: Double? = null,
    val omega3: Double? = null,
    val servingSizeGrams: Double? = null,
    val servingUnitOptions: List<ServingUnitOption> = emptyList(),
    val selectedServingUnit: String? = null,
    val selectedServingQuantity: Double? = null,
    val customNote: String? = null
) {
    /** Unique key for favorite deduplication (name + calorie combo). */
    val favoriteKey: String get() = "${name.lowercase()}|$calories"

    /** New entry for the given log date (new id), copying nutrition and media from this entry. */
    fun duplicatedForLogging(
        logDate: Instant,
        mealType: MealType = MealType.currentMeal
    ): FoodEntry = FoodEntry(
        id = UUID.randomUUID(),
        name = name,
        calories = calories,
        protein = protein,
        carbs = carbs,
        fat = fat,
        timestamp = logDate,
        imageFilename = imageFilename,
        additionalImageFilenames = additionalImageFilenames,
        emoji = emoji,
        source = source,
        mealType = mealType,
        sugar = sugar,
        addedSugar = addedSugar,
        fiber = fiber,
        saturatedFat = saturatedFat,
        monounsaturatedFat = monounsaturatedFat,
        polyunsaturatedFat = polyunsaturatedFat,
        cholesterol = cholesterol,
        sodium = sodium,
        potassium = potassium,
        transFat = transFat,
        calcium = calcium,
        iron = iron,
        magnesium = magnesium,
        zinc = zinc,
        vitaminA = vitaminA,
        vitaminC = vitaminC,
        vitaminD = vitaminD,
        vitaminB12 = vitaminB12,
        vitaminE = vitaminE,
        vitaminK = vitaminK,
        folate = folate,
        omega3 = omega3,
        servingSizeGrams = servingSizeGrams,
        servingUnitOptions = servingUnitOptions,
        selectedServingUnit = selectedServingUnit,
        selectedServingQuantity = selectedServingQuantity,
        customNote = customNote
    )

    val allImageFilenames: List<String>
        get() = listOfNotNull(imageFilename) + additionalImageFilenames
}
