package com.apoorvdarshan.calorietracker.ui.workouts

import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.apoorvdarshan.calorietracker.data.ExerciseRepository
import com.apoorvdarshan.calorietracker.models.Gender
import kotlinx.coroutines.delay
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Existing DB photographs remain the resilience path until both generated frames are accepted. */
private val ExerciseImageFilter: ColorFilter = run {
    val saturation = ColorMatrix().apply { setToSaturation(0.19f) }
    val contrast = 1.10f
    val translate = (1f - contrast) * 127.5f + (-0.05f * 255f)
    val contrastBrightness = ColorMatrix(
        floatArrayOf(
            contrast, 0f, 0f, 0f, translate,
            0f, contrast, 0f, 0f, translate,
            0f, 0f, contrast, 0f, translate,
            0f, 0f, 0f, 1f, 0f
        )
    )
    contrastBrightness.timesAssign(saturation)
    ColorFilter.colorMatrix(contrastBrightness)
}

internal data class GeneratedExerciseSequence(
    val imagePaths: List<String>,
    val frameDurationMs: Long
)

/**
 * Displays every independently generated Imagen frame listed in the bundled artwork index. An
 * incomplete or malformed indexed sequence is never mixed with legacy photography: the untouched
 * FreeExerciseDB endpoints remain the safe fallback for that exercise.
 *
 * Android packages optimized WebP derivatives from the canonical accepted-output tree at build
 * time. No network lookup, cache migration, or database write is involved. `Other` intentionally
 * follows the male art.
 */
@Composable
fun AnimatedExerciseImage(
    exerciseId: String?,
    imagePaths: List<String>,
    gender: Gender = Gender.MALE,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    fallbackLabel: String? = null
) {
    val context = LocalContext.current
    val animatorDurationScale = rememberAnimatorDurationScale()
    val figureGender = if (gender == Gender.FEMALE) "female" else "male"
    val generatedPaths = remember(context, exerciseId, figureGender) {
        val safeId = safeExerciseArtworkId(exerciseId)
        if (safeId == null) {
            null
        } else {
            val indexJson = sequenceOf("exercise-artwork-index.json", "index.json")
                .mapNotNull { assetName ->
                    runCatching {
                        context.assets.open(assetName).bufferedReader().use { it.readText() }
                    }.getOrNull()
                }
                .firstOrNull()
            generatedExerciseSequence(safeId, figureGender, indexJson)
        }
    }

    if (generatedPaths != null) {
        FrameSequence(
            imagePaths = generatedPaths.imagePaths,
            modifier = modifier,
            contentScale = ContentScale.Fit,
            colorFilter = null,
            animatorDurationScale = animatorDurationScale,
            baseFrameDurationMs = generatedPaths.frameDurationMs
        )
    } else {
        LegacyExerciseImage(
            imagePaths = imagePaths,
            modifier = modifier,
            contentScale = contentScale,
            fallbackLabel = fallbackLabel,
            animatorDurationScale = animatorDurationScale
        )
    }
}

internal fun safeExerciseArtworkId(exerciseId: String?): String? =
    exerciseId?.takeIf { it.matches(Regex("[A-Za-z0-9_-]+")) }

internal fun generatedExerciseFramePaths(
    exerciseId: String,
    gender: String,
    indexJson: String?
): List<String>? = generatedExerciseSequence(exerciseId, gender, indexJson)?.imagePaths

