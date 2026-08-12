package com.apoorvdarshan.calorietracker.ui.workouts

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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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

/**
 * Displays the two independently generated Imagen endpoints when the complete gender pair is
 * bundled. A partial or rejected pair is never mixed with legacy photography: the untouched
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
    val animationsEnabled = remember(context) {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f
        ) != 0f
    }
    val figureGender = if (gender == Gender.FEMALE) "female" else "male"
    val generatedPaths = remember(context, exerciseId, figureGender) {
        val safeId = safeExerciseArtworkId(exerciseId)
        if (safeId == null) {
            null
        } else {
            val directory = "frames/$figureGender/$safeId"
            val names = runCatching {
                context.assets.list(directory)?.toSet().orEmpty()
            }.getOrDefault(emptySet())
            generatedExerciseFramePaths(safeId, figureGender, names)
        }
    }

    if (generatedPaths != null) {
        FrameSequence(
            imagePaths = generatedPaths,
            modifier = modifier,
            contentScale = ContentScale.Fit,
            colorFilter = null,
            animationsEnabled = animationsEnabled,
            frameDurationMs = 850L
        )
    } else {
        LegacyExerciseImage(
            imagePaths = imagePaths,
            modifier = modifier,
            contentScale = contentScale,
            fallbackLabel = fallbackLabel,
            animationsEnabled = animationsEnabled
        )
    }
}

internal fun safeExerciseArtworkId(exerciseId: String?): String? =
    exerciseId?.takeIf { it.matches(Regex("[A-Za-z0-9_-]+")) }

internal fun generatedExerciseFramePaths(
    exerciseId: String,
    gender: String,
    availableFilenames: Set<String>
): List<String>? {
    val safeId = safeExerciseArtworkId(exerciseId) ?: return null
    if (gender !in setOf("male", "female")) return null
    if ("0.webp" !in availableFilenames || "1.webp" !in availableFilenames) return null
    val directory = "frames/$gender/$safeId"
    return listOf("$directory/0.webp", "$directory/1.webp")
}

@Composable
private fun FrameSequence(
    imagePaths: List<String>,
    modifier: Modifier,
    contentScale: ContentScale,
    colorFilter: ColorFilter?,
    animationsEnabled: Boolean,
    frameDurationMs: Long
) {
    var index by remember(imagePaths) { mutableIntStateOf(0) }
    LaunchedEffect(imagePaths, animationsEnabled, frameDurationMs) {
        index = 0
        if (imagePaths.size > 1 && animationsEnabled) {
            while (true) {
                delay(frameDurationMs)
                index = (index + 1) % imagePaths.size
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
    animationsEnabled: Boolean
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
        animationsEnabled = animationsEnabled,
        frameDurationMs = 850L
    )
}
