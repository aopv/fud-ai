package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable

/** Optional product-label details returned by Open Food Facts for barcode logs. */
@Serializable
data class FoodProductMetadata(
    val barcode: String,
    val packageQuantity: String? = null,
    val ingredientsText: String? = null,
    val allergens: List<String> = emptyList(),
    val traces: List<String> = emptyList(),
    val nutriScore: String? = null,
    val novaGroup: Int? = null,
    val ecoScore: String? = null,
    val labels: List<String> = emptyList(),
    val categories: List<String> = emptyList(),
    val imageUrl: String? = null
) {
    val hasDisplayDetails: Boolean
        get() = barcode.isNotEmpty() ||
            packageQuantity != null ||
            ingredientsText != null ||
            allergens.isNotEmpty() ||
            traces.isNotEmpty() ||
            nutriScore != null ||
            novaGroup != null ||
            ecoScore != null ||
            labels.isNotEmpty() ||
            categories.isNotEmpty()
}
