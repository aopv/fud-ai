package com.apoorvdarshan.calorietracker.ui.home

import android.Manifest
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.runtime.saveable.rememberSaveable
import com.apoorvdarshan.calorietracker.ui.navigation.LocalLaunchFillEpoch
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.FloatingActionButton
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.DriveFileRenameOutline
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Coffee
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ImageSearch
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Nightlight
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import com.apoorvdarshan.calorietracker.ui.util.clockTimePattern
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FastingSession
import com.apoorvdarshan.calorietracker.models.formatFastingDuration
import com.apoorvdarshan.calorietracker.services.MealShare
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.HomeTopNutrient
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.QuickAction
import com.apoorvdarshan.calorietracker.models.QuickActionRequest
import com.apoorvdarshan.calorietracker.models.ServingUnitOption
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysis
import com.apoorvdarshan.calorietracker.ui.components.InAppCameraCaptureDialog
import com.apoorvdarshan.calorietracker.ui.components.DateWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.components.FudGlassPrimaryButton
import com.apoorvdarshan.calorietracker.ui.components.FudGlassSurface
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextField
import com.apoorvdarshan.calorietracker.ui.components.KitchenReceiptRule
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavScrollPadding
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.WeekFields
import java.util.Locale
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

private enum class AddMenuGroup {
    PhotoAndScan,
    DescribeMeal,
    ReuseMeal,
    Water,
    Fasting
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    container: AppContainer,
    quickActionRequest: QuickActionRequest? = null,
    initialEntryId: String? = null,
    capabilityOnly: Boolean = false,
    onCapabilityClose: (() -> Unit)? = null,
    onQuickActionHandled: (Long) -> Unit = {}
) {
    val vm: HomeViewModel = viewModel(factory = HomeViewModel.Factory(container))
    val ui by vm.ui.collectAsState()
    val ctx = LocalContext.current
    val allEntries by container.foodRepository.entries.collectAsState(initial = emptyList())

    var showText by remember { mutableStateOf(false) }
    var showVoice by remember { mutableStateOf(false) }
    var showManual by remember { mutableStateOf(false) }
    var savedMealsTab by remember { mutableStateOf<SavedTab?>(null) }
    var showBarcodeScanner by remember { mutableStateOf(false) }
    var showCopyFromDay by remember { mutableStateOf(false) }
    var showAddMenu by remember { mutableStateOf(false) }
    var addMenuGroup by remember { mutableStateOf<AddMenuGroup?>(null) }
    var showSortMenu by remember { mutableStateOf(false) }
    var editingEntry by remember { mutableStateOf<FoodEntry?>(null) }
    var handledInitialEntryId by remember { mutableStateOf<String?>(null) }
    var showNutritionDetail by remember { mutableStateOf(false) }
    var showCustomWaterLog by remember { mutableStateOf(false) }
    var showFastingStart by remember { mutableStateOf(false) }
    var editingFast by remember { mutableStateOf<FastingSession?>(null) }

    var showCameraCapture by remember { mutableStateOf(false) }
    var showMultiPhotoCapture by remember { mutableStateOf(false) }
    var pendingCaptureImageBytes by remember { mutableStateOf<List<ByteArray>>(emptyList()) }
    var isImportingPhotos by remember { mutableStateOf(false) }
    val finishCapability = {
        if (capabilityOnly) onCapabilityClose?.invoke()
    }

    LaunchedEffect(initialEntryId, allEntries) {
        if (initialEntryId != null && handledInitialEntryId != initialEntryId) {
            allEntries.firstOrNull { it.id.toString() == initialEntryId }?.let {
                editingEntry = it
                handledInitialEntryId = initialEntryId
            }
        }
    }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 10)
    ) { uris ->
        val remaining = 10 - pendingCaptureImageBytes.size
        val imported = uris.take(remaining).mapNotNull { uri ->
            ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }
        if (imported.isNotEmpty()) {
            pendingCaptureImageBytes = (pendingCaptureImageBytes + imported).take(10)
        }
        if (pendingCaptureImageBytes.isNotEmpty()) showMultiPhotoCapture = true
        else finishCapability()
    }

    val cameraPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            pendingCaptureImageBytes = emptyList()
            showCameraCapture = true
        } else finishCapability()
    }

    fun openCamera() {
        isImportingPhotos = false
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingCaptureImageBytes = emptyList()
            showCameraCapture = true
        } else {
            cameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    val barcodePermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) showBarcodeScanner = true else finishCapability()
    }

    fun openBarcodeScanner() {
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            showBarcodeScanner = true
        } else {
            barcodePermission.launch(Manifest.permission.CAMERA)
        }
    }

    LaunchedEffect(
        quickActionRequest?.id,
        ui.analyzing,
        ui.pendingAnalysis,
        ui.error
    ) {
        val request = quickActionRequest ?: return@LaunchedEffect
        if (ui.analyzing || ui.pendingAnalysis != null || ui.error != null) return@LaunchedEffect

        showText = false
        showVoice = false
        showManual = false
        savedMealsTab = null
        showBarcodeScanner = false
        showCopyFromDay = false
        showAddMenu = false
        addMenuGroup = null
        editingEntry = null
        showNutritionDetail = false
        showCustomWaterLog = false
        showFastingStart = false
        editingFast = null
        showCameraCapture = false
        showMultiPhotoCapture = false
        vm.setSelectedDate(LocalDate.now())

        when (request.action) {
            QuickAction.CAMERA -> openCamera()
            QuickAction.PHOTOS -> {
                isImportingPhotos = true
                pendingCaptureImageBytes = emptyList()
                photoPicker.launch(
                    PickVisualMediaRequest(
                        ActivityResultContracts.PickVisualMedia.ImageOnly
                    )
                )
            }
            QuickAction.VOICE -> showVoice = true
            QuickAction.TEXT -> showText = true
            QuickAction.BARCODE -> openBarcodeScanner()
            QuickAction.FAVORITES -> savedMealsTab = SavedTab.FAVORITES
            QuickAction.FREQUENT -> savedMealsTab = SavedTab.FREQUENT
            QuickAction.RECENT -> savedMealsTab = SavedTab.RECENTS
            QuickAction.MANUAL -> showManual = true
        }
        onQuickActionHandled(request.id)
    }

    val today = LocalDate.now()
    val selectedDate = ui.date
    val isToday = selectedDate == today
    val mealGroups = remember(ui.todayEntries, ui.foodLogSortOrder) {
        foodLogMealGroups(ui.todayEntries, ui.foodLogSortOrder)
    }
    val completedFasts = remember(ui.fastingSessions, selectedDate) {
        ui.fastingSessions.filter { session ->
            session.endedAt?.atZone(ZoneId.systemDefault())?.toLocalDate() == selectedDate
        }.sortedByDescending { it.endedAt }
    }

    // Targeted native capability routes keep a minimal v7 backdrop behind the
    // camera/editor sheet instead of flashing the retired native Home layout.
    if (capabilityOnly) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Transparent)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            FudGlassSurface(modifier = Modifier.fillMaxWidth(), padding = 22.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(
                        "FÜD AI",
                        color = AppColors.NeoCobalt,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Black
                    )
                    Text(
                        if (initialEntryId != null) "EDIT FOOD" else "ADD FOOD",
                        fontSize = 34.sp,
                        fontWeight = FontWeight.Black
                    )
                    Text(
                        "Complete the native capability, then return to your shared diary.",
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.66f)
                    )
                    if (onCapabilityClose != null) {
                        FudGlassPrimaryButton(
                            text = "Back to Füd AI",
                            onClick = onCapabilityClose
                        )
                    }
                }
            }
        }
    } else {
    // No topBar: the empty TopAppBar used to act as the status-bar spacer, but the
    // ad strip above this screen (TabWithBanner) now owns that inset.
    Scaffold(
        containerColor = Color.Transparent,
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(top = 2.dp, bottom = BottomNavScrollPadding + 60.dp)
        ) {
            item(key = "home-masthead") {
                KitchenTodayHeader(
                    selectedDate = selectedDate,
                    isToday = isToday,
                    onCalendarClick = {
                        android.app.DatePickerDialog(
                            ctx,
                            { _, year, month, day ->
                                vm.setSelectedDate(LocalDate.of(year, month + 1, day))
                            },
                            selectedDate.year,
                            selectedDate.monthValue - 1,
                            selectedDate.dayOfMonth
                        ).apply {
                            datePicker.maxDate = today
                                .atStartOfDay(ZoneId.systemDefault())
                                .toInstant()
                                .toEpochMilli()
                        }.show()
                    },
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 1.dp)
                )
            }

            // Fasting timeline. It is a separate model and never participates in
            // FoodEntry totals, macros, meal grouping, Health nutrition, or exports.
            if (ui.fastingTrackingEnabled && ((isToday && ui.activeFast != null) || completedFasts.isNotEmpty())) {
                item { SectionHeader(stringResource(R.string.fasting)) }
                if (isToday) {
                    ui.activeFast?.let { session ->
                        item(key = "active-fast-${session.id}") {
                            SectionCardWrapper(isFirst = true, isLast = completedFasts.isEmpty()) {
                                ActiveFastingRow(
                                    session = session,
                                    onClick = { editingFast = session }
                                )
                            }
                        }
                    }
                }
                items(completedFasts, key = { "fast-${it.id}" }) { session ->
                    val index = completedFasts.indexOf(session)
                    val hasActive = isToday && ui.activeFast != null
                    SectionCardWrapper(
                        isFirst = !hasActive && index == 0,
                        isLast = index == completedFasts.lastIndex
                    ) {
                        CompletedFastingRow(session = session, onClick = { editingFast = session })
                    }
                }
            }

            // Food log
            item { Spacer(Modifier.height(1.dp)) }
            if (mealGroups.isEmpty()) {
                item { SectionHeader(if (isToday) stringResource(R.string.home_todays_food) else stringResource(R.string.home_food_log)) }
                item {
                    SectionCardWrapper(isFirst = true, isLast = true) {
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 13.dp, vertical = 11.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Icon(
                                Icons.Filled.Restaurant,
                                contentDescription = null,
                                tint = AppColors.KitchenHerb,
                                modifier = Modifier.size(20.dp)
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                                Text(
                                    stringResource(R.string.home_no_foods_logged),
                                    style = MaterialTheme.typography.titleSmall,
                                    color = AppColors.KitchenEspresso
                                )
                                Text(
                                    stringResource(R.string.home_add_food),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = AppColors.KitchenEspresso.copy(alpha = 0.52f)
                                )
                            }
                        }
                    }
                }
            } else {
                for ((groupIndex, group) in mealGroups.withIndex()) {
                    item(key = "header-${group.id}") {
                        MealSectionHeader(
                            meal = group.meal,
                            totalCalories = group.totalCalories,
                            totalProtein = group.totalProtein,
                            totalCarbs = group.totalCarbs,
                            totalFat = group.totalFat,
                            onShare = { MealShare.share(ctx, group.entries) },
                            showSortMenu = groupIndex == 0,
                            sortOrder = ui.foodLogSortOrder,
                            sortMenuExpanded = showSortMenu,
                            onSortClick = { showSortMenu = true },
                            onSortDismiss = { showSortMenu = false },
                            onSortOrderSelected = { order ->
                                showSortMenu = false
                                vm.setFoodLogSortOrder(order)
                            }
                        )
                    }
                    items(group.entries, key = { it.id }) { entry ->
                        val index = group.entries.indexOf(entry)
                        val scrapbookIndex = groupIndex * 5 + index
                        val rowShape = RoundedCornerShape(2.dp)
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(
                                    start = if (scrapbookIndex % 2 == 0) 14.dp else 42.dp,
                                    end = if (scrapbookIndex % 2 == 0) 40.dp else 14.dp
                                )
                                .offset(y = (-3).dp)
                        ) {
                            // Tap row -> open EditFoodEntrySheet (matches iOS .onTapGesture).
                            // Swipe trailing edge -> delete; swipe leading edge -> toggle favorite.
                            // Mirrors iOS ContentView.swift .swipeActions(edge: .trailing) on the row,
                            // which exposes Delete (destructive) + Favorite/Unfavorite buttons.
                            val isFav = ui.isFavorite(entry)
                            SwipeableFoodRow(
                                entry = entry,
                                isFavorite = isFav,
                                rowShape = rowShape,
                                scrapbookIndex = scrapbookIndex,
                                onTap = { editingEntry = entry },
                                onDelete = { vm.deleteEntry(entry.id) },
                                onToggleFavorite = { vm.toggleFavorite(entry) }
                            )
                        }
                    }
                }
            }

            // The reference reads like a real day's stack of meal receipts:
            // food first, then the small stone-and-stamp tally at the foot of
            // the page. All values and the nutrition-detail action are unchanged.
            item(key = "daily-tally") {
                Column(
                    modifier = Modifier
                        .padding(top = if (mealGroups.isEmpty()) 10.dp else 1.dp)
                        .pointerInput(selectedDate) {
                            var accum = 0f
                            val threshold = 80.dp.toPx()
                            detectHorizontalDragGestures(
                                onDragStart = { accum = 0f },
                                onDragCancel = { accum = 0f },
                                onHorizontalDrag = { change, amount -> accum += amount; change.consume() },
                                onDragEnd = {
                                    if (accum > threshold) {
                                        vm.setSelectedDate(selectedDate.minusDays(1))
                                    } else if (accum < -threshold) {
                                        val next = selectedDate.plusDays(1)
                                        if (!next.isAfter(today)) vm.setSelectedDate(next)
                                    }
                                    accum = 0f
                                }
                            )
                        }
                ) {
                    KitchenDailySummary(
                        calories = ui.caloriesToday,
                        calorieGoal = ui.profile?.effectiveCalories ?: 2000,
                        nutrients = ui.homeTopNutrients,
                        entries = ui.todayEntries,
                        nutrientGoal = { nutrient ->
                            nutrient.goal(ui.profile, ui.optionalNutrientGoals)
                        }
                    )
                    if (ui.waterTrackingEnabled) {
                        Spacer(Modifier.height(10.dp))
                        WaterProgressRow(
                            current = ui.waterTodayMl,
                            goal = ui.waterDailyGoalMl,
                            unit = ui.waterUnit,
                            modifier = Modifier.padding(horizontal = 20.dp)
                        )
                    }
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .padding(vertical = 0.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .heightIn(min = 48.dp)
                                .clickable(role = Role.Button) { showNutritionDetail = true },
                            contentAlignment = Alignment.Center
                        ) {
                            ViewMoreButton()
                        }
                    }
                }
            }
        }

        // Compact tomato order ticket: the Add Food action remains exactly where
        // it is available, without covering half the diary like a generic FAB.
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = 16.dp, bottom = 79.dp)
        ) {
            val addFoodLabel = stringResource(R.string.home_add_food)
            Box(
                modifier = Modifier
                    .width(132.dp)
                    .height(48.dp)
                    .semantics(mergeDescendants = true) {
                        contentDescription = addFoodLabel
                    }
                    .clickable {
                        addMenuGroup = null
                        showAddMenu = true
                    },
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(38.dp)
                        .shadow(
                            elevation = 4.dp,
                            shape = RoundedCornerShape(3.dp),
                            ambientColor = Color.Black.copy(alpha = 0.16f),
                            spotColor = Color.Black.copy(alpha = 0.16f)
                        )
                        .graphicsLayer { rotationZ = -0.5f }
                        .clip(RoundedCornerShape(3.dp))
                        .background(AppColors.KitchenTomato)
                        .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.32f), RoundedCornerShape(3.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = null,
                            tint = AppColors.KitchenCream,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            text = addFoodLabel.uppercase(Locale.getDefault()),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Black,
                            color = AppColors.KitchenCream
                        )
                        androidx.compose.foundation.Image(
                            painter = painterResource(R.drawable.kt_nav_quickadd),
                            contentDescription = null,
                            modifier = Modifier.size(25.dp)
                        )
                    }
                }
            }
            // Glass-styled, progressive add menu. Actions read in task order from
            // top to bottom, with the most common choice first.
            SheetGlassDropdownMenu(
                expanded = showAddMenu,
                onDismissRequest = {
                    showAddMenu = false
                    addMenuGroup = null
                },
                menuWidth = 238.dp
            ) {
                when (addMenuGroup) {
                    null -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_add_group_photo_scan), leadingIcon = Icons.Filled.CameraAlt, trailingIcon = Icons.Filled.ChevronRight) { addMenuGroup = AddMenuGroup.PhotoAndScan }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_add_group_describe), leadingIcon = Icons.Filled.Edit, trailingIcon = Icons.Filled.ChevronRight) { addMenuGroup = AddMenuGroup.DescribeMeal }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_add_group_reuse), leadingIcon = Icons.Filled.Bookmark, trailingIcon = Icons.Filled.ChevronRight) { addMenuGroup = AddMenuGroup.ReuseMeal }
                        if (ui.waterTrackingEnabled) {
                            SheetGlassDropdownMenuItem(label = stringResource(R.string.water), leadingIcon = Icons.Filled.WaterDrop, trailingIcon = Icons.Filled.ChevronRight) { addMenuGroup = AddMenuGroup.Water }
                        }
                        if (ui.fastingTrackingEnabled) {
                            if (ui.activeFast == null) {
                                SheetGlassDropdownMenuItem(label = stringResource(R.string.fasting_start), leadingIcon = Icons.Filled.Timer) {
                                    showAddMenu = false
                                    showFastingStart = true
                                }
                            } else {
                                SheetGlassDropdownMenuItem(label = stringResource(R.string.fasting), leadingIcon = Icons.Filled.Timer, trailingIcon = Icons.Filled.ChevronRight) { addMenuGroup = AddMenuGroup.Fasting }
                            }
                        }
                    }

                    AddMenuGroup.PhotoAndScan -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_camera), leadingIcon = Icons.Filled.CameraAlt) { showAddMenu = false; addMenuGroup = null; openCamera() }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_from_photos), leadingIcon = Icons.Filled.PhotoLibrary) {
                            showAddMenu = false
                            addMenuGroup = null
                            isImportingPhotos = true
                            pendingCaptureImageBytes = emptyList()
                            photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_add_barcode), leadingIcon = Icons.Filled.QrCodeScanner) { showAddMenu = false; addMenuGroup = null; openBarcodeScanner() }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.onboarding_back), leadingIcon = Icons.Filled.ChevronLeft) { addMenuGroup = null }
                    }

                    AddMenuGroup.DescribeMeal -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_text_input), leadingIcon = Icons.Filled.Edit) { showAddMenu = false; addMenuGroup = null; showText = true }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_voice), leadingIcon = Icons.Filled.Mic) { showAddMenu = false; addMenuGroup = null; showVoice = true }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_manual_entry), leadingIcon = Icons.Filled.DriveFileRenameOutline) { showAddMenu = false; addMenuGroup = null; showManual = true }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.onboarding_back), leadingIcon = Icons.Filled.ChevronLeft) { addMenuGroup = null }
                    }

                    AddMenuGroup.ReuseMeal -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.saved_meals_tab_recents), leadingIcon = Icons.Filled.History) { showAddMenu = false; addMenuGroup = null; savedMealsTab = SavedTab.RECENTS }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.saved_meals_tab_frequent), leadingIcon = Icons.Filled.Repeat) { showAddMenu = false; addMenuGroup = null; savedMealsTab = SavedTab.FREQUENT }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.saved_meals_tab_favorites), leadingIcon = Icons.Filled.Favorite) { showAddMenu = false; addMenuGroup = null; savedMealsTab = SavedTab.FAVORITES }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.home_menu_copy_from_day), leadingIcon = Icons.Filled.CalendarMonth) { showAddMenu = false; addMenuGroup = null; showCopyFromDay = true }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.onboarding_back), leadingIcon = Icons.Filled.ChevronLeft) { addMenuGroup = null }
                    }

                    AddMenuGroup.Water -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.water_one_glass_dynamic, ui.waterUnit.format(250)), leadingIcon = Icons.Filled.WaterDrop) { showAddMenu = false; addMenuGroup = null; vm.addWater(250) }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.water_two_glasses_dynamic, ui.waterUnit.format(500)), leadingIcon = Icons.Filled.WaterDrop) { showAddMenu = false; addMenuGroup = null; vm.addWater(500) }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.water_three_glasses_dynamic, ui.waterUnit.format(750)), leadingIcon = Icons.Filled.WaterDrop) { showAddMenu = false; addMenuGroup = null; vm.addWater(750) }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.water_custom_amount), leadingIcon = Icons.Filled.DriveFileRenameOutline) { showAddMenu = false; addMenuGroup = null; showCustomWaterLog = true }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.onboarding_back), leadingIcon = Icons.Filled.ChevronLeft) { addMenuGroup = null }
                    }

                    AddMenuGroup.Fasting -> {
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.fasting_end), leadingIcon = Icons.Filled.Stop) {
                            showAddMenu = false
                            addMenuGroup = null
                            vm.endFast()
                        }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.fasting_cancel), leadingIcon = Icons.Filled.Delete) {
                            showAddMenu = false
                            addMenuGroup = null
                            vm.cancelFast()
                        }
                        SheetGlassDropdownMenuItem(label = stringResource(R.string.onboarding_back), leadingIcon = Icons.Filled.ChevronLeft) { addMenuGroup = null }
                    }
                }
            }
        }
        }
    }
    }

    if (showText) {
        TextInputDialog(
            onDismiss = {
                showText = false
                finishCapability()
            },
            onSubmit = { showText = false; vm.analyzeText(it) }
        )
    }

    if (showCustomWaterLog) {
        WaterCustomAmountSheet(
            unit = ui.waterUnit,
            onDismiss = { showCustomWaterLog = false },
            onAdd = vm::addWater
        )
    }

    if (showFastingStart) {
        FastingGoalDialog(
            title = stringResource(R.string.fasting_start),
            initialMinutes = ui.fastingDefaultGoalMinutes,
            confirmLabel = stringResource(R.string.fasting_start),
            onConfirm = {
                showFastingStart = false
                vm.startFast(it)
            },
            onDismiss = { showFastingStart = false }
        )
    }

    editingFast?.let { session ->
        FastingSessionDialog(
            session = session,
            onSave = {
                vm.updateFast(it)
                editingFast = null
            },
            onEndNow = {
                vm.updateFast(it)
                vm.endFast()
                editingFast = null
            },
            onDelete = {
                vm.deleteFast(session.id)
                editingFast = null
            },
            onDismiss = { editingFast = null }
        )
    }

    if (showVoice) {
        VoiceInputSheet(
            container = container,
            onDismiss = {
                showVoice = false
                finishCapability()
            },
            onSubmit = { showVoice = false; vm.analyzeText(it) }
        )
    }

    if (showManual) {
        ManualEntryDialog(
            onDismiss = {
                showManual = false
                finishCapability()
            },
            onSave = { name, kcal, p, c, f, fiber, meal ->
                showManual = false
                vm.saveManualEntry(name, kcal, p, c, f, fiber, meal, finishCapability)
            }
        )
    }

    savedMealsTab?.let { tab ->
        SavedMealsSheet(
            container = container,
            tab = tab,
            onDismiss = { savedMealsTab = null },
            // Tapping a Saved Meals row opens the FoodResultSheet for review
            // instead of logging immediately — same UX as the photo flow.
            onRelogEntry = { vm.reviewSavedMeal(it) }
        )
    }

    if (showCopyFromDay) {
        CopyFromDaySheet(
            targetDate = ui.date,
            allEntries = allEntries,
            onCopy = { entries ->
                vm.copyEntriesToSelectedDay(entries)
                showCopyFromDay = false
            },
            onDismiss = { showCopyFromDay = false }
        )
    }

    if (showBarcodeScanner) {
        BarcodeScannerSheet(
            onBarcode = { barcode ->
                showBarcodeScanner = false
                vm.lookupBarcode(barcode)
            },
            onDismiss = {
                showBarcodeScanner = false
                finishCapability()
            }
        )
    }

    if (showCameraCapture) {
        InAppCameraCaptureDialog(
            onCapture = { bytes ->
                showCameraCapture = false
                pendingCaptureImageBytes = (pendingCaptureImageBytes + bytes).take(10)
                showMultiPhotoCapture = true
            },
            onDismiss = {
                showCameraCapture = false
                if (pendingCaptureImageBytes.isNotEmpty()) {
                    showMultiPhotoCapture = true
                } else finishCapability()
            }
        )
    }

    if (showMultiPhotoCapture && pendingCaptureImageBytes.isNotEmpty()) {
        MultiPhotoCaptureSheet(
            imageBytesList = pendingCaptureImageBytes,
            addsFromLibrary = isImportingPhotos,
            onAddPhoto = {
                if (pendingCaptureImageBytes.size < 10) {
                    if (isImportingPhotos) {
                        photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    } else {
                        showMultiPhotoCapture = false
                        showCameraCapture = true
                    }
                }
            },
            onRemove = { index ->
                pendingCaptureImageBytes = pendingCaptureImageBytes.filterIndexed { itemIndex, _ -> itemIndex != index }
                if (pendingCaptureImageBytes.isEmpty()) showMultiPhotoCapture = false
            },
            onAnalyze = { note, progressiveMeal ->
                val images = pendingCaptureImageBytes
                pendingCaptureImageBytes = emptyList()
                showMultiPhotoCapture = false
                vm.analyzePhotos(images, note, progressiveMeal)
            },
            onDismiss = {
                showMultiPhotoCapture = false
                pendingCaptureImageBytes = emptyList()
                finishCapability()
            }
        )
    }

    editingEntry?.let { entry ->
        EditFoodEntrySheet(
            entry = entry,
            preferGramsByDefault = ui.preferGramsByDefault,
            onReprocess = { updatedNote ->
                vm.reprocessFoodEntry(entry, updatedNote)
            },
            onSave = { updated ->
                editingEntry = null
                vm.updateEntry(updated, finishCapability)
            },
            onDismiss = {
                editingEntry = null
                finishCapability()
            }
        )
    }

    if (showNutritionDetail) {
        NutritionDetailSheet(
            entries = ui.todayEntries,
            profile = ui.profile,
            homeTopNutrients = ui.homeTopNutrients,
            optionalGoals = ui.optionalNutrientGoals,
            onHomeTopNutrientsChange = vm::setHomeTopNutrients,
            onDismiss = { showNutritionDetail = false }
        )
    }

    if (ui.analyzing) AnalyzingOverlay(imageBytes = ui.pendingImageBytes)
    ui.pendingAnalysis?.let { analysis ->
        FoodResultSheet(
            analysis = analysis,
            imageBytesList = ui.pendingImageBytesList,
            preferGramsByDefault = ui.preferGramsByDefault,
            profile = ui.profile,
            dayEntries = ui.todayEntries,
            source = ui.pendingReviewSource?.source
                ?: ui.pendingFoodSource
                ?: if (ui.pendingImageBytes != null) FoodSource.SNAP_FOOD else FoodSource.TEXT_INPUT,
            onWhatIfSuggestion = vm::suggestMealWhatIf,
            onSave = { name, grams, scale, mealType, selectedServingUnit, selectedServingQuantity, editedAnalysis ->
                vm.saveAnalysis(
                    name = name,
                    servingGrams = grams,
                    scale = scale,
                    mealType = mealType,
                    selectedServingUnit = selectedServingUnit,
                    selectedServingQuantity = selectedServingQuantity,
                    editedAnalysis = editedAnalysis,
                    onComplete = finishCapability
                )
            },
            onDismiss = {
                vm.dismissPending()
                finishCapability()
            }
        )
    }

    ui.error?.let { err ->
        FudGlassDialog(onDismissRequest = {
            vm.dismissPending()
            finishCapability()
        }) {
            Text(stringResource(R.string.error_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(err, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f))
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_retry),
                onPrimary = { vm.retryPendingAnalysis() },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = {
                    vm.dismissPending()
                    finishCapability()
                }
            )
        }
    }
}

