package com.apoorvdarshan.calorietracker.models

import androidx.annotation.StringRes
import com.apoorvdarshan.calorietracker.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalTime

@Serializable
enum class MealType {
    @SerialName("breakfast") BREAKFAST,
    @SerialName("lunch") LUNCH,
    @SerialName("dinner") DINNER,
    @SerialName("snack") SNACK,
    @SerialName("other") OTHER;

    @get:StringRes
    val displayNameRes: Int get() = when (this) {
        BREAKFAST -> R.string.meal_breakfast
        LUNCH -> R.string.meal_lunch
        DINNER -> R.string.meal_dinner
        SNACK -> R.string.meal_snack
        OTHER -> R.string.meal_other
    }

    companion object {
        val currentMeal: MealType get() {
            return CurrentMealSchedule.value.mealTypeAt(LocalTime.now())
        }
    }
}
