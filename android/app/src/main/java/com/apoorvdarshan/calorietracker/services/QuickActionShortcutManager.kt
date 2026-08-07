package com.apoorvdarshan.calorietracker.services

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import com.apoorvdarshan.calorietracker.MainActivity
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.QuickAction

object QuickActionShortcutManager {
    const val INTENT_ACTION = "com.apoorvdarshan.calorietracker.QUICK_ACTION"
    private const val EXTRA_ACTION = "quick_action"

    fun update(context: Context, actions: List<QuickAction>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val manager = context.getSystemService(ShortcutManager::class.java) ?: return
        manager.dynamicShortcuts = actions.take(3).mapIndexed { index, action ->
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = INTENT_ACTION
                putExtra(EXTRA_ACTION, action.name)
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            ShortcutInfo.Builder(context, "quick_action_${index + 1}")
                .setShortLabel(action.title)
                .setLongLabel("Quick Action ${index + 1}: ${action.title}")
                .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
                .setIntent(intent)
                .build()
        }
    }

    fun actionFrom(intent: Intent?): QuickAction? {
        if (intent?.action != INTENT_ACTION) return null
        return QuickAction.fromStorage(intent.getStringExtra(EXTRA_ACTION))
    }
}
