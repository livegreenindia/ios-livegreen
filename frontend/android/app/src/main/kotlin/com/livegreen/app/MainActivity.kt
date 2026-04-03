package com.livegreen.app

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.media.AudioManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.content.ComponentName
import android.accessibilityservice.AccessibilityService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "livegreen/digital_wellbeing"
	private val BLOCKER_CHANNEL = "livegreen/app_blocker"
	private val DEVICE_STATE_CHANNEL = "com.livegreen.app/device_state"
	private val BLOCKER_PREFS = "app_blocker"

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
						val pm = packageManager
						val identifiers = listOf("youtube", "instagram", "facebook", "snapchat")
						val usageMap = mutableMapOf<String, Long>()
						
						if (range == "daily") {
							// Use queryEvents for precision on daily views to avoid UTC bucket overlap causing >24h
							val events = usageStatsManager.queryEvents(start, end)
							val event = android.app.usage.UsageEvents.Event()
							val startTimes = mutableMapOf<String, Long>()
							
							while (events.hasNextEvent()) {
								events.getNextEvent(event)
								val pkg = event.packageName
								
								if (event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED) {
									startTimes[pkg] = event.timeStamp
								} else if (event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED || 
										   event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED) {
									val startTime = startTimes[pkg]
									if (startTime != null) {
										val duration = event.timeStamp - startTime
										if (duration > 0) {
											usageMap[pkg] = (usageMap[pkg] ?: 0L) + duration
										}
										startTimes.remove(pkg)
									}
								}
							}
							// Add ongoing sessions
							for ((pkg, startTime) in startTimes) {
								val duration = end - startTime
								if (duration > 0) {
									usageMap[pkg] = (usageMap[pkg] ?: 0L) + duration
								}
							}
						} else {
							// Use queryAndAggregateUsageStats for broader ranges (weekly/monthly/yearly)
							val aggregate = usageStatsManager.queryAndAggregateUsageStats(start, end)
							if (aggregate != null && aggregate.isNotEmpty()) {
								for ((pkg, stat) in aggregate) {
									val timeMillis = try { stat.totalTimeInForeground } catch (_: Exception) { 0L }
									if (timeMillis > 0) {
										usageMap[pkg] = (usageMap[pkg] ?: 0L) + timeMillis
									}
								}
							}
							
							if (usageMap.isEmpty()) {
								val statsList = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
								if (statsList != null) {
									for (stat in statsList) {
										val pkg = stat.packageName
										val timeMillis = try { stat.totalTimeInForeground } catch (_: Exception) { 0L }
										if (timeMillis > 0) {
											usageMap[pkg] = (usageMap[pkg] ?: 0L) + timeMillis
										}
									}
								}
							}
						}

						val appsList = mutableListOf<Map<String, Any>>()
						
						for ((pkg, timeMillis) in usageMap) {
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

		// Screen Control / App Blocker channel
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKER_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"checkAccessibilityPermission" -> {
					try {
						result.success(isAccessibilityServiceEnabled(this, AppBlockerService::class.java))
					} catch (ex: Exception) {
						result.success(false)
					}
				}
				"requestAccessibilityPermission" -> {
					try {
						val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_INTENT", "Failed to open accessibility settings: ${ex.message}", null)
					}
				}
				"updateQuietHours" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val morning = (args?.get("morning") as? Number)?.toInt() ?: 7 * 60
						val evening = (args?.get("evening") as? Number)?.toInt() ?: 22 * 60
						getSharedPreferences(BLOCKER_PREFS, Context.MODE_PRIVATE)
							.edit()
							.putInt("quiet_morning", morning)
							.putInt("quiet_evening", evening)
							.apply()
						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_QUIET", "Failed to save quiet hours: ${ex.message}", null)
					}
				}
				"updateUsage" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val pkg = (args?.get("package") as? String) ?: ""
						val minutes = (args?.get("minutes") as? Number)?.toInt() ?: 0
						if (pkg.isNotBlank()) {
							getSharedPreferences(BLOCKER_PREFS, Context.MODE_PRIVATE)
								.edit()
								.putInt("usage_$pkg", minutes)
								.apply()
						}
						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_USAGE", "Failed to save usage: ${ex.message}", null)
					}
				}
				"updateLimits" -> {
					try {
						val raw = call.arguments as? Map<*, *>
						val limits = mutableMapOf<String, Int>()
						if (raw != null) {
							for ((k, v) in raw) {
								val pkg = k?.toString() ?: continue
								val limit = (v as? Number)?.toInt() ?: continue
								limits[pkg] = limit
							}
						}

						val prefs = getSharedPreferences(BLOCKER_PREFS, Context.MODE_PRIVATE)
						val editor = prefs.edit()
						// hard limit is enabled when limits map is non-empty
						editor.putBoolean("hard_limit_enabled", limits.isNotEmpty())
						editor.putStringSet("tracked_packages", limits.keys)
						for ((pkg, limit) in limits) {
							editor.putInt("limit_$pkg", limit)
						}
						editor.apply()

						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_LIMITS", "Failed to save limits: ${ex.message}", null)
					}
				}
				"blockApp" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val pkg = (args?.get("package") as? String) ?: ""
						if (pkg.isNotBlank()) {
							val prefs = getSharedPreferences(BLOCKER_PREFS, Context.MODE_PRIVATE)
							val current = prefs.getStringSet("manual_blocked_packages", emptySet())?.toMutableSet() ?: mutableSetOf()
							current.add(pkg)
							prefs.edit().putStringSet("manual_blocked_packages", current).apply()
						}
						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_BLOCK", "Failed to block package: ${ex.message}", null)
					}
				}
				"unblockApp" -> {
					try {
						val args = call.arguments as? Map<*, *>
						val pkg = (args?.get("package") as? String) ?: ""
						if (pkg.isNotBlank()) {
							val prefs = getSharedPreferences(BLOCKER_PREFS, Context.MODE_PRIVATE)
							val current = prefs.getStringSet("manual_blocked_packages", emptySet())?.toMutableSet() ?: mutableSetOf()
							current.remove(pkg)
							prefs.edit().putStringSet("manual_blocked_packages", current).apply()
						}
						result.success(true)
					} catch (ex: Exception) {
						result.error("ERR_UNBLOCK", "Failed to unblock package: ${ex.message}", null)
					}
				}
				else -> result.notImplemented()
			}
		}

		// Device state channel for mindfulness reminder mute checks
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATE_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"isSilentModeEnabled" -> {
					try {
						val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
						result.success(audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL)
					} catch (ex: Exception) {
						result.success(false)
					}
				}
				"isDoNotDisturbEnabled" -> {
					try {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
							val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
							result.success(
								notificationManager.currentInterruptionFilter !=
									NotificationManager.INTERRUPTION_FILTER_ALL
							)
						} else {
							result.success(false)
						}
					} catch (ex: Exception) {
						result.success(false)
					}
				}
				"isAirplaneModeEnabled" -> {
					try {
						val enabled = Settings.Global.getInt(
							contentResolver,
							Settings.Global.AIRPLANE_MODE_ON,
							0
						) == 1
						result.success(enabled)
					} catch (ex: Exception) {
						result.success(false)
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

	private fun isAccessibilityServiceEnabled(context: Context, service: Class<out AccessibilityService>): Boolean {
		val expected = ComponentName(context, service).flattenToString()
		val enabled = Settings.Secure.getString(
			context.contentResolver,
			Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
		) ?: return false
		return enabled.split(":").any { it.equals(expected, ignoreCase = true) }
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

			val mindfulnessAudioChannel = NotificationChannel(
				"mindfulness_bell_audio",
				"Mindfulness Bell Audio",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "Mindfulness bell reminders with sound"
				enableVibration(true)
				enableLights(true)
				lightColor = 0xFF00A859.toInt()
			}
			notificationManager.createNotificationChannel(mindfulnessAudioChannel)

			val mindfulnessVibrateChannel = NotificationChannel(
				"mindfulness_bell_vibrate",
				"Mindfulness Bell Vibrate Only",
				NotificationManager.IMPORTANCE_HIGH
			).apply {
				description = "Mindfulness bell reminders with vibration only"
				enableVibration(true)
				setSound(null, null)
			}
			notificationManager.createNotificationChannel(mindfulnessVibrateChannel)
		}
	}
}
