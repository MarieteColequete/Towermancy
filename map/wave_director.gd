class_name WaveDirector
extends Node

# -------------------------
# Exports
# -------------------------

@export var enemy_scene: PackedScene

# HP multiplier increases by this value every 10 waves.
# e.g. 0.5 means +50% HP at wave 10, +100% at wave 20, etc.
@export var hp_per_ten_waves: float = 0.5

# Base seconds between spawn ticks at wave 0. Scales up to 3x by wave 200.
@export var default_spawn_interval: float = 0.5

@export var player_health: Player

# -------------------------
# Signals
# -------------------------

# Emitted whenever the enemy count changes (spawned or died/reached base).
signal enemies_remaining_changed(count: int)
signal wave_started(wave_number: int)

# -------------------------
# Enemy unlock thresholds (wave number)
# -------------------------

const UNLOCK_WAVE: Dictionary = {
	Enemy.EnemyType.NORMIE:   0,
	Enemy.EnemyType.ROGUE:    4,
	Enemy.EnemyType.WARRIOR:  8,
	Enemy.EnemyType.WIZARD:   15,
	# BOSS and UBER_BOSS are never bought with tokens — spawned as elite/ultimate
}

# Token cost per enemy type
const TOKEN_COST: Dictionary = {
	Enemy.EnemyType.NORMIE:  1,
	Enemy.EnemyType.ROGUE:   2,
	Enemy.EnemyType.WARRIOR: 4,
	Enemy.EnemyType.WIZARD:  3,
}

# -------------------------
# Wave state
# -------------------------

var _current_wave: int = 0

# spawn_point_index -> Array[Enemy.EnemyType] queue
var _spawn_queues: Dictionary = {}

# All available spawn points
var _spawn_data: Array[Dictionary] = []

# Timer for sequential spawning
var _spawn_timer: Timer

# Whether a wave is currently running
var _wave_active: bool = false

# Number of spawn points with non-empty queues at wave start (used for interval calc)
var _active_spawn_count: int = 1

# Count of enemies still alive or queued this wave
var _enemies_remaining: int = 0

var _map_director: Node


# -------------------------
# Setup
# -------------------------

func _ready() -> void:
	_map_director = get_parent()

	if player_health == null:
		push_warning("[WaveDirector] player_health not assigned!")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = default_spawn_interval
	_spawn_timer.autostart = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)


func update_spawn_points(data: Array[Dictionary]) -> void:
	_spawn_data = data


# -------------------------
# Wave generation
# -------------------------

# Main entry point. Call this to start a wave.
# horde = true skips distribution and uses all spawn points for every enemy.
func start_wave(wave_number: int, horde: bool = false) -> void:
	if _wave_active:
		push_warning("[WaveDirector] Wave already active, ignoring start_wave call.")
		return

	_current_wave = wave_number
	_spawn_queues.clear()
	wave_started.emit(wave_number)

	var is_elite: bool = wave_number > 0 and wave_number % 10 == 0
	var is_ultimate: bool = wave_number > 0 and wave_number % 100 == 0

	if is_ultimate:
		_build_ultimate_wave(horde)
	elif is_elite:
		_build_elite_wave(horde)
	else:
		_build_normal_wave(wave_number, horde)

	# Count total queued enemies and active spawn points
	_enemies_remaining = 0
	_active_spawn_count = 0
	for queue in _spawn_queues.values():
		var size: int = (queue as Array).size()
		_enemies_remaining += size
		if size > 0:
			_active_spawn_count += 1
	_active_spawn_count = maxi(1, _active_spawn_count)
	enemies_remaining_changed.emit(_enemies_remaining)

	_spawn_timer.wait_time = _compute_spawn_interval(wave_number, _enemies_remaining, _active_spawn_count)
	_wave_active = true
	_spawn_timer.start()


# -------------------------
# Wave builders
# -------------------------

