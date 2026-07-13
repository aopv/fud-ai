package com.apoorvdarshan.calorietracker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Privacy-policy entry point required by Health Connect on every supported Android version.
 *
 * Android 13 and below invoke this activity directly through
 * ACTION_SHOW_PERMISSIONS_RATIONALE. Android 14+ reach the same activity through the
 * VIEW_PERMISSION_USAGE alias declared in the manifest.
 */
class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runCatching {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
            )
        }
        finish()
    }

    private companion object {
        const val PRIVACY_POLICY_URL = "https://fud-ai.app/privacy.html"
    }
}
