class_name UserStatTracker
extends RefCounted

## UserStatTracker — Tracks player lifetime metrics, engagement, and session data
## Automatically updates session metrics, login streaks, run counts, and play duration.
## Serializes to and from SaveManager safely.

var stats: Dictionary = {
	"TotalGames": 0,
	"TotalRuns": 0,
	"TotalIAPs": 0,
	"TotalIAPCurrencySpent": 0.0,
	"CumulativeIAPSpent": 0.0,
	"TotalIAPPurchased": 0,
	"LastIAPTier": 0,
	"NumSessions": 1,
	"NumSessionsInVersion": 1,
	"DaysPlayed": 1,
	"DaysSinceLastPlayed": 0,
	"CurrentLoginStreak": 1,
	"TotalTimeInRuns": 0.0,
	"EngagementPlayTime": 0.0,
	"EngagementTotalTime": 0.0,
	"TotalHighScoresBeat": 0,
	"CoinsCollectedTotal": 0,
	"CurrentCoinBalance": 0,
	"EnemiesKilledTotal": 0,
	"HeadshotCount": 0,
	"MeleeKillCount": 0,
	"DismantleCountTotal": 0,
	"LastLoginTimestamp": 0,
	"AccountCreationTime": 0,
	"HoursSinceLastIAP": 9999.0,
	"HoursSinceLastAdWatch": 999.0,
	"RemainingDailyGiftsToday": 3,
	"UnclaimedCalendarRewardStreak": 0,
	"SecondsInRun": 0.0
}

var _run_start_time_msec: int = 0
var _is_run_active: bool = false


func _init() -> void:
	pass


func initialize_from_save(saved_stats: Dictionary) -> void:
	if saved_stats != null and not saved_stats.is_empty():
		for key in saved_stats.keys():
			if stats.has(key):
				stats[key] = saved_stats[key]

	var now_unix: int = int(Time.get_unix_time_from_system())
	if int(stats["AccountCreationTime"]) <= 0:
		stats["AccountCreationTime"] = now_unix

	# Calculate session & login streak
	var last_login: int = int(stats["LastLoginTimestamp"])
	if last_login > 0:
		var diff_sec: int = now_unix - last_login
		var days_diff: int = int(float(diff_sec) / 86400.0)
		stats["DaysSinceLastPlayed"] = days_diff

		if days_diff == 1:
			stats["CurrentLoginStreak"] = int(stats["CurrentLoginStreak"]) + 1
			stats["DaysPlayed"] = int(stats["DaysPlayed"]) + 1
		elif days_diff > 1:
			stats["CurrentLoginStreak"] = 1
			stats["DaysPlayed"] = int(stats["DaysPlayed"]) + 1
	else:
		stats["DaysSinceLastPlayed"] = 0

	stats["NumSessions"] = int(stats["NumSessions"]) + 1
	stats["NumSessionsInVersion"] = int(stats["NumSessionsInVersion"]) + 1
	stats["LastLoginTimestamp"] = now_unix


func serialize_for_save() -> Dictionary:
	return stats.duplicate(true)


func get_stat(stat_name: String, default_val: Variant = null) -> Variant:
	if stats.has(stat_name):
		return stats[stat_name]
	return default_val


func set_stat(stat_name: String, val: Variant) -> void:
	stats[stat_name] = val


func increment_stat(stat_name: String, amount: float = 1.0) -> void:
	if stats.has(stat_name):
		var current: Variant = stats[stat_name]
		if current is int:
			stats[stat_name] = int(current) + int(amount)
		elif current is float:
			stats[stat_name] = float(current) + amount
	else:
		stats[stat_name] = amount


func on_run_started() -> void:
	_is_run_active = true
	_run_start_time_msec = Time.get_ticks_msec()
	stats["SecondsInRun"] = 0.0
	increment_stat("TotalGames", 1)


func on_run_ended(survived: bool = true) -> void:
	if not _is_run_active:
		return
	_is_run_active = false
	var elapsed_sec: float = float(Time.get_ticks_msec() - _run_start_time_msec) / 1000.0
	stats["SecondsInRun"] = elapsed_sec
	increment_stat("TotalTimeInRuns", elapsed_sec)
	increment_stat("EngagementPlayTime", elapsed_sec)
	increment_stat("TotalRuns", 1)


func record_run_completed(duration_sec: float = 0.0) -> void:
	_is_run_active = false
	var elapsed: float = duration_sec
	if elapsed <= 0.0 and _run_start_time_msec > 0:
		elapsed = float(Time.get_ticks_msec() - _run_start_time_msec) / 1000.0
	stats["SecondsInRun"] = elapsed
	increment_stat("TotalTimeInRuns", elapsed)
	increment_stat("EngagementPlayTime", elapsed)
	increment_stat("TotalRuns", 1)


func add_app_runtime(delta: float) -> void:
	stats["EngagementTotalTime"] = float(stats["EngagementTotalTime"]) + delta
	if _is_run_active:
		stats["SecondsInRun"] = float(stats["SecondsInRun"]) + delta


func record_iap(price: float, tier: int = 1) -> void:
	increment_stat("TotalIAPs", 1)
	increment_stat("TotalIAPPurchased", 1)
	increment_stat("TotalIAPCurrencySpent", price)
	increment_stat("CumulativeIAPSpent", price)
	set_stat("LastIAPTier", tier)
	set_stat("HoursSinceLastIAP", 0.0)


func record_ad_watched() -> void:
	set_stat("HoursSinceLastAdWatch", 0.0)
