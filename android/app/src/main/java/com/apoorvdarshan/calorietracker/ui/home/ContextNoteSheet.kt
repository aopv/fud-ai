package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.components.KitchenReceiptRule
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Camera review step. Photos stay as ordered independent byte arrays; the
 * optional note and complete photo set are sent as one meal request. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MultiPhotoCaptureSheet(
    imageBytesList: List<ByteArray>,
    addsFromLibrary: Boolean,
    onAddPhoto: () -> Unit,
    onRemove: (Int) -> Unit,
    onAnalyze: (String?, Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var note by remember { mutableStateOf("") }
    var progressiveMeal by remember { mutableStateOf(false) }
    var showProgressiveInfo by remember { mutableStateOf(false) }
    var noteExpanded by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
        containerColor = AppColors.KitchenPaper
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(
                onClick = onDismiss,
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Text(
                    stringResource(R.string.action_cancel),
                    color = AppColors.KitchenCobalt,
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                "${imageBytesList.size} / 10",
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.labelMedium,
                color = AppColors.KitchenEspresso.copy(alpha = 0.62f),
                textAlign = TextAlign.Center
            )
            Button(
                onClick = {
                    onAnalyze(
                        note.takeIf { it.isNotBlank() },
                        progressiveMeal && imageBytesList.size > 1
                    )
                },
                shape = RoundedCornerShape(3.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.KitchenTomato,
                    contentColor = AppColors.KitchenCream
                ),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 7.dp),
                modifier = Modifier.heightIn(min = 48.dp)
            ) {
                Text(
                    stringResource(R.string.action_analyze),
                    fontWeight = FontWeight.Bold
                )
            }
        }

        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(bottom = 18.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val photoWidth = (maxWidth - 28.dp).coerceAtLeast(240.dp)
                val photoHeight = photoWidth.coerceAtMost(372.dp)
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = 14.dp)
                ) {
                    itemsIndexed(imageBytesList, key = { index, bytes -> "$index-${bytes.size}" }) { index, bytes ->
                        val bitmap by produceState<android.graphics.Bitmap?>(
                            initialValue = null,
                            key1 = bytes
                        ) {
                            value = withContext(Dispatchers.Default) { decodePreview(bytes) }
                        }
                        val photoDescription = stringResource(R.string.capture_photo_description, index + 1)
                        Box(
                            modifier = Modifier
                                .width(photoWidth)
                                .height(photoHeight)
                                .clip(RoundedCornerShape(3.dp))
                                .background(AppColors.KitchenBone)
                                .border(
                                    1.dp,
                                    AppColors.KitchenEspresso.copy(alpha = 0.22f),
                                    RoundedCornerShape(3.dp)
                                )
                        ) {
                            val decodedBitmap = bitmap
                            if (decodedBitmap != null) {
                                androidx.compose.foundation.Image(
                                    bitmap = decodedBitmap.asImageBitmap(),
                                    contentDescription = photoDescription,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                            } else {
                                Icon(
                                    Icons.Filled.PhotoLibrary,
                                    contentDescription = null,
                                    tint = AppColors.KitchenEspresso.copy(alpha = 0.34f),
                                    modifier = Modifier.align(Alignment.Center).size(34.dp)
                                )
                            }
                            IconButton(
                                onClick = { onRemove(index) },
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(48.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(Color.Black.copy(alpha = 0.62f), androidx.compose.foundation.shape.CircleShape),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        Icons.Filled.Close,
                                        contentDescription = stringResource(R.string.cd_remove_image),
                                        tint = Color.White,
                                        modifier = Modifier.size(19.dp)
                                    )
                                }
                            }
                            Text(
                                stringResource(R.string.capture_photo_label, index + 1).uppercase(Locale.getDefault()),
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = AppColors.KitchenEspresso,
                                modifier = Modifier
                                    .align(Alignment.BottomStart)
                                    .padding(9.dp)
                                    .background(AppColors.KitchenPaper.copy(alpha = 0.92f), RoundedCornerShape(2.dp))
                                    .border(
                                        1.dp,
                                        AppColors.KitchenEspresso.copy(alpha = 0.22f),
                                        RoundedCornerShape(2.dp)
                                    )
                                    .padding(horizontal = 9.dp, vertical = 5.dp)
                            )
                        }
                    }
                }
            }

            val utilityShape = RoundedCornerShape(3.dp)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .clip(utilityShape)
                    .background(AppColors.KitchenPaper)
                    .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.18f), utilityShape)
                    .heightIn(min = 48.dp)
                    .clickable(enabled = imageBytesList.size < 10, onClick = onAddPhoto)
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    pluralStringResource(
                        R.plurals.capture_photo_count,
                        imageBytesList.size,
                        imageBytesList.size,
                        10
                    ).uppercase(Locale.getDefault()),
                    style = MaterialTheme.typography.labelSmall,
                    color = AppColors.KitchenEspresso.copy(alpha = 0.66f)
                )
                Spacer(Modifier.weight(1f))
                if (imageBytesList.size < 10) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            if (addsFromLibrary) Icons.Filled.PhotoLibrary else Icons.Filled.CameraAlt,
                            contentDescription = null,
                            tint = AppColors.KitchenTomato,
                            modifier = Modifier.size(16.dp)
                        )
                        Text(
                            stringResource(
                                if (addsFromLibrary) R.string.capture_add_photos else R.string.capture_add_photo
                            ).uppercase(Locale.getDefault()),
                            modifier = Modifier.padding(start = 7.dp),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.KitchenTomato
                        )
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .clip(utilityShape)
                    .background(AppColors.KitchenPaper)
                    .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.18f), utilityShape)
                    .padding(horizontal = 12.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(1.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(R.string.progressive_meal_title),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.KitchenHerb
                        )
                        IconButton(
                            onClick = { showProgressiveInfo = true },
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                Icons.Filled.Info,
                                contentDescription = stringResource(R.string.progressive_meal_info_title),
                                tint = AppColors.KitchenTomato,
                                modifier = Modifier.size(17.dp)
                            )
                        }
                    }
                    Text(
                        stringResource(
                            if (imageBytesList.size > 1) R.string.capture_progressive_ready
                            else R.string.capture_progressive_needs_second
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        color = AppColors.KitchenEspresso.copy(alpha = 0.62f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Switch(
                    checked = progressiveMeal,
                    onCheckedChange = { progressiveMeal = it },
                    enabled = imageBytesList.size > 1
                )
            }

            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .clip(utilityShape)
                    .background(AppColors.KitchenPaper)
                    .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.18f), utilityShape)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .clickable { noteExpanded = !noteExpanded }
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            stringResource(R.string.context_note_section).uppercase(),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.KitchenHerb
                        )
                        if (note.isNotBlank() && !noteExpanded) {
                            Text(
                                note,
                                style = MaterialTheme.typography.labelSmall,
                                color = AppColors.KitchenEspresso.copy(alpha = 0.66f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    Text(
                        if (noteExpanded) "−" else "+",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = AppColors.KitchenTomato
                    )
                }
                if (noteExpanded) {
                    KitchenReceiptRule(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp),
                        color = AppColors.KitchenHerb
                    )
                    OutlinedTextField(
                        value = note,
                        onValueChange = { note = it },
                        placeholder = { Text(stringResource(R.string.context_note_placeholder)) },
                        textStyle = MaterialTheme.typography.bodyMedium,
                        shape = RoundedCornerShape(3.dp),
                        maxLines = 3,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 10.dp, vertical = 9.dp)
                            .heightIn(min = 74.dp)
                    )
                }
            }
        }
    }

    if (showProgressiveInfo) {
        AlertDialog(
            onDismissRequest = { showProgressiveInfo = false },
            title = { Text(stringResource(R.string.progressive_meal_info_title)) },
            text = { Text(stringResource(R.string.progressive_meal_info_body)) },
            confirmButton = {
                TextButton(onClick = { showProgressiveInfo = false }) {
                    Text(stringResource(R.string.action_done))
                }
            }
        )
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
