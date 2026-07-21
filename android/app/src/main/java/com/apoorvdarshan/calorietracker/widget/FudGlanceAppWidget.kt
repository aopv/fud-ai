package com.apoorvdarshan.calorietracker.widget

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidget
import com.apoorvdarshan.calorietracker.R

/** Shared error handling for every Fud AI home-screen widget. */
abstract class FudGlanceAppWidget : GlanceAppWidget(R.layout.widget_initial_fallback) {
    override fun onCompositionError(
        context: Context,
        glanceId: GlanceId,
        appWidgetId: Int,
        throwable: Throwable
    ) {
        Log.e(TAG, "Widget composition failed for appWidgetId=$appWidgetId", throwable)
        super.onCompositionError(context, glanceId, appWidgetId, throwable)
    }

    private companion object {
        const val TAG = "FudAIWidget"
    }
}
