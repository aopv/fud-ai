package com.apoorvdarshan.calorietracker.services

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Combines the two Camera + Camera shots into a single side-by-side image so
 * the food log row and edit sheet can show both angles through the entry's
 * one image slot. Mirrors iOS FoodImageComposer.
 */
object FoodImageComposer {
    /**
     * Both halves are scaled to a common height (bounded by the smaller photo
     * and this cap) so the pair lines up and the stored JPEG stays small.
     */
    private const val MAX_HEIGHT = 1200

    /** Returns the composite JPEG, or [first] unchanged if anything fails to decode. */
    fun sideBySide(first: ByteArray, second: ByteArray): ByteArray {
        val left = decodeUpright(first) ?: return first
        val right = decodeUpright(second) ?: return first

        val height = min(min(left.height, right.height), MAX_HEIGHT)
        if (height <= 0) return first
        val leftWidth = (left.width * height / left.height.toFloat()).roundToInt()
        val rightWidth = (right.width * height / right.height.toFloat()).roundToInt()
        if (leftWidth <= 0 || rightWidth <= 0) return first

        val combined = Bitmap.createBitmap(leftWidth + rightWidth, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(combined)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(left, null, Rect(0, 0, leftWidth, height), paint)
        canvas.drawBitmap(right, null, Rect(leftWidth, 0, leftWidth + rightWidth, height), paint)

        val out = ByteArrayOutputStream()
        combined.compress(Bitmap.CompressFormat.JPEG, 80, out)
        return out.toByteArray()
    }

    /**
     * Decode honoring EXIF orientation. BitmapFactory ignores the EXIF tag, and
     * re-encoding the composite drops it — without this a device that stores
     * rotation as metadata would get a sideways half baked into the result.
     */
    private fun decodeUpright(bytes: ByteArray): Bitmap? {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(bytes))
                .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
