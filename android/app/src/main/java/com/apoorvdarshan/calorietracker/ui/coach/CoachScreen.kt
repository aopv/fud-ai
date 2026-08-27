package com.apoorvdarshan.calorietracker.ui.coach

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import com.apoorvdarshan.calorietracker.R
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.models.ChatMessage
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.ui.components.InAppCameraCaptureDialog
import com.apoorvdarshan.calorietracker.ui.components.KitchenReceiptRule
import com.apoorvdarshan.calorietracker.models.SpeechLanguage
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavDockedControlPadding
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.io.ByteArrayOutputStream
import java.text.NumberFormat
import java.util.Base64
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.ZoneId

/**
 * Verbatim port of struct ChatView in
 * ios/calorietracker/Views/ChatView.swift.
 *
 * Layout (top to bottom):
 *   - TopAppBar with "Coach" title + reset icon (disabled when empty)
 *   - empty state OR message list (weight 1f)
 *   - horizontal scrolling promptChips (always visible)
 *   - capsule input bar with gradient send button
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CoachScreen(container: AppContainer, initialAction: String? = null) {
    val vm: CoachViewModel = viewModel(factory = CoachViewModel.Factory(container))
    val ui by vm.ui.collectAsState()
    val foods by container.foodRepository.entries.collectAsState(initial = emptyList())
    val profile by container.profileRepository.profile.collectAsState(initial = null)
    var input by remember { mutableStateOf("") }
    var attachedImageBytes by remember { mutableStateOf<ByteArray?>(null) }
    var showCameraCapture by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    var showResetConfirm by remember { mutableStateOf(false) }
    var handledInitialAction by remember { mutableStateOf<String?>(null) }
    var preparingAttachment by remember { mutableStateOf(false) }
    val ctx = LocalContext.current
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val imageScope = rememberCoroutineScope()

    // Dismiss the keyboard when the USER drags the chat (DragInteraction only —
    // the auto-scroll after sending a message must not steal focus).
    LaunchedEffect(listState) {
        listState.interactionSource.interactions.collect { interaction ->
            if (interaction is DragInteraction.Start) {
                keyboard?.hide()
                focusManager.clearFocus()
            }
        }
    }

    fun hideKeyboard() {
        focusManager.clearFocus()
        keyboard?.hide()
    }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        if (uri != null) {
            imageScope.launch {
                val bytes = withContext(Dispatchers.IO) {
                    ctx.contentResolver.openInputStream(uri)?.use { stream ->
                        val original = stream.readBytes()
                        resizedJpeg(original, maxDimension = 1800, quality = 86) ?: original
                    }
                }
                if (bytes != null) attachedImageBytes = bytes
            }
        }
    }

    val cameraPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) showCameraCapture = true
    }

    fun openCamera() {
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            showCameraCapture = true
        } else {
            cameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    fun sendCurrentDraft(textOverride: String? = null) {
        val image = attachedImageBytes
        val trimmed = (textOverride ?: input).trim()
        if (trimmed.isEmpty() && image == null) return
        if (ui.sending || preparingAttachment) return
        hideKeyboard()
        input = ""
        attachedImageBytes = null
        if (image == null) {
            vm.send(trimmed)
            return
        }
        preparingAttachment = true
        imageScope.launch {
            try {
                val (imageForAi, thumbnail) = withContext(Dispatchers.Default) {
                    (resizedJpeg(image, maxDimension = 1600, quality = 78) ?: image) to
                        (resizedJpeg(image, maxDimension = 700, quality = 68) ?: image)
                }
                vm.send(trimmed, imageBytes = imageForAi, thumbnailBytes = thumbnail)
            } finally {
                preparingAttachment = false
            }
        }
    }

    // Inline (WhatsApp-style) voice recorder — records with whatever STT provider
    // the user has configured and drops the transcript straight into the send path.
    val voiceScope = rememberCoroutineScope()
    val voiceProvider by container.prefs.selectedSpeechProvider
        .collectAsState(initial = SpeechProvider.NATIVE)
    val voiceLanguage by container.prefs.selectedSpeechLanguage(voiceProvider)
        .collectAsState(initial = SpeechLanguage.defaultFor(voiceProvider))
    val voice = remember { CoachVoiceController(ctx, container, voiceScope) { text -> sendCurrentDraft(text) } }
    LaunchedEffect(voiceProvider, voiceLanguage) {
        voice.provider = voiceProvider
        voice.nativeLocale = voiceLanguage.nativeLocaleTag()
    }

    LaunchedEffect(initialAction, voice) {
        if (initialAction == null || handledInitialAction == initialAction) return@LaunchedEffect
        handledInitialAction = initialAction
        when (initialAction) {
            "camera" -> openCamera()
            "photos" -> photoPicker.launch(
                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
            )
            "voice" -> voice.begin()
        }
    }

    LaunchedEffect(ui.messages.size, ui.sending) {
        if (ui.messages.isNotEmpty()) listState.animateScrollToItem(ui.messages.size - 1)
    }

    Scaffold(containerColor = Color.Transparent) { padding ->
        // The app is edge-to-edge, so the IME would otherwise overlay the input bar.
        // Lift the whole column above the keyboard (imePadding) with a small gap; when
        // the keyboard is down, keep the docked-nav clearance instead.
        // Keyboard-down clearance = the nav-bar system inset (from the Scaffold) plus the
        // docked-control padding, so the bar clears the floating bottom nav.
        val restClearance = padding.calculateBottomPadding() + BottomNavDockedControlPadding
        Column(
            Modifier
                .fillMaxSize()
                .padding(top = padding.calculateTopPadding() + 6.dp)
                // Track the keyboard rigidly: bottom inset = max(ime, rest clearance).
                // windowInsetsPadding animates it in the layout phase, so the bar sits
                // tight on the keyboard with no bounce and no floaty gap (a plain
                // conditional pad jumps discretely against the smooth IME animation).
                .windowInsetsPadding(
                    WindowInsets.ime
                        .union(WindowInsets(bottom = restClearance))
                        .only(WindowInsetsSides.Bottom)
                )
        ) {
            val resolvedChips = ui.suggestions.map { stringResource(it) }
            val todayFoods = remember(foods) {
                val today = LocalDate.now()
                val zone = ZoneId.systemDefault()
                foods.filter { it.timestamp.atZone(zone).toLocalDate() == today }
            }
            val todayCalories = todayFoods.sumOf { it.calories }
            val todayProtein = todayFoods.sumOf { it.protein }
            val todayCarbs = todayFoods.sumOf { it.carbs }
            val calorieUnit = stringResource(R.string.unit_kcal)
            val gramUnit = stringResource(R.string.unit_g)
            val calorieValue = "${formatWhole(todayCalories)} $calorieUnit"
            val proteinValue = "${MacroValueFormatter.string(todayProtein)} $gramUnit"
            val carbsValue = "${MacroValueFormatter.string(todayCarbs)} $gramUnit"
            val coachInsights = listOf(
                CoachInsight(
                    stringResource(R.string.macro_calories),
                    profile?.effectiveCalories?.let { target ->
                        stringResource(
                            R.string.coach_summary_with_target_format,
                            calorieValue,
                            "${formatWhole(target)} $calorieUnit"
                        )
                    } ?: stringResource(R.string.coach_summary_without_target_format, calorieValue)
                ),
                CoachInsight(
                    stringResource(R.string.macro_protein),
                    profile?.effectiveProtein?.let { target ->
                        stringResource(
                            R.string.coach_summary_with_target_format,
                            proteinValue,
                            "$target $gramUnit"
                        )
                    } ?: stringResource(R.string.coach_summary_without_target_format, proteinValue)
                ),
                CoachInsight(
                    stringResource(R.string.macro_carbs),
                    profile?.effectiveCarbs?.let { target ->
                        stringResource(
                            R.string.coach_summary_with_target_format,
                            carbsValue,
                            "$target $gramUnit"
                        )
                    } ?: stringResource(R.string.coach_summary_without_target_format, carbsValue)
                )
            )
            if (ui.messages.isEmpty()) {
                BoxWithConstraints(Modifier.fillMaxWidth().weight(1f)) {
                    val noteMinimumHeight = (maxHeight * 0.68f).coerceIn(380.dp, 455.dp)
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                    ) {
                        EmptyState(
                            headline = stringResource(R.string.coach_summary_headline_format, calorieValue),
                            insights = coachInsights,
                            minimumHeight = noteMinimumHeight,
                            modifier = Modifier.fillMaxWidth()
                        )
                        PromptChipRow(
                            chips = resolvedChips,
                            enabled = !ui.sending && !preparingAttachment,
                            onTap = { chip ->
                                hideKeyboard()
                                input = ""
                                attachedImageBytes = null
                                vm.send(chip)
                            }
                        )
                    }
                }
            } else {
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .pointerInput(Unit) {
                            detectTapGestures(onTap = { hideKeyboard() })
                        }
                ) {
                    val resolvedError = ui.error ?: ui.errorRes?.let { stringResource(it) }
                    MessageList(
                        messages = ui.messages,
                        sending = ui.sending,
                        error = resolvedError,
                        listState = listState,
                        modifier = Modifier.fillMaxSize()
                    )
                }
                PromptChipRow(
                    chips = resolvedChips,
                    enabled = !ui.sending && !preparingAttachment,
                    onTap = { chip ->
                        hideKeyboard()
                        input = ""
                        attachedImageBytes = null
                        vm.send(chip)
                    }
                )
            }

            // input bar — capsule with gradient send button
            InputBar(
                value = input,
                onValueChange = { input = it },
                attachedImageBytes = attachedImageBytes,
                sending = ui.sending || preparingAttachment,
                onPickImage = {
                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                onCaptureImage = { openCamera() },
                voice = voice,
                canReset = ui.messages.isNotEmpty(),
                onReset = { showResetConfirm = true },
                onRemoveImage = { attachedImageBytes = null },
                onSend = { sendCurrentDraft() }
            )
        }
    }

    if (showCameraCapture) {
        InAppCameraCaptureDialog(
            onCapture = { bytes ->
                showCameraCapture = false
                imageScope.launch {
                    attachedImageBytes = withContext(Dispatchers.Default) {
                        resizedJpeg(bytes, maxDimension = 1800, quality = 86) ?: bytes
                    }
                }
            },
            onDismiss = { showCameraCapture = false }
        )
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text(stringResource(R.string.coach_reset_dialog_title)) },
            text = { Text(stringResource(R.string.coach_reset_dialog_message)) },
            confirmButton = {
                TextButton(onClick = {
                    vm.resetConversation()
                    showResetConfirm = false
                }) { Text(stringResource(R.string.coach_reset_confirm), color = Color(0xFFD32F2F)) }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirm = false }) { Text(stringResource(R.string.action_cancel)) }
            }
        )
    }

}

/**
 * Verbatim port of `emptyState` in ChatView.swift.
 * 108dp glassy disc with bubble.left.and.bubble.right.fill (44sp) icon,
 * "Ask your Coach" title (rounded title2 semibold), subtitle.
 */
