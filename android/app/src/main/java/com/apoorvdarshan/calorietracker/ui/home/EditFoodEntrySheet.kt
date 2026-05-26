package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
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
import androidx.compose.runtime.LaunchedEffect
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
    onSave: (FoodEntry) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { it != SheetValue.Hidden }
    )
    var baseEntry by remember { mutableStateOf(entry) }
    val baseServing = entry.servingSizeGrams ?: 100.0
    var servingUnitOptions by remember {
        mutableStateOf(ServingUnitOption.normalizedOptions(entry.servingUnitOptions, baseServing))
    }
    var showAddCustomPortion by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf(entry.name) }
    val initialServingUnit = if (preferGramsByDefault) {
        ServingUnitOption.grams.unit
    } else {
        entry.selectedServingUnit
    }
    var selectedServingUnitId by remember {
        mutableStateOf(ServingUnitOption.initialUnitId(initialServingUnit, servingUnitOptions))
    }
    var servingGrams by remember { mutableStateOf(baseServing) }
    var servingQuantityText by remember {
        mutableStateOf(
            ServingUnitOption.initialQuantityText(
                totalGrams = baseServing,
                selectedUnitId = selectedServingUnitId,
                selectedQuantity = entry.selectedServingQuantity,
                options = servingUnitOptions
            )
        )
    }

    LaunchedEffect(entry, preferGramsByDefault) {
        val initialOptions = ServingUnitOption.normalizedOptions(entry.servingUnitOptions, baseServing)
        servingUnitOptions = initialOptions
        servingGrams = baseServing
        val newInitialServingUnit = if (preferGramsByDefault) {
            ServingUnitOption.grams.unit
        } else {
            entry.selectedServingUnit
        }
        val newSelectedUnitId = ServingUnitOption.initialUnitId(newInitialServingUnit, initialOptions)
        selectedServingUnitId = newSelectedUnitId
        servingQuantityText = ServingUnitOption.initialQuantityText(
            totalGrams = baseServing,
            selectedUnitId = newSelectedUnitId,
            selectedQuantity = entry.selectedServingQuantity,
            options = initialOptions
        )
    }
    val selectedServingOption = ServingUnitOption.optionMatching(selectedServingUnitId, servingUnitOptions)
    val selectedServingQuantity = ServingUnitOption.parseQuantity(servingQuantityText)?.takeIf { it > 0 }
    val scale = if (baseServing > 0) servingGrams / baseServing else 1.0
    var mealType by remember { mutableStateOf(entry.mealType) }
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
    val dateFormatter = remember { DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US) }
    val timeFormatter = remember { DateTimeFormatter.ofPattern("h:mm a", Locale.US) }
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val dismissKeyboard = {
        focusManager.clearFocus(force = true)
        keyboardController?.hide()
    }

    fun scaledInt(v: Int) = (v * scale).roundToInt()
    fun scaledMacro(v: Double) = v * scale
    fun scaledD(v: Double?) = v?.let { ((it * scale) * 10).roundToInt() / 10.0 }

    fun buildUpdated(): FoodEntry = entry.copy(
        name = name.trim().ifEmpty { entry.name },
        calories = scaledInt(baseEntry.calories),
        protein = scaledMacro(baseEntry.protein),
        carbs = scaledMacro(baseEntry.carbs),
        fat = scaledMacro(baseEntry.fat),
        timestamp = loggedDate.atTime(loggedTime).atZone(zone).toInstant(),
        mealType = mealType,
        sugar = scaledD(baseEntry.sugar),
        addedSugar = scaledD(baseEntry.addedSugar),
        fiber = scaledD(baseEntry.fiber),
        saturatedFat = scaledD(baseEntry.saturatedFat),
        monounsaturatedFat = scaledD(baseEntry.monounsaturatedFat),
        polyunsaturatedFat = scaledD(baseEntry.polyunsaturatedFat),
        cholesterol = scaledD(baseEntry.cholesterol),
        sodium = scaledD(baseEntry.sodium),
        potassium = scaledD(baseEntry.potassium),
        transFat = scaledD(baseEntry.transFat),
        calcium = scaledD(baseEntry.calcium),
        iron = scaledD(baseEntry.iron),
        magnesium = scaledD(baseEntry.magnesium),
        zinc = scaledD(baseEntry.zinc),
        vitaminA = scaledD(baseEntry.vitaminA),
        vitaminC = scaledD(baseEntry.vitaminC),
        vitaminD = scaledD(baseEntry.vitaminD),
        vitaminB12 = scaledD(baseEntry.vitaminB12),
        vitaminE = scaledD(baseEntry.vitaminE),
        vitaminK = scaledD(baseEntry.vitaminK),
        folate = scaledD(baseEntry.folate),
        omega3 = scaledD(baseEntry.omega3),
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
            onPrimary = { onSave(buildUpdated()) }
        )

        // Hoist string reads above LazyColumn
        val gUnit = stringResource(R.string.unit_g)
        val mgUnit = stringResource(R.string.unit_mg)
        val mcgUnit = "mcg"

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
                val bitmap = remember(entry.imageFilename) {
                    entry.imageFilename?.let { container.imageStore.load(it) }
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
                        Text(entry.emoji ?: "🍽", fontSize = 80.sp)
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
            item {
                androidx.compose.material3.TextButton(
                    onClick = { showAddCustomPortion = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = null,
                            tint = AppColors.Calorie,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            "Custom Portion Size",
                            color = AppColors.Calorie,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            item { SheetSectionHeader(stringResource(R.string.sheet_nutrition)) }
            item {
                SheetPillCard {
                    SheetEditableNutritionRowInt(stringResource(R.string.nutrition_label_calories), baseEntry.calories, scale, stringResource(R.string.unit_kcal)) { baseEntry = baseEntry.copy(calories = it) }
                    SheetHairline()
                    SheetEditableNutritionRow(stringResource(R.string.nutrition_label_protein), baseEntry.protein, scale, stringResource(R.string.unit_g)) { baseEntry = baseEntry.copy(protein = it ?: 0.0) }
                    SheetHairline()
                    SheetEditableNutritionRow(stringResource(R.string.nutrition_label_carbs), baseEntry.carbs, scale, stringResource(R.string.unit_g)) { baseEntry = baseEntry.copy(carbs = it ?: 0.0) }
                    SheetHairline()
                    SheetEditableNutritionRow(stringResource(R.string.nutrition_label_fat), baseEntry.fat, scale, stringResource(R.string.unit_g)) { baseEntry = baseEntry.copy(fat = it ?: 0.0) }
                }
            }

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
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_sugar), baseEntry.sugar, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(sugar = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_added_sugar), baseEntry.addedSugar, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(addedSugar = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_fiber), baseEntry.fiber, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(fiber = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_saturated_fat), baseEntry.saturatedFat, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(saturatedFat = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_mono_fat), baseEntry.monounsaturatedFat, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(monounsaturatedFat = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_poly_fat), baseEntry.polyunsaturatedFat, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(polyunsaturatedFat = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_cholesterol), baseEntry.cholesterol, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(cholesterol = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_sodium), baseEntry.sodium, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(sodium = it) }
                        SheetHairline()
                        SheetEditableNutritionRow(stringResource(R.string.sheet_micro_potassium), baseEntry.potassium, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(potassium = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Trans Fat", baseEntry.transFat, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(transFat = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Calcium", baseEntry.calcium, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(calcium = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Iron", baseEntry.iron, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(iron = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Magnesium", baseEntry.magnesium, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(magnesium = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Zinc", baseEntry.zinc, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(zinc = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin A", baseEntry.vitaminA, scale, mcgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminA = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin C", baseEntry.vitaminC, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminC = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin D", baseEntry.vitaminD, scale, mcgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminD = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin B12", baseEntry.vitaminB12, scale, mcgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminB12 = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin E", baseEntry.vitaminE, scale, mgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminE = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Vitamin K", baseEntry.vitaminK, scale, mcgUnit, dim = true) { baseEntry = baseEntry.copy(vitaminK = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Folate", baseEntry.folate, scale, mcgUnit, dim = true) { baseEntry = baseEntry.copy(folate = it) }
                        SheetHairline()
                        SheetEditableNutritionRow("Omega-3", baseEntry.omega3, scale, gUnit, dim = true) { baseEntry = baseEntry.copy(omega3 = it) }
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

    if (showAddCustomPortion) {
        AddCustomPortionDialog(
            currentGrams = servingGrams,
            onDismiss = { showAddCustomPortion = false },
            onAdd = { name, grams ->
                val newOption = ServingUnitOption(
                    unit = name,
                    gramsPerUnit = grams,
                    quantity = servingGrams / grams
                )
                val exists = servingUnitOptions.any { it.id == newOption.id }
                servingUnitOptions = if (exists) {
                    servingUnitOptions.map { if (it.id == newOption.id) newOption else it }
                } else {
                    servingUnitOptions + newOption
                }
                selectedServingUnitId = newOption.id
                
                val quantity = if (grams > 0) servingGrams / grams else servingGrams
                servingQuantityText = ServingUnitOption.formatQuantity(quantity)
            }
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
