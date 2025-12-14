# CheddaBoards SDK for Godot 4.x
# Standalone HTTP API integration - works with any game engine
# 
# SETUP:
# 1. Copy this file to your project (e.g., res://addons/cheddaboards.gd)
# 2. Add as autoload: Project → Project Settings → Autoload → Add this script as "CheddaBoards"
# 3. Set your API key in _ready() or call CheddaBoards.set_api_key("your_key")
#
# USAGE:
#   CheddaBoards.submit_score("player_123", 5000, 10)
#   CheddaBoards.get_leaderboard(10)
#   CheddaBoards.get_player_rank("player_123")

extends Node

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION - Set your API key here
# ═══════════════════════════════════════════════════════════════════

const API_BASE_URL = "https://cheddaboards.com/.netlify/functions/api"
# Alternative (requires Netlify redirect):
# const API_BASE_URL = "https://cheddaboards.com/api"

var api_key: String = ""  # Set via set_api_key() or directly here

# ═══════════════════════════════════════════════════════════════════
# SIGNALS - Connect to these in your game
# ═══════════════════════════════════════════════════════════════════

signal score_submitted(success: bool, message: String)
signal leaderboard_received(success: bool, data: Array)
signal player_rank_received(success: bool, data: Dictionary)
signal player_profile_received(success: bool, data: Dictionary)
signal achievement_unlocked(success: bool, message: String)
signal achievements_received(success: bool, data: Array)
signal request_failed(endpoint: String, error: String)

# ═══════════════════════════════════════════════════════════════════
# INTERNAL STATE
# ═══════════════════════════════════════════════════════════════════

var _http_request: HTTPRequest

func _ready():
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	
	# Optional: Set your API key here
	# api_key = "cb_your-game_1234567890"

# ═══════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════

## Set the API key (get this from CheddaBoards dashboard)
func set_api_key(key: String) -> void:
	api_key = key

## Submit a score for a player
## @param player_id: Unique identifier for the player (your system's ID)
## @param score: The score value (integer)
## @param streak: Optional streak/combo value (default 0)
## @param rounds: Optional number of rounds played
## @param nickname: Optional display name for leaderboard (2-20 chars)
func submit_score(player_id: String, score: int, streak: int = 0, rounds: int = -1, nickname: String = "") -> void:
	var body = {
		"playerId": player_id,
		"score": score,
		"streak": streak
	}
	if rounds >= 0:
		body["rounds"] = rounds
	if not nickname.is_empty():
		body["nickname"] = nickname
	
	_make_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")

## Get the leaderboard
## @param limit: Number of entries to fetch (1-1000, default 100)
## @param sort: Sort by "score" or "streak"
func get_leaderboard(limit: int = 100, sort: String = "score") -> void:
	var url = "/leaderboard?limit=%d&sort=%s" % [limit, sort]
	_make_request(url, HTTPClient.METHOD_GET, {}, "leaderboard")

## Get a player's rank on the leaderboard
## @param player_id: The player's unique identifier
## @param sort: Sort by "score" or "streak"
func get_player_rank(player_id: String, sort: String = "score") -> void:
	var url = "/players/%s/rank?sort=%s" % [player_id.uri_encode(), sort]
	_make_request(url, HTTPClient.METHOD_GET, {}, "player_rank")

## Get a player's full profile
## @param player_id: The player's unique identifier
func get_player_profile(player_id: String) -> void:
	var url = "/players/%s/profile" % player_id.uri_encode()
	_make_request(url, HTTPClient.METHOD_GET, {}, "player_profile")

## Unlock an achievement for a player
## @param player_id: The player's unique identifier
## @param achievement_id: The achievement identifier
func unlock_achievement(player_id: String, achievement_id: String) -> void:
	var body = {
		"playerId": player_id,
		"achievementId": achievement_id
	}
	_make_request("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")

## Get all achievements for a player
## @param player_id: The player's unique identifier
func get_achievements(player_id: String) -> void:
	var url = "/players/%s/achievements" % player_id.uri_encode()
	_make_request(url, HTTPClient.METHOD_GET, {}, "achievements")

## Get game info
func get_game_info() -> void:
	_make_request("/game", HTTPClient.METHOD_GET, {}, "game_info")

## Get game statistics
func get_game_stats() -> void:
	_make_request("/game/stats", HTTPClient.METHOD_GET, {}, "game_stats")