private data class CoachInsight(val label: String, val observation: String)

private fun formatWhole(value: Int): String = NumberFormat.getIntegerInstance().format(value)

@Composable
private fun EmptyState(
    headline: String,
    insights: List<CoachInsight>,
    minimumHeight: Dp,
    modifier: Modifier = Modifier
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val notePaper = if (isDark) Color(0xFF263A61) else Color(0xFFD7E3F6)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 32.dp, top = 4.dp, end = 32.dp, bottom = 5.dp),
        contentAlignment = Alignment.TopCenter
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 340.dp)
                .shadow(
                    8.dp,
                    RoundedCornerShape(3.dp),
                    ambientColor = Color.Black.copy(alpha = 0.14f),
                    spotColor = Color.Black.copy(alpha = 0.14f)
                )
                .clip(RoundedCornerShape(3.dp))
                .background(notePaper)
                .border(1.dp, AppColors.KitchenCobalt.copy(alpha = 0.28f), RoundedCornerShape(3.dp))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = minimumHeight)
                    .padding(horizontal = 24.dp, vertical = 30.dp),
                horizontalAlignment = Alignment.Start,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    headline,
                    style = MaterialTheme.typography.headlineLarge.copy(lineHeight = 34.sp),
                    color = AppColors.KitchenCobalt
                )
                KitchenReceiptRule(color = AppColors.KitchenCobalt)
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    insights.forEach { insight ->
                        Row(
                            modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp),
                            verticalAlignment = Alignment.Top,
                            horizontalArrangement = Arrangement.spacedBy(11.dp)
                        ) {
                            Box(
                                Modifier
                                    .padding(top = 2.dp)
                                    .size(21.dp)
                                    .border(1.dp, AppColors.KitchenCobalt, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Text("✓", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.KitchenCobalt)
                            }
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    insight.label.uppercase(Locale.getDefault()),
                                    fontSize = 10.sp,
                                    letterSpacing = 1.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = AppColors.KitchenCobalt
                                )
                                Text(
                                    insight.observation,
                                    fontSize = 13.sp,
                                    lineHeight = 18.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = AppColors.KitchenEspresso.copy(alpha = 0.88f)
                                )
                            }
                        }
                    }
                }
                KitchenReceiptRule(color = AppColors.KitchenCobalt)
                Text(
                    stringResource(R.string.coach_summary_provenance).uppercase(Locale.getDefault()),
                    fontSize = 9.sp,
                    letterSpacing = 1.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.KitchenCobalt.copy(alpha = 0.78f)
                )
            }
            Box(
                Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 8.dp)
                    .size(15.dp)
                    .shadow(3.dp, CircleShape)
                    .clip(CircleShape)
                    .background(AppColors.KitchenCobalt)
                    .border(1.dp, Color.White.copy(alpha = 0.38f), CircleShape)
            )
        }
    }
}