internal fun generatedExerciseSequence(
    exerciseId: String,
    gender: String,
    indexJson: String?
): GeneratedExerciseSequence? {
    val safeId = safeExerciseArtworkId(exerciseId) ?: return null
    if (gender !in setOf("male", "female")) return null
    if (indexJson == null) return null

    return runCatching {
        val entries = Json.parseToJsonElement(indexJson).jsonObject["entries"]?.jsonArray
            ?: return@runCatching null
        val entry = entries.firstOrNull { element ->
            val objectValue = element.jsonObject
            objectValue["exerciseID"]?.jsonPrimitive?.contentOrNull == safeId &&
                objectValue["gender"]?.jsonPrimitive?.contentOrNull == gender
        }?.jsonObject ?: return@runCatching null

        val frames = entry["frames"]?.jsonArray ?: return@runCatching null
        val indexedPaths = frames.mapNotNull { element ->
            val frame = element.jsonObject
            val frameIndex = frame["frameIndex"]?.jsonPrimitive?.intOrNull ?: return@mapNotNull null
            val packagedPath = frame["path"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
            val assetPath = if (packagedPath.startsWith("frames/")) {
                packagedPath
            } else {
                packagedPath.substringAfter("/packaged-768/", missingDelimiterValue = "")
            }
            val expectedPath = "frames/$gender/$safeId/$frameIndex.webp"
            if (assetPath == expectedPath) frameIndex to assetPath else null
        }?.sortedBy { it.first } ?: return@runCatching null

        val frameIndexes = indexedPaths.map { it.first }
        if (indexedPaths.size != frames.size || frameIndexes.size < 2 ||
            frameIndexes != frameIndexes.indices.toList()
        ) {
            null
        } else {
            val frameDurationMs = entry["frameDurationMs"]?.jsonPrimitive?.intOrNull
                ?.takeIf { it > 0 }?.toLong()
                ?: generatedFrameDurationMs(indexedPaths.size)
            GeneratedExerciseSequence(indexedPaths.map { it.second }, frameDurationMs)
        }
    }.getOrNull()
}

/** Existing two-endpoint art retains its calm cadence; interpolated sequences play smoothly. */
internal fun generatedFrameDurationMs(frameCount: Int): Long = if (frameCount >= 3) 120L else 850L

/** 0,1,2,3,2,1 avoids a visible last-frame-to-first-frame jump. */
internal fun pingPongFrameIndexes(frameCount: Int): List<Int> = when {
    frameCount <= 0 -> emptyList()
    frameCount == 1 -> listOf(0)
    else -> (0 until frameCount).toList() + (frameCount - 2 downTo 1).toList()
}

internal fun scaledFrameDurationMs(baseDurationMs: Long, animatorDurationScale: Float): Long =
    (baseDurationMs * animatorDurationScale.coerceAtLeast(0f)).toLong().coerceAtLeast(1L)

@Composable
private fun rememberAnimatorDurationScale(): Float {
    val context = LocalContext.current
    val resolver = context.contentResolver
    fun readScale(): Float = runCatching {
        Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
    }.getOrDefault(1f).coerceAtLeast(0f)

    var scale by remember(resolver) { mutableFloatStateOf(readScale()) }
    DisposableEffect(resolver) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                scale = readScale()
            }
        }
        resolver.registerContentObserver(
            Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
            false,
            observer
        )
        onDispose { resolver.unregisterContentObserver(observer) }
    }
    return scale
}

@Composable
private fun FrameSequence(
    imagePaths: List<String>,
    modifier: Modifier,
    contentScale: ContentScale,
    colorFilter: ColorFilter?,
    animatorDurationScale: Float,
    baseFrameDurationMs: Long
) {
    var index by remember(imagePaths) { mutableIntStateOf(0) }
    val playbackOrder = remember(imagePaths) { pingPongFrameIndexes(imagePaths.size) }
    LaunchedEffect(imagePaths, playbackOrder, animatorDurationScale, baseFrameDurationMs) {
        index = 0
        if (playbackOrder.size > 1 && animatorDurationScale > 0f) {
            var playbackIndex = 0
            while (true) {
                delay(scaledFrameDurationMs(baseFrameDurationMs, animatorDurationScale))
                playbackIndex = (playbackIndex + 1) % playbackOrder.size
                index = playbackOrder[playbackIndex]
            }
        }
    }
    Box(modifier) {
        imagePaths.forEachIndexed { imageIndex, path ->
            AsyncImage(
                model = ExerciseRepository.imageAssetUri(path),
                contentDescription = null,
                contentScale = contentScale,
                colorFilter = colorFilter,
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(if (imageIndex == index) 1f else 0f)
            )
        }
    }
}

@Composable
private fun LegacyExerciseImage(
    imagePaths: List<String>,
    modifier: Modifier,
    contentScale: ContentScale,
    fallbackLabel: String?,
    animatorDurationScale: Float
) {
    val colors = workoutsColors()
    if (imagePaths.isEmpty()) {
        Box(
            modifier.background(
                Brush.linearGradient(listOf(colors.panel, colors.card, colors.accent.copy(alpha = 0.12f)))
            ),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(
                    Icons.Filled.FitnessCenter,
                    contentDescription = null,
                    tint = colors.charcoal,
                    modifier = Modifier.size(36.dp)
                )
                if (!fallbackLabel.isNullOrBlank()) {
                    Text(
                        fallbackLabel.uppercase(),
                        color = colors.charcoal,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.2.sp
                    )
                }
            }
        }
        return
    }

    FrameSequence(
        imagePaths = imagePaths,
        modifier = modifier,
        contentScale = contentScale,
        colorFilter = ExerciseImageFilter,
        animatorDurationScale = animatorDurationScale,
        baseFrameDurationMs = 850L
    )
}