## Health check - verify API connection
func health_check() -> void:
	_make_request("/health", HTTPClient.METHOD_GET, {}, "health")

# ═══════════════════════════════════════════════════════════════════
# INTERNAL METHODS
# ═══════════════════════════════════════════════════════════════════

var _current_endpoint: String = ""

func _make_request(endpoint: String, method: int, body: Dictionary, request_type: String) -> void:
	if api_key.is_empty():
		push_error("CheddaBoards: API key not set! Call set_api_key() first.")
		request_failed.emit(endpoint, "API key not set")
		return
	
	_current_endpoint = request_type
	
	var headers = [
		"Content-Type: application/json",
		"X-API-Key: " + api_key
	]
	
	var url = API_BASE_URL + endpoint
	var json_body = JSON.stringify(body) if body.size() > 0 else ""
	
	var error = _http_request.request(url, headers, method, json_body)
	if error != OK:
		push_error("CheddaBoards: HTTP request failed to start: %s" % error)
		request_failed.emit(endpoint, "Request failed to start")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("CheddaBoards: Request failed with result %d" % result)
		request_failed.emit(_current_endpoint, "Network error")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("CheddaBoards: Failed to parse JSON response")
		request_failed.emit(_current_endpoint, "Invalid JSON response")
		return
	
	var response = json.data
	
	if response_code != 200:
		var error_msg = response.get("error", "Unknown error")
		push_error("CheddaBoards: API error (%d): %s" % [response_code, error_msg])
		request_failed.emit(_current_endpoint, error_msg)
		_emit_failure_signal(response.get("error", "Request failed"))
		return
	
	if not response.get("ok", false):
		var error_msg = response.get("error", "Unknown error")
		request_failed.emit(_current_endpoint, error_msg)
		_emit_failure_signal(error_msg)
		return
	
	# Success - emit appropriate signal
	var data = response.get("data", {})
	_emit_success_signal(data)

func _emit_success_signal(data) -> void:
	match _current_endpoint:
		"submit_score":
			score_submitted.emit(true, data.get("message", "Score submitted"))
		"leaderboard":
			leaderboard_received.emit(true, data.get("leaderboard", []))
		"player_rank":
			player_rank_received.emit(true, data)
		"player_profile":
			player_profile_received.emit(true, data)
		"unlock_achievement":
			achievement_unlocked.emit(true, data.get("message", "Achievement unlocked"))
		"achievements":
			achievements_received.emit(true, data.get("achievements", []))

func _emit_failure_signal(error: String) -> void:
	match _current_endpoint:
		"submit_score":
			score_submitted.emit(false, error)
		"leaderboard":
			leaderboard_received.emit(false, [])
		"player_rank":
			player_rank_received.emit(false, {})
		"player_profile":
			player_profile_received.emit(false, {})
		"unlock_achievement":
			achievement_unlocked.emit(false, error)
		"achievements":
			achievements_received.emit(false, [])


# ═══════════════════════════════════════════════════════════════════
# EXAMPLE USAGE (copy to your game script)
# ═══════════════════════════════════════════════════════════════════
#
# extends Node
#
# func _ready():
#     # Set API key (get from CheddaBoards dashboard)
#     CheddaBoards.set_api_key("cb_your-game_1234567890")
#     
#     # Connect signals
#     CheddaBoards.score_submitted.connect(_on_score_submitted)
#     CheddaBoards.leaderboard_received.connect(_on_leaderboard_received)
#     CheddaBoards.player_rank_received.connect(_on_rank_received)
#
# func _on_game_over(final_score: int, streak: int):
#     # Use a unique player ID (could be device ID, user account, etc.)
#     var player_id = OS.get_unique_id()  # Or your own ID system
#     CheddaBoards.submit_score(player_id, final_score, streak)
#
# func _on_score_submitted(success: bool, message: String):
#     if success:
#         print("Score saved: ", message)
#         CheddaBoards.get_player_rank(OS.get_unique_id())
#     else:
#         print("Failed to save score: ", message)
#
# func _on_leaderboard_received(success: bool, entries: Array):
#     if success:
#         for entry in entries:
#             print("#%d %s - %d pts" % [entry.rank, entry.nickname, entry.score])
#
# func _on_rank_received(success: bool, data: Dictionary):
#     if success:
#         print("Your rank: #%d out of %d players" % [data.rank, data.totalPlayers])
