package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.R

/**
 * "Camera + Note" intermediate sheet. Shows the just-captured photo and a
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
