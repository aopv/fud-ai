package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import com.apoorvdarshan.calorietracker.ui.theme.FudElevation
import com.apoorvdarshan.calorietracker.ui.theme.FudRadii
import com.apoorvdarshan.calorietracker.ui.theme.FudSizing
import com.apoorvdarshan.calorietracker.ui.theme.FudSpacing
import com.apoorvdarshan.calorietracker.ui.theme.FudTheme

@Composable
fun FudGlassSurface(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    padding: Dp = 16.dp,
    contentAlignment: Alignment = Alignment.TopStart,
    content: @Composable BoxScope.() -> Unit
) {
    val colors = FudTheme.colors
    val shape = RoundedCornerShape(cornerRadius)
    val sheen = Brush.verticalGradient(
        listOf(
            colors.glassHighlight,
            Color.White.copy(alpha = if (colors.isDark) 0.018f else 0.075f),
            colors.accent.copy(alpha = if (colors.isDark) 0.024f else 0.040f)
        )
    )
    val border = Brush.linearGradient(
        listOf(
            colors.glassBorder,
            Color.White.copy(alpha = if (colors.isDark) 0.045f else 0.24f),
            colors.accent.copy(alpha = if (colors.isDark) 0.065f else 0.12f)
        )
    )

    Box(
        modifier = modifier
            .shadow(
                elevation = if (colors.isDark) FudElevation.floating else FudElevation.raised,
                shape = shape,
                ambientColor = colors.shadow,
                spotColor = colors.shadow
            )
            .clip(shape)
            .background(colors.glassBase)
            .background(sheen)
            .border(FudSpacing.hairline, border, shape)
            .padding(padding),
        contentAlignment = contentAlignment,
        content = content
    )
}

@Composable
fun FudGlassColumn(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    padding: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    FudGlassSurface(
        modifier = modifier,
        cornerRadius = cornerRadius,
        padding = 0.dp
    ) {
        Column(Modifier.padding(padding), content = content)
    }
}

@Composable
fun FudIconBubble(
    icon: ImageVector,
    modifier: Modifier = Modifier,
    size: Dp = 34.dp,
    iconSize: Dp = 19.dp,
    tint: Color = AppColors.Calorie
) {
    val colors = FudTheme.colors
    val bubbleFill = Brush.linearGradient(
        listOf(
            tint.copy(alpha = if (colors.isDark) 0.17f else 0.12f),
            colors.accentEnd.copy(alpha = if (colors.isDark) 0.08f else 0.055f)
        )
    )
    val bubbleBorder = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = if (colors.isDark) 0.14f else 0.62f),
            tint.copy(alpha = if (colors.isDark) 0.18f else 0.22f)
        )
    )
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(bubbleFill)
            .border(0.7.dp, bubbleBorder, CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(iconSize)
        )
    }
}

@Composable
fun FudGlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = if (singleLine) 1 else Int.MAX_VALUE,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    textStyle: TextStyle = TextStyle(
        color = MaterialTheme.colorScheme.onSurface,
        fontSize = 16.sp,
        fontWeight = FontWeight.Normal,
        letterSpacing = 0.05.sp
    )
) {
    val colors = FudTheme.colors
    val shape = RoundedCornerShape(FudRadii.medium)
    val fieldSheen = Brush.verticalGradient(
        listOf(
            Color.White.copy(alpha = if (colors.isDark) 0.08f else 0.22f),
            Color.White.copy(alpha = if (colors.isDark) 0.018f else 0.05f),
            colors.accent.copy(alpha = if (colors.isDark) 0.022f else 0.035f)
        )
    )
    val fieldBorder = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = if (colors.isDark) 0.15f else 0.58f),
            colors.accent.copy(alpha = if (colors.isDark) 0.08f else 0.13f)
        )
    )
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = singleLine,
        minLines = minLines,
        maxLines = maxLines,
        keyboardOptions = keyboardOptions,
        visualTransformation = visualTransformation,
        textStyle = textStyle,
        cursorBrush = SolidColor(colors.accent),
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = if (singleLine) FudSizing.controlHeight else 118.dp)
            .clip(shape)
            .background(colors.field)
            .background(fieldSheen)
            .border(0.7.dp, fieldBorder, shape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        decorationBox = { inner ->
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = if (singleLine) Alignment.CenterStart else Alignment.TopStart
            ) {
                if (value.isEmpty() && placeholder.isNotBlank()) {
                    Text(
                        placeholder,
                        color = colors.textTertiary,
                        fontSize = textStyle.fontSize,
                        fontWeight = FontWeight.Normal
                    )
                }
                inner()
            }
        }
    )
}

@Composable
fun FudGlassDialog(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Dialog(
        onDismissRequest = onDismissRequest,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        FudGlassSurface(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = FudSpacing.extraLarge),
            cornerRadius = FudRadii.sheet,
            padding = FudSpacing.large
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(FudSpacing.regular),
                content = content
            )
        }
    }
}

@Composable
fun FudGlassPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier.fillMaxWidth(),
    enabled: Boolean = true,
    height: Dp = 50.dp,
    content: (@Composable RowScope.() -> Unit)? = null
) {
    val colors = FudTheme.colors
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (isPressed && enabled) 0.985f else 1f,
        animationSpec = tween(durationMillis = 90),
        label = "fudPrimaryPress"
    )
    val brush = if (enabled) {
        Brush.linearGradient(listOf(colors.accent, colors.accentEnd))
    } else {
        Brush.linearGradient(
            listOf(
                colors.surfaceMuted,
                colors.surfaceMuted
            )
        )
    }
    Row(
        modifier
            .heightIn(min = FudSizing.minimumTouchTarget)
            .height(height)
            .graphicsLayer {
                scaleX = pressScale
                scaleY = pressScale
            }
            .shadow(
                elevation = if (enabled) FudElevation.resting else 0.dp,
                shape = RoundedCornerShape(FudRadii.medium),
                ambientColor = colors.accent.copy(alpha = 0.22f),
                spotColor = colors.accent.copy(alpha = 0.22f)
            )
            .clip(RoundedCornerShape(FudRadii.medium))
            .background(brush)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClick = onClick
            )
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        if (content != null) {
            content()
        } else {
            Text(
                text,
                color = if (enabled) colors.onAccent else colors.textTertiary,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
fun FudGlassTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = AppColors.Calorie
) {
    val colors = FudTheme.colors
    val shape = RoundedCornerShape(FudRadii.small)
    val fill = if (colors.isDark) Color.White.copy(alpha = 0.04f) else colors.surfaceMuted.copy(alpha = 0.58f)
    val border = if (colors.isDark) Color.White.copy(alpha = 0.09f) else colors.glassBorder.copy(alpha = 0.62f)
    Box(
        modifier
            .heightIn(min = FudSizing.minimumTouchTarget)
            .clip(shape)
            .background(fill)
            .border(0.6.dp, border, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, color = color, style = MaterialTheme.typography.labelLarge)
    }
}

@Composable
fun FudGlassDialogActions(
    primaryText: String,
    onPrimary: () -> Unit,
    modifier: Modifier = Modifier,
    dismissText: String? = null,
    onDismiss: (() -> Unit)? = null,
    destructive: Boolean = false
) {
    Row(
        modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (dismissText != null && onDismiss != null) {
            FudGlassTextButton(
                text = dismissText,
                onClick = onDismiss,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            Spacer(Modifier.width(6.dp))
        }
        val primaryColor = if (destructive) FudTheme.colors.error else AppColors.Calorie
        FudGlassTextButton(text = primaryText, onClick = onPrimary, color = primaryColor)
    }
}
