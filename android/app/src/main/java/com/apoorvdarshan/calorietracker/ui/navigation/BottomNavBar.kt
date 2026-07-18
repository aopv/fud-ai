package com.apoorvdarshan.calorietracker.ui.navigation

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.Composable
import androidx.annotation.StringRes
import com.apoorvdarshan.calorietracker.R
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import kotlinx.coroutines.launch

data class BottomTab(val route: String, val icon: ImageVector, @get:StringRes val labelRes: Int)

val BottomTabs = listOf(
    BottomTab(FudAIRoutes.HOME, Icons.Filled.Home, R.string.nav_home),
    BottomTab(FudAIRoutes.PROGRESS, Icons.Filled.BarChart, R.string.nav_progress),
    BottomTab(FudAIRoutes.COACH, Icons.Filled.Forum, R.string.nav_coach),
    BottomTab(FudAIRoutes.SETTINGS, Icons.Filled.Settings, R.string.nav_settings),
    BottomTab(FudAIRoutes.WORKOUTS, Icons.Filled.FitnessCenter, R.string.nav_workouts)
)

private val BarHeight = 70.dp
private val BarCorner = 35.dp
private val PillCorner = 24.dp
private val PillInsetH = 7.dp
private val PillInsetV = 6.dp

val BottomNavScrollPadding = 132.dp
val BottomNavDockedControlPadding = 82.dp

/**
 * Floating Liquid Glass tab bar — capsule with translucent backdrop, glassy
 * sheen, hairline border, soft shadow, and a spring-animated bright pill
 * behind the active tab.
 *
 * The pill is **draggable**: place a finger anywhere on the bar and slide
 * horizontally to drag it across tabs. Taps still work normally (drag is
 * only claimed after horizontal touch slop). On release the pill snaps to
 * the nearest tab; haptic ticks fire each time the pill crosses a boundary
 * during the drag, mirroring the iOS 26 Liquid Glass tab-bar feel.
 */
@Composable
fun FudAIBottomNavBar(
    currentRoute: String?,
    showAboutBadge: Boolean = false,
    onTap: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val isDark = MaterialTheme.colorScheme.background.let {
        (it.red + it.green + it.blue) / 3f < 0.5f
    }

    val barShape = RoundedCornerShape(BarCorner)

    val backdropColor = if (isDark) Color(0xFF15151A).copy(alpha = 0.92f)
                        else Color(0xFFFCF6F1).copy(alpha = 0.90f)

    val barSheen = Brush.verticalGradient(
        colors = if (isDark)
            listOf(Color.White.copy(alpha = 0.13f), Color.White.copy(alpha = 0.0f))
        else
            listOf(
                Color.White.copy(alpha = 0.70f),
                Color.White.copy(alpha = 0.18f),
                AppColors.Calorie.copy(alpha = 0.030f)
            )
    )

    val barBorder = Brush.linearGradient(
        if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.24f),
                Color.White.copy(alpha = 0.07f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.92f),
                Color.White.copy(alpha = 0.36f),
                AppColors.Calorie.copy(alpha = 0.13f)
            )
        }
    )
    val shadowAlpha = if (isDark) 0.32f else 0.14f

    Box(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        BoxWithConstraints(
            Modifier
                .fillMaxWidth()
                .height(BarHeight)
                .shadow(
                    elevation = if (isDark) 20.dp else 16.dp,
                    shape = barShape,
                    ambientColor = Color.Black.copy(alpha = shadowAlpha),
                    spotColor = Color.Black.copy(alpha = shadowAlpha)
                )
                .clip(barShape)
                .background(backdropColor)
                .background(if (isDark) Brush.linearGradient(listOf(Color.Transparent, Color.Transparent)) else Brush.linearGradient(listOf(Color.White.copy(alpha = 0.18f), AppColors.Calorie.copy(alpha = 0.020f))))
                .background(barSheen)
                .border(0.75.dp, barBorder, barShape)
        ) {
            val density = LocalDensity.current
            val haptic = LocalHapticFeedback.current
            val scope = rememberCoroutineScope()

            val barWidthDp = maxWidth
            val tabCount = BottomTabs.size
            val tabWidthDp = barWidthDp / tabCount
            val tabWidthPx = with(density) { tabWidthDp.toPx() }
            val maxOffsetPx = tabWidthPx * (tabCount - 1)

            val selectedIndex = BottomTabs.indexOfFirst { it.route == currentRoute }
                .coerceAtLeast(0)

            // Spring animator drives the pill when it's NOT being dragged
            // (initial mount, external route changes, settle-after-release).
            val pillAnim = remember { Animatable(0f) }
            var isDragging by remember { mutableStateOf(false) }
            var dragOffsetPx by remember { mutableFloatStateOf(0f) }
            var hoverIndex by remember { mutableIntStateOf(selectedIndex) }

            // Sync pill position once the bar's width has been measured, and on
            // any later external selectedIndex change. Skip while dragging so a
            // mid-drag recomposition doesn't yank the pill back to a snapped
            // position.
            LaunchedEffect(selectedIndex, tabWidthPx) {
                if (!isDragging) {
                    val target = selectedIndex * tabWidthPx
                    if (pillAnim.value == 0f && selectedIndex > 0) {
                        pillAnim.snapTo(target)
                    } else {
                        pillAnim.animateTo(
                            target,
                            spring(
                                dampingRatio = Spring.DampingRatioLowBouncy,
                                stiffness = 320f
                            )
                        )
                    }
                }
            }

            val pillPx = if (isDragging) dragOffsetPx else pillAnim.value
            val pillOffsetDp = with(density) { pillPx.toDp() }

            val pillScale by animateFloatAsState(
                targetValue = if (isDragging) 1.06f else 1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = 380f
                ),
                label = "pillDragScale"
            )

            // Active-tab pill — the bright glass disc.
            ActivePill(
                tabWidth = tabWidthDp,
                isDark = isDark,
                modifier = Modifier
                    .offset(x = pillOffsetDp)
                    .graphicsLayer {
                        scaleX = pillScale
                        scaleY = pillScale
                        transformOrigin = TransformOrigin(0.5f, 0.5f)
                    }
            )

            // Shared drag handlers used by every TabItem. clickable on the
            // tab handles the tap (proven reliable); a sibling pointerInput
            // with detectHorizontalDragGestures handles the drag — both can
            // listen on the same pointer stream because clickable claims on
            // release-without-slop and the drag detector claims on slop.
            fun startDrag() {
                isDragging = true
                dragOffsetPx = pillAnim.value
                hoverIndex = selectedIndex
            }
            fun endDrag() {
                val landed = hoverIndex
                scope.launch {
                    pillAnim.snapTo(dragOffsetPx)
                    isDragging = false
                    pillAnim.animateTo(
                        landed * tabWidthPx,
                        spring(
                            dampingRatio = Spring.DampingRatioLowBouncy,
                            stiffness = 320f
                        )
                    )
                }
                if (BottomTabs[landed].route != currentRoute) {
                    onTap(BottomTabs[landed].route)
                }
            }
            fun onDragDelta(delta: Float) {
                dragOffsetPx = (dragOffsetPx + delta).coerceIn(0f, maxOffsetPx)
                val newHover = ((dragOffsetPx + tabWidthPx / 2f) / tabWidthPx)
                    .toInt().coerceIn(0, tabCount - 1)
                if (newHover != hoverIndex) {
                    hoverIndex = newHover
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
            }

            Row(
                Modifier.fillMaxWidth().fillMaxHeight(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                for (tab in BottomTabs) {
                    val selected = tab.route == currentRoute
                    TabItem(
                        tab = tab,
                        selected = selected,
                        showBadge = showAboutBadge && tab.route == FudAIRoutes.SETTINGS,
                        isDark = isDark,
                        modifier = Modifier
                            .width(tabWidthDp)
                            .fillMaxHeight()
                            .pointerInput(tabWidthPx, tabCount) {
                                if (tabWidthPx <= 0f) return@pointerInput
                                detectHorizontalDragGestures(
                                    onDragStart = { startDrag() },
                                    onDragEnd = { endDrag() },
                                    onDragCancel = { endDrag() },
                                    onHorizontalDrag = { change, dragAmount ->
                                        onDragDelta(dragAmount)
                                        change.consume()
                                    }
                                )
                            }
                    ) { onTap(tab.route) }
                }
            }
        }
    }
}

