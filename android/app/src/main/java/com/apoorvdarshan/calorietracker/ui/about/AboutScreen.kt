package com.apoorvdarshan.calorietracker.ui.about

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AlternateEmail
import androidx.compose.material.icons.filled.Work
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarRate
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import com.apoorvdarshan.calorietracker.R
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.services.update.AndroidUpdateChecker
import com.apoorvdarshan.calorietracker.services.update.AndroidUpdateState
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import kotlinx.coroutines.launch

/**
 * Verbatim port of struct AboutSettingsSections in
 * ios/calorietracker/ContentView.swift.
 *
 * The former About tab was folded into Settings as its last section, so this
 * renders just the About *rows* (no Scaffold / LazyColumn); the caller wraps
 * it in a Settings SectionCard titled "About":
 *   Update / Rate / Share / Open Source / Star / Vote on PH /
 *   Support / Report Issue / Request Feature / Contact / Follow on X /
 *   Follow on Instagram / Follow on LinkedIn / Privacy Policy / Terms, then
 *   the 'Made by Apoorv Darshan' / 'with care, for everyone' footer.
 *
 * Icons are pink (Calorie); labels use the onSurface color; hairline dividers
 * separate the rows, mirroring the iOS grouped-list look.
 */
@Composable
fun AboutSettingsRows(container: AppContainer) {
    val ctx = LocalContext.current
    val shareText = stringResource(R.string.about_share_message)
    val shareChooser = stringResource(R.string.about_share_chooser)
    val currentVersion = remember(ctx) { AndroidUpdateChecker.currentVersion(ctx) }
    var updateState by remember { mutableStateOf<AndroidUpdateState>(AndroidUpdateState.Idle) }
    val scope = rememberCoroutineScope()

    fun open(url: String) =
        ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))

    fun openPlayStore() = openPlayStore(ctx)

    fun refreshUpdateState() {
        scope.launch {
            updateState = AndroidUpdateState.Checking
            updateState = AndroidUpdateChecker.check(ctx, currentVersion)
        }
    }

    LaunchedEffect(currentVersion) {
        updateState = AndroidUpdateState.Checking
        updateState = AndroidUpdateChecker.check(ctx, currentVersion)
    }

    fun share() {
        ctx.startActivity(Intent.createChooser(
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, shareText)
            },
            shareChooser
        ))
    }

    fun rate() {
        openPlayStore()
    }

    fun email() = ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:apoorv@fud-ai.app")))

    Column(Modifier.fillMaxWidth()) {
        UpdateRow(
            state = updateState,
            currentVersion = currentVersion,
            onRefresh = ::refreshUpdateState,
            onOpenStore = ::openPlayStore
        )
        Hairline()
        AboutRow(Icons.Filled.Star, stringResource(R.string.about_rate), onClick = ::rate)
        Hairline()
        AboutRow(Icons.Filled.Share, stringResource(R.string.about_share), onClick = ::share)
        Hairline()
        AboutRow(Icons.Filled.Code, stringResource(R.string.about_open_source)) { open("https://github.com/apoorvdarshan/fud-ai") }
        Hairline()
        AboutRow(Icons.Filled.StarRate, stringResource(R.string.about_star_github)) { open("https://github.com/apoorvdarshan/fud-ai") }
        Hairline()
        AboutRow(Icons.Filled.ThumbUp, stringResource(R.string.about_vote_ph)) { open("https://www.producthunt.com/products/fud-ai-calorie-tracker") }
        Hairline()
        AboutRow(Icons.Filled.Favorite, stringResource(R.string.about_support)) { open("https://ko-fi.com/apoorvdarshan") }
        Hairline()
        AboutRow(Icons.Filled.BugReport, stringResource(R.string.about_report_issue)) { open("https://github.com/apoorvdarshan/fud-ai/issues/new?labels=bug&title=Bug:%20") }
        Hairline()
        AboutRow(Icons.Filled.Lightbulb, stringResource(R.string.about_request_feature)) { open("https://github.com/apoorvdarshan/fud-ai/issues/new?labels=enhancement&title=Feature:%20") }
        Hairline()
        AboutRow(Icons.Filled.Email, stringResource(R.string.about_contact), onClick = ::email)
        Hairline()
        AboutRow(Icons.Filled.AlternateEmail, stringResource(R.string.about_follow_x)) { open("https://x.com/apoorvdarshan") }
        Hairline()
        AboutRow(Icons.Filled.PhotoCamera, stringResource(R.string.about_follow_instagram)) { open("https://www.instagram.com/fudai.app/") }
        Hairline()
        AboutRow(Icons.Filled.Work, stringResource(R.string.about_follow_linkedin)) { open("https://www.linkedin.com/company/fud-ai-app") }
        Hairline()
        AboutRow(Icons.Filled.Lock, stringResource(R.string.about_privacy)) { open("https://fud-ai.app/privacy.html") }
        Hairline()
        AboutRow(Icons.Filled.Description, stringResource(R.string.about_terms)) { open("https://fud-ai.app/terms.html") }

        Column(
            Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                stringResource(R.string.about_made_by),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
            )
            Text(
                stringResource(R.string.about_with_care),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.4f)
            )
        }
    }
}