@Composable
private fun ActiveFastingRow(session: FastingSession, onClick: () -> Unit) {
    var now by remember(session.id) { mutableStateOf(Instant.now()) }
    LaunchedEffect(session.id) {
        while (true) {
            delay(1_000)
            now = Instant.now()
        }
    }
    val elapsed = session.durationSeconds(now)
    val progress = (elapsed.toFloat() / (session.goalMinutes * 60f)).coerceIn(0f, 1f)
    val context = LocalContext.current
    val timeFormatter = remember(context) {
        DateTimeFormatter.ofPattern(clockTimePattern(context), Locale.getDefault())
            .withZone(ZoneId.systemDefault())
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 13.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Timer, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(27.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.fasting_in_progress), fontWeight = FontWeight.SemiBold)
                Text(
                    stringResource(R.string.fasting_started_format, timeFormatter.format(session.startedAt)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    formatFastingDuration(elapsed),
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    stringResource(R.string.fasting_goal_format, formatFastingDuration(session.goalMinutes.toLong() * 60)),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                )
            }
            Spacer(Modifier.width(8.dp))
            Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
        }
        Spacer(Modifier.height(9.dp))
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth().height(5.dp).clip(CircleShape),
            color = MaterialTheme.colorScheme.primary,
            trackColor = AppColors.Calorie.copy(alpha = 0.16f)
        )
    }
}