func _build_normal_wave(wave_number: int, horde: bool) -> void:
	var tokens: int = _compute_tokens(wave_number)
	var hp_mult: float = _compute_hp_multiplier(wave_number)
	var available_types: Array = _get_unlocked_types(wave_number)
	var max_group: int = int(10 + float(wave_number) / 4.0)

	# Build a list of groups. Each group is a block of the same enemy type.
	# Group size is proportional to remaining tokens divided by the type's cost,
	# capped at max_group to avoid all tokens going to one type in low waves.
	# Types are picked in sequence so same-cost types don't end up in the same group.
	var groups: Array[Array] = []
	var remaining: int = tokens

	while remaining > 0 and not available_types.is_empty():
		var affordable: Array = available_types.filter(
			func(t): return TOKEN_COST[t] <= remaining
		)
		if affordable.is_empty():
			break

		# Pick a random affordable type for this group
		var chosen: Enemy.EnemyType = affordable[randi() % affordable.size()]
		var cost: int = TOKEN_COST[chosen]

		# Group size: proportional to remaining/cost, capped at max_group
		var group_size: int = mini(int(remaining / cost), max_group)
		group_size = maxi(1, group_size)

		# Spend tokens and build the group
		var actual_size: int = mini(group_size, remaining / cost)
		var group: Array[Enemy.EnemyType] = []
		for i in range(actual_size):
			group.append(chosen)
		groups.append(group)
		remaining -= cost * actual_size

		# Remove chosen type so next iteration picks a different one
		# It will be re-added if tokens still remain after one full cycle
		available_types.erase(chosen)
		if available_types.is_empty():
			# All types used once — refill with still-affordable types for next cycle
			available_types = _get_unlocked_types(wave_number).filter(
				func(t): return TOKEN_COST[t] <= remaining
			)

	# Shuffle group order so the sequence varies, but keep each group intact
	groups.shuffle()

	# Flatten groups into a single enemy list
	var enemy_list: Array[Enemy.EnemyType] = []
	for group in groups:
		for type in group:
			enemy_list.append(type)

	_distribute_to_queues(enemy_list, horde, hp_mult)


func _build_elite_wave(horde: bool) -> void:
	# One BOSS at the heaviest spawn point, plus a normal wave underneath
	var hp_mult: float = _compute_hp_multiplier(_current_wave)
	_build_normal_wave(_current_wave, horde)

	# Add the boss on top at the farthest spawn point
	if not _spawn_data.is_empty() and not horde:
		var heaviest: Dictionary = _get_heaviest_spawn()
		var idx: int = _spawn_data.find(heaviest)
		if not _spawn_queues.has(idx):
			_spawn_queues[idx] = []
		# Boss goes at the front of the queue
		(_spawn_queues[idx] as Array).push_front(
			_make_entry(Enemy.EnemyType.BOSS, hp_mult)
		)
	else:
		# Horde: boss at every spawn
		for i in range(_spawn_data.size()):
			if not _spawn_queues.has(i):
				_spawn_queues[i] = []
			(_spawn_queues[i] as Array).push_front(
				_make_entry(Enemy.EnemyType.BOSS, hp_mult)
			)


func _build_ultimate_wave(horde: bool) -> void:
	# One UBER_BOSS at the heaviest spawn point, plus a normal wave underneath
	var hp_mult: float = _compute_hp_multiplier(_current_wave)
	_build_normal_wave(_current_wave, horde)

	if not _spawn_data.is_empty() and not horde:
		var heaviest: Dictionary = _get_heaviest_spawn()
		var idx: int = _spawn_data.find(heaviest)
		if not _spawn_queues.has(idx):
			_spawn_queues[idx] = []
		(_spawn_queues[idx] as Array).push_front(
			_make_entry(Enemy.EnemyType.UBER_BOSS, hp_mult)
		)
	else:
		for i in range(_spawn_data.size()):
			if not _spawn_queues.has(i):
				_spawn_queues[i] = []
			(_spawn_queues[i] as Array).push_front(
				_make_entry(Enemy.EnemyType.UBER_BOSS, hp_mult)
			)


