package com.apoorvdarshan.calorietracker.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetReceiver

/** Keeps widget recovery work registered while at least one widget is installed. */
abstract class FudGlanceAppWidgetReceiver : GlanceAppWidgetReceiver() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshScheduler.onWidgetEnabled(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetRefreshScheduler.ensurePeriodic(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetRefreshScheduler.stopIfUnused(context)
    }
}