@Composable
private fun CompletedFastingRow(session: FastingSession, onClick: () -> Unit) {
    val context = LocalContext.current
    val timeFormatter = remember(context) {
        DateTimeFormatter.ofPattern(clockTimePattern(context), Locale.getDefault())
            .withZone(ZoneId.systemDefault())
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.Timer, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(27.dp))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                stringResource(R.string.fasting_completed_format, formatFastingDuration(session.durationSeconds())),
                fontWeight = FontWeight.SemiBold
            )
            session.endedAt?.let { endedAt ->
                Text(
                    "${timeFormatter.format(session.startedAt)} – ${timeFormatter.format(endedAt)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                )
            }
        }
        Text(
            stringResource(R.string.fasting_goal_format, formatFastingDuration(session.goalMinutes.toLong() * 60)),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
        )
        Spacer(Modifier.width(8.dp))
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
    }
}

@Composable
private fun FastingGoalDialog(
    title: String,
    initialMinutes: Int,
    confirmLabel: String,
    onConfirm: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    var hours by remember(initialMinutes) { mutableIntStateOf((initialMinutes / 60).coerceIn(1, 168)) }
    FudGlassDialog(onDismissRequest = onDismiss) {
        Text(title, fontSize = 21.sp, fontWeight = FontWeight.Bold)
        Text(
            stringResource(R.string.fasting_choose_goal),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.64f)
        )
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(onClick = { hours = (hours - 1).coerceAtLeast(1) }) {
                Text("−", fontSize = 28.sp, color = MaterialTheme.colorScheme.primary)
            }
            Text("$hours ${stringResource(R.string.fasting_hours)}", fontSize = 28.sp, fontWeight = FontWeight.Bold)
            TextButton(onClick = { hours = (hours + 1).coerceAtMost(168) }) {
                Text("+", fontSize = 28.sp, color = MaterialTheme.colorScheme.primary)
            }
        }
        FudGlassDialogActions(
            primaryText = confirmLabel,
            onPrimary = { onConfirm(hours * 60) },
            dismissText = stringResource(R.string.action_cancel),
            onDismiss = onDismiss
        )
    }
}

