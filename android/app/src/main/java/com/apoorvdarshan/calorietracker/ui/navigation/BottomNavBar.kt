package com.apoorvdarshan.calorietracker.ui.navigation

import androidx.annotation.StringRes
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsGymnastics
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.WorkoutTabMode
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import kotlinx.coroutines.launch

/** Native navigation routes paired with their tactile Kitchen Table objects. */
data class BottomTab(
    val route: String,
    val icon: ImageVector,
    @get:StringRes val labelRes: Int,
    @get:DrawableRes val drawableRes: Int
)

val BottomTabs = listOf(
    BottomTab(FudAIRoutes.HOME, Icons.Filled.Home, R.string.nav_home, R.drawable.kt_nav_home),
    BottomTab(FudAIRoutes.PROGRESS, Icons.Filled.BarChart, R.string.nav_progress, R.drawable.kt_nav_progress),
    BottomTab(FudAIRoutes.COACH, Icons.Filled.Forum, R.string.nav_coach, R.drawable.kt_nav_coach),
    BottomTab(FudAIRoutes.SETTINGS, Icons.Filled.Settings, R.string.nav_settings, R.drawable.kt_nav_settings),
    BottomTab(FudAIRoutes.WORKOUTS, Icons.Filled.FitnessCenter, R.string.nav_workouts, R.drawable.kt_nav_workouts)
)

private val BarHeight = 72.dp
val BottomNavScrollPadding = 112.dp
val BottomNavDockedControlPadding = 76.dp

@Composable
fun FudAIBottomNavBar(
    currentRoute: String?,
    showAboutBadge: Boolean = false,
    workoutMode: WorkoutTabMode = WorkoutTabMode.Default,
    onTap: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val tabs = remember(workoutMode) {
        BottomTabs.map { tab ->
            if (tab.route != FudAIRoutes.WORKOUTS) tab else tab.copy(
                icon = if (workoutMode == WorkoutTabMode.LOG) {
                    Icons.Filled.SportsGymnastics
                } else {
                    Icons.Filled.FitnessCenter
                }
            )
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 0.dp, vertical = 0.dp)
            .shadow(
                elevation = 5.dp,
                shape = RoundedCornerShape(topStart = 7.dp, topEnd = 7.dp),
                ambientColor = Color.Black.copy(alpha = 0.11f),
                spotColor = Color.Black.copy(alpha = 0.11f)
            )
            .clip(RoundedCornerShape(topStart = 7.dp, topEnd = 7.dp))
            .background(AppColors.KitchenPaper)
            .border(
                1.dp,
                AppColors.KitchenEspresso.copy(alpha = 0.18f),
                RoundedCornerShape(topStart = 7.dp, topEnd = 7.dp)
            )
            .height(BarHeight)
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(2.dp)
                .background(AppColors.KitchenBrass.copy(alpha = 0.5f))
        )
        BoxWithConstraints(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .padding(horizontal = 2.dp, vertical = 2.dp)
        ) {
            val density = LocalDensity.current
            val haptic = LocalHapticFeedback.current
            val scope = rememberCoroutineScope()
            val tabCount = tabs.size
            val tabWidthDp = maxWidth / tabCount
            val tabWidthPx = with(density) { tabWidthDp.toPx() }
            val maxOffsetPx = tabWidthPx * (tabCount - 1)
            val selectedIndex = tabs.indexOfFirst { it.route == currentRoute }.coerceAtLeast(0)

            // Keep the original swipe-to-select contract: the active marker follows
            // the finger, haptics tick at tab boundaries, and release selects the
            // nearest route. Taps remain owned by each selectable tab.
            val markerAnim = remember { Animatable(0f) }
            var isDragging by remember { mutableStateOf(false) }
            var dragOffsetPx by remember { mutableFloatStateOf(0f) }
            var hoverIndex by remember { mutableIntStateOf(selectedIndex) }

            LaunchedEffect(selectedIndex, tabWidthPx) {
                if (!isDragging) {
                    val target = selectedIndex * tabWidthPx
                    if (markerAnim.value == 0f && selectedIndex > 0) {
                        markerAnim.snapTo(target)
                    } else {
                        markerAnim.animateTo(
                            target,
                            spring(
                                dampingRatio = Spring.DampingRatioLowBouncy,
                                stiffness = 320f
                            )
                        )
                    }
                }
            }

            fun startDrag() {
                isDragging = true
                dragOffsetPx = markerAnim.value
                hoverIndex = selectedIndex
            }

            fun endDrag() {
                val landed = hoverIndex
                scope.launch {
                    markerAnim.snapTo(dragOffsetPx)
                    isDragging = false
                    markerAnim.animateTo(
                        landed * tabWidthPx,
                        spring(
                            dampingRatio = Spring.DampingRatioLowBouncy,
                            stiffness = 320f
                        )
                    )
                }
                if (tabs[landed].route != currentRoute) onTap(tabs[landed].route)
            }

            fun onDragDelta(delta: Float) {
                dragOffsetPx = (dragOffsetPx + delta).coerceIn(0f, maxOffsetPx)
                val newHover = ((dragOffsetPx + tabWidthPx / 2f) / tabWidthPx)
                    .toInt()
                    .coerceIn(0, tabCount - 1)
                if (newHover != hoverIndex) {
                    hoverIndex = newHover
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
            }

            val markerOffsetDp = with(density) {
                (if (isDragging) dragOffsetPx else markerAnim.value).toDp()
            }
            Box(
                Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = markerOffsetDp)
                    .width(tabWidthDp)
                    .height(2.dp)
                    .padding(horizontal = tabWidthDp * 0.26f)
                    .background(AppColors.KitchenTomato)
            )

            Row(
                Modifier.fillMaxWidth().fillMaxHeight(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                tabs.forEachIndexed { index, tab ->
                    KitchenTabItem(
                        tab = tab,
                        selected = index == if (isDragging) hoverIndex else selectedIndex,
                        showBadge = showAboutBadge && tab.route == FudAIRoutes.SETTINGS,
                        objectRotation = listOf(-4f, 2f, -2f, 3f, -5f)[index],
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
                            },
                        onClick = { onTap(tab.route) }
                    )
                }
            }
        }
    }
}

