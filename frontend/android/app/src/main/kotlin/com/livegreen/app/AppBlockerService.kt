package com.livegreen.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {
	companion object {
		private const val PREFS_NAME = "app_blocker"
		private const val KEY_QUIET_MORNING = "quiet_morning"
		private const val KEY_QUIET_EVENING = "quiet_evening"
		private const val KEY_HARD_LIMIT_ENABLED = "hard_limit_enabled"
		private const val KEY_TRACKED_PACKAGES = "tracked_packages"
		private const val KEY_MANUAL_BLOCKED = "manual_blocked_packages"

		@Volatile private var lastBlockedPkg: String? = null
		@Volatile private var lastBlockedAtMs: Long = 0
	}

	override fun onAccessibilityEvent(event: AccessibilityEvent?) {
		val pkg = event?.packageName?.toString() ?: return
		// Never block our own app UI
		if (pkg == packageName) return

		val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
		val tracked = prefs.getStringSet(KEY_TRACKED_PACKAGES, emptySet()) ?: emptySet()
		val manual = prefs.getStringSet(KEY_MANUAL_BLOCKED, emptySet()) ?: emptySet()

		// Only react to packages we manage
		if (!tracked.contains(pkg) && !manual.contains(pkg)) return

		val nowMs = System.currentTimeMillis()
		if (pkg == lastBlockedPkg && (nowMs - lastBlockedAtMs) < 1500) return

		val shouldBlock = shouldBlockPackageNow(prefs, pkg, manual.contains(pkg))
		if (!shouldBlock) return

		lastBlockedPkg = pkg
		lastBlockedAtMs = nowMs

		// Best-effort: send user to Home. This is a lightweight blocker.
		performGlobalAction(GLOBAL_ACTION_HOME)
	}

	private fun shouldBlockPackageNow(
		prefs: android.content.SharedPreferences,
		pkg: String,
		manualBlocked: Boolean,
	): Boolean {
		if (manualBlocked) return true

		// Quiet hours: allow apps only between [morning, evening]
		val morning = prefs.getInt(KEY_QUIET_MORNING, 7 * 60)
		val evening = prefs.getInt(KEY_QUIET_EVENING, 22 * 60)
		val nowMinutes = currentMinutesOfDay()

		val allowed = if (morning <= evening) {
			nowMinutes in morning..evening
		} else {
			// Range crosses midnight
			nowMinutes >= morning || nowMinutes <= evening
		}
		if (!allowed) return true

		val hard = prefs.getBoolean(KEY_HARD_LIMIT_ENABLED, false)
		if (!hard) return false

		val usage = prefs.getInt("usage_$pkg", 0)
		val limit = prefs.getInt("limit_$pkg", 60)
		return usage >= limit
	}

	private fun currentMinutesOfDay(): Int {
		val cal = java.util.Calendar.getInstance()
		return (cal.get(java.util.Calendar.HOUR_OF_DAY) * 60) + cal.get(java.util.Calendar.MINUTE)
	}

	override fun onInterrupt() {
		// no-op
	}
}