@Composable
private fun FastingSessionDialog(
    session: FastingSession,
    onSave: (FastingSession) -> Unit,
    onEndNow: (FastingSession) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var startedAt by remember(session.id) { mutableStateOf(session.startedAt) }
    var endedAt by remember(session.id) { mutableStateOf(session.endedAt ?: Instant.now()) }
    var goalHours by remember(session.id) { mutableIntStateOf((session.goalMinutes / 60).coerceIn(1, 168)) }
    val dateTimeFormatter = remember(context) {
        DateTimeFormatter.ofPattern("MMM d, yyyy • ${clockTimePattern(context)}", Locale.getDefault())
            .withZone(ZoneId.systemDefault())
    }

    FudGlassDialog(onDismissRequest = onDismiss) {
        Text(
            stringResource(if (session.isActive) R.string.fasting_active else R.string.fasting_edit),
            fontSize = 21.sp,
            fontWeight = FontWeight.Bold
        )
        FastingEditorRow(
            label = stringResource(R.string.fasting_started),
            value = dateTimeFormatter.format(startedAt),
            onClick = { showInstantPicker(context, startedAt) { startedAt = it } }
        )
        if (!session.isActive) {
            FastingEditorRow(
                label = stringResource(R.string.fasting_ended),
                value = dateTimeFormatter.format(endedAt),
                onClick = { showInstantPicker(context, endedAt) { endedAt = maxOf(it, startedAt) } }
            )
        }
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(stringResource(R.string.settings_fasting_goal), fontWeight = FontWeight.Medium)
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { goalHours = (goalHours - 1).coerceAtLeast(1) }) { Text("−", color = MaterialTheme.colorScheme.primary) }
                Text("$goalHours h", fontWeight = FontWeight.SemiBold)
                TextButton(onClick = { goalHours = (goalHours + 1).coerceAtMost(168) }) { Text("+", color = MaterialTheme.colorScheme.primary) }
            }
        }

        if (session.isActive) {
            Button(
                onClick = {
                    onEndNow(session.copy(startedAt = startedAt, goalMinutes = goalHours * 60))
                },
                colors = ButtonDefaults.buttonColors(containerColor = AppColors.Calorie),
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(Icons.Filled.Stop, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.fasting_end))
            }
        }
        TextButton(onClick = onDelete, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.Delete, contentDescription = null, tint = Color(0xFFFF453A))
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(if (session.isActive) R.string.fasting_cancel else R.string.fasting_delete),
                color = Color(0xFFFF453A)
            )
        }
        FudGlassDialogActions(
            primaryText = stringResource(R.string.action_save),
            onPrimary = {
                onSave(
                    session.copy(
                        startedAt = startedAt,
                        endedAt = if (session.isActive) null else maxOf(endedAt, startedAt),
                        goalMinutes = goalHours * 60
                    )
                )
            },
            dismissText = stringResource(R.string.action_cancel),
            onDismiss = onDismiss
        )
    }
}

@Composable
private fun FastingEditorRow(label: String, value: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, fontWeight = FontWeight.Medium)
        Spacer(Modifier.weight(1f))
        Text(value, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f))
        Spacer(Modifier.width(6.dp))
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
    }
}

private fun showInstantPicker(context: android.content.Context, initial: Instant, onPicked: (Instant) -> Unit) {
    val zone = ZoneId.systemDefault()
    val value = initial.atZone(zone)
    DatePickerDialog(
        context,
        { _, year, month, day ->
            TimePickerDialog(
                context,
                { _, hour, minute ->
                    onPicked(ZonedDateTime.of(year, month + 1, day, hour, minute, 0, 0, zone).toInstant())
                },
                value.hour,
                value.minute,
                android.text.format.DateFormat.is24HourFormat(context)
            ).show()
        },
        value.year,
        value.monthValue - 1,
        value.dayOfMonth
    ).show()
}

// ── Week strip (iOS port) ────────────────────────────────────────────

@Composable
private fun WeekStripSection(selectedDate: LocalDate, onSelect: (LocalDate) -> Unit) {
    val firstDow = remember { WeekFields.of(Locale.getDefault()).firstDayOfWeek }
    val weekStart = remember(selectedDate, firstDow) {
        val offset = ((selectedDate.dayOfWeek.value - firstDow.value) + 7) % 7
        selectedDate.minusDays(offset.toLong())
    }
    val today = remember { LocalDate.now() }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        for (i in 0..6) {
            val date = weekStart.plusDays(i.toLong())
            val isSel = date == selectedDate
            val isTdy = date == today
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .weight(1f)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = { onSelect(date) }
                    )
            ) {
                Text(
                    shortDay(date.dayOfWeek),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isSel) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
                Spacer(Modifier.height(6.dp))
                Box(
                    Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(
                            if (isSel) AppColors.CalorieGradient
                            else Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                        )
                        .then(
                            if (isTdy && !isSel) Modifier.border(1.5.dp, AppColors.Calorie.copy(alpha = 0.35f), CircleShape)
                            else Modifier
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        date.dayOfMonth.toString(),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = when {
                            isSel -> MaterialTheme.colorScheme.onPrimary
                            isTdy -> AppColors.Calorie
                            else -> MaterialTheme.colorScheme.onSurface
                        }
                    )
                }
            }
        }
    }
}

private fun shortDay(dow: DayOfWeek): String = when (dow) {
    DayOfWeek.MONDAY -> "M"
    DayOfWeek.TUESDAY -> "T"
    DayOfWeek.WEDNESDAY -> "W"
    DayOfWeek.THURSDAY -> "T"
    DayOfWeek.FRIDAY -> "F"
    DayOfWeek.SATURDAY -> "S"
    DayOfWeek.SUNDAY -> "S"
}

