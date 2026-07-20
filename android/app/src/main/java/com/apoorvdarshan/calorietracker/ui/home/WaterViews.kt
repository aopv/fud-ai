package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import com.apoorvdarshan.calorietracker.models.WaterUnit
import androidx.compose.ui.res.stringResource

@Composable
fun WaterProgressRow(current: Int, goal: Int, unit: WaterUnit, modifier: Modifier = Modifier) {
    val progress = if (goal > 0) (current.toFloat() / goal).coerceIn(0f, 1f) else 0f
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Filled.WaterDrop,
                contentDescription = null,
                tint = AppColors.Calorie,
                modifier = Modifier.size(17.dp)
            )
            Text(
                stringResource(R.string.water),
                modifier = Modifier.padding(start = 6.dp),
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${unit.displayValue(current)} / ${unit.format(goal)}",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                fontSize = 12.sp
            )
        }
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth().height(5.dp).clip(RoundedCornerShape(3.dp)),
            color = AppColors.Calorie,
            trackColor = AppColors.Calorie.copy(alpha = 0.16f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WaterCustomAmountSheet(unit: WaterUnit, onDismiss: () -> Unit, onAdd: (Int) -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var customAmount by remember { mutableStateOf("") }
    val amountMl = customAmount.replace(',', '.').toDoubleOrNull()
        ?.takeIf { it > 0 }
        ?.let(unit::toMilliliters)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
                Spacer(Modifier.weight(1f))
                Text(stringResource(R.string.water_log_title), fontWeight = FontWeight.Bold, fontSize = 20.sp)
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.padding(horizontal = 31.dp))
            }

            Text(stringResource(R.string.water_how_much), fontWeight = FontWeight.SemiBold, fontSize = 18.sp)

            OutlinedTextField(
                value = customAmount,
                onValueChange = { value ->
                    val filtered = value.filter { it.isDigit() || (unit == WaterUnit.FLUID_OUNCES && (it == '.' || it == ',')) }
                    val normalized = filtered.replace(',', '.')
                    val pieces = normalized.split('.', limit = 3)
                    customAmount = if (pieces.size > 1) "${pieces[0]}.${pieces[1].take(1)}".take(6) else normalized.take(5)
                },
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.water_custom_amount)) },
                suffix = { Text(unit.symbol) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (unit == WaterUnit.MILLILITERS) KeyboardType.Number else KeyboardType.Decimal
                )
            )

            Button(
                onClick = {
                    amountMl?.let(onAdd)
                    onDismiss()
                },
                enabled = amountMl != null,
                modifier = Modifier.fillMaxWidth().height(54.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AppColors.Calorie)
            ) {
                Icon(Icons.Filled.WaterDrop, contentDescription = null)
                Text(stringResource(R.string.water_add), modifier = Modifier.padding(start = 8.dp), fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
