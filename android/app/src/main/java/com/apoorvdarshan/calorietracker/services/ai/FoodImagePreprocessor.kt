package com.apoorvdarshan.calorietracker.services.ai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.math.max

/** Prepares food photos for vision requests without changing the locally stored original. */
internal object FoodImagePreprocessor {
    private const val MAX_DIMENSION = 1_600
    private const val JPEG_QUALITY = 80

    fun prepareForUpload(bytes: ByteArray): ByteArray = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return bytes

        var sampleSize = 1
        val longest = max(bounds.outWidth, bounds.outHeight)
        while (longest / (sampleSize * 2) >= MAX_DIMENSION) sampleSize *= 2

        val decoded = BitmapFactory.decodeByteArray(
            bytes,
            0,
            bytes.size,
            BitmapFactory.Options().apply { inSampleSize = sampleSize }
        ) ?: return bytes
        val oriented = decoded.applyingExifOrientation(bytes)
        val orientedLongest = max(oriented.width, oriented.height)
        val scaled = if (orientedLongest > MAX_DIMENSION) {
            val ratio = MAX_DIMENSION.toFloat() / orientedLongest.toFloat()
            Bitmap.createScaledBitmap(
                oriented,
                (oriented.width * ratio).toInt().coerceAtLeast(1),
                (oriented.height * ratio).toInt().coerceAtLeast(1),
                true
            )
        } else {
            oriented
        }

        ByteArrayOutputStream().use { output ->
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)) return bytes
            output.toByteArray()
        }
    }.getOrDefault(bytes)

    private fun Bitmap.applyingExifOrientation(bytes: ByteArray): Bitmap {
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return this
        }
        return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
    }
}