@Composable
private fun KitchenTodayHeader(
    selectedDate: LocalDate,
    isToday: Boolean,
    onCalendarClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(1.dp)
        ) {
            Text(
                text = if (isToday) stringResource(R.string.widget_today) else selectedDate.format(
                    DateTimeFormatter.ofPattern("MMMM d", Locale.getDefault())
                ),
                fontSize = 23.sp,
                lineHeight = 25.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.KitchenEspresso
            )
            Text(
                text = selectedDate.format(
                    DateTimeFormatter.ofPattern("MMMM d, EEEE", Locale.getDefault())
                ),
                fontSize = 10.sp,
                lineHeight = 12.sp,
                color = AppColors.KitchenEspresso.copy(alpha = 0.68f)
            )
        }
        val dateLabel = stringResource(R.string.label_date)
        Box(
            Modifier
                .size(48.dp)
                .semantics { contentDescription = dateLabel }
                .clickable(role = Role.Button, onClick = onCalendarClick),
            contentAlignment = Alignment.Center
        ) {
            Box(
                Modifier
                    .size(28.dp)
                    .shadow(2.dp, CircleShape)
                    .clip(CircleShape)
                    .background(AppColors.KitchenPaper)
                    .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.24f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.CalendarMonth,
                    contentDescription = null,
                    tint = AppColors.KitchenEspresso,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

@Composable
private fun KitchenDailySummary(
    calories: Int,
    calorieGoal: Int,
    nutrients: List<HomeTopNutrient>,
    entries: List<FoodEntry>,
    nutrientGoal: (HomeTopNutrient) -> Int
) {
    val useAccessibleGrid = LocalDensity.current.fontScale > 1.22f
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        if (useAccessibleGrid) {
            CaloriePebble(
                calories = calories,
                calorieGoal = calorieGoal,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
            nutrients.chunked(2).forEachIndexed { rowIndex, rowNutrients ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    rowNutrients.forEachIndexed { columnIndex, nutrient ->
                        val index = rowIndex * 2 + columnIndex
                        NutrientStamp(
                            name = stringResource(nutrient.displayNameRes),
                            value = MacroValueFormatter.string(nutrient.current(entries)),
                            unit = stringResource(nutrient.unitRes),
                            goal = nutrientGoal(nutrient),
                            color = nutrientStampColor(nutrient),
                            rotation = listOf(-1.2f, 0.8f, -0.7f, 1f)[index % 4],
                            modifier = Modifier.weight(1f)
                        )
                    }
                    if (rowNutrients.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        } else {
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                CaloriePebble(calories = calories, calorieGoal = calorieGoal)
                nutrients.forEachIndexed { index, nutrient ->
                    NutrientStamp(
                        name = stringResource(nutrient.displayNameRes),
                        value = MacroValueFormatter.string(nutrient.current(entries)),
                        unit = stringResource(nutrient.unitRes),
                        goal = nutrientGoal(nutrient),
                        color = nutrientStampColor(nutrient),
                        rotation = listOf(-1.2f, 0.8f, -0.7f, 1f)[index % 4],
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
        KitchenReceiptRule()
    }
}

private fun nutrientStampColor(nutrient: HomeTopNutrient): Color = when (nutrient) {
    HomeTopNutrient.PROTEIN -> AppColors.KitchenHerb
    HomeTopNutrient.CARBS -> AppColors.KitchenCobalt
    HomeTopNutrient.FAT -> AppColors.KitchenTomato
    else -> AppColors.KitchenBrass
}

@Composable
private fun CaloriePebble(
    calories: Int,
    calorieGoal: Int,
    modifier: Modifier = Modifier
) {
    val calorieDescription = stringResource(
        R.string.home_calorie_summary_a11y,
        calories,
        calorieGoal
    )
    Box(
        modifier
            .size(78.dp)
            .shadow(
                5.dp,
                CircleShape,
                ambientColor = Color.Black.copy(alpha = 0.15f),
                spotColor = Color.Black.copy(alpha = 0.15f)
            )
            .clip(CircleShape)
            .background(AppColors.KitchenBone)
            .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.25f), CircleShape)
            .semantics(mergeDescendants = true) {
                contentDescription = calorieDescription
            },
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = calories.toString(),
                style = MaterialTheme.typography.headlineMedium,
                color = AppColors.KitchenEspresso,
                maxLines = 1
            )
            Text(
                text = stringResource(R.string.unit_kcal).uppercase(Locale.getDefault()),
                style = MaterialTheme.typography.labelSmall,
                color = AppColors.KitchenEspresso
            )
        }
    }
}

@Composable
private fun NutrientStamp(
    name: String,
    value: String,
    unit: String,
    goal: Int,
    color: Color,
    rotation: Float,
    modifier: Modifier = Modifier
) {
    val goalText = if (goal > 0) "$goal$unit" else "—"
    Column(
        modifier = modifier
            .height(72.dp)
            .graphicsLayer { rotationZ = rotation }
            .shadow(2.dp, RoundedCornerShape(3.dp))
            .clip(RoundedCornerShape(3.dp))
            .background(AppColors.KitchenPaper)
            .border(1.4.dp, color.copy(alpha = 0.78f), RoundedCornerShape(3.dp))
            .semantics(mergeDescendants = true) {
                contentDescription = listOf(name, "$value$unit", goalText).joinToString(", ")
            }
            .padding(horizontal = 2.dp, vertical = 7.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            text = name,
            color = color,
            fontSize = 7.sp,
            lineHeight = 8.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = "$value$unit",
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.KitchenEspresso,
            maxLines = 1
        )
        Spacer(Modifier.height(2.dp))
    }
}

// ── Calorie hero ─────────────────────────────────────────────────────

/**
 * Verbatim port of the calorie hero block in HomeView.body
 * (ios/calorietracker/ContentView.swift, lines ~322–362):
 *
 *   VStack(spacing: 20) {
 *     VStack(spacing: 4) {
 *       Text("\(selectedCalories)")
 *         .font(.system(size: 72, weight: .bold, design: .rounded))
 *         .foregroundStyle(LinearGradient(colors: AppColors.calorieGradient,
 *                                         startPoint: .topLeading,
 *                                         endPoint: .bottomTrailing))
 *         .contentTransition(.numericText())
 *         .animation(.snappy, value: selectedCalories)
 *       Text("of \(calorieGoal) kcal")
 *         .font(.system(.callout, design: .rounded, weight: .medium))
 *         .foregroundStyle(.tertiary)
 *     }
 *     GeometryReader { geo in
 *       ZStack(alignment: .leading) {
 *         Capsule().fill(AppColors.calorie.opacity(0.10)).frame(height: 10)
 *         Capsule().fill(LinearGradient(.leading, .trailing))
 *                  .frame(width: max(10, geo.size.width * progress), height: 10)
 *                  .shadow(color: AppColors.calorie.opacity(0.35), radius: 8, y: 3)
 *                  .animation(.spring(response: 0.8, dampingFraction: 0.75), value: selectedCalories)
 *       }
 *     }.frame(height: 10).padding(.horizontal, 24)
 *     Text("\(caloriesRemaining) left")
 *       .font(.system(.footnote, design: .rounded, weight: .medium))
 *       .foregroundStyle(.secondary)
 *   }
 *   .padding(.vertical, 20)
 */
@Composable
private fun CalorieHero(current: Int, goal: Int) {
    val ratio = if (goal > 0) (current.toFloat() / goal).coerceIn(0f, 1f) else 0f
    // Fill-from-zero on app open. lastEpoch is saveable so it survives tab switches
    // (where Home leaves/re-enters composition) — only a real app-open (new epoch)
    // replays the sweep; tab returns snap to the current value.
    val epoch = LocalLaunchFillEpoch.current
    var lastEpoch by rememberSaveable { mutableIntStateOf(0) }
    val animatedRatio = remember { Animatable(if (lastEpoch == epoch) ratio else 0f) }
    LaunchedEffect(epoch, ratio) {
        val spec = spring<Float>(dampingRatio = 0.85f, stiffness = 55f)
        if (lastEpoch != epoch) {
            animatedRatio.snapTo(0f)
            animatedRatio.animateTo(ratio, spec)
            lastEpoch = epoch
        } else {
            animatedRatio.animateTo(ratio, spec)
        }
    }
    val statusText = when {
        goal <= 0 -> "No goal"
        current < goal -> "${goal - current} left"
        current > goal -> "${current - goal} over"
        else -> "Goal reached"
    }
    val gradientColors = listOf(AppColors.CalorieStart, AppColors.CalorieEnd)
    val stackReadout = LocalDensity.current.fontScale > 1.15f

    FudGlassSurface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        cornerRadius = 22.dp,
        padding = 20.dp
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (stackReadout) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    CalorieValueReadout(current)
                    CalorieGoalReadout(goal, statusText, Alignment.Start)
                }
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Bottom
                ) {
                    CalorieValueReadout(current)
                    Spacer(Modifier.weight(1f))
                    CalorieGoalReadout(goal, statusText, Alignment.End)
                }
            }
            KitchenReceiptRule()
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(11.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
            ) {
                Box(
                    Modifier
                        .width(maxWidth * animatedRatio.value)
                        .fillMaxHeight()
                        .background(Brush.horizontalGradient(gradientColors))
                )
            }
        }
    }
}

// ── Macro card (iOS port) ────────────────────────────────────────────

@Composable
private fun CalorieValueReadout(current: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(
            "CALORIES",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.tertiary
        )
        Text(
            "$current",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1
        )
    }
}

@Composable
private fun CalorieGoalReadout(
    goal: Int,
    statusText: String,
    horizontalAlignment: Alignment.Horizontal
) {
    Column(horizontalAlignment = horizontalAlignment) {
        Text(
            stringResource(R.string.home_kcal_of_format, goal.toString()),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f),
            maxLines = 2
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Icon(
                Icons.Filled.LocalFireDepartment,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(14.dp)
            )
            Text(
                statusText,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun ViewMoreButton() {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            stringResource(R.string.home_view_more),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
        )
        Spacer(Modifier.width(5.dp))
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
            modifier = Modifier.size(9.dp)
        )
    }
}

// ── Section headers / cards / rows ──────────────────────────────────

@Composable
private fun SectionHeader(title: String) {
    Box(
        Modifier
            .padding(start = 22.dp, top = 7.dp, bottom = 1.dp)
            .graphicsLayer { rotationZ = -1.2f }
            .shadow(2.dp, RoundedCornerShape(2.dp))
            .background(AppColors.KitchenPaper, RoundedCornerShape(2.dp))
            .border(
                1.dp,
                AppColors.KitchenEspresso.copy(alpha = 0.16f),
                RoundedCornerShape(2.dp)
            )
            .padding(horizontal = 10.dp, vertical = 3.dp)
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontStyle = FontStyle.Italic,
            color = AppColors.KitchenEspresso
        )
    }
}

