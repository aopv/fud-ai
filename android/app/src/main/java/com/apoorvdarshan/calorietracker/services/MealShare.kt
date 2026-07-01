package com.apoorvdarshan.calorietracker.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealType
import org.json.JSONArray
import org.json.JSONObject
import java.util.Base64
import kotlin.math.roundToInt

/**
 * Encodes/decodes a logged meal into a `fudai://add-meal?d=<base64url>` deep link so it can be
 * shared (any app) and imported directly into Fud AI — including cross-platform. The payload
 * schema is byte-identical to the iOS `MealShare`, so a link produced on one platform imports
 * on the other.
 */
object MealShare {
    const val SCHEME = "fudai"
    const val HOST = "add-meal"
    /** Verified App Link host + path — tapping this opens the app directly (no browser). */
    const val WEB_HOST = "www.fud-ai.app"
    const val WEB_PATH = "/add-meal"
    private const val VERSION = 1

    // MARK: Encode

    /**
     * A shareable link carrying every entry's nutrients (no image). Uses an https://fud-ai.app
     * URL so messengers (WhatsApp etc.) make it tappable — the page then opens the app via the
     * fudai://add-meal scheme. `d` is byte-identical to the scheme link, so import is unchanged.
     */
    fun link(entries: List<FoodEntry>): String {
        val meals = JSONArray()
        entries.forEach { meals.put(mealJson(it)) }
        val payload = JSONObject().put("v", VERSION).put("meals", meals)
        val b64 = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(payload.toString().toByteArray(Charsets.UTF_8))
        return "https://$WEB_HOST$WEB_PATH?d=$b64"
    }

    /** Fire the system share sheet with a readable summary + the fudai://add-meal link. */
    fun share(context: Context, entries: List<FoodEntry>) {
        if (entries.isEmpty()) return
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, shareText(entries))
        }
        context.startActivity(Intent.createChooser(send, "Share meal"))
    }

    /** Human-readable summary plus the import link — the text put on the share sheet. */
    fun shareText(entries: List<FoodEntry>): String {
        val lines = entries.map { e ->
            val macros = "${e.protein.roundToInt()}P · ${e.carbs.roundToInt()}C · ${e.fat.roundToInt()}F"
            val prefix = e.emoji?.let { "$it " } ?: ""
            "$prefix${e.name} — ${e.calories} kcal · $macros"
        }.toMutableList()
        lines.add("")
        lines.add("Open in Fud AI to add:")
        lines.add(link(entries))
        return lines.joinToString("\n")
    }

    private fun mealJson(e: FoodEntry): JSONObject {
        val d = JSONObject()
            .put("name", e.name)
            .put("calories", e.calories)
            .put("protein", e.protein)
            .put("carbs", e.carbs)
            .put("fat", e.fat)
            .put("mealType", e.mealType.name.lowercase())
        e.emoji?.let { d.put("emoji", it) }
        fun put(key: String, v: Double?) { if (v != null) d.put(key, v) }
        put("sugar", e.sugar); put("addedSugar", e.addedSugar); put("fiber", e.fiber)
        put("saturatedFat", e.saturatedFat); put("monounsaturatedFat", e.monounsaturatedFat)
        put("polyunsaturatedFat", e.polyunsaturatedFat); put("cholesterol", e.cholesterol)
        put("sodium", e.sodium); put("potassium", e.potassium); put("transFat", e.transFat)
        put("calcium", e.calcium); put("iron", e.iron); put("magnesium", e.magnesium); put("zinc", e.zinc)
        put("vitaminA", e.vitaminA); put("vitaminC", e.vitaminC); put("vitaminD", e.vitaminD)
        put("vitaminB12", e.vitaminB12); put("vitaminE", e.vitaminE); put("vitaminK", e.vitaminK)
        put("folate", e.folate); put("omega3", e.omega3)
        put("servingSizeGrams", e.servingSizeGrams)
        e.selectedServingUnit?.let { d.put("selectedServingUnit", it) }
        put("selectedServingQuantity", e.selectedServingQuantity)
        e.customNote?.let { d.put("customNote", it) }
        return d
    }

    // MARK: Decode

    /** True for both the custom scheme and the https App Link that carry a shared meal. */
    fun handles(uri: Uri): Boolean {
        if (uri.scheme == SCHEME && uri.host == HOST) return true
        return uri.scheme == "https" &&
            (uri.host == WEB_HOST || uri.host == "fud-ai.app") &&
            uri.path == WEB_PATH
    }

    /**
     * Parse a shared-meal link (custom scheme or https App Link) back into fresh [FoodEntry]
     * values (new ids, logged now).
     */
    fun meals(uri: Uri): List<FoodEntry>? {
        if (!handles(uri)) return null
        val encoded = uri.getQueryParameter("d") ?: return null
        val json = runCatching {
            val bytes = Base64.getUrlDecoder().decode(encoded)
            JSONObject(String(bytes, Charsets.UTF_8))
        }.getOrNull() ?: return null
        val mealsArr = json.optJSONArray("meals") ?: return null
        val entries = (0 until mealsArr.length()).mapNotNull { i ->
            mealsArr.optJSONObject(i)?.let(::entryFrom)
        }
        return entries.ifEmpty { null }
    }

    private fun entryFrom(d: JSONObject): FoodEntry? {
        val name = d.optString("name").takeIf { it.isNotEmpty() } ?: return null
        if (!d.has("calories")) return null
        fun dbl(k: String): Double? = if (d.has(k) && !d.isNull(k)) d.optDouble(k) else null
        val meal = runCatching { MealType.valueOf(d.optString("mealType").uppercase()) }
            .getOrDefault(MealType.currentMeal)
        return FoodEntry(
            name = name,
            calories = d.optInt("calories"),
            protein = d.optDouble("protein", 0.0),
            carbs = d.optDouble("carbs", 0.0),
            fat = d.optDouble("fat", 0.0),
            emoji = if (d.has("emoji")) d.optString("emoji") else null,
            source = FoodSource.MANUAL,
            mealType = meal,
            sugar = dbl("sugar"), addedSugar = dbl("addedSugar"), fiber = dbl("fiber"),
            saturatedFat = dbl("saturatedFat"), monounsaturatedFat = dbl("monounsaturatedFat"),
            polyunsaturatedFat = dbl("polyunsaturatedFat"), cholesterol = dbl("cholesterol"),
            sodium = dbl("sodium"), potassium = dbl("potassium"), transFat = dbl("transFat"),
            calcium = dbl("calcium"), iron = dbl("iron"), magnesium = dbl("magnesium"), zinc = dbl("zinc"),
            vitaminA = dbl("vitaminA"), vitaminC = dbl("vitaminC"), vitaminD = dbl("vitaminD"),
            vitaminB12 = dbl("vitaminB12"), vitaminE = dbl("vitaminE"), vitaminK = dbl("vitaminK"),
            folate = dbl("folate"), omega3 = dbl("omega3"),
            servingSizeGrams = dbl("servingSizeGrams"),
            selectedServingUnit = if (d.has("selectedServingUnit")) d.optString("selectedServingUnit") else null,
            selectedServingQuantity = dbl("selectedServingQuantity"),
            customNote = if (d.has("customNote")) d.optString("customNote") else null
        )
    }
}