# -------------------------
# Distribution
# -------------------------

# Splits the flat enemy list across available spawn points.
# Each spawn point gets a contiguous slice of the shuffled list.
func _distribute_to_queues(
	enemy_list: Array[Enemy.EnemyType],
	horde: bool,
	hp_mult: float
) -> void:
	if enemy_list.is_empty():
		return

	if horde:
		# Every enemy goes to every spawn point
		for i in range(_spawn_data.size()):
			_spawn_queues[i] = []
			for type in enemy_list:
				(_spawn_queues[i] as Array).append(_make_entry(type, hp_mult))
		return

	# Decide how many spawn points to use (scale with enemy count)
	var points_to_use: int = clampi(
		enemy_list.size() / 3,
		1,
		_spawn_data.size()
	)

	# Sort spawn points by weight descending (farthest first = harder spawns)
	var sorted_spawns: Array = _spawn_data.duplicate()
	sorted_spawns.sort_custom(func(a, b): return a["weight"] > b["weight"])
	var active_spawns: Array = sorted_spawns.slice(0, points_to_use)

	# Distribute enemies round-robin across active spawn points
	for i in range(active_spawns.size()):
		var original_idx: int = _spawn_data.find(active_spawns[i])
		_spawn_queues[original_idx] = []

	var spawn_idx: int = 0
	for type in enemy_list:
		var original_idx: int = _spawn_data.find(active_spawns[spawn_idx])
		(_spawn_queues[original_idx] as Array).append(_make_entry(type, hp_mult))
		spawn_idx = (spawn_idx + 1) % active_spawns.size()


# -------------------------
# Spawn tick
# -------------------------

func _on_spawn_tick() -> void:
	var any_remaining: bool = false

	for spawn_idx in _spawn_queues.keys():
		var queue: Array = _spawn_queues[spawn_idx]
		if queue.is_empty():
			continue

		any_remaining = true
		var entry: Dictionary = queue.pop_front()
		_spawn_single(spawn_idx, entry["type"], entry["hp_mult"])

	if not any_remaining:
		_spawn_timer.stop()
		_wave_active = false
		_spawn_queues.clear()


# -------------------------
# Actual spawning
# -------------------------

func _spawn_single(spawn_idx: int, type: Enemy.EnemyType, hp_mult: float) -> void:
	if enemy_scene == null:
		push_error("[WaveDirector] enemy_scene is not assigned!")
		return
	if spawn_idx >= _spawn_data.size():
		return

	var enemy: Enemy = enemy_scene.instantiate()
	_apply_stats(enemy, type, hp_mult, _compute_speed_mult(_current_wave))
	enemy.map_director = _map_director
	enemy.reached_base.connect(_on_enemy_reached_base)
	enemy.died.connect(_on_enemy_removed)
	add_child(enemy)
	enemy.activate(_spawn_data[spawn_idx]["spawn_position"])


# Kept for external use (e.g. debug, scripted events)
func spawn_at_all(type: Enemy.EnemyType) -> void:
	for i in range(_spawn_data.size()):
		_spawn_single(i, type, 1.0)  # No HP or speed scaling for manual spawns


# -------------------------
# Token and scaling helpers
# -------------------------

# Tokens scale exponentially with wave number.
func _compute_tokens(wave_number: int) -> int:
	return int(1 + (10 * wave_number * pow(1.01, wave_number)))


# HP multiplier increases linearly: +hp_per_ten_waves every 10 waves.
func _compute_hp_multiplier(wave_number: int) -> float:
	return 1.0 + floor(float(wave_number) / 10.0) * hp_per_ten_waves


func _get_unlocked_types(wave_number: int) -> Array:
	var result: Array = []
	for type in UNLOCK_WAVE.keys():
		if wave_number >= UNLOCK_WAVE[type]:
			result.append(type)
	return result