@Composable
private fun MealSectionHeader(
    meal: MealType,
    totalCalories: Int? = null,
    totalProtein: Double = 0.0,
    totalCarbs: Double = 0.0,
    totalFat: Double = 0.0,
    onShare: (() -> Unit)? = null,
    showSortMenu: Boolean = false,
    sortOrder: FoodLogSortOrder = FoodLogSortOrder.STANDARD,
    sortMenuExpanded: Boolean = false,
    onSortClick: () -> Unit = {},
    onSortDismiss: () -> Unit = {},
    onSortOrderSelected: (FoodLogSortOrder) -> Unit = {}
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 28.dp, end = 20.dp, top = 1.dp, bottom = 0.dp)
            .offset(y = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            Modifier
                .graphicsLayer { rotationZ = -1.6f }
                .shadow(2.dp, RoundedCornerShape(2.dp))
                .background(AppColors.KitchenPaper, RoundedCornerShape(2.dp))
                .border(
                    1.dp,
                    AppColors.KitchenEspresso.copy(alpha = 0.16f),
                    RoundedCornerShape(2.dp)
                )
                .padding(horizontal = 8.dp, vertical = 1.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                mealIcon(meal),
                contentDescription = null,
                tint = AppColors.KitchenHerb,
                modifier = Modifier.size(10.dp)
            )
            Spacer(Modifier.width(5.dp))
            Text(
                stringResource(meal.displayNameRes),
                fontSize = 12.sp,
                lineHeight = 13.sp,
                fontWeight = FontWeight.Medium,
                fontStyle = FontStyle.Italic,
                color = AppColors.KitchenEspresso
            )
        }
        if (showSortMenu) {
            Spacer(Modifier.width(10.dp))
            Box {
                Row(
                    modifier = Modifier
                        .widthIn(min = 48.dp)
                        .heightIn(min = 48.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .clickable { onSortClick() }
                        .padding(horizontal = 5.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Icon(
                        Icons.Filled.SwapVert,
                        contentDescription = null,
                        tint = AppColors.KitchenTomato,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        stringResource(R.string.sort),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.KitchenTomato
                    )
                }
                SheetGlassDropdownMenu(
                    expanded = sortMenuExpanded,
                    onDismissRequest = onSortDismiss,
                    menuWidth = 226.dp
                ) {
                    for (order in FoodLogSortOrder.values()) {
                        SheetGlassDropdownMenuItem(
                            label = stringResource(order.displayNameRes),
                            selected = order == sortOrder,
                            reserveSelectionSlot = true,
                            onClick = { onSortOrderSelected(order) }
                        )
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
        if (onShare != null) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clickable(role = Role.Button) { onShare() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.IosShare,
                    contentDescription = stringResource(R.string.cd_share_meal),
                    tint = AppColors.KitchenTomato,
                    modifier = Modifier.size(15.dp)
                )
            }
        }
    }
}

private data class FoodLogMealGroup(
    val id: String,
    val meal: MealType,
    val entries: List<FoodEntry>
) {
    // Combined nutrients for this meal group (issue #103: chicken + pasta + sauce = one total).
    val totalCalories: Int get() = entries.sumOf { it.calories }
    val totalProtein: Double get() = entries.sumOf { it.protein }
    val totalCarbs: Double get() = entries.sumOf { it.carbs }
    val totalFat: Double get() = entries.sumOf { it.fat }
}

private fun foodLogMealGroups(
    entries: List<FoodEntry>,
    sortOrder: FoodLogSortOrder
): List<FoodLogMealGroup> = when (sortOrder) {
    FoodLogSortOrder.STANDARD -> {
        val grouped = entries.groupBy { it.mealType }
        listOf(MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK, MealType.OTHER)
            .mapNotNull { meal ->
                val mealEntries = grouped[meal].orEmpty()
                if (mealEntries.isEmpty()) null else FoodLogMealGroup(
                    id = "standard-${meal.name}",
                    meal = meal,
                    entries = mealEntries
                )
            }
    }
    FoodLogSortOrder.LATEST_MEALS_FIRST -> latestMealRuns(entries)
}

private fun latestMealRuns(entries: List<FoodEntry>): List<FoodLogMealGroup> {
    val sortedEntries = entries.sortedByDescending { it.timestamp }
    val groups = mutableListOf<FoodLogMealGroup>()
    var currentMeal: MealType? = null
    val currentEntries = mutableListOf<FoodEntry>()

    fun appendCurrentGroup() {
        val meal = currentMeal ?: return
        if (currentEntries.isEmpty()) return
        groups += FoodLogMealGroup(
            id = "latest-${groups.size}-${meal.name}-${currentEntries.first().id}",
            meal = meal,
            entries = currentEntries.toList()
        )
    }

    for (entry in sortedEntries) {
        if (entry.mealType == currentMeal) {
            currentEntries += entry
        } else {
            appendCurrentGroup()
            currentMeal = entry.mealType
            currentEntries.clear()
            currentEntries += entry
        }
    }

    appendCurrentGroup()
    return groups
}

private fun mealIcon(meal: MealType): ImageVector = when (meal) {
    MealType.BREAKFAST -> Icons.Filled.WbTwilight
    MealType.LUNCH -> Icons.Filled.WbSunny
    MealType.DINNER -> Icons.Filled.Bedtime
    MealType.SNACK -> Icons.Filled.Coffee
    MealType.OTHER -> Icons.Filled.Restaurant
}

private fun sectionCardShape(isFirst: Boolean, isLast: Boolean): RoundedCornerShape {
    return when {
        isFirst && isLast -> RoundedCornerShape(4.dp)
        isFirst -> RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp)
        isLast -> RoundedCornerShape(bottomStart = 4.dp, bottomEnd = 4.dp)
        else -> RoundedCornerShape(1.dp)
    }
}

@Composable
private fun SectionCardWrapper(
    isFirst: Boolean,
    isLast: Boolean,
    transparent: Boolean = false,
    content: @Composable () -> Unit
) {
    val shape = sectionCardShape(isFirst, isLast)
    val paperDecoration = if (transparent) {
        Modifier
    } else {
        Modifier
            .shadow(
                3.dp,
                shape,
                ambientColor = Color.Black.copy(alpha = 0.1f),
                spotColor = Color.Black.copy(alpha = 0.1f)
            )
            .clip(shape)
            .background(AppColors.KitchenPaper)
            .border(
                1.dp,
                AppColors.KitchenEspresso.copy(alpha = 0.18f),
                shape
            )
    }
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = if (transparent) 18.dp else 22.dp)
            .then(paperDecoration)
    ) { content() }
}

@Composable
private fun Divider() {
    Box(
        Modifier
            .padding(start = 92.dp, end = 10.dp)
            .fillMaxWidth()
            .height(0.5.dp)
            .background(AppColors.KitchenEspresso.copy(alpha = 0.12f))
    )
}

/**
 * Swipe-to-action wrapper around FoodRow.
 *
 * - Swipe right-to-left (trailing) past threshold → delete (mirrors iOS swipeActions
 *   trailing destructive button).
 * - Swipe left-to-right (leading) past threshold → toggle favorite (mirrors iOS
 *   .swipeActions secondary heart button).
 * - Tap → open EditFoodEntrySheet (matches iOS .onTapGesture).
 *
 * The dismiss state is reset on a no-confirm swing-back so partial swipes don't
 * leave the row stuck mid-flight when the user releases short of the threshold.
 */
@Composable
private fun SwipeableFoodRow(
    entry: FoodEntry,
    isFavorite: Boolean,
    rowShape: RoundedCornerShape,
    scrapbookIndex: Int,
    onTap: () -> Unit,
    onDelete: () -> Unit,
    onToggleFavorite: () -> Unit
) {
    val density = LocalDensity.current
    val favoriteTriggerPx = with(density) { 150.dp.toPx() }
    val deleteTriggerPx = with(density) { 220.dp.toPx() }
    var offsetPx by remember(entry.id) { mutableFloatStateOf(0f) }

    BoxWithConstraints(
        modifier = Modifier.fillMaxWidth()
    ) {
        val maxSwipePx = with(density) { maxWidth.toPx() * 0.72f }
        Box(Modifier.fillMaxWidth()) {
            SwipeBackground(offsetPx = offsetPx, isFavorite = isFavorite)
            Box(
                modifier = Modifier
                    .offset { IntOffset(offsetPx.roundToInt(), 0) }
                    .pointerInput(entry.id, maxSwipePx) {
                        detectHorizontalDragGestures(
                            onHorizontalDrag = { change, dragAmount ->
                                change.consume()
                                offsetPx = (offsetPx + dragAmount).coerceIn(-maxSwipePx, maxSwipePx)
                            },
                            onDragEnd = {
                                val finalOffset = offsetPx
                                offsetPx = 0f
                                when {
                                    finalOffset <= -deleteTriggerPx -> onDelete()
                                    finalOffset >= favoriteTriggerPx -> onToggleFavorite()
                                }
                            },
                            onDragCancel = {
                                offsetPx = 0f
                            }
                        )
                    }
                    .clickable(onClick = onTap)
            ) {
                FoodRow(
                    entry = entry,
                    isFavorite = isFavorite,
                    rowShape = rowShape,
                    scrapbookIndex = scrapbookIndex
                )
            }
        }
    }
}

@Composable
private fun BoxScope.SwipeBackground(offsetPx: Float, isFavorite: Boolean) {
    if (offsetPx == 0f) {
        Box(Modifier.matchParentSize())
        return
    }
    val (bg, icon, label) = if (offsetPx < 0f) {
        Triple(
            Color(0xFFD32F2F),
            Icons.Filled.Delete,
            stringResource(R.string.home_swipe_delete)
        )
    } else {
        Triple(
            AppColors.Calorie,
            if (isFavorite) Icons.Filled.FavoriteBorder else Icons.Filled.Favorite,
            if (isFavorite) stringResource(R.string.home_swipe_unfavorite) else stringResource(R.string.home_swipe_favorite)
        )
    }
    // iOS Mail-style trailing reveal: paint only the area the foreground has
    // moved out of, pinned to the matching edge. Width = absolute offset.
    val widthPx = kotlin.math.abs(offsetPx)
    val widthDp = with(LocalDensity.current) { widthPx.toDp() }
    val alignment = if (offsetPx < 0f) Alignment.CenterEnd else Alignment.CenterStart

    Box(Modifier.matchParentSize()) {
        Box(
            Modifier
                .align(alignment)
                .fillMaxHeight()
                .width(widthDp)
                .background(bg),
            contentAlignment = Alignment.Center
        ) {
            if (widthPx > 24f) {
                Icon(icon, contentDescription = label, tint = Color.White)
            }
        }
    }
}

private data class Quad<A, B, C, D>(val a: A, val b: B, val c: C, val d: D)