private fun openPlayStore(context: Context) {
    val marketIntent = Intent(
        Intent.ACTION_VIEW,
        Uri.parse(AndroidUpdateChecker.PLAY_STORE_MARKET_URL)
    ).apply {
        setPackage("com.android.vending")
        addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
    }
    runCatching { context.startActivity(marketIntent) }.onFailure {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(AndroidUpdateChecker.PLAY_STORE_WEB_URL))
        )
    }
}

@Composable
private fun UpdateRow(
    state: AndroidUpdateState,
    currentVersion: String,
    onRefresh: () -> Unit,
    onOpenStore: () -> Unit
) {
    when (state) {
        AndroidUpdateState.Checking -> AboutRow(
            icon = Icons.Filled.Sync,
            label = stringResource(R.string.about_update_checking),
            trailing = {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = AppColors.Calorie
                )
            },
            onClick = {}
        )
        is AndroidUpdateState.Available -> AboutRow(
            icon = Icons.Filled.SystemUpdate,
            label = stringResource(R.string.about_update_available),
            subtitle = stringResource(R.string.about_update_details_format, state.current, state.latest),
            showDot = true,
            trailing = {
                Text(
                    stringResource(R.string.about_update_action),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Calorie
                )
            },
            onClick = onOpenStore
        )
        is AndroidUpdateState.Failed -> AboutRow(
            icon = Icons.Filled.Sync,
            label = stringResource(R.string.about_check_updates),
            subtitle = stringResource(R.string.about_version_format, state.current),
            onClick = onRefresh
        )
        is AndroidUpdateState.UpToDate -> AboutRow(
            icon = Icons.Filled.CheckCircle,
            label = stringResource(R.string.about_app_version),
            trailing = {
                Text(
                    state.current,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            },
            onClick = onRefresh
        )
        AndroidUpdateState.Idle -> AboutRow(
            icon = Icons.Filled.Sync,
            label = stringResource(R.string.about_check_updates),
            subtitle = stringResource(R.string.about_version_format, currentVersion),
            onClick = onRefresh
        )
    }
}

@Composable
private fun AboutRow(
    icon: ImageVector,
    label: String,
    subtitle: String? = null,
    showDot: Boolean = false,
    trailing: (@Composable () -> Unit)? = null,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
            Icon(
                icon,
                contentDescription = null,
                tint = AppColors.Calorie,
                modifier = Modifier.size(22.dp)
            )
            if (showDot) {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(AppColors.Calorie)
                )
            }
        }
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f)) {
            Text(label, fontSize = 17.sp, color = MaterialTheme.colorScheme.onSurface)
            if (!subtitle.isNullOrBlank()) {
                Text(
                    subtitle,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            }
        }
        if (trailing != null) {
            Spacer(Modifier.width(12.dp))
            trailing()
        }
    }
}

@Composable
private fun Hairline() {
    Box(
        Modifier
            .padding(start = 54.dp)
            .fillMaxWidth()
            .height(0.5.dp)
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
    )
}
