# CheddaBoards Demo Game - Godot 4.x
# A simple click-to-score game demonstrating SDK integration
#
# SETUP:
# 1. Create a new Godot 4 project
# 2. Add CheddaBoards.gd as Autoload named "CheddaBoards"
# 3. Create a new scene with a Control node as root
# 4. Attach this script to the Control node
# 5. Run and play!

extends Control

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════

const API_KEY = "cb_test-api_1555406776"  # Replace with your key
const GAME_DURATION = 30.0  # Seconds per round

# ═══════════════════════════════════════════════════════════════════
# GAME STATE
# ═══════════════════════════════════════════════════════════════════

var player_id: String = ""
var player_name: String = ""
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var time_left: float = 0.0
var game_active: bool = false

# UI Elements
var title_label: Label
var score_label: Label
var streak_label: Label
var timer_label: Label
var status_label: Label
var name_label: Label
var name_input: LineEdit
var start_button: Button
var leaderboard_button: Button
var target_button: Button
var leaderboard_panel: PanelContainer
var leaderboard_list: VBoxContainer
var close_lb_button: Button

func _ready():
	# Setup CheddaBoards
	CheddaBoards.set_api_key(API_KEY)
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.leaderboard_received.connect(_on_leaderboard_received)
	CheddaBoards.player_rank_received.connect(_on_rank_received)
	CheddaBoards.request_failed.connect(_on_request_failed)
	
	# Create UI
	_create_ui()
	
	# Load saved name if exists
	if FileAccess.file_exists("user://player_name.txt"):
		var file = FileAccess.open("user://player_name.txt", FileAccess.READ)
		name_input.text = file.get_as_text().strip_edges()
		file.close()
	
	# Initial state
	_show_menu()

func _process(delta):
	if game_active:
		time_left -= delta
		timer_label.text = "⏱ %.1f" % max(0, time_left)
		
		if time_left <= 0:
			_end_game()

# ═══════════════════════════════════════════════════════════════════
# UI CREATION
# ═══════════════════════════════════════════════════════════════════

