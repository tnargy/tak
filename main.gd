extends Node2D

# Game state
var board = []
var current_player = 1  # 1 for Player 1 (White), 2 for Player 2 (Black)
var turn_count = 0
var player_pieces = {1: {"flats": 21, "capstone": 1}, 2: {"flats": 21, "capstone": 1}}
var selected_square = null
var selected_piece_type = "flat"
var game_over = false

# Constants
const BOARD_SIZE = 5
const MAX_STACK = 5
const SQUARE_SIZE = 64
const PIECE_OFFSET = 10

# Preload piece scenes
var flat_scene = preload("res://flat.tscn")
var wall_scene = preload("res://wall.tscn")
var capstone_scene = preload("res://capstone.tscn")

func _ready():
	# Initialize 5x5 board
	for i in range(BOARD_SIZE):
		var row = []
		for j in range(BOARD_SIZE):
			row.append({"stack": [], "node": create_square(i, j)})
		board.append(row)
	# Setup UI
	setup_ui()
	# Update turn label
	update_turn_label()

func create_square(row, col):
	var square = Node2D.new()
	square.position = Vector2(col * SQUARE_SIZE, row * SQUARE_SIZE)
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://Square.jpg")  # Placeholder texture for square
	sprite.scale = Vector2(SQUARE_SIZE / 64.0, SQUARE_SIZE / 64.0)
	square.add_child(sprite)
	add_child(square)
	return square

func setup_ui():
	var ui = VBoxContainer.new()
	ui.position = Vector2(BOARD_SIZE * SQUARE_SIZE + 20, 20)
	
	var turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Player 1's Turn"
	ui.add_child(turn_label)
	
	var flat_button = Button.new()
	flat_button.text = "Place Flat"
	flat_button.pressed.connect(func(): selected_piece_type = "flat")
	ui.add_child(flat_button)
	
	var wall_button = Button.new()
	wall_button.text = "Place Wall"
	wall_button.pressed.connect(func(): selected_piece_type = "wall")
	ui.add_child(wall_button)
	
	var capstone_button = Button.new()
	capstone_button.text = "Place Capstone"
	capstone_button.pressed.connect(func(): selected_piece_type = "capstone")
	ui.add_child(capstone_button)
	
	add_child(ui)

func _input(event):
	if game_over: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pos = get_global_mouse_position()
		var row = int(pos.y / SQUARE_SIZE)
		var col = int(pos.x / SQUARE_SIZE)
		if row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE:
			if selected_square == null:
				# Select a square for movement or placement
				if board[row][col]["stack"].size() > 0 and is_stack_controlled(row, col):
					selected_square = Vector2i(row, col)
				else:
					place_piece(row, col)
			else:
				# Attempt to move stack
				move_stack(selected_square.x, selected_square.y, row, col)
				selected_square = null

func place_piece(row, col):
	if board[row][col]["stack"].size() > 0: return  # Square occupied
	var piece_player = current_player if turn_count >= 2 else 3 - current_player
	var piece = null
	
	if selected_piece_type == "flat" and player_pieces[current_player]["flats"] > 0:
		piece = flat_scene.instantiate()
		player_pieces[current_player]["flats"] -= 1
	elif selected_piece_type == "wall" and player_pieces[current_player]["flats"] > 0:
		piece = wall_scene.instantiate()
		player_pieces[current_player]["flats"] -= 1
	elif selected_piece_type == "capstone" and player_pieces[current_player]["capstone"] > 0:
		piece = capstone_scene.instantiate()
		player_pieces[current_player]["capstone"] -= 1
	else:
		return
	
	if piece:
		piece.player = piece_player
		piece.position = Vector2(0, -board[row][col]["stack"].size() * PIECE_OFFSET)
		board[row][col]["stack"].append(piece)
		board[row][col]["node"].add_child(piece)
		end_turn()