/**
 * Bright "glass-on-glass" pill highlighting the active tab. Layered on top of
 * the bar so it reads like a brighter slab of glass within the larger one.
 */
@Composable
private fun ActivePill(tabWidth: Dp, isDark: Boolean, modifier: Modifier = Modifier) {
    val pillShape = RoundedCornerShape(PillCorner)

    val fill = if (isDark) Color.White.copy(alpha = 0.15f)
               else AppColors.Calorie.copy(alpha = 0.13f)

    val sheen = Brush.verticalGradient(
        colors = if (isDark)
            listOf(Color.White.copy(alpha = 0.19f), Color.White.copy(alpha = 0.0f))
        else
            listOf(Color.White.copy(alpha = 0.52f), Color.White.copy(alpha = 0.09f))
    )

    val border = Brush.linearGradient(
        listOf(
            Color.White.copy(alpha = if (isDark) 0.28f else 0.70f),
            Color.White.copy(alpha = if (isDark) 0.07f else 0.20f)
        )
    )

    Box(
        modifier
            .width(tabWidth)
            .fillMaxHeight()
            .padding(horizontal = PillInsetH, vertical = PillInsetV)
            .clip(pillShape)
            .background(fill)
            .background(sheen)
            .border(0.75.dp, border, pillShape)
    )
}

@Composable
private fun TabItem(
    tab: BottomTab,
    selected: Boolean,
    showBadge: Boolean,
    isDark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val activeColor = AppColors.Calorie
    val inactiveColor = if (isDark) Color.White.copy(alpha = 0.70f)
                        else Color.Black.copy(alpha = 0.62f)
    val tint = if (selected) activeColor else inactiveColor

    val iconScale by animateFloatAsState(
        targetValue = if (selected) 1.08f else 1.0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = 380f
        ),
        label = "tabIconScale"
    )

    val label = stringResource(tab.labelRes)
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier.clickable(
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box {
            Icon(
                tab.icon,
                contentDescription = label,
                tint = tint,
                modifier = Modifier.size(if (selected) 25.dp else 23.dp).scale(iconScale)
            )
            if (showBadge) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AppColors.Calorie)
                )
            }
        }
        Spacer(Modifier.height(2.dp))
        Text(
            label,
            color = tint,
            fontSize = 11.sp,
            lineHeight = 13.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            letterSpacing = 0.1.sp
        )
    }
}
