package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Icon
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.ServingUnitOption
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

// Shared visual primitives for the food review/edit sheets. Names are
// `Sheet*`-prefixed so they don't collide with the look-alike privates in
// HomeScreen.kt and NutritionDetailSheet.kt.

private val SheetSurfaceShape = RoundedCornerShape(22.dp)
private val SheetControlShape = RoundedCornerShape(16.dp)

@Composable
internal fun SheetReviewToolbar(
    title: String,
    primaryLabel: String,
    secondaryLabel: String? = null,
    onCancel: () -> Unit,
    onPrimary: () -> Unit,
    onSecondary: (() -> Unit)? = null
) {
    val compact = LocalConfiguration.current.screenWidthDp < 400
    val outerPadding = if (compact) 8.dp else 16.dp
    val itemGap = if (compact) 4.dp else 8.dp
    Row(
        Modifier.fillMaxWidth().padding(horizontal = outerPadding, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SheetToolbarPill(stringResource(R.string.action_cancel), compact = compact, onClick = onCancel)
        Spacer(Modifier.width(itemGap))
        Text(
            title,
            fontSize = if (compact) 16.sp else 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.94f),
            lineHeight = 20.sp,
            letterSpacing = (-0.1).sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f)
        )
        Spacer(Modifier.width(itemGap))
        if (secondaryLabel != null && onSecondary != null) {
            SheetToolbarPill(secondaryLabel, compact = compact, onClick = onSecondary)
            Spacer(Modifier.width(itemGap))
        }
        SheetToolbarPill(primaryLabel, bold = true, compact = compact, onClick = onPrimary)
    }
}

@Composable
private fun SheetToolbarPill(
    label: String,
    bold: Boolean = false,
    compact: Boolean = false,
    onClick: () -> Unit
) {
    val shape = CircleShape
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val horizontalPadding = when {
        compact && bold -> 12.dp
        compact -> 10.dp
        else -> 16.dp
    }
    val pillVisual = if (bold) {
        Modifier
            .shadow(
                elevation = 6.dp,
                shape = shape,
                ambientColor = AppColors.Calorie.copy(alpha = 0.18f),
                spotColor = AppColors.Calorie.copy(alpha = 0.18f)
            )
            .clip(shape)
            .background(Brush.linearGradient(listOf(AppColors.CalorieStart, AppColors.CalorieEnd)))
            .background(
                Brush.verticalGradient(
                    listOf(Color.White.copy(alpha = 0.18f), Color.Transparent)
                )
            )
            .border(0.7.dp, Color.White.copy(alpha = 0.20f), shape)
    } else {
        Modifier
            .clip(shape)
            .background(
                if (isDark) {
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.48f)
                } else {
                    Color(0xFFF0E5DE).copy(alpha = 0.92f)
                }
            )
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = if (isDark) 0.10f else 0.30f),
                        Color.White.copy(alpha = if (isDark) 0.02f else 0.08f)
                    )
                )
            )
            .border(
                0.75.dp,
                Color.White.copy(alpha = if (isDark) 0.14f else 0.56f),
                shape
            )
    }
    Box(
        Modifier
            .heightIn(min = 48.dp)
            .clip(shape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Box(
            pillVisual
                .padding(horizontal = horizontalPadding, vertical = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                label,
                color = if (bold) AppColors.OnAccent else AppColors.Calorie,
                fontSize = if (compact) 14.sp else 15.sp,
                lineHeight = 18.sp,
                fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Medium,
                letterSpacing = 0.05.sp
            )
        }
    }
}

@Composable
internal fun SheetSectionHeader(title: String) {
    Text(
        title,
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.64f),
        letterSpacing = 0.2.sp,
        modifier = Modifier.padding(start = 18.dp, top = 10.dp, bottom = 5.dp)
    )
}

@Composable
internal fun SheetPillRow(
    onClick: (() -> Unit)? = null,
    content: @Composable RowScope.() -> Unit
) {
    val shape = SheetSurfaceShape
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val rowFill = if (isDark) {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.46f)
    } else {
        Color(0xFFF0E4DE).copy(alpha = 0.92f)
    }
    val rowSheen = Brush.verticalGradient(
        listOf(
            Color.White.copy(alpha = if (isDark) 0.10f else 0.28f),
            Color.White.copy(alpha = if (isDark) 0.025f else 0.07f),
            AppColors.Calorie.copy(alpha = if (isDark) 0.025f else 0.050f)
        )
    )
    val rowBorder = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = if (isDark) 0.18f else 0.62f),
            AppColors.Calorie.copy(alpha = if (isDark) 0.07f else 0.15f)
        )
    )
    val shadowColor = Color.Black.copy(alpha = if (isDark) 0.22f else 0.09f)
    val base = Modifier
        .fillMaxWidth()
        .shadow(
            elevation = 5.dp,
            shape = shape,
            ambientColor = shadowColor,
            spotColor = shadowColor
        )
        .clip(shape)
        .background(rowFill)
        .background(rowSheen)
        .border(0.75.dp, rowBorder, shape)
    val withClick = if (onClick != null) base.clickable(onClick = onClick) else base
    Row(
        withClick.padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content
    )
}