@Composable
private fun KitchenTabItem(
    tab: BottomTab,
    selected: Boolean,
    showBadge: Boolean,
    objectRotation: Float,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.04f else 1f,
        animationSpec = spring(dampingRatio = 0.82f, stiffness = 420f),
        label = "kitchenTabObject"
    )
    val label = stringResource(tab.labelRes)
    val ink = if (selected) AppColors.KitchenTomato else AppColors.KitchenEspresso

    Column(
        modifier = modifier
            .semantics(mergeDescendants = true) {}
            .selectable(
                selected = selected,
                role = Role.Tab,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(contentAlignment = Alignment.Center) {
            Image(
                painter = painterResource(tab.drawableRes),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .size(38.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        rotationZ = objectRotation
                    }
            )
            if (tab.route == FudAIRoutes.WORKOUTS) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(18.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(AppColors.KitchenPaper)
                        .border(
                            1.dp,
                            ink.copy(alpha = 0.52f),
                            RoundedCornerShape(3.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = tab.icon,
                        contentDescription = null,
                        tint = ink,
                        modifier = Modifier.size(13.dp)
                    )
                }
            }
            if (showBadge) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AppColors.KitchenTomato)
                )
            }
        }
        Spacer(Modifier.height(0.dp))
        Text(
            text = label,
            color = ink,
            fontFamily = MaterialTheme.typography.labelSmall.fontFamily,
            fontSize = 8.sp,
            fontWeight = if (selected) FontWeight.Black else FontWeight.Bold,
            maxLines = 1
        )
        Spacer(Modifier.height(2.dp))
    }
}
