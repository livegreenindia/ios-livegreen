package com.livegreen.app

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "livegreen/digital_wellbeing"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		// Create notification channels for Android 8+
		createNotificationChannels()

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"appOpsState" -> {
					try {
						val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
						val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
							appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
						} else {
							appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
						}
						val label = when (mode) {
							AppOpsManager.MODE_ALLOWED -> "allow"
							AppOpsManager.MODE_IGNORED -> "ignore"
							AppOpsManager.MODE_ERRORED -> "errored"
							AppOpsManager.MODE_DEFAULT -> "default"
							else -> mode.toString()
						}
						val map: MutableMap<String, Any> = HashMap()
						map["mode"] = mode
						map["label"] = label
						result.success(map)
					} catch (ex: Exception) {
						result.error("ERR_APPOPS", "Failed to read appops: ${ex.message}", null)
					}
				}

				"isPermissionGranted" -> {
					val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
					val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
						appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
					} else {
						appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
					}
					result.success(mode == AppOpsManager.MODE_ALLOWED)
				}
				"openPermissionSettings" -> {
						try {
							val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							// If there's an activity that can handle this intent, start it. Otherwise fall back.
							if (intent.resolveActivity(packageManager) != null) {
								startActivity(intent)
								result.success(true)
							} else {
								// Fallback: open the App Info / Application Details settings so user can find the app and grant permissions
								val pkgIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
								pkgIntent.data = android.net.Uri.parse("package:$packageName")
								pkgIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
								startActivity(pkgIntent)
								result.success(true)
							}
						} catch (ex: Exception) {
							// If something goes wrong, return an error to Flutter so it can show a message
							result.error("ERR_INTENT", "Failed to open settings: ${ex.message}", null)
						}
				}
				"getUsageSummary" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val range = (args?.get("range") as? String) ?: "weekly"
						val end = System.currentTimeMillis()
						
						// For daily, use start of today (midnight) instead of last 24 hours
						val calendar = java.util.Calendar.getInstance()
						calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
						calendar.set(java.util.Calendar.MINUTE, 0)
						calendar.set(java.util.Calendar.SECOND, 0)
						calendar.set(java.util.Calendar.MILLISECOND, 0)
						val startOfToday = calendar.timeInMillis
						
						val start = when (range) {
							"weekly" -> end - 7L * 24 * 60 * 60 * 1000
							"monthly" -> end - 30L * 24 * 60 * 60 * 1000
							"yearly" -> end - 365L * 24 * 60 * 60 * 1000
							"daily" -> startOfToday  // Use start of today (midnight)
							else -> end - 7L * 24 * 60 * 60 * 1000
						}

						val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

						// We'll aggregate usage reported by UsageStats. Note: totalTimeInForeground is available on API 23+.
						val statsList = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
						var totalMillis: Long = 0
						if (statsList != null) {
							for (s in statsList) {
								try {
									totalMillis += s.totalTimeInForeground
								} catch (ex: Exception) {
									// ignore individual app failures
								}
							}
						}

						val totalMinutes = totalMillis.toDouble() / 60000.0
						val map: MutableMap<String, Any> = HashMap()
						map["minutes"] = totalMinutes
						result.success(map)
					} catch (ex: Exception) {
						result.error("ERR_USAGE", "Failed to query usage stats: ${ex.message}", null)
					}
				}
				"getSocialMediaUsage" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val range = (args?.get("range") as? String) ?: "daily"
						val end = System.currentTimeMillis()
						
						// For daily, use start of today (midnight) instead of last 24 hours
						val calendar = java.util.Calendar.getInstance()
						calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
						calendar.set(java.util.Calendar.MINUTE, 0)
						calendar.set(java.util.Calendar.SECOND, 0)
						calendar.set(java.util.Calendar.MILLISECOND, 0)
						val startOfToday = calendar.timeInMillis
						
						val start = when (range) {
							"weekly" -> end - 7L * 24 * 60 * 60 * 1000
							"monthly" -> end - 30L * 24 * 60 * 60 * 1000
							"yearly" -> end - 365L * 24 * 60 * 60 * 1000
							"daily" -> startOfToday  // Use start of today (midnight)
							else -> startOfToday
						}

						val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

						// Prefer aggregated stats API for reliability across Android versions
						val aggregate = usageStatsManager.queryAndAggregateUsageStats(start, end)

						val appsList = mutableListOf<Map<String, Any>>()
						val pm = packageManager

						// identifiers to classify social media
						val identifiers = listOf(
							"youtube", "revanced", "instagram", "snapchat", "pinterest",
							"facebook", "twitter", "x", "threads", "tiktok", "reels", "shorts",
							"whatsapp", "telegram", "discord", "reddit", "linkedin", "tumblr", "mastodon"
						)

						for ((pkg, stat) in aggregate) {
							val timeMillis = try { stat.totalTimeInForeground } catch (_: Exception) { 0L }
							if (timeMillis <= 0) continue

							val pkgLower = pkg.lowercase()
							var appName: String = pkg
							try {
								val appInfo = pm.getApplicationInfo(pkg, 0)
								appName = pm.getApplicationLabel(appInfo).toString()
							} catch (_: Exception) {
								// Fallback to package if label not accessible due to package visibility
								val parts = pkg.split(".")
								if (parts.isNotEmpty()) {
									appName = parts.last().replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
								}
							}
							val nameLower = appName.lowercase()

							val isSocial = identifiers.any { id -> pkgLower.contains(id) || nameLower.contains(id) }
							if (!isSocial) continue

							val minutes = timeMillis.toDouble() / 60000.0
							val appMap = mutableMapOf<String, Any>()
							appMap["packageName"] = pkg
							appMap["appName"] = appName
							appMap["minutes"] = minutes // keep as Double for precision
							appMap["timeMillis"] = timeMillis
							appsList.add(appMap)
						}

						// sort by usage desc
						appsList.sortByDescending { (it["timeMillis"] as? Long) ?: 0L }

						val resultMap = mutableMapOf<String, Any>()
						resultMap["apps"] = appsList
						result.success(resultMap)
					} catch (ex: Exception) {
						result.error("ERR_SOCIAL_USAGE", "Failed to query social media usage: ${ex.message}", null)
					}
				}
				else -> result.notImplemented()
			}
		}

		// Samsung Health channel - minimal stubs. Replace TODOs with real Samsung Health SDK integration.
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "livegreen/samsung_health").setMethodCallHandler { call, result ->
			when (call.method) {
				"connect" -> {
					// TODO: Implement Samsung Health SDK auth / permission flow.
					// For now, return true on Android to allow Dart to proceed.
					result.success(true)
				}
				"fetchData" -> {
					try {
						// TODO: Query Samsung Health for steps, heart rate, sleep, workouts.
						val stub: MutableMap<String, Any> = HashMap()
						stub.put("steps", 0)
						stub.put("heart_rate", 0)
						stub.put("sleep", emptyList<String>())
						result.success(stub)
					} catch (ex: Exception) {
						result.error("ERR_SAMSUNG", "Failed to fetch Samsung data: ${ex.message}", null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	/**
	 * Create notification channels for Android 8 (API 26) and above.
	 * This ensures proper notification categorization and user control.
	 */
	private fun createNotificationChannels() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

			// Activity Reminders Channel (morning, midday, evening reminders)
			val activityChannel = NotificationChannel(
				"activity_reminders",
				"Activity Reminders",
				NotificationManager.IMPORTANCE_DEFAULT
			).apply {
				description = "Daily eco-activity reminders and encouragements"
				enableVibration(true)
				enableLights(true)
				lightColor = 0xFF00A859.toInt() // LiveGreen primary color
			}
			notificationManager.createNotificationChannel(activityChannel)

			// Achievements Channel (instant celebration notifications)
			val achievementsChannel = NotificationChannel(
				"achievements",
				"Achievements",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "Instant celebrations when you hit milestones"
				enableVibration(true)
				enableLights(true)
				lightColor = 0xFFFFD700.toInt() // Gold for achievements
			}
			notificationManager.createNotificationChannel(achievementsChannel)

			// Digital Wellbeing Channel (social media alerts)
			val wellbeingChannel = NotificationChannel(
				"digital_wellbeing",
				"Digital Wellbeing",
				NotificationManager.IMPORTANCE_LOW
			).apply {
				description = "Gentle alerts about screen time and social media usage"
				enableVibration(false)
			}
			notificationManager.createNotificationChannel(wellbeingChannel)
		}
	}
}
