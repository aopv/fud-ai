package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.apoorvdarshan.calorietracker.R
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView

/**
 * Central AdMob configuration — mirror of iOS `AdsConfig`.
 *
 * The **App ID** lives in AndroidManifest.xml (`com.google.android.gms.ads.APPLICATION_ID`).
 * Right now everything uses Google's official TEST IDs, which always fill and never put the
 * AdMob account at risk during development. To go live: paste the real Android unit ID into
 * [REAL_BANNER_UNIT_ID], set [USE_TEST_ADS] = false, and swap the manifest App ID.
 */
object AdsConfig {
    private const val USE_TEST_ADS = true

    // Google official TEST banner ad unit ID (Android).
    private const val TEST_BANNER_UNIT_ID = "ca-app-pub-3940256099942544/6300978111"

    // TODO: real Android banner ad unit ID from AdMob (then set USE_TEST_ADS = false).
    private const val REAL_BANNER_UNIT_ID = ""

    val bannerUnitId: String
        get() = if (USE_TEST_ADS || REAL_BANNER_UNIT_ID.isEmpty()) TEST_BANNER_UNIT_ID else REAL_BANNER_UNIT_ID
}

/**
 * The 50dp ad strip pinned above each tab's content — mirror of iOS `AdBannerStrip`.
 *
 * Opaque all the way up through the status bar, and the tab content is laid out *below*
 * it (not behind it), so scrolled rows can never appear above the ad. Shows a subtle
 * placeholder until the first ad arrives, so a slow cold-start fill doesn't pop into an
 * empty-looking gap.
 */
@Composable
fun AdBannerStrip(modifier: Modifier = Modifier) {
    var isLoaded by remember { mutableStateOf(false) }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .height(50.dp),
        contentAlignment = Alignment.Center
    ) {
        if (!isLoaded) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp, vertical = 3.dp)
                    .background(
                        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                        RoundedCornerShape(10.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = stringResource(R.string.ad_label),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f)
                )
            }
        }
        AndroidView(
            factory = { ctx ->
                AdView(ctx).apply {
                    setAdSize(AdSize.BANNER)
                    adUnitId = AdsConfig.bannerUnitId
                    adListener = object : AdListener() {
                        override fun onAdLoaded() {
                            isLoaded = true
                        }
                    }
                    loadAd(AdRequest.Builder().build())
                }
            }
        )
    }
}
