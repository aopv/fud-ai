package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

/** Camera review step. Photos stay as ordered independent byte arrays; the
 * optional note and complete photo set are sent as one meal request. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MultiPhotoCaptureSheet(
    imageBytesList: List<ByteArray>,
    onAddPhoto: () -> Unit,
    onRemove: (Int) -> Unit,
    onAnalyze: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var note by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        SheetReviewToolbar(
            title = "Meal Photos",
            primaryLabel = stringResource(R.string.action_analyze),
            onCancel = onDismiss,
            onPrimary = { onAnalyze(note.takeIf { it.isNotBlank() }) }
        )

        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    "${imageBytesList.size} of 10 photos",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
                if (imageBytesList.size < 10) {
                    Button(onClick = onAddPhoto) {
                        Icon(Icons.Filled.CameraAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                        Text("Add Photo", modifier = Modifier.padding(start = 8.dp))
                    }
                }
            }

            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp)
            ) {
                itemsIndexed(imageBytesList, key = { index, bytes -> "$index-${bytes.size}" }) { index, bytes ->
                    val bitmap = remember(bytes) { decodePreview(bytes) }
                    Box {
                        if (bitmap != null) {
                            androidx.compose.foundation.Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = "Photo ${index + 1}",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(width = 240.dp, height = 260.dp)
                                    .clip(RoundedCornerShape(20.dp))
                            )
                        }
                        IconButton(
                            onClick = { onRemove(index) },
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(8.dp)
                                .size(34.dp)
                                .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.62f), androidx.compose.foundation.shape.CircleShape)
                        ) {
                            Icon(Icons.Filled.Close, contentDescription = "Remove photo", tint = androidx.compose.ui.graphics.Color.White)
                        }
                        Text(
                            "Photo ${index + 1}",
                            color = androidx.compose.ui.graphics.Color.White,
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .padding(10.dp)
                                .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.58f), RoundedCornerShape(50))
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                        )
                    }
                }
            }

            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SheetSectionHeader("Add a note (optional)")
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    placeholder = { Text("e.g. chicken is 180g, rice is 220g, use half the sauce") },
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.fillMaxWidth().heightIn(min = 110.dp)
                )
            }
        }
    }
}

private fun decodePreview(bytes: ByteArray): android.graphics.Bitmap? {
    val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 720) sample *= 2
    return android.graphics.BitmapFactory.decodeByteArray(
        bytes,
        0,
        bytes.size,
        android.graphics.BitmapFactory.Options().apply { inSampleSize = sample }
    )
}

/**
 * "From Photos + Note" intermediate sheet. Shows the selected photo and a
 * multiline text field for the user to add context (e.g. "no oil", "extra
 * cheese") before sending the image off to the AI. Mirrors iOS
 * ContextDescriptionSheet which gates `cameraMode == .snapFoodWithContext`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContextNoteSheet(
    imageBytes: ByteArray,
    onAnalyze: (note: String) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var note by remember { mutableStateOf("") }
    val bitmap = remember(imageBytes) {
        android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        SheetReviewToolbar(
            title = stringResource(R.string.context_note_title),
            primaryLabel = stringResource(R.string.action_analyze),
            onCancel = onDismiss,
            onPrimary = { onAnalyze(note) }
        )

        Column(
            // Scroll + imePadding so the note field is always reachable above the
            // keyboard. Without this, the field sits below the 240dp photo and gets
            // hidden behind the keyboard on taller/OEM keyboards (e.g. Galaxy S25).
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Box(
                Modifier.fillMaxWidth().padding(top = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                if (bitmap != null) {
                    androidx.compose.foundation.Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = null,
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .size(240.dp)
                            .clip(RoundedCornerShape(20.dp))
                    )
                }
            }

            SheetSectionHeader("Add a note (optional)")

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                placeholder = {
                    Text(
                        "e.g. no oil, extra cheese, large portion",
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                    )
                },
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 110.dp)
            )
        }
    }
}
