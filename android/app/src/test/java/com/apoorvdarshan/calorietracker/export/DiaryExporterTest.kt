package com.apoorvdarshan.calorietracker.export

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class DiaryExporterTest {
    private val nutrientFields = listOf(
        "sugar_g", "added_sugar_g", "fiber_g", "saturated_fat_g",
        "monounsaturated_fat_g", "polyunsaturated_fat_g", "cholesterol_mg",
        "sodium_mg", "potassium_mg", "trans_fat_g", "calcium_mg", "iron_mg",
        "magnesium_mg", "zinc_mg", "vitamin_a_mcg", "vitamin_c_mg",
        "vitamin_d_mcg", "vitamin_b12_mcg", "vitamin_e_mg", "vitamin_k_mcg",
        "folate_mcg", "omega3_g",
    )

    @Test
    fun jsonIncludesEveryStoredNutrient() {
        val entry = nutrientEntry()
        val date = entry.timestamp.atZone(ZoneId.systemDefault()).toLocalDate()
        val (_, json) = requireNotNull(build(entry, date, DiaryFormat.JSON))
        val root = JsonParser.parseString(json).asJsonObject
        assertEquals("1.1", root["export"].asJsonObject["format_version"].asString)
        val item = root["days"].asJsonArray[0].asJsonObject["meals"].asJsonArray[0]
            .asJsonObject["items"].asJsonArray[0].asJsonObject

        nutrientFields.forEach { field -> assertTrue("Missing JSON nutrient field: $field", item.has(field)) }
        assertEquals(3.3, item["fiber_g"].asDouble, 0.0001)
        assertEquals(8.8, item["sodium_mg"].asDouble, 0.0001)
        assertEquals(18.8, item["vitamin_b12_mcg"].asDouble, 0.0001)
    }

    @Test
    fun csvAndMarkdownIncludeEveryStoredNutrient() {
        val entry = nutrientEntry()
        val date = entry.timestamp.atZone(ZoneId.systemDefault()).toLocalDate()
        val (_, csv) = requireNotNull(build(entry, date, DiaryFormat.CSV))
        val lines = csv.trimEnd().lines()
        val headers = lines[0].split(',')
        val values = lines[1].split(',')
        assertEquals(headers.size, values.size)
        nutrientFields.forEach { field -> assertTrue("Missing CSV nutrient column: $field", headers.contains(field)) }
        assertEquals("3.3", values[headers.indexOf("fiber_g")])

        val (_, markdown) = requireNotNull(build(entry, date, DiaryFormat.MARKDOWN))
        listOf("Fiber (g)", "Sodium (mg)", "Vitamin A (mcg)", "Vitamin B12 (mcg)", "Omega-3 (g)")
            .forEach { heading -> assertTrue("Missing Markdown nutrient heading: $heading", markdown.contains(heading)) }
    }

    private fun build(entry: FoodEntry, date: LocalDate, format: DiaryFormat) = DiaryExporter.build(
        entries = listOf(entry),
        start = date,
        end = date,
        format = format,
        profile = UserProfile(customCalories = 2_000, customProtein = 120, customCarbs = 200, customFat = 60),
        mealDisplay = { it.name },
    )

    private fun nutrientEntry() = FoodEntry(
        name = "Nutrient fixture",
        calories = 120,
        protein = 4.4,
        carbs = 5.5,
        fat = 6.6,
        timestamp = Instant.ofEpochSecond(1_752_840_000),
        source = FoodSource.MANUAL,
        mealType = MealType.LUNCH,
        sugar = 1.1,
        addedSugar = 2.2,
        fiber = 3.3,
        saturatedFat = 4.4,
        monounsaturatedFat = 5.5,
        polyunsaturatedFat = 6.6,
        cholesterol = 7.7,
        sodium = 8.8,
        potassium = 9.9,
        transFat = 10.1,
        calcium = 11.1,
        iron = 12.2,
        magnesium = 13.3,
        zinc = 14.4,
        vitaminA = 15.5,
        vitaminC = 16.6,
        vitaminD = 17.7,
        vitaminB12 = 18.8,
        vitaminE = 19.9,
        vitaminK = 20.1,
        folate = 21.2,
        omega3 = 22.3,
        servingSizeGrams = 100.0,
    )
}