@Composable
internal fun SheetPillCard(content: @Composable ColumnScope.() -> Unit) {
    val shape = SheetSurfaceShape
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val cardFill = if (isDark) {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.46f)
    } else {
        Color(0xFFF0E4DE).copy(alpha = 0.92f)
    }
    val cardSheen = Brush.verticalGradient(
        listOf(
            Color.White.copy(alpha = if (isDark) 0.10f else 0.28f),
            Color.White.copy(alpha = if (isDark) 0.025f else 0.07f),
            AppColors.Calorie.copy(alpha = if (isDark) 0.025f else 0.050f)
        )
    )
    val cardBorder = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = if (isDark) 0.18f else 0.62f),
            AppColors.Calorie.copy(alpha = if (isDark) 0.07f else 0.15f)
        )
    )
    val shadowColor = Color.Black.copy(alpha = if (isDark) 0.22f else 0.09f)
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 5.dp,
                shape = shape,
                ambientColor = shadowColor,
                spotColor = shadowColor
            )
            .clip(shape)
            .background(cardFill)
            .background(cardSheen)
            .border(0.75.dp, cardBorder, shape)
            .padding(vertical = 4.dp),
        content = content
    )
}

@Composable
internal fun ServingQuantityCard(
    quantityText: String,
    onQuantityChange: (String) -> Unit,
    selectedUnitId: String,
    onSelectedUnitChange: (String) -> Unit,
    servingSizeGrams: Double,
    unitOptions: List<ServingUnitOption>,
    menuExpanded: Boolean,
    onMenuExpandedChange: (Boolean) -> Unit,
    gramUnit: String
) {
    val pickerOptions = ServingUnitOption.pickerOptions(unitOptions)
    val selectedOption = ServingUnitOption.optionMatching(selectedUnitId, unitOptions)
    val parsedQuantity = ServingUnitOption.parseQuantity(quantityText)
    val selectedUnitLabel = selectedOption.displayUnit(parsedQuantity)
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    val compact = LocalConfiguration.current.screenWidthDp < 380
    val quantityFieldWidth = if (compact) 64.dp else 72.dp
    val unitLabelMaxWidth = if (compact) 64.dp else 82.dp
    val dismissKeyboard = {
        focusManager.clearFocus(force = true)
        keyboardController?.hide()
    }
    val focusRequester = remember { FocusRequester() }
    var quantityFieldValue by remember {
        mutableStateOf(TextFieldValue(quantityText, selection = TextRange(quantityText.length)))
    }

    LaunchedEffect(quantityText) {
        if (quantityText != quantityFieldValue.text) {
            quantityFieldValue = TextFieldValue(
                text = quantityText,
                selection = TextRange(quantityText.length)
            )
        }
    }

    SheetPillCard {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .padding(horizontal = 18.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                stringResource(R.string.sheet_quantity),
                fontSize = 17.sp,
                modifier = Modifier
                    .padding(end = 8.dp)
                    .clickable { dismissKeyboard() }
            )
            Spacer(
                Modifier
                    .weight(1f)
                    .clickable { dismissKeyboard() }
            )
            BasicTextField(
                value = quantityFieldValue,
                onValueChange = { newValue ->
                    quantityFieldValue = newValue.copy(
                        selection = TextRange(newValue.text.length)
                    )
                    onQuantityChange(newValue.text)
                },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                textStyle = TextStyle(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.End
                ),
                cursorBrush = SolidColor(AppColors.Calorie),
                modifier = Modifier
                    .width(quantityFieldWidth)
                    .focusRequester(focusRequester)
            )
            if (quantityText.isNotEmpty()) {
                Spacer(Modifier.width(2.dp))
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .clickable {
                            quantityFieldValue = TextFieldValue("", selection = TextRange.Zero)
                            onQuantityChange("")
                            focusRequester.requestFocus()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Cancel,
                        contentDescription = stringResource(R.string.cd_clear_quantity),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.52f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            Spacer(Modifier.width(2.dp))
            if (pickerOptions.size > 1) {
                Box {
                    Row(
                        modifier = Modifier
                            .heightIn(min = 48.dp)
                            .clip(SheetControlShape)
                            .clickable {
                                dismissKeyboard()
                                onMenuExpandedChange(true)
                            }
                            .padding(horizontal = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            selectedUnitLabel,
                            fontSize = 17.sp,
                            color = AppColors.Calorie,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            textAlign = TextAlign.End,
                            modifier = Modifier.widthIn(min = 32.dp, max = unitLabelMaxWidth)
                        )
                        Icon(
                            Icons.Filled.UnfoldMore,
                            contentDescription = null,
                            tint = AppColors.Calorie
                        )
                    }
                    SheetGlassDropdownMenu(
                        expanded = menuExpanded,
                        onDismissRequest = { onMenuExpandedChange(false) },
                        menuWidth = 150.dp
                    ) {
                        for (option in pickerOptions) {
                            val optionLabel = option.displayUnit(
                                if (option.id == selectedUnitId) parsedQuantity else null
                            )
                            SheetGlassDropdownMenuItem(
                                label = optionLabel,
                                selected = option.id == selectedUnitId,
                                reserveSelectionSlot = true,
                                onClick = {
                                    onSelectedUnitChange(option.id)
                                    onMenuExpandedChange(false)
                                }
                            )
                        }
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .clickable { dismissKeyboard() },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        gramUnit,
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.64f)
                    )
                }
            }
        }

        if (!selectedOption.isGramUnit) {
            SheetHairline()
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(stringResource(R.string.label_total), fontSize = 17.sp, modifier = Modifier.weight(1f))
                Text(
                    "~${sheetFormatGrams(servingSizeGrams)} $gramUnit",
                    fontSize = 17.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            }
        }
    }
}

