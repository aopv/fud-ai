package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.theme.FudRadii
import com.apoorvdarshan.calorietracker.ui.theme.FudTheme

/**
 * Polished selection bottom sheet shared by Settings and Onboarding so the two stay
 * pixel-identical: rounded top corners, the app's surface tint, rounded-card option rows
 * with a glass sheen + accent border, and an accent checkmark on the selected item.
 * Optionally accepts a free-form custom value (e.g. a custom model ID).
 *
 * Mirrors the styling of SettingsScreen's internal ListSheet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> OptionPickerSheet(
    title: String,
    items: List<T>,
    label: @Composable (T) -> String,
    selected: (T) -> Boolean,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit,
    subtitle: (@Composable (T) -> String?)? = null,
    footer: String? = null,
    customPlaceholder: String? = null,
    onCustomSubmit: ((String) -> Unit)? = null
) {
    val colors = FudTheme.colors
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = FudRadii.sheet, topEnd = FudRadii.sheet),
        containerColor = colors.sheet,
        contentColor = colors.textPrimary
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
            Text(title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(12.dp))
            LazyColumn(
                Modifier.fillMaxWidth().heightIn(max = 420.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(items) { item ->
                    OptionPickerRow(
                        label = label(item),
                        subtitle = subtitle?.invoke(item),
                        isSelected = selected(item),
                        onClick = { onSelect(item) }
                    )
                }
            }
            if (onCustomSubmit != null) {
                footer?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = colors.textSecondary
                    )
                }
                var custom by remember { mutableStateOf("") }
                Spacer(Modifier.height(8.dp))
                FudGlassTextField(
                    value = custom,
                    onValueChange = { custom = it },
                    placeholder = customPlaceholder.orEmpty(),
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                FudGlassPrimaryButton(
                    text = stringResource(R.string.action_save),
                    onClick = { if (custom.isNotBlank()) onCustomSubmit(custom.trim()) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun OptionPickerRow(
    label: String,
    subtitle: String?,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val colors = FudTheme.colors
    val shape = RoundedCornerShape(FudRadii.medium)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(shape)
            .background(
                if (isSelected) colors.accent.copy(alpha = if (colors.isDark) 0.16f else 0.11f)
                else colors.surfaceMuted.copy(alpha = if (colors.isDark) 0.68f else 0.78f)
            )
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = if (colors.isDark) 0.075f else 0.20f),
                        Color.White.copy(alpha = if (colors.isDark) 0.018f else 0.045f),
                        colors.accent.copy(alpha = if (isSelected) 0.06f else if (colors.isDark) 0.02f else 0.035f)
                    )
                )
            )
            .border(
                0.7.dp,
                Brush.linearGradient(
                    listOf(
                        colors.glassBorder.copy(alpha = if (colors.isDark) 0.82f else 0.76f),
                        colors.accent.copy(alpha = if (isSelected) 0.26f else if (colors.isDark) 0.07f else 0.12f)
                    )
                ),
                shape
            )
            .semantics { selected = isSelected }
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                label,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                color = colors.textPrimary
            )
            if (!subtitle.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = colors.textSecondary
                )
            }
        }
        if (isSelected) {
            Spacer(Modifier.width(8.dp))
            Icon(
                Icons.Filled.Check,
                contentDescription = stringResource(R.string.sheet_selected_a11y),
                tint = colors.accent,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}
