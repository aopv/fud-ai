package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

@Composable
fun FudGlassSurface(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 0.dp,
    padding: Dp = 16.dp,
    contentAlignment: Alignment = Alignment.TopStart,
    content: @Composable BoxScope.() -> Unit
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val shape = RoundedCornerShape(cornerRadius)
    val baseColor = if (isDark) AppColors.NeoInk else AppColors.NeoPaper
    val shadowColor = if (isDark) Color.Black.copy(alpha = 0.28f)
                      else Color.Black.copy(alpha = 0.11f)
    val borderColor = if (isDark) Color.White else AppColors.NeoInk

    Box(
        modifier = modifier
            .shadow(
                elevation = 8.dp,
                shape = shape,
                ambientColor = shadowColor,
                spotColor = shadowColor
            )
            .clip(shape)
            .background(baseColor)
            .border(2.dp, borderColor, shape)
            .padding(padding),
        contentAlignment = contentAlignment,
        content = content
    )
}

@Composable
fun FudGlassColumn(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 0.dp,
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
    tint: Color = AppColors.NeoCobalt
) {
    val plainIconSize = if (iconSize < size * 0.88f) size * 0.88f else iconSize
    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(plainIconSize)
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
        fontWeight = FontWeight.Medium
    )
) {
    val shape = RoundedCornerShape(0.dp)
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val fieldFill = if (isDark) {
        Color(0xFF141414)
    } else {
        Color.White
    }
    val fieldBorder = if (isDark) Color.White else AppColors.NeoInk
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = singleLine,
        minLines = minLines,
        maxLines = maxLines,
        keyboardOptions = keyboardOptions,
        visualTransformation = visualTransformation,
        textStyle = textStyle,
        cursorBrush = SolidColor(AppColors.NeoCobalt),
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = if (singleLine) 52.dp else 118.dp)
            .clip(shape)
            .background(fieldFill)
            .border(2.dp, fieldBorder, shape)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        decorationBox = { inner ->
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = if (singleLine) Alignment.CenterStart else Alignment.TopStart
            ) {
                if (value.isEmpty() && placeholder.isNotBlank()) {
                    Text(
                        placeholder,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f),
                        fontSize = textStyle.fontSize,
                        fontWeight = FontWeight.Medium
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
                .padding(horizontal = 24.dp),
            cornerRadius = 0.dp,
            padding = 20.dp
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
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
    val brush = if (enabled) {
        Brush.linearGradient(listOf(AppColors.NeoAcid, AppColors.NeoAcid))
    } else {
        Brush.linearGradient(
            listOf(
                AppColors.NeoAcid.copy(alpha = 0.35f),
                AppColors.NeoAcid.copy(alpha = 0.35f)
            )
        )
    }
    Row(
        modifier
            .height(height)
            .clip(RoundedCornerShape(0.dp))
            .background(brush)
            .border(2.dp, AppColors.NeoInk, RoundedCornerShape(0.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        if (content != null) {
            content()
        } else {
            Text(text.uppercase(), color = AppColors.NeoInk, fontWeight = FontWeight.Black, fontSize = 16.sp)
        }
    }
}

@Composable
fun FudGlassTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = AppColors.NeoCobalt
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val shape = RoundedCornerShape(0.dp)
    val fill = if (isDark) {
        Color(0xFF141414)
    } else {
        Color.White
    }
    val border = if (isDark) {
        Color.White
    } else {
        AppColors.NeoInk
    }
    Box(
        modifier
            .clip(shape)
            .background(fill)
            .border(2.dp, border, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text.uppercase(), color = color, fontSize = 15.sp, fontWeight = FontWeight.Black)
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
        val primaryColor = if (destructive) Color(0xFFFF453A) else AppColors.NeoCobalt
        FudGlassTextButton(text = primaryText, onClick = onPrimary, color = primaryColor)
    }
}
