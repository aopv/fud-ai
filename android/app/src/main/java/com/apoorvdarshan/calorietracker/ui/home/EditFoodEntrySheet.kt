package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysis
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import com.apoorvdarshan.calorietracker.ui.util.clockTimePattern
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.ServingUnitOption
import com.apoorvdarshan.calorietracker.ui.components.DateWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextField
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

/**
 * Edit page for an existing FoodEntry. Visually identical to [FoodResultSheet]
 * (the first-time review page), so the edit experience matches the logging
 * experience. Differences from FoodResultSheet:
 *   - Top-right action says "Save" instead of "Log".
 *   - Initial values come from the existing entry; save mutates it via onSave.
 * Deletion is handled by swipe-to-delete on the Home food log list.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditFoodEntrySheet(
    entry: FoodEntry,
    preferGramsByDefault: Boolean = false,
    onReprocess: suspend (updatedNote: String) -> FoodAnalysis,
    onSave: (FoodEntry) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { it != SheetValue.Hidden }
    )
    var currentBaseEntry by remember(entry) { mutableStateOf(entry) }
    var noteText by remember(entry) { mutableStateOf(entry.customNote ?: "") }
    var isReprocessing by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val baseServing = currentBaseEntry.servingSizeGrams ?: 100.0
    val servingUnitOptions = remember(currentBaseEntry.servingUnitOptions, baseServing) {
        ServingUnitOption.normalizedOptions(currentBaseEntry.servingUnitOptions, baseServing)
    }
    var name by remember(currentBaseEntry) { mutableStateOf(currentBaseEntry.name) }
    val initialServingUnit = if (preferGramsByDefault) {
        ServingUnitOption.grams.unit
    } else {
        currentBaseEntry.selectedServingUnit
    }
    var selectedServingUnitId by remember(currentBaseEntry, servingUnitOptions, preferGramsByDefault) {
        mutableStateOf(ServingUnitOption.initialUnitId(initialServingUnit, servingUnitOptions))
    }
    var servingGrams by remember(currentBaseEntry, baseServing) { mutableStateOf(baseServing) }
    var servingQuantityText by remember(currentBaseEntry, servingUnitOptions, preferGramsByDefault) {
        mutableStateOf(
            ServingUnitOption.initialQuantityText(
                totalGrams = baseServing,
                selectedUnitId = selectedServingUnitId,
                selectedQuantity = currentBaseEntry.selectedServingQuantity,
                options = servingUnitOptions
            )
        )
    }
    val selectedServingOption = ServingUnitOption.optionMatching(selectedServingUnitId, servingUnitOptions)
    val selectedServingQuantity = ServingUnitOption.parseQuantity(servingQuantityText)?.takeIf { it > 0 }
    val scale = if (baseServing > 0) servingGrams / baseServing else 1.0
    var mealType by remember(entry) { mutableStateOf(currentBaseEntry.mealType) }
    var moreNutritionExpanded by remember { mutableStateOf(false) }
    var mealMenuExpanded by remember { mutableStateOf(false) }
    var servingMenuExpanded by remember { mutableStateOf(false) }
    val zone = remember { ZoneId.systemDefault() }
    val initialLoggedAt = remember(entry.id, entry.timestamp) { entry.timestamp.atZone(zone) }
    var loggedDate by remember(entry.id, entry.timestamp) { mutableStateOf(initialLoggedAt.toLocalDate()) }
    var loggedTime by remember(entry.id, entry.timestamp) { mutableStateOf(initialLoggedAt.toLocalTime().withSecond(0).withNano(0)) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val sheetSurface = if (isDark) MaterialTheme.colorScheme.surface else Color(0xFFFAF3EE)
    val context = LocalContext.current
    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US) }
    val timeFormatter = remember(context) { DateTimeFormatter.ofPattern(clockTimePattern(context), Locale.US) }
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val dismissKeyboard = {
        focusManager.clearFocus(force = true)
        keyboardController?.hide()
    }

    fun scaledInt(v: Int) = (v * scale).roundToInt()
    fun scaledMacro(v: Double) = v * scale
    fun scaledD(v: Double?) = v?.let { ((it * scale) * 10).roundToInt() / 10.0 }

    fun buildUpdated(): FoodEntry = currentBaseEntry.copy(
        name = name.trim().ifEmpty { currentBaseEntry.name },
        calories = scaledInt(currentBaseEntry.calories),
        protein = scaledMacro(currentBaseEntry.protein),
        carbs = scaledMacro(currentBaseEntry.carbs),
        fat = scaledMacro(currentBaseEntry.fat),
        timestamp = loggedDate.atTime(loggedTime).atZone(zone).toInstant(),
        mealType = mealType,
        customNote = noteText.trim().takeIf { it.isNotEmpty() },
        sugar = scaledD(currentBaseEntry.sugar),
        addedSugar = scaledD(currentBaseEntry.addedSugar),
        fiber = scaledD(currentBaseEntry.fiber),
        saturatedFat = scaledD(currentBaseEntry.saturatedFat),
        monounsaturatedFat = scaledD(currentBaseEntry.monounsaturatedFat),
        polyunsaturatedFat = scaledD(currentBaseEntry.polyunsaturatedFat),
        cholesterol = scaledD(currentBaseEntry.cholesterol),
        sodium = scaledD(currentBaseEntry.sodium),
        potassium = scaledD(currentBaseEntry.potassium),
        transFat = scaledD(currentBaseEntry.transFat),
        calcium = scaledD(currentBaseEntry.calcium),
        iron = scaledD(currentBaseEntry.iron),
        magnesium = scaledD(currentBaseEntry.magnesium),
        zinc = scaledD(currentBaseEntry.zinc),
        vitaminA = scaledD(currentBaseEntry.vitaminA),
        vitaminC = scaledD(currentBaseEntry.vitaminC),
        vitaminD = scaledD(currentBaseEntry.vitaminD),
        vitaminB12 = scaledD(currentBaseEntry.vitaminB12),
        vitaminE = scaledD(currentBaseEntry.vitaminE),
        vitaminK = scaledD(currentBaseEntry.vitaminK),
        folate = scaledD(currentBaseEntry.folate),
        omega3 = scaledD(currentBaseEntry.omega3),
        servingSizeGrams = servingGrams,
        servingUnitOptions = servingUnitOptions,
        selectedServingUnit = if (servingUnitOptions.isEmpty()) null else selectedServingOption.unit,
        selectedServingQuantity = if (servingUnitOptions.isEmpty()) null else selectedServingQuantity
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = sheetSurface
    ) {
        SheetReviewToolbar(
            title = stringResource(R.string.sheet_edit_food),
            primaryLabel = stringResource(R.string.action_save),
            onCancel = onDismiss,
            onPrimary = { if (!isReprocessing) onSave(buildUpdated()) }
        )

        // Hoist string + composition reads above LazyColumn — its lambda has
        // LazyListScope (not @Composable), so stringResource can't be called
        // from inside.
        val gUnit = stringResource(R.string.unit_g)
        val mgUnit = stringResource(R.string.unit_mg)
        val mcgUnit = "mcg"
        val micros = listOf(
            Triple(stringResource(R.string.sheet_micro_sugar), scaledD(currentBaseEntry.sugar), gUnit),
            Triple(stringResource(R.string.sheet_micro_added_sugar), scaledD(currentBaseEntry.addedSugar), gUnit),
            Triple(stringResource(R.string.sheet_micro_fiber), scaledD(currentBaseEntry.fiber), gUnit),
            Triple(stringResource(R.string.sheet_micro_saturated_fat), scaledD(currentBaseEntry.saturatedFat), gUnit),
            Triple(stringResource(R.string.sheet_micro_mono_fat), scaledD(currentBaseEntry.monounsaturatedFat), gUnit),
            Triple(stringResource(R.string.sheet_micro_poly_fat), scaledD(currentBaseEntry.polyunsaturatedFat), gUnit),
            Triple(stringResource(R.string.sheet_micro_cholesterol), scaledD(currentBaseEntry.cholesterol), mgUnit),
            Triple(stringResource(R.string.sheet_micro_sodium), scaledD(currentBaseEntry.sodium), mgUnit),
            Triple(stringResource(R.string.sheet_micro_potassium), scaledD(currentBaseEntry.potassium), mgUnit),
            Triple("Trans Fat", scaledD(currentBaseEntry.transFat), gUnit),
            Triple("Calcium", scaledD(currentBaseEntry.calcium), mgUnit),
            Triple("Iron", scaledD(currentBaseEntry.iron), mgUnit),
            Triple("Magnesium", scaledD(currentBaseEntry.magnesium), mgUnit),
            Triple("Zinc", scaledD(currentBaseEntry.zinc), mgUnit),
            Triple("Vitamin A", scaledD(currentBaseEntry.vitaminA), mcgUnit),
            Triple("Vitamin C", scaledD(currentBaseEntry.vitaminC), mgUnit),
            Triple("Vitamin D", scaledD(currentBaseEntry.vitaminD), mcgUnit),
            Triple("Vitamin B12", scaledD(currentBaseEntry.vitaminB12), mcgUnit),
            Triple("Vitamin E", scaledD(currentBaseEntry.vitaminE), mgUnit),
            Triple("Vitamin K", scaledD(currentBaseEntry.vitaminK), mcgUnit),
            Triple("Folate", scaledD(currentBaseEntry.folate), mcgUnit),
            Triple("Omega-3", scaledD(currentBaseEntry.omega3), gUnit)
        )

        Box(modifier = Modifier.fillMaxWidth()) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .pointerInput(Unit) {
                        detectTapGestures(onTap = { dismissKeyboard() })
                    }
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
            // Square hero (saved photo) OR 80sp emoji fallback — centered.
            item {
                val ctx = LocalContext.current
                val container = (ctx.applicationContext as com.apoorvdarshan.calorietracker.FudAIApp).container
                val bitmap = remember(currentBaseEntry.imageFilename) {
                    currentBaseEntry.imageFilename?.let { container.imageStore.load(it) }
                }
                Box(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    if (bitmap != null) {
                        androidx.compose.foundation.Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = null,
                            contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                            modifier = Modifier
                                .size(240.dp)
                                .clip(RoundedCornerShape(20.dp))
                        )
                    } else {
                        Text(currentBaseEntry.emoji ?: "🍽", fontSize = 80.sp)
                    }
                }
            }

            item { SheetSectionHeader(stringResource(R.string.sheet_food_details)) }
            item {
                SheetPillRow {
                    Text(stringResource(R.string.sheet_name), fontSize = 17.sp, modifier = Modifier.padding(end = 8.dp))
                    Spacer(Modifier.weight(1f))
                    androidx.compose.foundation.text.BasicTextField(
                        value = name,
                        onValueChange = { name = it },
                        singleLine = true,
                        textStyle = androidx.compose.ui.text.TextStyle(
                            color = MaterialTheme.colorScheme.onSurface,
                            fontSize = 17.sp,
                            textAlign = androidx.compose.ui.text.style.TextAlign.End
                        ),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(AppColors.Calorie),
                        modifier = Modifier.weight(2f)
                    )
                }
            }

            item { SheetSectionHeader(stringResource(R.string.sheet_serving)) }
            item {
                ServingQuantityCard(
                    quantityText = servingQuantityText,
                    onQuantityChange = { newValue ->
                        servingQuantityText = newValue
                        ServingUnitOption.parseQuantity(newValue)?.takeIf { it > 0 }?.let {
                            servingGrams = it * selectedServingOption.gramsPerUnit
                        }
                    },
                    selectedUnitId = selectedServingUnitId,
                    onSelectedUnitChange = { optionId ->
                        selectedServingUnitId = optionId
                        val option = ServingUnitOption.optionMatching(optionId, servingUnitOptions)
                        val quantity = if (option.gramsPerUnit > 0) servingGrams / option.gramsPerUnit else servingGrams
                        servingQuantityText = ServingUnitOption.formatQuantity(quantity)
                    },
                    servingSizeGrams = servingGrams,
                    unitOptions = servingUnitOptions,
                    menuExpanded = servingMenuExpanded,
                    onMenuExpandedChange = { servingMenuExpanded = it },
                    gramUnit = stringResource(R.string.unit_g)
                )
            }

            item { SheetSectionHeader(stringResource(R.string.sheet_nutrition)) }
            item {
                SheetPillCard {
                    SheetNutritionRow(stringResource(R.string.nutrition_label_calories), "${scaledInt(currentBaseEntry.calories)}", stringResource(R.string.unit_kcal))
                    SheetHairline()
                    SheetNutritionRow(stringResource(R.string.nutrition_label_protein), MacroValueFormatter.string(scaledMacro(currentBaseEntry.protein)), stringResource(R.string.unit_g))
                    SheetHairline()
                    SheetNutritionRow(stringResource(R.string.nutrition_label_carbs), MacroValueFormatter.string(scaledMacro(currentBaseEntry.carbs)), stringResource(R.string.unit_g))
                    SheetHairline()
                    SheetNutritionRow(stringResource(R.string.nutrition_label_fat), MacroValueFormatter.string(scaledMacro(currentBaseEntry.fat)), stringResource(R.string.unit_g))
                }
            }

            // "More Nutrition" — own pill row with chevron-right that flips to
            // chevron-down when expanded; matches iOS DisclosureGroup behavior.
            // (gUnit / mgUnit / micros hoisted above the LazyColumn so the
            // composable reads happen in @Composable scope.)
            if (micros.any { it.second != null }) {
                item {
                    SheetPillRow(onClick = { moreNutritionExpanded = !moreNutritionExpanded }) {
                        Text(stringResource(R.string.sheet_more_nutrition), fontSize = 17.sp, modifier = Modifier.weight(1f))
                        Icon(
                            if (moreNutritionExpanded) Icons.Filled.KeyboardArrowDown
                            else Icons.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                        )
                    }
                }
                if (moreNutritionExpanded) {
                    item {
                        SheetPillCard {
                            val present = micros.filter { it.second != null }
                            present.forEachIndexed { idx, (label, value, unit) ->
                                if (idx > 0) SheetHairline()
                                SheetNutritionRow(label, String.format("%.1f", value), unit, dim = true)
                            }
                        }
                    }
                }
            }

            item { SheetSectionHeader(stringResource(R.string.sheet_meal)) }
            item {
                SheetPillRow(onClick = { mealMenuExpanded = true }) {
                    Text(stringResource(R.string.sheet_meal_type), fontSize = 17.sp, modifier = Modifier.weight(1f))
                    // Wrap only the right cluster in a Box so the DropdownMenu
                    // anchors on the right side of the row (under the value),
                    // not at the row's left edge.
                    Box {
                        androidx.compose.foundation.layout.Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                sheetMealIcon(mealType),
                                contentDescription = null,
                                tint = AppColors.Calorie,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                stringResource(mealType.displayNameRes),
                                fontSize = 17.sp,
                                color = AppColors.Calorie,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(Modifier.width(6.dp))
                            Icon(
                                Icons.Filled.UnfoldMore,
                                contentDescription = null,
                                tint = AppColors.Calorie
                            )
                        }
                        SheetGlassDropdownMenu(
                            expanded = mealMenuExpanded,
                            onDismissRequest = { mealMenuExpanded = false },
                            menuWidth = 184.dp
                        ) {
                            for (m in MealType.values()) {
                                SheetGlassDropdownMenuItem(
                                    label = stringResource(m.displayNameRes),
                                    leadingIcon = sheetMealIcon(m),
                                    selected = m == mealType,
                                    onClick = {
                                        mealType = m
                                        mealMenuExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }
            }

            item { SheetSectionHeader("AI Note") }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = noteText,
                        onValueChange = { noteText = it },
                        enabled = !isReprocessing,
                        placeholder = { Text("e.g. cooked in olive oil, half portion", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)) },
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier.fillMaxWidth().heightIn(min = 90.dp)
                    )
                    
                    if (noteText.trim() != (currentBaseEntry.customNote ?: "")) {
                        if (isReprocessing) {
                            Box(Modifier.fillMaxWidth().padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(color = AppColors.Calorie, modifier = Modifier.size(24.dp))
                            }
                        } else {
                            TextButton(
                                onClick = {
                                    scope.launch {
                                        isReprocessing = true
                                        errorText = null
                                        try {
                                            val newAnalysis = onReprocess(noteText)
                                            currentBaseEntry = currentBaseEntry.copy(
                                                name = newAnalysis.name,
                                                calories = newAnalysis.calories,
                                                protein = newAnalysis.protein,
                                                carbs = newAnalysis.carbs,
                                                fat = newAnalysis.fat,
                                                sugar = newAnalysis.sugar,
                                                addedSugar = newAnalysis.addedSugar,
                                                fiber = newAnalysis.fiber,
                                                saturatedFat = newAnalysis.saturatedFat,
                                                monounsaturatedFat = newAnalysis.monounsaturatedFat,
                                                polyunsaturatedFat = newAnalysis.polyunsaturatedFat,
                                                cholesterol = newAnalysis.cholesterol,
                                                sodium = newAnalysis.sodium,
                                                potassium = newAnalysis.potassium,
                                                transFat = newAnalysis.transFat,
                                                calcium = newAnalysis.calcium,
                                                iron = newAnalysis.iron,
                                                magnesium = newAnalysis.magnesium,
                                                zinc = newAnalysis.zinc,
                                                vitaminA = newAnalysis.vitaminA,
                                                vitaminC = newAnalysis.vitaminC,
                                                vitaminD = newAnalysis.vitaminD,
                                                vitaminB12 = newAnalysis.vitaminB12,
                                                vitaminE = newAnalysis.vitaminE,
                                                vitaminK = newAnalysis.vitaminK,
                                                folate = newAnalysis.folate,
                                                omega3 = newAnalysis.omega3,
                                                servingSizeGrams = newAnalysis.servingSizeGrams,
                                                servingUnitOptions = newAnalysis.servingUnitOptions,
                                                selectedServingUnit = newAnalysis.selectedServingUnit,
                                                selectedServingQuantity = newAnalysis.selectedServingQuantity,
                                                customNote = noteText.trim().takeIf { it.isNotEmpty() },
                                                emoji = newAnalysis.emoji
                                            )
                                        } catch (e: Exception) {
                                            errorText = e.localizedMessage ?: "Reprocessing failed"
                                        } finally {
                                            isReprocessing = false
                                        }
                                    }
                                },
                                modifier = Modifier.align(Alignment.End)
                            ) {
                                Text("Reprocess with AI", color = AppColors.Calorie, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                    errorText?.let {
                        Text(it, color = Color.Red, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }

            item { SheetSectionHeader("Date & Time") }
            item {
                SheetPillCard {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable {
                                dismissKeyboard()
                                showDatePicker = true
                            }
                            .padding(horizontal = 18.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Date", fontSize = 17.sp, modifier = Modifier.weight(1f))
                        Text(
                            loggedDate.format(dateFormatter),
                            fontSize = 17.sp,
                            color = AppColors.Calorie,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    SheetHairline()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable {
                                dismissKeyboard()
                                showTimePicker = true
                            }
                            .padding(horizontal = 18.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("Time", fontSize = 17.sp, modifier = Modifier.weight(1f))
                        Text(
                            loggedTime.format(timeFormatter),
                            fontSize = 17.sp,
                            color = AppColors.Calorie,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
        if (isReprocessing) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .pointerInput(Unit) {
                        detectTapGestures { /* Consume touches to disable UI interaction during reprocessing */ }
                    }
            )
        }
    }

    if (showDatePicker) {
        var pickedDate by remember(loggedDate) { mutableStateOf(loggedDate) }
        FudGlassDialog(onDismissRequest = { showDatePicker = false }) {
            Text("Date", fontSize = 21.sp, fontWeight = FontWeight.Bold)
            DateWheelPicker(
                selected = pickedDate,
                onSelect = { pickedDate = it },
                minYear = LocalDate.now().year - 10,
                maxYear = LocalDate.now().year,
                modifier = Modifier.fillMaxWidth()
            )
            FudGlassDialogActions(
                primaryText = "Done",
                onPrimary = {
                    loggedDate = pickedDate
                    showDatePicker = false
                },
                dismissText = "Cancel",
                onDismiss = { showDatePicker = false }
            )
        }
    }

    if (showTimePicker) {
        EditFoodTimeDialog(
            initialTime = loggedTime,
            onConfirm = {
                loggedTime = it
                showTimePicker = false
            },
            onDismiss = { showTimePicker = false }
        )
    }
}