func _create_ui():
	var viewport_size = get_viewport().size
	var center_x = viewport_size.x / 2
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	title_label = Label.new()
	title_label.text = "🧀 Chedda Click"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 30)
	title_label.size = Vector2(viewport_size.x, 50)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	add_child(title_label)
	
	# Score display
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.position = Vector2(0, 100)
	score_label.size = Vector2(viewport_size.x, 50)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(score_label)
	
	# Streak display
	streak_label = Label.new()
	streak_label.text = "Streak: 0"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.position = Vector2(0, 150)
	streak_label.size = Vector2(viewport_size.x, 30)
	streak_label.add_theme_font_size_override("font_size", 22)
	streak_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
	add_child(streak_label)
	
	# Timer display
	timer_label = Label.new()
	timer_label.text = "⏱ 30.0"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(0, 185)
	timer_label.size = Vector2(viewport_size.x, 30)
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	add_child(timer_label)
	
	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, 225)
	status_label.size = Vector2(viewport_size.x, 30)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(status_label)
	
	# Name input label
	name_label = Label.new()
	name_label.text = "Enter Your Name:"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 270)
	name_label.size = Vector2(viewport_size.x, 25)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(name_label)
	
	# Name input field
	name_input = LineEdit.new()
	name_input.placeholder_text = "CheeseChaser99"
	name_input.position = Vector2(center_x - 120, 295)
	name_input.size = Vector2(240, 45)
	name_input.max_length = 20
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 20)
	name_input.text_submitted.connect(func(_t): _start_game())
	add_child(name_input)
	
	# Start button
	start_button = Button.new()
	start_button.text = "🎮 PLAY"
	start_button.position = Vector2(center_x - 120, 355)
	start_button.size = Vector2(240, 55)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(_start_game)
	add_child(start_button)
	
	# Leaderboard button
	leaderboard_button = Button.new()
	leaderboard_button.text = "🏆 LEADERBOARD"
	leaderboard_button.position = Vector2(center_x - 120, 420)
	leaderboard_button.size = Vector2(240, 50)
	leaderboard_button.add_theme_font_size_override("font_size", 18)
	leaderboard_button.pressed.connect(_show_leaderboard)
	add_child(leaderboard_button)
	
	# Click target (the cheese!)
	target_button = Button.new()
	target_button.text = "🧀"
	target_button.size = Vector2(90, 90)
	target_button.add_theme_font_size_override("font_size", 50)
	target_button.pressed.connect(_on_target_clicked)
	target_button.visible = false
	add_child(target_button)
	
	# Leaderboard panel
	leaderboard_panel = PanelContainer.new()
	leaderboard_panel.position = Vector2(center_x - 160, 270)
	leaderboard_panel.size = Vector2(320, 350)
	leaderboard_panel.visible = false
	add_child(leaderboard_panel)
	
	var panel_vbox = VBoxContainer.new()
	panel_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_vbox.add_theme_constant_override("separation", 5)
	leaderboard_panel.add_child(panel_vbox)
	
	var lb_title = Label.new()
	lb_title.text = "🏆 TOP SCORES"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 22)
	lb_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	panel_vbox.add_child(lb_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_vbox.add_child(scroll)
	
	leaderboard_list = VBoxContainer.new()
	leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_list.add_theme_constant_override("separation", 8)
	scroll.add_child(leaderboard_list)
	
	close_lb_button = Button.new()
	close_lb_button.text = "✕ CLOSE"
	close_lb_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_lb_button.custom_minimum_size = Vector2(120, 35)
	close_lb_button.pressed.connect(_close_leaderboard)
	panel_vbox.add_child(close_lb_button)

# ═══════════════════════════════════════════════════════════════════
# GAME LOGIC
# ═══════════════════════════════════════════════════════════════════

func _show_menu():
	game_active = false
	start_button.visible = true
	leaderboard_button.visible = true
	name_label.visible = true
	name_input.visible = true
	name_input.editable = true
	target_button.visible = false
	leaderboard_panel.visible = false
	
	score_label.text = "Click the 🧀 to score!"
	streak_label.text = "Best Streak: %d 🔥" % best_streak if best_streak > 0 else "30 seconds to score big!"
	timer_label.text = "⏱ %.1f" % GAME_DURATION
	status_label.text = ""

func _sanitize_player_id(name: String) -> String:
	# Convert name to valid player ID
	var id = name.strip_edges().to_lower().replace(" ", "_")
	var valid_id = ""
	for c in id:
		if c in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			valid_id += c
	
	# Ensure it's not empty and within limits
	if valid_id.is_empty():
		valid_id = "player_" + str(randi() % 100000)
	
	return valid_id.substr(0, 50)

func _start_game():
	# Get player name
	player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player_" + str(randi() % 10000)
		name_input.text = player_name
	
	# Generate player ID from name
	player_id = _sanitize_player_id(player_name)
	
	# Save name for next time
	var file = FileAccess.open("user://player_name.txt", FileAccess.WRITE)
	file.store_string(player_name)
	file.close()
	
	# Reset game state
	score = 0
	streak = 0
	time_left = GAME_DURATION
	game_active = true
	
	# Update UI
	start_button.visible = false
	leaderboard_button.visible = false
	name_label.visible = false
	name_input.visible = false
	leaderboard_panel.visible = false
	target_button.visible = true
	
	score_label.text = "Score: 0"
	streak_label.text = "Streak: 0"
	status_label.text = "Go %s! Click the cheese!" % player_name
	
	_move_target()

func _move_target():
	var viewport_size = get_viewport().size
	var margin = 100
	var new_pos = Vector2(
		randf_range(margin, viewport_size.x - margin),
		randf_range(280, viewport_size.y - margin)
	)
	target_button.position = new_pos - target_button.size / 2

func _on_target_clicked():
	if not game_active:
		return
	
	# Increase score (streak bonus!)
	var points = 10 + streak * 2
	score += points
	streak += 1
	best_streak = max(best_streak, streak)
	
	# Update UI
	score_label.text = "Score: %d (+%d)" % [score, points]
	streak_label.text = "Streak: %d 🔥" % streak
	
	# Visual feedback - make cheese briefly bigger
	var tween = create_tween()
	tween.tween_property(target_button, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(target_button, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Move target
	_move_target()

func _end_game():
	game_active = false
	target_button.visible = false
	status_label.text = "⏳ Submitting score..."
	
	# Submit to CheddaBoards with nickname!
	CheddaBoards.submit_score(player_id, score, best_streak, -1, player_name)

func _show_leaderboard():
	leaderboard_panel.visible = true
	start_button.visible = false
	leaderboard_button.visible = false
	name_label.visible = false
	name_input.visible = false
	status_label.text = "Loading..."
	
	# Clear existing entries
	for child in leaderboard_list.get_children():
		child.queue_free()
	
	# Add loading text
	var loading = Label.new()
	loading.text = "Loading..."
	loading.name = "loading"
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_list.add_child(loading)
	
	# Fetch from CheddaBoards
	CheddaBoards.get_leaderboard(100)

func _close_leaderboard():
	leaderboard_panel.visible = false
	_show_menu()

# ═══════════════════════════════════════════════════════════════════
# CHEDDABOARDS CALLBACKS
# ═══════════════════════════════════════════════════════════════════

func _on_score_submitted(success: bool, message: String):
	if success:
		status_label.text = "✅ Score saved!"
		# Get our rank
		CheddaBoards.get_player_rank(player_id)
	else:
		status_label.text = "❌ " + message
		await get_tree().create_timer(2.0).timeout
		_show_menu()

func _on_rank_received(success: bool, data: Dictionary):
	if success and data.has("rank"):
		var rank_text = "#%d" % data.rank
		if data.rank == 1:
			rank_text = "🥇 #1"
		elif data.rank == 2:
			rank_text = "🥈 #2"
		elif data.rank == 3:
			rank_text = "🥉 #3"
		
		status_label.text = "🏆 %s - Rank %s of %d!" % [player_name, rank_text, data.totalPlayers]
	else:
		status_label.text = "✅ Score saved!"
	
	# Show menu after delay
	await get_tree().create_timer(2.5).timeout
	_show_menu()

func _on_leaderboard_received(success: bool, entries: Array):
	# Remove loading text
	var loading = leaderboard_list.get_node_or_null("loading")
	if loading:
		loading.queue_free()
	
	status_label.text = ""
	
	if not success or entries.is_empty():
		var empty = Label.new()
		empty.text = "No scores yet!\nBe the first! 🧀"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaderboard_list.add_child(empty)
		return
	
	# Get current player name for highlighting
	var current_name = name_input.text.strip_edges()
	
	# Add entries
	for entry in entries:
		var is_current_player = (current_name != "" and entry.nickname == current_name) or (player_id != "" and entry.get("playerId", "") == player_id)		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		# Add background highlight for current player
		if is_current_player:
			var bg = ColorRect.new()
			bg.color = Color(1.0, 0.85, 0.0, 0.2)  # Gold with transparency
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(bg)
			bg.show_behind_parent = true
		
		# Rank with medal
		var rank_label = Label.new()
		var rank_text = "#%d" % entry.rank
		if entry.rank == 1:
			rank_text = "🥇"
		elif entry.rank == 2:
			rank_text = "🥈"
		elif entry.rank == 3:
			rank_text = "🥉"
		rank_label.text = rank_text
		rank_label.custom_minimum_size = Vector2(35, 0)
		rank_label.add_theme_font_size_override("font_size", 16)
		if is_current_player:
			rank_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		hbox.add_child(rank_label)
		
		# Name
		var name_lbl = Label.new()
		name_lbl.text = entry.nickname + (" ◀ YOU" if is_current_player else "")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		if is_current_player:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))  # Bright yellow
		elif entry.rank <= 3:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		hbox.add_child(name_lbl)
		
		# Score
		var score_lbl = Label.new()
		score_lbl.text = str(entry.score)
		score_lbl.add_theme_font_size_override("font_size", 16)
		if is_current_player:
			score_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))  # Bright green
		else:
			score_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		hbox.add_child(score_lbl)
		
		leaderboard_list.add_child(hbox)

func _on_request_failed(endpoint: String, error: String):
	status_label.text = "❌ " + error
	print("CheddaBoards error on %s: %s" % [endpoint, error])
	
	# If on leaderboard, show error
	if leaderboard_panel.visible:
		var loading = leaderboard_list.get_node_or_null("loading")
		if loading:
			loading.text = "Failed to load 😢"