@Composable
internal fun SheetNutritionRow(label: String, value: String, unit: String, dim: Boolean = false) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            fontSize = 16.sp,
            color = if (dim) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
        Text(
            value,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(Modifier.width(6.dp))
        Text(
            unit,
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            modifier = Modifier.width(36.dp)
        )
    }
}

@Composable
internal fun SheetHairline() {
    Box(
        Modifier
            .padding(start = 18.dp)
            .fillMaxWidth()
            .height(0.5.dp)
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
    )
}

@Composable
internal fun SheetGlassDropdownMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    menuWidth: Dp? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = SheetSurfaceShape
    val sizedModifier = if (menuWidth != null) modifier.width(menuWidth) else modifier
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val menuContainer = if (isDark) Color(0xFA141416) else Color(0xFFFCF6F2).copy(alpha = 0.99f)
    val menuSheen = Brush.verticalGradient(
        colors = if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.065f),
                Color.White.copy(alpha = 0.020f),
                AppColors.Calorie.copy(alpha = 0.030f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.76f),
                Color.White.copy(alpha = 0.28f),
                AppColors.Calorie.copy(alpha = 0.035f)
            )
        }
    )
    val menuBorder = Brush.linearGradient(
        colors = if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.20f),
                Color.White.copy(alpha = 0.065f),
                AppColors.Calorie.copy(alpha = 0.08f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.96f),
                Color.White.copy(alpha = 0.44f),
                AppColors.Calorie.copy(alpha = 0.13f)
            )
        }
    )

    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismissRequest,
        shape = shape,
        containerColor = menuContainer,
        tonalElevation = 0.dp,
        shadowElevation = 16.dp,
        modifier = sizedModifier
            .background(menuSheen, shape)
            .border(0.8.dp, menuBorder, shape)
            .padding(vertical = 5.dp),
        content = content
    )
}

@Composable
internal fun SheetGlassDropdownMenuItem(
    label: String,
    selected: Boolean = false,
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    reserveSelectionSlot: Boolean = false,
    onClick: () -> Unit
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val checkTint = if (isDark) Color.White else AppColors.Calorie
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 7.dp, vertical = 1.dp)
            .heightIn(min = 48.dp)
            .clip(SheetControlShape)
            .background(
                if (selected) {
                    AppColors.Calorie.copy(alpha = if (isDark) 0.14f else 0.09f)
                } else {
                    Color.Transparent
                }
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        when {
            leadingIcon != null -> {
                Icon(
                    leadingIcon,
                    contentDescription = null,
                    tint = AppColors.Calorie,
                    modifier = Modifier.size(19.dp)
                )
                Spacer(Modifier.width(10.dp))
            }
            reserveSelectionSlot -> {
                Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) {
                    if (selected) {
                        Icon(
                            Icons.Filled.Check,
                            contentDescription = null,
                            tint = checkTint,
                            modifier = Modifier.size(17.dp)
                        )
                    }
                }
                Spacer(Modifier.width(8.dp))
            }
        }

        Text(
            label,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.94f),
            lineHeight = 19.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )

        if (selected && leadingIcon != null) {
            Spacer(Modifier.width(8.dp))
            Icon(
                Icons.Filled.Check,
                contentDescription = null,
                tint = checkTint,
                modifier = Modifier.size(17.dp)
            )
        } else if (trailingIcon != null) {
            Spacer(Modifier.width(8.dp))
            Icon(
                trailingIcon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

internal fun sheetMealIcon(meal: MealType): ImageVector = when (meal) {
    MealType.BREAKFAST -> Icons.Filled.WbTwilight
    MealType.LUNCH -> Icons.Filled.WbSunny
    MealType.DINNER -> Icons.Filled.Bedtime
    MealType.SNACK -> Icons.Filled.LocalCafe
    MealType.OTHER -> Icons.Filled.Restaurant
}

internal fun sheetFormatGrams(value: Double): String =
    if (value == value.toInt().toDouble()) value.toInt().toString()
    else String.format("%.1f", value)
