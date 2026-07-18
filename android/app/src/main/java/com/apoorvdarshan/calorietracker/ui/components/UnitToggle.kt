package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.ui.theme.FudElevation
import com.apoorvdarshan.calorietracker.ui.theme.FudRadii
import com.apoorvdarshan.calorietracker.ui.theme.FudTheme

/**
 * Two options side-by-side inside a softly inset glass track. The selected
 * segment is a raised neutral surface so unit changes remain calm and legible.
 */
@Composable
fun UnitToggle(
    leftLabel: String,
    rightLabel: String,
    isLeft: Boolean,
    onSelect: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = FudTheme.colors
    val trackShape = RoundedCornerShape(22.dp)
    val trackColor = colors.surfaceMuted.copy(alpha = if (colors.isDark) 0.72f else 0.88f)
    Box(
        modifier = modifier
            .clip(trackShape)
            .background(trackColor)
            .border(
                0.7.dp,
                colors.glassBorder.copy(alpha = if (colors.isDark) 0.42f else 0.72f),
                trackShape
            )
            .padding(4.dp)
    ) {
        Row {
            UnitSegment(
                label = leftLabel,
                selected = isLeft,
                onClick = { if (!isLeft) onSelect(true) },
                modifier = Modifier.weight(1f)
            )
            UnitSegment(
                label = rightLabel,
                selected = !isLeft,
                onClick = { if (isLeft) onSelect(false) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun UnitSegment(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = FudTheme.colors
    val shape = RoundedCornerShape(FudRadii.medium)
    // iOS UISegmentedControl uses a slightly lighter neutral fill for the
    // selected thumb (not an accent colour) — matches that look.
    val bg by animateColorAsState(
        if (selected) {
            if (colors.isDark) colors.surfaceRaised.copy(alpha = 0.96f)
            else Color.White.copy(alpha = 0.82f)
        }
        else Color.Transparent,
        label = "segBg"
    )
    val fg by animateColorAsState(
        if (selected) colors.textPrimary else colors.textSecondary,
        label = "segFg"
    )
    Box(
        modifier = modifier
            .heightIn(min = 40.dp)
            .then(
                if (selected) {
                    Modifier.shadow(
                        elevation = FudElevation.resting,
                        shape = shape,
                        ambientColor = colors.shadow,
                        spotColor = colors.shadow
                    )
                } else Modifier
            )
            .clip(shape)
            .background(bg)
            .border(
                0.6.dp,
                if (selected) colors.glassBorder.copy(alpha = 0.62f) else Color.Transparent,
                shape
            )
            .semantics { this.selected = selected }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Button,
                onClick = onClick
            )
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            color = fg,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium
        )
    }
}
