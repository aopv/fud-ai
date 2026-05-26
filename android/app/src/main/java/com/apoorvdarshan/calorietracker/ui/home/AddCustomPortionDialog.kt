package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.models.ServingUnitOption
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextField
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

@Composable
fun AddCustomPortionDialog(
    currentGrams: Double,
    onDismiss: () -> Unit,
    onAdd: (name: String, grams: Double) -> Unit
) {
    val predefinedUnits = listOf(
        "piece", "serving", "portion", "slice", "cup",
        "bowl", "plate", "container", "package", "can",
        "bottle", "glass", "cookie", "bar", "scoop"
    )

    var selectedUnit by remember { mutableStateOf(predefinedUnits.first()) }
    var gramsText by remember { mutableStateOf(ServingUnitOption.formatQuantity(currentGrams)) }

    FudGlassDialog(onDismissRequest = onDismiss) {
        Text("Custom Portion Size", fontSize = 21.sp, fontWeight = FontWeight.Bold)

        Spacer(Modifier.height(8.dp))

        Text(
            "Unit",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.padding(bottom = 4.dp)
        )

        // Scrollable list — max ~5 visible rows, same pill card style as the rest of the sheet
        SheetPillCard {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 220.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                predefinedUnits.forEachIndexed { index, unit ->
                    val isSelected = unit == selectedUnit
                    if (index > 0) SheetHairline()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedUnit = unit }
                            .padding(horizontal = 18.dp, vertical = 13.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            unit,
                            fontSize = 16.sp,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) AppColors.Calorie
                                    else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f)
                        )
                        if (isSelected) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = null,
                                tint = AppColors.Calorie,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        FudGlassTextField(
            value = gramsText,
            onValueChange = { gramsText = it },
            placeholder = "Weight in grams",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)
        )

        FudGlassDialogActions(
            primaryText = "Add",
            onPrimary = {
                val grams = ServingUnitOption.parseQuantity(gramsText)
                if (grams != null && grams > 0) {
                    onAdd(selectedUnit, grams)
                    onDismiss()
                }
            },
            dismissText = "Cancel",
            onDismiss = onDismiss
        )
    }
}