@Composable
private fun FoodRow(
    entry: FoodEntry,
    isFavorite: Boolean = false,
    rowShape: RoundedCornerShape = RoundedCornerShape(2.dp),
    scrapbookIndex: Int = kotlin.math.abs(entry.id.hashCode())
) {
    val ctx = LocalContext.current
    val timeFmt = DateTimeFormatter.ofPattern(clockTimePattern(ctx), Locale.US).withZone(ZoneId.systemDefault())
    val container = (ctx.applicationContext as com.apoorvdarshan.calorietracker.FudAIApp).container
    val bitmap by produceState<android.graphics.Bitmap?>(
        initialValue = null,
        key1 = entry.imageFilename
    ) {
        value = withContext(Dispatchers.IO) {
            entry.imageFilename?.let(container.imageStore::loadThumbnail)
        }
    }
    val photoRotation = if (scrapbookIndex % 2 == 0) -2.2f else 1.8f
    val scrapRotation = when (scrapbookIndex % 4) {
        0 -> -1.25f
        1 -> 0.9f
        2 -> -0.65f
        else -> 1.1f
    }
    val detailLine = entry.ingredients
        .take(4)
        .joinToString(" · ") { it.name }
        .ifBlank {
            entry.customNote?.takeIf { it.isNotBlank() }
                ?: "P ${MacroValueFormatter.withUnit(entry.protein)}  ·  C ${MacroValueFormatter.withUnit(entry.carbs)}  ·  F ${MacroValueFormatter.withUnit(entry.fat)}"
        }
    val stampText = entry.ingredients.firstOrNull()?.name
        ?.takeIf { it.isNotBlank() }
        ?: stringResource(entry.mealType.displayNameRes)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 94.dp)
            .graphicsLayer { rotationZ = scrapRotation }
            .shadow(
                3.dp,
                rowShape,
                ambientColor = Color.Black.copy(alpha = 0.1f),
                spotColor = Color.Black.copy(alpha = 0.1f)
            )
            .clip(rowShape)
            .background(AppColors.KitchenPaper)
            .border(
                1.dp,
                AppColors.KitchenEspresso.copy(alpha = 0.17f),
                rowShape
            )
            .padding(horizontal = 6.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Column(
            modifier = Modifier.width(5.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            repeat(6) {
                Box(
                    Modifier
                        .size(3.dp)
                        .clip(CircleShape)
                        .background(AppColors.KitchenEspresso.copy(alpha = 0.28f))
                )
            }
        }
        Box(
            Modifier
                .size(80.dp)
                .graphicsLayer { rotationZ = photoRotation }
                .shadow(3.dp, RoundedCornerShape(2.dp))
                .clip(RoundedCornerShape(2.dp))
                .background(AppColors.KitchenPaper)
                .border(
                    1.dp,
                    AppColors.KitchenEspresso.copy(alpha = 0.22f),
                    RoundedCornerShape(2.dp)
                )
                .padding(4.dp),
            contentAlignment = Alignment.Center
        ) {
            val decodedBitmap = bitmap
            when {
                decodedBitmap != null -> androidx.compose.foundation.Image(
                    bitmap = decodedBitmap.asImageBitmap(),
                    contentDescription = entry.name,
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(1.dp))
                )
                entry.emoji != null -> Text(entry.emoji ?: "", fontSize = 36.sp)
                else -> Icon(
                    Icons.Filled.Restaurant,
                    contentDescription = null,
                    tint = AppColors.KitchenHerb,
                    modifier = Modifier.size(28.dp)
                )
            }
            if (entry.additionalImageFilenames.isNotEmpty()) {
                Text(
                    "+${entry.additionalImageFilenames.size}",
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(5.dp)
                        .background(Color.Black.copy(alpha = 0.62f), RoundedCornerShape(50))
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                )
            }
        }

        Column(
            Modifier.weight(1f).padding(top = 1.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        entry.name,
                        fontSize = 14.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.KitchenEspresso,
                        maxLines = 2,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    if (isFavorite) {
                        Icon(
                            Icons.Filled.Favorite,
                            contentDescription = stringResource(R.string.cd_favorited),
                            tint = AppColors.KitchenTomato,
                            modifier = Modifier.size(12.dp)
                        )
                    }
                }
            }

            Text(
                detailLine,
                fontSize = 9.sp,
                lineHeight = 11.sp,
                color = AppColors.KitchenEspresso.copy(alpha = 0.78f),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    "${entry.calories} kcal",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.KitchenTomato
                )
                entry.servingSizeGrams?.takeIf { it > 0 }?.let { grams ->
                    Text("·", color = AppColors.KitchenEspresso.copy(alpha = 0.4f))
                    val gramsText = if (grams == grams.toInt().toDouble()) "${grams.toInt()}g"
                                    else String.format("%.1fg", grams)
                    Text(
                        gramsText,
                        fontSize = 12.sp,
                        color = AppColors.KitchenEspresso.copy(alpha = 0.62f)
                    )
                }
                Spacer(Modifier.weight(1f))
                Text(
                    timeFmt.format(entry.timestamp).lowercase(),
                    fontSize = 9.sp,
                    fontStyle = FontStyle.Italic,
                    color = AppColors.KitchenHerb
                )
            }
        }

        Box(
            modifier = Modifier
                .width(43.dp)
                .height(55.dp)
                .graphicsLayer { rotationZ = if (scrapbookIndex % 2 == 0) 2.4f else -2f }
                .background(AppColors.KitchenBone)
                .border(
                    1.2.dp,
                    if (scrapbookIndex % 3 == 0) AppColors.KitchenHerb else AppColors.KitchenCobalt,
                    RoundedCornerShape(1.dp)
                )
                .padding(horizontal = 3.dp, vertical = 4.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                stampText.uppercase(Locale.getDefault()),
                fontSize = 6.sp,
                lineHeight = 7.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = if (scrapbookIndex % 3 == 0) AppColors.KitchenHerb else AppColors.KitchenCobalt,
                maxLines = 4,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun MacroChip(label: String, value: Double) {
    val chipColor = when (label) {
        "P" -> AppColors.Protein
        "C" -> AppColors.Carbs
        else -> AppColors.Fat
    }
    Box(
        Modifier
            .graphicsLayer { rotationZ = if (label == "C") 1f else -0.6f }
            .clip(RoundedCornerShape(3.dp))
            .background(AppColors.KitchenPaper)
            .border(1.dp, chipColor.copy(alpha = 0.72f), RoundedCornerShape(3.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(
            "$label ${MacroValueFormatter.withUnit(value)}",
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.KitchenEspresso.copy(alpha = 0.78f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CopyFromDaySheet(
    targetDate: LocalDate,
    allEntries: List<FoodEntry>,
    onCopy: (List<FoodEntry>) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { it != SheetValue.Hidden }
    )
    var sourceDate by remember(targetDate) { mutableStateOf(targetDate.minusDays(1)) }
    var showDatePicker by remember { mutableStateOf(false) }
    val zone = ZoneId.systemDefault()
    val dateFmt = remember { DateTimeFormatter.ofPattern("MMM d", Locale.US) }
    val sourceEntries = remember(allEntries, sourceDate) {
        allEntries
            .filter { it.timestamp.atZone(zone).toLocalDate() == sourceDate }
            .sortedByDescending { it.timestamp }
    }
    val groups = remember(sourceEntries) {
        foodLogMealGroups(sourceEntries, FoodLogSortOrder.STANDARD)
    }
    val targetText = if (targetDate == LocalDate.now()) "today" else targetDate.format(dateFmt)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.background
    ) {
        SheetReviewToolbar(
            title = stringResource(R.string.home_menu_copy_from_day),
            primaryLabel = if (sourceEntries.isEmpty()) stringResource(R.string.action_done) else stringResource(R.string.copy_all),
            onCancel = onDismiss,
            onPrimary = { if (sourceEntries.isEmpty()) onDismiss() else onCopy(sourceEntries) }
        )

        LazyColumn(
            modifier = Modifier.fillMaxWidth().padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                Column(Modifier.padding(horizontal = 20.dp)) {
                    SheetSectionHeader(stringResource(R.string.section_source))
                    SheetPillRow(onClick = { showDatePicker = true }) {
                        Text(stringResource(R.string.copy_from), fontSize = 17.sp, modifier = Modifier.weight(1f))
                        Text(
                            sourceDate.format(dateFmt),
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Foods will be copied to $targetText. Original entries stay unchanged.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                        modifier = Modifier.padding(horizontal = 18.dp)
                    )
                }
            }

            if (sourceEntries.isEmpty()) {
                item {
                    SectionCardWrapper(isFirst = true, isLast = true) {
                        Column(
                            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 28.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Icon(
                                Icons.Filled.CalendarMonth,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.45f),
                                modifier = Modifier.size(34.dp)
                            )
                            Text(
                                stringResource(R.string.copy_no_foods_on_day),
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                        }
                    }
                }
            } else {
                item {
                    FudGlassPrimaryButton(
                        text = pluralStringResource(R.plurals.copy_foods_to, sourceEntries.size, sourceEntries.size, targetText),
                        onClick = { onCopy(sourceEntries) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp)
                    )
                }

                groups.forEach { group ->
                    item(key = "copy-header-${group.id}") {
                        MealSectionHeader(meal = group.meal)
                    }
                    item(key = "copy-meal-${group.id}") {
                        FudGlassSurface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            cornerRadius = 18.dp,
                            padding = 0.dp
                        ) {
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clickable { onCopy(group.entries) }
                                    .padding(horizontal = 16.dp, vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.Center
                            ) {
                                Text(
                                    stringResource(R.string.copy_meal_format, stringResource(group.meal.displayNameRes)),
                                    color = MaterialTheme.colorScheme.primary,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                    items(group.entries, key = { "copy-entry-${it.id}" }) { entry ->
                        val index = group.entries.indexOf(entry)
                        val isFirst = index == 0
                        val isLast = index == group.entries.lastIndex
                        val rowShape = sectionCardShape(isFirst, isLast)
                        SectionCardWrapper(isFirst = isFirst, isLast = isLast, transparent = true) {
                            Box(Modifier.clickable { onCopy(listOf(entry)) }) {
                                FoodRow(entry = entry, rowShape = rowShape)
                            }
                            if (index != group.entries.lastIndex) Divider()
                        }
                    }
                }
            }
        }
    }

    if (showDatePicker) {
        var pickedDate by remember(sourceDate) { mutableStateOf(sourceDate) }
        FudGlassDialog(onDismissRequest = { showDatePicker = false }) {
            Text(stringResource(R.string.copy_from), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            DateWheelPicker(
                selected = pickedDate,
                onSelect = { pickedDate = it },
                minYear = LocalDate.now().year - 10,
                maxYear = LocalDate.now().year,
                modifier = Modifier.fillMaxWidth()
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_done),
                onPrimary = {
                    sourceDate = pickedDate
                    showDatePicker = false
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { showDatePicker = false }
            )
        }
    }
}

// ── Dialogs (unchanged styling polish) ──────────────────────────────

@Composable
private fun AnalyzingOverlay(imageBytes: ByteArray? = null) {
    // Verbatim port of ios/calorietracker/Views/AnalyzingView.swift:
    //   VStack { (image | text.magnifyingglass) → ProgressView(.large) → "Analyzing your food..." }
    //   filling the screen, opaque background, calorie-pink accents.
    val bitmap by produceState<android.graphics.Bitmap?>(initialValue = null, key1 = imageBytes) {
        value = imageBytes?.let { bytes ->
            withContext(Dispatchers.Default) {
                android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
        }
    }
    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            val decodedBitmap = bitmap
            if (decodedBitmap != null) {
                androidx.compose.foundation.Image(
                    bitmap = decodedBitmap.asImageBitmap(),
                    contentDescription = null,
                    contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                    modifier = Modifier
                        .size(250.dp)
                        .clip(RoundedCornerShape(16.dp))
                )
            } else {
                Icon(
                    Icons.Filled.ImageSearch,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(64.dp)
                )
            }
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.primary,
                strokeWidth = 4.dp,
                modifier = Modifier.size(40.dp)
            )
            // iOS uses two different copies depending on the input mode — photo flows
            // say "Analyzing your food..." while text/voice flows say
            // "Looking up nutrition..." (see ContentView.swift cases .analyzing /
            // .analyzingText). pendingImageBytes is the discriminator.
            Text(
                if (imageBytes != null) stringResource(R.string.home_analyzing_food) else stringResource(R.string.home_looking_up_nutrition),
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun CameraPairTransitionOverlay() {
    var entered by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (entered) 1f else 0.86f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = Spring.StiffnessMediumLow),
        label = "cameraPairTransitionScale"
    )

    LaunchedEffect(Unit) {
        entered = true
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.72f)),
        contentAlignment = Alignment.Center
    ) {
        FudGlassSurface(
            modifier = Modifier
                .width(250.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            cornerRadius = 28.dp,
            padding = 22.dp,
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(58.dp)
                        .clip(CircleShape)
                        .background(AppColors.CalorieGradient),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.AddAPhoto,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(30.dp)
                    )
                }
                Text(
                    stringResource(R.string.home_first_photo_saved),
                    fontSize = 19.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    stringResource(R.string.home_take_second_shot),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
                )
            }
        }
    }
}

@Composable
private fun AnalysisResultDialog(
    analysis: com.apoorvdarshan.calorietracker.services.ai.FoodAnalysis,
    onSave: () -> Unit,
    onDismiss: () -> Unit
) {
    FudGlassDialog(onDismissRequest = onDismiss) {
        Text("${analysis.emoji ?: "🍽"}  ${analysis.name}", fontSize = 21.sp, fontWeight = FontWeight.Bold)
        FudGlassSurface(modifier = Modifier.fillMaxWidth(), cornerRadius = 20.dp, padding = 16.dp) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("${analysis.calories} kcal", fontSize = 30.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Text(stringResource(R.string.macro_protein_format, MacroValueFormatter.withUnit(analysis.protein)))
                Text(stringResource(R.string.macro_carbs_format, MacroValueFormatter.withUnit(analysis.carbs)))
                Text(stringResource(R.string.macro_fat_format, MacroValueFormatter.withUnit(analysis.fat)))
                if (analysis.fiber != null || analysis.sugar != null || analysis.sodium != null) {
                    Spacer(Modifier.height(2.dp))
                    analysis.fiber?.let { Text(stringResource(R.string.nutrient_fiber_format, it.toString()), fontSize = 12.sp) }
                    analysis.sugar?.let { Text(stringResource(R.string.nutrient_sugar_format, it.toString()), fontSize = 12.sp) }
                    analysis.saturatedFat?.let { Text(stringResource(R.string.nutrient_sat_fat_format, it.toString()), fontSize = 12.sp) }
                    analysis.sodium?.let { Text(stringResource(R.string.nutrient_sodium_format, it.toString()), fontSize = 12.sp) }
                    analysis.potassium?.let { Text(stringResource(R.string.nutrient_potassium_format, it.toString()), fontSize = 12.sp) }
                    analysis.cholesterol?.let { Text(stringResource(R.string.nutrient_cholesterol_format, it.toString()), fontSize = 12.sp) }
                }
                Text(
                    stringResource(R.string.home_serving_format, analysis.servingSizeGrams.toInt()),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            }
        }
        FudGlassDialogActions(
            primaryText = stringResource(R.string.action_save),
            onPrimary = onSave,
            dismissText = stringResource(R.string.action_discard),
            onDismiss = onDismiss
        )
    }
}

@Composable
private fun TextInputDialog(onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    // Keep the input composable stable so rotating placeholder examples do not drop IME focus.
    val placeholders = listOf(
        stringResource(R.string.text_input_placeholder_1),
        stringResource(R.string.text_input_placeholder_2),
        stringResource(R.string.text_input_placeholder_3),
        stringResource(R.string.text_input_placeholder_4)
    )
    var input by remember { mutableStateOf("") }
    var placeholderIdx by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(2000)
            if (input.isEmpty()) placeholderIdx = (placeholderIdx + 1) % placeholders.size
        }
    }
    FudGlassDialog(onDismissRequest = onDismiss) {
        FudGlassTextField(
            value = input,
            onValueChange = { input = it },
            placeholder = placeholders[placeholderIdx],
            singleLine = false,
            minLines = 3,
            maxLines = 5,
            modifier = Modifier.fillMaxWidth()
        )
        FudGlassPrimaryButton(
            text = stringResource(R.string.action_analyze),
            onClick = { if (input.isNotBlank()) onSubmit(input.trim()) },
            enabled = input.isNotBlank()
        )
        TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.action_cancel), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
        }
    }
}

@Composable
private fun ManualEntryDialog(
    onDismiss: () -> Unit,
    onSave: (name: String, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double?, mealType: MealType) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var calories by remember { mutableStateOf("") }
    var protein by remember { mutableStateOf("") }
    var carbs by remember { mutableStateOf("") }
    var fat by remember { mutableStateOf("") }
    var fiber by remember { mutableStateOf("") }
    var mealType by remember { mutableStateOf(MealType.currentMeal) }
    var mealMenuExpanded by remember { mutableStateOf(false) }

    val canSave = name.isNotBlank() && calories.toIntOrNull() != null

    FudGlassDialog(onDismissRequest = onDismiss) {
                Text(stringResource(R.string.manual_title), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)

                FudGlassTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = stringResource(R.string.manual_name_placeholder),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(stringResource(R.string.manual_calories), calories, { calories = it.filter(Char::isDigit) }, Modifier.weight(1f))
                    NumberField(stringResource(R.string.manual_protein), protein, { protein = filterDecimalInput(it) }, Modifier.weight(1f), decimal = true)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    NumberField(stringResource(R.string.manual_carbs), carbs, { carbs = filterDecimalInput(it) }, Modifier.weight(1f), decimal = true)
                    NumberField(stringResource(R.string.manual_fat), fat, { fat = filterDecimalInput(it) }, Modifier.weight(1f), decimal = true)
                }
                NumberField(
                    "${stringResource(R.string.sheet_micro_fiber)} (${stringResource(R.string.unit_g)})",
                    fiber,
                    { fiber = filterDecimalInput(it) },
                    Modifier.fillMaxWidth(),
                    decimal = true
                )

                // Meal Type — DropdownMenu styled to match the FoodResultSheet /
                // EditFoodEntrySheet meal pickers (icon + label, pink, anchored
                // to the right cluster).
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .clickable { mealMenuExpanded = true }
                        .padding(horizontal = 14.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(stringResource(R.string.sheet_meal_type), fontSize = 16.sp, modifier = Modifier.weight(1f))
                    Box {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                sheetMealIcon(mealType),
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                stringResource(mealType.displayNameRes),
                                fontSize = 16.sp,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Medium
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

                FudGlassPrimaryButton(
                    text = stringResource(R.string.action_save),
                    onClick = {
                        onSave(
                            name.trim(),
                            calories.toIntOrNull() ?: 0,
                            ServingUnitOption.parseQuantity(protein) ?: 0.0,
                            ServingUnitOption.parseQuantity(carbs) ?: 0.0,
                            ServingUnitOption.parseQuantity(fat) ?: 0.0,
                            parseOptionalManualNutritionValue(fiber),
                            mealType
                        )
                    },
                    enabled = canSave,
                    modifier = Modifier.fillMaxWidth()
                )
                TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.action_cancel), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                }
    }
}

@Composable
private fun NumberField(label: String, value: String, onValueChange: (String) -> Unit, modifier: Modifier = Modifier, decimal: Boolean = false) {
    FudGlassTextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = label,
        singleLine = true,
        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
            keyboardType = if (decimal) androidx.compose.ui.text.input.KeyboardType.Decimal else androidx.compose.ui.text.input.KeyboardType.Number
        ),
        modifier = modifier
    )
}

private fun filterDecimalInput(value: String): String =
    value.filter { it.isDigit() || it == '.' || it == ',' }

internal fun parseOptionalManualNutritionValue(value: String): Double? =
    ServingUnitOption.parseQuantity(value)?.takeIf { it >= 0 }
