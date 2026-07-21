package com.apoorvdarshan.calorietracker.services

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.apoorvdarshan.calorietracker.services.update.AndroidUpdateChecker
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.apoorvdarshan.calorietracker.MainActivity
import com.apoorvdarshan.calorietracker.R
import java.util.Calendar

/**
 * Schedules + fires the local reminders the app supports:
 *   - Weight log reminder: daily at 8:00am — gated by the master Notifications
 *     toggle so it tracks the system permission state and never fires silently
 *   - Streak reminder + Daily summary: present in code for parity with iOS but
 *     not wired to the Settings UI yet
 *
 * Uses inexact alarms (setAndAllowWhileIdle) — a daily nudge firing within a
 * few minutes of the chosen time is perfectly fine, and Play Store reserves
 * the exact-alarm permission for calendar / alarm-clock apps only.
 *
 * Also owns the "weight_goal" channel used from WeightRepository crossings.
 *
 * OriginOS / MIUI / HyperOS aggressive battery optimization can still kill
 * inexact alarms unless the app is whitelisted — Settings UI exposes a deep
 * link to the battery-optimization exception screen.
 */
class NotificationService(private val context: Context) {

    fun createChannels() {
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val streak = NotificationChannel(
            CHANNEL_STREAK,
            context.getString(R.string.notif_channel_streak),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = context.getString(R.string.notif_channel_streak_desc) }

        val daily = NotificationChannel(
            CHANNEL_DAILY,
            context.getString(R.string.notif_channel_daily),
            NotificationManager.IMPORTANCE_LOW
        ).apply { description = context.getString(R.string.notif_channel_daily_desc) }

        val goal = NotificationChannel(
            CHANNEL_WEIGHT_GOAL,
            context.getString(R.string.notif_channel_weight_goal),
            NotificationManager.IMPORTANCE_HIGH
        ).apply { description = context.getString(R.string.notif_channel_weight_goal_desc) }

        val weight = NotificationChannel(
            CHANNEL_WEIGHT_LOG,
            context.getString(R.string.notif_channel_weight_log),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = context.getString(R.string.notif_channel_weight_log_desc) }

        val bodyFat = NotificationChannel(
            CHANNEL_BODY_FAT_LOG,
            context.getString(R.string.notif_channel_body_fat),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = context.getString(R.string.notif_channel_body_fat_desc) }

        val appUpdate = NotificationChannel(
            CHANNEL_APP_UPDATE,
            context.getString(R.string.notif_channel_updates),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = context.getString(R.string.notif_channel_updates_desc) }

        val water = NotificationChannel(
            CHANNEL_WATER,
            context.getString(R.string.notif_channel_water),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply { description = context.getString(R.string.notif_channel_water_desc) }

        mgr.createNotificationChannels(listOf(streak, daily, goal, weight, bodyFat, appUpdate, water))
    }

    fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun showGoalReached() {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val content = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notif = NotificationCompat.Builder(context, CHANNEL_WEIGHT_GOAL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.notif_goal_weight_title))
            .setContentText(context.getString(R.string.notif_goal_weight_text))
            .setContentIntent(content)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        NotificationManagerCompat.from(context).notifySafely(context, GOAL_NOTIFICATION_ID, notif)
    }