func move_stack(from_row, from_col, to_row, to_col):
	if abs(from_row - to_row) + abs(from_col - to_col) != 1: return  # Must be adjacent
	var stack = board[from_row][from_col]["stack"]
	if stack.size() == 0: return
	
	# Simple movement: move up to MAX_STACK pieces
	var move_count = min(stack.size(), MAX_STACK)
	var pieces_to_move = stack.slice(-move_count)
	
	# Check if destination has a wall or capstone
	if board[to_row][to_col]["stack"].size() > 0:
		var top_piece = board[to_row][to_col]["stack"][-1]
		if top_piece.type == "wall" and pieces_to_move[-1].type != "capstone":
			return  # Can't move onto wall unless capstone
		if top_piece.type == "capstone":
			return  # Can't move onto capstone
	
	# Move pieces
	for i in range(move_count):
		var piece = stack.pop_back()
		piece.position = Vector2(0, -board[to_row][to_col]["stack"].size() * PIECE_OFFSET)
		board[to_row][to_col]["stack"].append(piece)
		board[to_row][to_col]["node"].add_child(piece)
	
	end_turn()

func is_stack_controlled(row, col):
	var stack = board[row][col]["stack"]
	if stack.size() == 0: return false
	return stack[-1].player == current_player

func end_turn():
	turn_count += 1
	current_player = 3 - current_player
	update_turn_label()
	check_win_condition()

func update_turn_label():
	var label = $VBoxContainer/TurnLabel
	label.text = "Player %d's Turn" % current_player

func check_win_condition():
	# Check for road win
	for player in [1, 2]:
		if has_road(player):
			game_over = true
			$VBoxContainer/TurnLabel.text = "Player %d Wins!" % player
			return
	# Check for game end (board full or no pieces)
	var board_full = true
	for row in board:
		for square in row:
			if square["stack"].size() == 0:
				board_full = false
	if board_full or player_pieces[1]["flats"] == 0 or player_pieces[2]["flats"] == 0:
		var flat_counts = {1: 0, 2: 0}
		for row in board:
			for square in row:
				if square["stack"].size() > 0 and square["stack"][-1].type == "flat":
					flat_counts[square["stack"][-1].player] += 1
		var winner = 1 if flat_counts[1] > flat_counts[2] else 2
		game_over = true
		$VBoxContainer/TurnLabel.text = "Player %d Wins!" % winner

func has_road(player):
	# Simple DFS to check for a road
	var visited = []
	for i in range(BOARD_SIZE):
		visited.append([])
		for j in range(BOARD_SIZE):
			visited[i].append(false)
	
	# Check horizontal roads
	for i in range(BOARD_SIZE):
		if board[i][0]["stack"].size() > 0 and board[i][0]["stack"][-1].player == player and board[i][0]["stack"][-1].type != "wall":
			if dfs(i, 0, player, visited, "horizontal"):
				return true
	
	# Check vertical roads
	visited = []
	for i in range(BOARD_SIZE):
		visited.append([])
		for j in range(BOARD_SIZE):
			visited[i].append(false)
	for j in range(BOARD_SIZE):
		if board[0][j]["stack"].size() > 0 and board[0][j]["stack"][-1].player == player and board[0][j]["stack"][-1].type != "wall":
			if dfs(0, j, player, visited, "vertical"):
				return true
	return false

func dfs(row, col, player, visited, direction):
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE: return false
	if visited[row][col]: return false
	if board[row][col]["stack"].size() == 0: return false
	var top_piece = board[row][col]["stack"][-1]
	if top_piece.player != player or top_piece.type == "wall": return false
	
	visited[row][col] = true
	if (direction == "horizontal" and col == BOARD_SIZE - 1) or (direction == "vertical" and row == BOARD_SIZE - 1):
		return true
	
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	if direction == "horizontal":
		directions = [Vector2i(0, 1), Vector2i(0, -1)]
	if direction == "vertical":
		directions = [Vector2i(1, 0), Vector2i(-1, 0)]
	
	for dir in directions:
		if dfs(row + dir.x, col + dir.y, player, visited, direction):
			return true
	return false