@Composable
private fun EditFoodTimeDialog(
    initialTime: LocalTime,
    onConfirm: (LocalTime) -> Unit,
    onDismiss: () -> Unit
) {
    var hourText by remember(initialTime) { mutableStateOf(initialTime.hour.toString().padStart(2, '0')) }
    var minuteText by remember(initialTime) { mutableStateOf(initialTime.minute.toString().padStart(2, '0')) }

    FudGlassDialog(onDismissRequest = onDismiss) {
        Text("Time", fontSize = 21.sp, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FudGlassTextField(
                value = hourText,
                onValueChange = { hourText = it.filter(Char::isDigit).take(2) },
                placeholder = "Hour",
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            FudGlassTextField(
                value = minuteText,
                onValueChange = { minuteText = it.filter(Char::isDigit).take(2) },
                placeholder = "Minute",
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
        }
        FudGlassDialogActions(
            primaryText = "Done",
            onPrimary = {
                val hour = hourText.toIntOrNull()?.coerceIn(0, 23) ?: initialTime.hour
                val minute = minuteText.toIntOrNull()?.coerceIn(0, 59) ?: initialTime.minute
                onConfirm(LocalTime.of(hour, minute))
            },
            dismissText = "Cancel",
            onDismiss = onDismiss
        )
    }
}