@Composable
private fun MessageList(
    messages: List<ChatMessage>,
    sending: Boolean,
    error: String?,
    listState: androidx.compose.foundation.lazy.LazyListState,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(messages, key = { it.id }) { MessageBubble(it) }

        if (sending) {
            item("typing") {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(3.dp))
                            .background(AppColors.KitchenPaper)
                            .border(
                                1.dp,
                                MaterialTheme.colorScheme.outlineVariant,
                                RoundedCornerShape(3.dp)
                            )
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    ) { TypingIndicator() }
                    Spacer(Modifier.weight(1f))
                }
            }
        }

        if (error != null) {
            item("error") {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFFFFEBEE).copy(alpha = 0.6f))
                        .border(0.5.dp, Color(0xFFD32F2F).copy(alpha = 0.25f), RoundedCornerShape(12.dp))
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text(error, fontSize = 12.sp, color = Color(0xFFD32F2F))
                }
            }
        }
    }
}

/**
 * 3-dot animated typing indicator. Cycles a "phase" 0 -> 1 -> 2 every 350ms;
 * the dot whose index == phase scales to 1.15 and goes opaque.
 * Verbatim port of struct TypingIndicator in ChatView.swift.
 */
@Composable
private fun TypingIndicator() {
    var phase by remember { mutableStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(350)
            phase = (phase + 1) % 3
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
        for (i in 0 until 3) {
            val active = i == phase
            val scale by animateFloatAsState(
                targetValue = if (active) 1.15f else 1.0f,
                animationSpec = tween(durationMillis = 350),
                label = "typingScale"
            )
            val alpha by animateFloatAsState(
                targetValue = if (active) 1.0f else 0.3f,
                animationSpec = tween(durationMillis = 350),
                label = "typingAlpha"
            )
            // iOS uses `.opacity(phase == i ? 1 : 0.3)` which dims the *whole* dot.
            // Use Modifier.alpha so the gradient fades uniformly instead of getting
            // a white overlay (the previous attempt actually brightened inactive dots).
            Box(
                Modifier
                    .size(7.dp)
                    .scale(scale)
                    .alpha(alpha)
                    .clip(CircleShape)
                    .background(AppColors.CalorieGradient)
            )
        }
    }
}

