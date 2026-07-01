package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import kotlin.math.roundToInt

/**
 * Confirmation shown when the user opens a `fudai://add-meal` link (issue #107). Lists the shared
 * meal(s) and adds them to the log on confirm — never silently, so a stray link can't add food
 * without the user seeing it first.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportSharedMealSheet(
    meals: List<FoodEntry>,
    onAdd: (List<FoodEntry>) -> Unit,
    onDismiss: () -> Unit,
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val isDark = MaterialTheme.colorScheme.background.let { (it.red + it.green + it.blue) / 3f < 0.5f }
    val totalCalories = meals.sumOf { it.calories }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = if (isDark) Color(0xF2141416) else Color(0xFFFAF3EE),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                if (meals.size == 1) "Add shared meal" else "Add ${meals.size} shared meals",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
            )

            meals.forEach { meal ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    meal.emoji?.let {
                        Text(it, fontSize = 20.sp, modifier = Modifier.padding(end = 10.dp))
                    }
                    Column(Modifier.weight(1f)) {
                        Text(meal.name, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                        Text(
                            "${meal.protein.roundToInt()}P · ${meal.carbs.roundToInt()}C · ${meal.fat.roundToInt()}F",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }
                    Text(
                        "${meal.calories} kcal",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Calorie,
                    )
                }
            }

            Text(
                "Adds to your log with the exact nutrients from the sender. No photo is included.",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )

            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(AppColors.CalorieGradient)
                    .clickable { onAdd(meals) }
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (meals.size == 1) "Add to Log" else "Add ${meals.size} to Log · $totalCalories kcal",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                )
            }
        }
    }
}