func _get_heaviest_spawn() -> Dictionary:
	var heaviest: Dictionary = _spawn_data[0]
	for entry in _spawn_data:
		if entry["weight"] > heaviest["weight"]:
			heaviest = entry
	return heaviest


# -------------------------
# Entry factory
# -------------------------

func _make_entry(type: Enemy.EnemyType, hp_mult: float) -> Dictionary:
	return { "type": type, "hp_mult": hp_mult }


# -------------------------
# Stat templates
# -------------------------

func _apply_stats(enemy: Enemy, type: Enemy.EnemyType, hp_mult: float, speed_mult: float = 1.0) -> void:
	enemy.enemy_type = type
	match type:
		Enemy.EnemyType.ROGUE:
			enemy.max_hp     = int(6 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 250.0 * 50 * speed_mult
			enemy.damage     = 1
			enemy.size       = 0.6
			enemy.armor      = 0
			enemy.plating    = 0
			enemy.gold_reward = 2

		Enemy.EnemyType.NORMIE:
			enemy.max_hp     = int(10 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 80.0 * 50 * speed_mult
			enemy.damage     = 1
			enemy.size       = 1.0
			enemy.armor      = 0
			enemy.plating    = 0
			enemy.gold_reward = 1

		Enemy.EnemyType.WARRIOR:
			enemy.max_hp     = int(30 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 50.0 * 50 * speed_mult
			enemy.damage     = 2
			enemy.size       = 1.2
			enemy.armor      = 30
			enemy.plating    = 0
			enemy.gold_reward = 3

		Enemy.EnemyType.WIZARD:
			enemy.max_hp     = int(15 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 100.0 * 50 * speed_mult
			enemy.damage     = 2
			enemy.size       = 1.0
			enemy.armor      = 0
			enemy.plating    = int(3 * hp_mult)
			enemy.gold_reward = 3

		Enemy.EnemyType.BOSS:
			enemy.max_hp     = int(100 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 30.0 * 50 * speed_mult
			enemy.damage     = 15
			enemy.size       = 2.0
			enemy.armor      = 50
			enemy.plating    = 3
			enemy.gold_reward = 20

		Enemy.EnemyType.UBER_BOSS:
			enemy.max_hp     = int(300 * hp_mult)
			enemy.current_hp = enemy.max_hp
			enemy.speed      = 20.0 * 50 * speed_mult
			enemy.damage     = 100
			enemy.size       = 3.0
			enemy.armor      = 100
			enemy.plating    = int(5 * hp_mult)
			enemy.gold_reward = 100


# -------------------------
# Spawn interval and speed scaling
# -------------------------

# Spawn interval scales from default down to a minimum that ensures
# at least 0.5% of total enemies spawn per second across all active spawn points.
func _compute_spawn_interval(wave_number: int, total_enemies: int, active_spawns: int) -> float:
	var speed_mult: float = _compute_speed_mult(wave_number)
	var scaled_interval: float = default_spawn_interval / speed_mult

	# Minimum interval: 0.5% of total enemies per second means
	# 1 tick per (active_spawns / (total * 0.005)) seconds
	var min_interval: float = float(active_spawns) / (float(total_enemies) * 0.005)
	min_interval = maxf(min_interval, 0.05)  # Hard floor to avoid div-by-zero or absurd rates

	return minf(scaled_interval, min_interval)


# Speed multiplier goes from x1 at wave 0 to x3 at wave 200, capped there.
func _compute_speed_mult(wave_number: int) -> float:
	return lerp(1.0, 3.0, minf(float(wave_number) / 200.0, 1.0))


# -------------------------
# Signal handlers
# -------------------------

func _on_enemy_reached_base(damage: int) -> void:
	if player_health != null:
		player_health.take_damage(damage)
	_on_enemy_removed(0)


func _on_enemy_removed(gold_reward: int = 0) -> void:
	_enemies_remaining = maxi(0, _enemies_remaining - 1)
	enemies_remaining_changed.emit(_enemies_remaining)
	if gold_reward > 0 and player_health != null:
		player_health.add_gold(gold_reward)