@Composable
private fun MessageBubble(msg: ChatMessage) {
    val isUser = msg.role == ChatMessage.Role.USER
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        if (!isUser) {
            AssistantBadge()
            Spacer(Modifier.width(8.dp))
            Bubble(content = msg.content, isUser = false)
            Spacer(Modifier.width(48.dp))
        } else {
            Spacer(Modifier.width(48.dp))
            Bubble(content = msg.content, isUser = true, attachmentImageBase64 = msg.attachmentImageBase64)
        }
    }
}

/** 26dp glassy disc with gradient sparkles icon. Verbatim port of `assistantBadge`. */
@Composable
private fun AssistantBadge() {
    Box(
        Modifier
            .padding(top = 8.dp)
            .size(26.dp)
            .clip(CircleShape)
            .background(AppColors.KitchenHerb.copy(alpha = 0.14f))
            .border(1.dp, AppColors.KitchenHerb.copy(alpha = 0.26f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Filled.AutoAwesome,
            contentDescription = null,
            modifier = Modifier.size(11.dp),
            tint = MaterialTheme.colorScheme.tertiary
        )
    }
}

/**
 * Verbatim port of `bubble`.
 *   .font(.system(.body, design: .rounded))            -> 17sp
 *   .padding(.horizontal, 16).padding(.vertical, 11)    -> same
 *   user background = LinearGradient(calorieGradient)
 *   assistant background = ultraThinMaterial + Calorie 0.035 tint
 *   stroke = LinearGradient white 0.45->0.05 user / 0.22->0.04 assistant
 *   user has top white 0.35->0 highlight (fakes .blendMode(.plusLighter))
 *   shadow user: Calorie 0.28, radius 10, y 6
 *   shadow asst: Black 0.12, radius 6, y 3
 */
@Composable
private fun Bubble(content: String, isUser: Boolean, attachmentImageBase64: String? = null) {
    val shape = if (isUser) {
        RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp, bottomStart = 4.dp, bottomEnd = 1.dp)
    } else {
        RoundedCornerShape(topStart = 1.dp, topEnd = 4.dp, bottomStart = 4.dp, bottomEnd = 4.dp)
    }
    val borderColor = if (isUser) AppColors.KitchenEspresso.copy(alpha = 0.20f)
                      else MaterialTheme.colorScheme.outlineVariant
    val shadowElevation = if (isUser) 5.dp else 3.dp
    val shadowColor = Color.Black.copy(alpha = if (isUser) 0.13f else 0.08f)

    Box(
        modifier = Modifier
            .widthIn(max = 320.dp)
            .shadow(
                elevation = shadowElevation,
                shape = shape,
                ambientColor = shadowColor,
                spotColor = shadowColor
            )
            .clip(shape)
            .then(
                if (isUser) {
                    Modifier.background(AppColors.KitchenTomato)
                } else {
                    Modifier.background(AppColors.KitchenPaper)
                }
            )
            .border(1.dp, borderColor, shape)
    ) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 11.dp)) {
            attachmentImageBase64?.let { encoded ->
                val bitmap by produceState<Bitmap?>(initialValue = null, key1 = encoded) {
                    value = withContext(Dispatchers.Default) {
                        runCatching {
                            val bytes = Base64.getDecoder().decode(encoded)
                            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                        }.getOrNull()
                    }
                }
                bitmap?.let { decodedBitmap ->
                    Image(
                        bitmap = decodedBitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(150.dp)
                            .clip(RoundedCornerShape(14.dp))
                    )
                    Spacer(Modifier.height(8.dp))
                }
            }
            if (isUser) {
                // User's own typed text — show verbatim, no markdown.
                Text(
                    content,
                    fontSize = 17.sp,
                    color = Color.White,
                    lineHeight = 22.sp,
                    style = TextStyle(fontWeight = FontWeight.Normal)
                )
            } else {
                // Coach replies often use markdown — render it.
                MarkdownText(content = content, color = MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}

/**
 * Horizontal scrolling chips. Verbatim port of `promptChips`.
 *   ScrollView(.horizontal) HStack spacing 8
 *     Capsule (ultraThinMaterial + Calorie 0.10 fill + Calorie 0.35->0.10 stroke)
 *     padding 14h × 9v, footnote rounded medium, calorie text
 */
@Composable
private fun PromptChipRow(chips: List<String>, enabled: Boolean, onTap: (String) -> Unit) {
    if (chips.isEmpty()) return
    var showMore by remember(chips) { mutableStateOf(false) }
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        chips.take(2).forEach { chip ->
            PromptChip(
                text = chip,
                enabled = enabled,
                onTap = onTap,
                modifier = Modifier.fillMaxWidth()
            )
        }
        if (chips.size > 2) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .clickable(enabled = enabled) { showMore = !showMore }
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    stringResource(if (showMore) R.string.coach_fewer_prompts else R.string.coach_more_prompts),
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.KitchenCobalt
                )
                Text(
                    if (showMore) "−" else "+",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = AppColors.KitchenCobalt
                )
            }
            if (showMore) {
                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(chips.drop(2)) { chip ->
                        PromptChip(
                            text = chip,
                            enabled = enabled,
                            onTap = onTap,
                            modifier = Modifier.width(238.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PromptChip(
    text: String,
    enabled: Boolean,
    onTap: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(3.dp)
    Box(
        modifier
            .heightIn(min = 50.dp)
            .clip(shape)
            .background(AppColors.KitchenPaper)
            .border(1.dp, AppColors.KitchenBrass.copy(alpha = 0.62f), shape)
            .clickable(enabled = enabled) { onTap(text) }
            .padding(horizontal = 15.dp, vertical = 10.dp),
        contentAlignment = Alignment.CenterStart
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text,
                modifier = Modifier.weight(1f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text("›", fontSize = 24.sp, color = AppColors.KitchenEspresso.copy(alpha = 0.55f))
        }
    }
}

/**
 * Capsule input bar. Verbatim port of `inputBar`.
 *   capsule containing TextField + 34dp gradient send button
 *   ultraThinMaterial fill + glassy stroke + drop shadow
 *   send: arrow.up icon, 16sp bold, white-on-gradient when canSend, gray otherwise
 */
@Composable
private fun InputBar(
    value: String,
    onValueChange: (String) -> Unit,
    attachedImageBytes: ByteArray?,
    sending: Boolean,
    onPickImage: () -> Unit,
    onCaptureImage: () -> Unit,
    voice: CoachVoiceController,
    canReset: Boolean,
    onReset: () -> Unit,
    onRemoveImage: () -> Unit,
    onSend: () -> Unit
) {
    val canSend = !sending && (value.trim().isNotEmpty() || attachedImageBytes != null)
    val capsule = RoundedCornerShape(4.dp)

    Column(
        modifier = Modifier
            .padding(horizontal = 12.dp)
            .padding(top = 4.dp, bottom = 10.dp)
            .fillMaxWidth()
            .shadow(
                elevation = 6.dp,
                shape = capsule,
                ambientColor = Color.Black.copy(alpha = 0.18f),
                spotColor = Color.Black.copy(alpha = 0.18f)
            )
            .clip(capsule)
            .background(AppColors.KitchenPaper)
            .border(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
                capsule
            )
            .padding(start = 4.dp, end = 5.dp, top = 4.dp, bottom = 4.dp),
    ) {
        attachedImageBytes?.let { bytes ->
            val bitmap by produceState<Bitmap?>(initialValue = null, key1 = bytes) {
                this.value = withContext(Dispatchers.Default) {
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }
            }
            bitmap?.let { decodedBitmap ->
                Box(
                    modifier = Modifier
                        .padding(start = 10.dp, end = 10.dp, top = 8.dp, bottom = 4.dp)
                        .size(width = 88.dp, height = 70.dp)
                        .clip(RoundedCornerShape(16.dp))
                ) {
                    Image(
                        bitmap = decodedBitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                    IconButton(
                        onClick = onRemoveImage,
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .size(48.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(24.dp)
                                .clip(CircleShape)
                                .background(Color.Black.copy(alpha = 0.55f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Filled.Close, contentDescription = stringResource(R.string.cd_remove_image), tint = Color.White, modifier = Modifier.size(14.dp))
                        }
                    }
                }
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (voice.phase != VoicePhase.Idle) {
                // Recording: the media pill + text field are replaced by the live
                // recording indicator (timer + slide-to-cancel hint / live text).
                CoachRecordingIndicator(voice, Modifier.weight(1f))
            } else {
                if (canReset) {
                    CoachMediaActionButton(
                        icon = Icons.Filled.Replay,
                        contentDescription = stringResource(R.string.coach_reset_chat_a11y),
                        enabled = !sending,
                        onClick = onReset
                    )
                }
                CoachMediaActions(
                    enabled = !sending,
                    onPickImage = onPickImage,
                    onCaptureImage = onCaptureImage
                )

                Box(Modifier.weight(1f).padding(horizontal = 2.dp, vertical = 8.dp)) {
                    if (value.isEmpty()) {
                        Text(
                            stringResource(R.string.coach_input_placeholder),
                            fontSize = 17.sp,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f)
                        )
                    }
                    BasicTextField(
                        value = value,
                        onValueChange = onValueChange,
                        textStyle = LocalTextStyle.current.copy(
                            color = MaterialTheme.colorScheme.onSurface,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Normal
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { onSend() }),
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            // Trailing control. Keep the mic at a stable call site (the else branch)
            // so a held press survives the left region swapping to the indicator.
            when {
                voice.phase == VoicePhase.Locked -> {
                    CoachVoiceCancelButton { voice.cancel() }
                    SendButton(canSend = true) { voice.stopAndSend() }
                }
                voice.phase == VoicePhase.Transcribing -> Unit
                canSend -> SendButton(canSend = canSend, onClick = onSend)
                else -> CoachMicButton(voice)
            }
        }
    }
}

@Composable
private fun CoachMediaActions(
    enabled: Boolean,
    onPickImage: () -> Unit,
    onCaptureImage: () -> Unit
) {
    val shape = RoundedCornerShape(19.dp)
    Row(
        modifier = Modifier
            .clip(shape),
        horizontalArrangement = Arrangement.spacedBy(0.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        CoachMediaActionButton(
            icon = Icons.Filled.PhotoLibrary,
            contentDescription = stringResource(R.string.cd_add_image),
            enabled = enabled,
            onClick = onPickImage
        )
        CoachMediaActionButton(
            icon = Icons.Filled.CameraAlt,
            contentDescription = stringResource(R.string.cd_open_camera),
            enabled = enabled,
            onClick = onCaptureImage
        )
    }
}

@Composable
private fun CoachMediaActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    contentDescription: String,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(
                    if (enabled) AppColors.Calorie.copy(alpha = 0.11f)
                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
                )
                .border(
                    0.6.dp,
                    Brush.linearGradient(
                        listOf(
                            Color.White.copy(alpha = 0.16f),
                            AppColors.Calorie.copy(alpha = 0.12f)
                        )
                    ),
                    CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                icon,
                contentDescription = contentDescription,
                tint = if (enabled) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.32f),
                modifier = Modifier.size(17.dp)
            )
        }
    }
}

@Composable
private fun SendButton(canSend: Boolean, onClick: () -> Unit) {
    val shape = CircleShape
    Box(
        Modifier
            .size(48.dp)
            .clickable(enabled = canSend, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Box(
            Modifier
                .size(34.dp)
                .then(
                    if (canSend) {
                        Modifier.shadow(
                            elevation = 8.dp,
                            shape = shape,
                            ambientColor = AppColors.Calorie.copy(alpha = 0.35f),
                            spotColor = AppColors.Calorie.copy(alpha = 0.35f)
                        )
                    } else Modifier
                )
                .clip(shape)
                .then(
                    if (canSend) Modifier.background(AppColors.CalorieGradient)
                    else Modifier.background(Color.Gray.copy(alpha = 0.35f))
                )
                .border(
                    0.6.dp,
                    Color.White.copy(alpha = if (canSend) 0.25f else 0.10f),
                    shape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.Filled.ArrowUpward,
                contentDescription = stringResource(R.string.coach_send_a11y),
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

private fun resizedJpeg(bytes: ByteArray, maxDimension: Int, quality: Int): ByteArray? {
    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
    val longest = maxOf(bitmap.width, bitmap.height)
    val scaled = if (longest > maxDimension) {
        val ratio = maxDimension.toFloat() / longest.toFloat()
        Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * ratio).toInt().coerceAtLeast(1),
            (bitmap.height * ratio).toInt().coerceAtLeast(1),
            true
        )
    } else {
        bitmap
    }
    return ByteArrayOutputStream().use { out ->
        scaled.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), out)
        out.toByteArray()
    }
}

// ── Markdown rendering for Coach replies ────────────────────────────────
// Lightweight renderer for the formatting the Coach actually emits: #/##/### headings,
// "- / * / 1." lists, ``` code fences ```, `inline code`, **bold**, *italic*, [links](url).
// Block layout here; inline styling via AnnotatedString. No third-party dependency.

private sealed class MdBlock {
    data class Heading(val level: Int, val text: String) : MdBlock()
    data class Bullet(val text: String) : MdBlock()
    data class Numbered(val number: String, val text: String) : MdBlock()
    data class Code(val text: String) : MdBlock()
    data class Paragraph(val text: String) : MdBlock()
}

private fun parseMarkdownBlocks(raw: String): List<MdBlock> {
    val blocks = mutableListOf<MdBlock>()
    val lines = raw.replace("\r\n", "\n").split("\n")
    var i = 0
    while (i < lines.size) {
        val trimmed = lines[i].trim()
        when {
            trimmed.startsWith("```") -> {
                val code = mutableListOf<String>()
                i++
                while (i < lines.size && !lines[i].trim().startsWith("```")) {
                    code.add(lines[i]); i++
                }
                i++ // skip closing fence
                blocks.add(MdBlock.Code(code.joinToString("\n")))
            }
            trimmed.isEmpty() -> i++
            headingLevel(trimmed) != null -> {
                val level = headingLevel(trimmed)!!
                blocks.add(MdBlock.Heading(level, trimmed.trimStart('#').trim()))
                i++
            }
            trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ") -> {
                blocks.add(MdBlock.Bullet(trimmed.drop(2).trim())); i++
            }
            numberedItem(trimmed) != null -> {
                val (num, rest) = numberedItem(trimmed)!!
                blocks.add(MdBlock.Numbered(num, rest)); i++
            }
            else -> { blocks.add(MdBlock.Paragraph(trimmed)); i++ }
        }
    }
    return blocks
}

private fun headingLevel(s: String): Int? {
    val hashes = s.takeWhile { it == '#' }.length
    if (hashes in 1..3 && s.getOrNull(hashes) == ' ') return hashes
    return null
}

private fun numberedItem(s: String): Pair<String, String>? {
    val dot = s.indexOf('.')
    if (dot <= 0) return null
    val num = s.substring(0, dot)
    if (!num.all { it.isDigit() } || s.getOrNull(dot + 1) != ' ') return null
    return num to s.substring(dot + 1).trim()
}

/** Inline markdown → AnnotatedString: **bold**, *italic* / _italic_, `code`, [text](url). */
private fun inlineMarkdown(text: String, linkColor: Color, codeBg: Color): AnnotatedString = buildAnnotatedString {
    var i = 0
    val n = text.length
    while (i < n) {
        val c = text[i]
        when {
            c == '*' && i + 1 < n && text[i + 1] == '*' -> {
                val end = text.indexOf("**", i + 2)
                if (end != -1) {
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(text.substring(i + 2, end)) }
                    i = end + 2
                } else { append(c); i++ }
            }
            (c == '*' || c == '_') -> {
                val end = text.indexOf(c, i + 1)
                if (end > i + 1) {
                    withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(text.substring(i + 1, end)) }
                    i = end + 1
                } else { append(c); i++ }
            }
            c == '`' -> {
                val end = text.indexOf('`', i + 1)
                if (end != -1) {
                    withStyle(SpanStyle(fontFamily = FontFamily.Monospace, background = codeBg)) {
                        append(text.substring(i + 1, end))
                    }
                    i = end + 1
                } else { append(c); i++ }
            }
            c == '[' -> {
                val close = text.indexOf(']', i + 1)
                val open = if (close != -1) close + 1 else -1
                if (close != -1 && text.getOrNull(open) == '(') {
                    val urlEnd = text.indexOf(')', open + 1)
                    if (urlEnd != -1) {
                        withStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)) {
                            append(text.substring(i + 1, close))
                        }
                        i = urlEnd + 1
                    } else { append(c); i++ }
                } else { append(c); i++ }
            }
            else -> { append(c); i++ }
        }
    }
}

@Composable
private fun MarkdownText(content: String, color: Color) {
    val linkColor = AppColors.Calorie
    val codeBg = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
    val blocks = remember(content) { parseMarkdownBlocks(content) }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        blocks.forEach { block ->
            when (block) {
                is MdBlock.Heading -> Text(
                    inlineMarkdown(block.text, linkColor, codeBg),
                    color = color,
                    fontWeight = FontWeight.Bold,
                    fontSize = when (block.level) { 1 -> 20.sp; 2 -> 18.sp; else -> 16.sp },
                    lineHeight = 24.sp
                )
                is MdBlock.Bullet -> Row {
                    Text("•", color = color, fontSize = 17.sp, lineHeight = 22.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(inlineMarkdown(block.text, linkColor, codeBg), color = color, fontSize = 17.sp, lineHeight = 22.sp)
                }
                is MdBlock.Numbered -> Row {
                    Text("${block.number}.", color = color, fontSize = 17.sp, fontWeight = FontWeight.Medium, lineHeight = 22.sp)
                    Spacer(Modifier.width(8.dp))
                    Text(inlineMarkdown(block.text, linkColor, codeBg), color = color, fontSize = 17.sp, lineHeight = 22.sp)
                }
                is MdBlock.Code -> Box(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(codeBg).padding(10.dp)
                ) {
                    Text(block.text, color = color, fontFamily = FontFamily.Monospace, fontSize = 14.sp, lineHeight = 20.sp)
                }
                is MdBlock.Paragraph -> Text(
                    inlineMarkdown(block.text, linkColor, codeBg),
                    color = color, fontSize = 17.sp, lineHeight = 22.sp
                )
            }
        }
    }
}