    /** Post a "new version available" notification. Tapping it opens the Play Store listing
     *  (market:// → web fallback), mirroring the About screen's open-store behavior. */
    fun showUpdateAvailable() {
        val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse(AndroidUpdateChecker.PLAY_STORE_MARKET_URL)).apply {
            setPackage("com.android.vending")
            addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
        }
        val resolvable = marketIntent.resolveActivity(context.packageManager) != null
        val intent = if (resolvable) marketIntent else
            Intent(Intent.ACTION_VIEW, Uri.parse(AndroidUpdateChecker.PLAY_STORE_WEB_URL))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
        val pi = PendingIntent.getActivity(
            context, REQUEST_APP_UPDATE, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notif = NotificationCompat.Builder(context, CHANNEL_APP_UPDATE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.notif_update_title))
            .setContentText(context.getString(R.string.notif_update_text))
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        NotificationManagerCompat.from(context).notifySafely(context, APP_UPDATE_NOTIFICATION_ID, notif)
    }

    // -- Scheduling ------------------------------------------------------

    fun scheduleStreakReminder(hour: Int, minute: Int) = schedule(
        REQUEST_STREAK, hour, minute, CHANNEL_STREAK,
        title = context.getString(R.string.notif_streak_title),
        text = context.getString(R.string.notif_streak_text)
    )

    fun scheduleDailySummary(hour: Int, minute: Int) = schedule(
        REQUEST_DAILY, hour, minute, CHANNEL_DAILY,
        title = context.getString(R.string.notif_summary_title),
        text = context.getString(R.string.notif_summary_text)
    )

    fun scheduleWeightReminder(hour: Int = 8, minute: Int = 0) = schedule(
        REQUEST_WEIGHT, hour, minute, CHANNEL_WEIGHT_LOG,
        title = context.getString(R.string.notif_weight_log_title),
        text = context.getString(R.string.notif_weight_log_text)
    )

    fun scheduleBodyFatReminder(hour: Int = 8, minute: Int = 0) = schedule(
        REQUEST_BODY_FAT, hour, minute, CHANNEL_BODY_FAT_LOG,
        title = context.getString(R.string.notif_body_fat_log_title),
        text = context.getString(R.string.notif_body_fat_log_text)
    )

    fun scheduleWaterReminder(hour: Int = 14, minute: Int = 0) = schedule(
        REQUEST_WATER, hour, minute, CHANNEL_WATER,
        title = context.getString(R.string.notif_water_title),
        text = context.getString(R.string.notif_water_text)
    )

    fun cancelStreakReminder() = cancel(REQUEST_STREAK)
    fun cancelDailySummary() = cancel(REQUEST_DAILY)
    fun cancelWeightReminder() = cancel(REQUEST_WEIGHT)
    fun cancelBodyFatReminder() = cancel(REQUEST_BODY_FAT)
    fun cancelWaterReminder() = cancel(REQUEST_WATER)

    private fun schedule(requestCode: Int, hour: Int, minute: Int, channel: String, title: String, text: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_CHANNEL, channel)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, text)
            putExtra(EXTRA_REQUEST, requestCode)
        }
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val now = Calendar.getInstance()
        val fire = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(now)) add(Calendar.DAY_OF_MONTH, 1)
        }

        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fire.timeInMillis, pi)
    }

    private fun cancel(requestCode: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
        )
        if (pi != null) {
            am.cancel(pi)
            pi.cancel()
        }
    }

    companion object {
        const val CHANNEL_STREAK = "streak_reminder"
        const val CHANNEL_DAILY = "daily_summary"
        const val CHANNEL_WEIGHT_GOAL = "weight_goal"
        const val CHANNEL_WEIGHT_LOG = "weight_log_reminder"
        const val CHANNEL_BODY_FAT_LOG = "body_fat_log_reminder"
        const val CHANNEL_APP_UPDATE = "app_update"
        const val CHANNEL_WATER = "water_reminder"
        const val EXTRA_CHANNEL = "channel"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_REQUEST = "request"
        private const val GOAL_NOTIFICATION_ID = 4242
        private const val APP_UPDATE_NOTIFICATION_ID = 5555
        private const val REQUEST_STREAK = 1001
        private const val REQUEST_DAILY = 1002
        private const val REQUEST_WEIGHT = 1003
        private const val REQUEST_BODY_FAT = 1004
        private const val REQUEST_APP_UPDATE = 1005
        private const val REQUEST_WATER = 1006
    }
}

/** Fired by the alarm. Posts the notification and re-schedules the same alarm +24h. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val channel = intent.getStringExtra(NotificationService.EXTRA_CHANNEL) ?: return
        val title = intent.getStringExtra(NotificationService.EXTRA_TITLE) ?: return
        val text = intent.getStringExtra(NotificationService.EXTRA_TEXT) ?: return
        val request = intent.getIntExtra(NotificationService.EXTRA_REQUEST, -1)

        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notif = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notifySafely(context, request, notif)

        // Re-arm for +24h so the reminder fires daily.
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val nextFire = System.currentTimeMillis() + 24L * 60 * 60 * 1000
        val reIntent = Intent(context, ReminderReceiver::class.java).apply { putExtras(intent) }
        val pi = PendingIntent.getBroadcast(
            context, request, reIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextFire, pi)
    }
}

private fun NotificationManagerCompat.notifySafely(
    context: Context,
    id: Int,
    notif: android.app.Notification
) {
    val canNotify = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED
    if (!canNotify) return

    try {
        notify(id, notif)
    } catch (_: SecurityException) {
        // Permission can still be revoked between the explicit check and notify().
    }
}
