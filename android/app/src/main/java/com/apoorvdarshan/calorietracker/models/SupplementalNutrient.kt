package com.apoorvdarshan.calorietracker.models

import com.apoorvdarshan.calorietracker.R

enum class SupplementalNutrient(
    val storageKey: String,
    val apiKey: String,
    val displayName: String,
    val displayNameRes: Int
) {
    CREATINE("creatine", "creatine", "Creatine", R.string.nutrition_label_creatine),
    BETA_ALANINE("betaAlanine", "beta_alanine", "Beta-Alanine", R.string.nutrition_label_beta_alanine),
    L_CITRULLINE("lCitrulline", "l_citrulline", "L-Citrulline", R.string.nutrition_label_l_citrulline),
    L_CARNITINE("lCarnitine", "l_carnitine", "L-Carnitine", R.string.nutrition_label_l_carnitine),
    L_ARGININE("lArginine", "l_arginine", "L-Arginine", R.string.nutrition_label_l_arginine),
    TAURINE("taurine", "taurine", "Taurine", R.string.nutrition_label_taurine),
    BETAINE("betaine", "betaine", "Betaine", R.string.nutrition_label_betaine),
    HMB("hmb", "hmb", "HMB", R.string.nutrition_label_hmb)

    ;

    val optionalNutrient: OptionalNutrient
        get() = OptionalNutrient.valueOf(name)
}
