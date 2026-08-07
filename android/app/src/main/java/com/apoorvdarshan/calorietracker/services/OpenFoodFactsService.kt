package com.apoorvdarshan.calorietracker.services

import com.apoorvdarshan.calorietracker.models.ServingUnitOption
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysis
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysisService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder
import java.util.Locale
import kotlin.math.round
import kotlin.math.roundToInt

object OpenFoodFactsService {
    private const val FIELDS = "product_name,generic_name,brands,quantity,serving_size,serving_quantity,nutriments"
    private const val USER_AGENT = "FudAI/Android (https://fud-ai.app)"

    class LookupException(message: String) : Exception(message)

    suspend fun lookup(
        barcode: String,
        client: OkHttpClient = FoodAnalysisService.defaultClient
    ): FoodAnalysis = withContext(Dispatchers.IO) {
        val code = barcode.trim()
        if (code.isEmpty()) throw LookupException("That barcode could not be read. Try scanning it again.")

        val encodedCode = URLEncoder.encode(code, "UTF-8")
        val url = "https://world.openfoodfacts.org/api/v2/product/$encodedCode.json?fields=$FIELDS"
        val request = Request.Builder()
            .url(url)
            .addHeader("User-Agent", USER_AGENT)
            .build()

        val raw = runCatching { client.newCall(request).execute() }
            .getOrElse { throw LookupException("Barcode lookup failed: ${it.localizedMessage ?: "network error"}") }
            .use { response ->
                if (!response.isSuccessful) {
                    throw LookupException("Open Food Facts returned an unexpected response.")
                }
                response.body?.string().orEmpty()
            }

        val json = runCatching { JSONObject(raw) }.getOrNull()
            ?: throw LookupException("Open Food Facts returned an unexpected response.")
        val product = json.optJSONObject("product")
        if (json.optInt("status", 0) == 0 || product == null) {
            throw LookupException("Product not found in Open Food Facts. Scan the nutrition label instead.")
        }
        analysis(product, code)
    }

    private fun analysis(product: JSONObject, barcode: String): FoodAnalysis {
        val nutriments = product.optJSONObject("nutriments")
            ?: throw LookupException("This barcode was found, but nutrition data is incomplete. Scan the nutrition label instead.")

        val servingGrams = maxOf(
            product.flexibleDouble("serving_quantity")
                ?: gramsFrom(product.optString("serving_size").takeIf { it.isNotBlank() })
                ?: 100.0,
            1.0
        )
        val scale = servingGrams / 100.0

        fun servingValue(key: String): Double? {
            nutriments.flexibleDouble("${key}_serving")?.let { return it }
            return nutriments.flexibleDouble("${key}_100g")?.let { it * scale }
        }

        val calories = servingValue("energy-kcal")
            ?: servingValue("energy")?.let { it * 0.23900573614 }
        val protein = servingValue("proteins")
        val carbs = servingValue("carbohydrates")
        val fat = servingValue("fat")

        if (calories == null && protein == null && carbs == null && fat == null) {
            throw LookupException("This barcode was found, but nutrition data is incomplete. Scan the nutrition label instead.")
        }

        val servingOption = ServingUnitOption(unit = "serving", gramsPerUnit = servingGrams, quantity = 1.0)
        return FoodAnalysis(
            name = productName(product, barcode),
            calories = (calories ?: 0.0).roundToInt(),
            protein = protein ?: 0.0,
            carbs = carbs ?: 0.0,
            fat = fat ?: 0.0,
            servingSizeGrams = servingGrams,
            emoji = "🏷️",
            sugar = rounded(servingValue("sugars")),
            addedSugar = rounded(servingValue("added-sugars")),
            fiber = rounded(servingValue("fiber")),
            saturatedFat = rounded(servingValue("saturated-fat")),
            monounsaturatedFat = rounded(servingValue("monounsaturated-fat")),
            polyunsaturatedFat = rounded(servingValue("polyunsaturated-fat")),
            cholesterol = milligrams(servingValue("cholesterol")),
            caffeine = milligrams(servingValue("caffeine")),
            sodium = milligrams(servingValue("sodium")),
            potassium = milligrams(servingValue("potassium")),
            transFat = rounded(servingValue("trans-fat")),
            calcium = milligrams(servingValue("calcium")),
            iron = milligrams(servingValue("iron")),
            magnesium = milligrams(servingValue("magnesium")),
            zinc = milligrams(servingValue("zinc")),
            vitaminA = micrograms(servingValue("vitamin-a")),
            vitaminC = milligrams(servingValue("vitamin-c")),
            vitaminD = micrograms(servingValue("vitamin-d")),
            vitaminB12 = micrograms(servingValue("vitamin-b12")),
            vitaminE = milligrams(servingValue("vitamin-e")),
            vitaminK = micrograms(servingValue("vitamin-k")),
            folate = micrograms(servingValue("folates")),
            omega3 = rounded(servingValue("omega-3-fat")),
            servingUnitOptions = listOf(servingOption),
            selectedServingUnit = servingOption.unit,
            selectedServingQuantity = 1.0
        )
    }

    private fun productName(product: JSONObject, barcode: String): String {
        val primary = firstNonEmpty(
            product.optString("product_name"),
            product.optString("generic_name")
        )
        val brand = product.optString("brands")
            .split(",")
            .firstOrNull()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }

        if (primary != null && brand != null && !primary.lowercase(Locale.US).contains(brand.lowercase(Locale.US))) {
            return "$brand $primary"
        }
        return primary ?: brand ?: "Barcode $barcode"
    }

    private fun firstNonEmpty(vararg values: String?): String? =
        values.mapNotNull { it?.trim() }.firstOrNull { it.isNotEmpty() }

    private fun rounded(value: Double?): Double? =
        value?.let { round(it * 10.0) / 10.0 }

    private fun milligrams(grams: Double?): Double? =
        grams?.let { round(it * 1000.0 * 10.0) / 10.0 }

    private fun micrograms(grams: Double?): Double? =
        grams?.let { round(it * 1_000_000.0 * 10.0) / 10.0 }

    private fun gramsFrom(servingSize: String?): Double? {
        var text = servingSize?.lowercase(Locale.US) ?: return null
        text = text.replace(",", ".").replace("fl. oz", "fl oz")
        val match = Regex("""([0-9]+(?:\.[0-9]+)?)\s*(fl oz|kg|mg|g|oz|ml|l)""")
            .find(text)
            ?: return null
        val value = match.groupValues[1].toDoubleOrNull() ?: return null
        return when (match.groupValues[2]) {
            "kg" -> value * 1000.0
            "mg" -> value / 1000.0
            "oz" -> value * 28.3495
            "fl oz" -> value * 29.5735
            "ml" -> value
            "l" -> value * 1000.0
            else -> value
        }
    }

    private fun JSONObject.flexibleDouble(key: String): Double? {
        if (!has(key) || isNull(key)) return null
        return when (val value = opt(key)) {
            is Number -> value.toDouble()
            is String -> value.trim().replace(",", ".").toDoubleOrNull()
            else -> null
        }?.takeUnless { it.isNaN() || it.isInfinite() }
    }
}
