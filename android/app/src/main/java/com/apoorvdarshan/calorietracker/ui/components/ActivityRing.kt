package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Verbatim port of ios/calorietracker/Views/ActivityRingView.swift.
 *
 * SwiftUI structure preserved:
 *   GeometryReader { geo in
 *       ZStack {
 *           Circle().stroke(track)                              // background track
 *           Circle().trim(0..animated).stroke(angularGradient)  // foreground arc
 *           if animated > 0.01 { glow dot at arc endpoint }     // endpoint dot
 *       }
 *   }
 *   .onAppear { spring(response: 1.2, damping: 0.75).delay(0.15) }
 *   .onChange(of: progress) { spring(response: 0.6, damping: 0.85) }
 */
@Composable
fun ActivityRing(
    progress: Float,
    modifier: Modifier = Modifier,
    size: Dp = 160.dp,
    strokeWidth: Dp = 14.dp,
    gradientColors: List<Color> = listOf(AppColors.CalorieStart, AppColors.CalorieEnd),
    centerContent: @Composable () -> Unit = {}
) {
    val animated = remember { Animatable(0f) }

    // .onAppear { withAnimation(.spring(response: 1.2, dampingFraction: 0.75).delay(0.15)) }
    LaunchedEffect(Unit) {
        delay(150)
        animated.animateTo(
            targetValue = progress.coerceIn(0f, 1.5f),
            animationSpec = spring(dampingRatio = 0.75f, stiffness = 30f) // response 1.2 ≈ stiffness 30
        )
    }
    // .onChange(of: progress) { withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) }
    LaunchedEffect(progress) {
        animated.animateTo(
            targetValue = progress.coerceIn(0f, 1.5f),
            animationSpec = spring(dampingRatio = 0.85f, stiffness = 110f) // response 0.6 ≈ stiffness 110
        )
    }

    val firstColor = gradientColors.firstOrNull() ?: Color.Transparent
    val lastColor = gradientColors.lastOrNull() ?: Color.White
    val trackColor = firstColor.copy(alpha = 0.15f)

    Box(modifier = modifier.size(size).aspectRatio(1f), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(size)) {
            val side = min(this.size.width, this.size.height)
            val stroke = Stroke(width = strokeWidth.toPx(), cap = StrokeCap.Round)
            val diameter = side - strokeWidth.toPx()
            val topLeft = Offset(
                x = (this.size.width - diameter) / 2f,
                y = (this.size.height - diameter) / 2f
            )
            val arcSize = Size(diameter, diameter)
            val centerX = this.size.width / 2f
            val centerY = this.size.height / 2f
            val radius = diameter / 2f

            // Background track — Circle().stroke(gradientColors.first?.opacity(0.15) ?? Color.gray.opacity(0.15))
            drawArc(
                color = trackColor,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = stroke
            )

            // Foreground arc with gradient — AngularGradient + .rotationEffect(.degrees(-90))
            val sweepDegrees = 360f * animated.value.coerceAtMost(1f)
            if (animated.value > 0f) {
                drawArc(
                    brush = Brush.sweepGradient(
                        colors = gradientColors + firstColor, // matches `gradientColors + [first]`
                        center = Offset(centerX, centerY)
                    ),
                    startAngle = -90f,
                    sweepAngle = sweepDegrees,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = stroke
                )
            }

            // Glow dot at arc endpoint — visible when animated > 0.01
            if (animated.value > 0.01f) {
                // SwiftUI does .offset(y: -radius).rotationEffect(.degrees(360 * progress - 90))
                // which places the dot at (-90 + 360*p) degrees on the circle.
                val endAngleRad = Math.toRadians((sweepDegrees - 90f).toDouble())
                val dotX = centerX + radius * cos(endAngleRad).toFloat()
                val dotY = centerY + radius * sin(endAngleRad).toFloat()
                val dotRadius = strokeWidth.toPx() / 2f

                // .shadow(color: last.opacity(0.6), radius: 6) — soft glow
                drawCircle(
                    color = lastColor.copy(alpha = 0.6f),
                    radius = dotRadius * 1.6f,
                    center = Offset(dotX, dotY)
                )
                drawCircle(
                    color = lastColor,
                    radius = dotRadius,
                    center = Offset(dotX, dotY)
                )
            }
        }
        centerContent()
    }
}

/** Ready-made center label: big number + small label (e.g. "1,247\nkcal"). */
@Composable
fun RingCenterLabel(primary: String, secondary: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            primary,
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold
        )
        Text(
            secondary,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}
