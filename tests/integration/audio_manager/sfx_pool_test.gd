## Integration tests for AudioManager SFX pool — Story 002.
##
## Covers the 6 QA acceptance criteria from the story:
##   AC-1: _ready() creates exactly 8 AudioStreamPlayer children on the SFX bus
##   AC-2: all 8 pool nodes start IDLE (_sfx_pool_state all false)
##   AC-3: fire-and-forget: claim → play → finished signal → IDLE
##   AC-4: pool full + non-win event → returns -1, no node stopped
##   AC-5: pool full + win event → stops node with least remaining time
##   AC-6: silent-fallback mode → pool still initializes with 8 nodes
##
## Pattern note: AudioManager omits class_name because the autoload name
## occupies the global identifier. Preload the script and add_child() to
## trigger _ready(). See autoload_config_test.gd for the established pattern.
##
## AC-5 headless approach: AudioStreamPlayer.get_playback_position() always
## returns 0.0 in headless (no audio hardware), so AudioStreamWAV.get_length()
## does not reliably reflect byte-array size in headless Godot — all streams
## read as 0.0. Instead we use a test-subclass (AudioManagerTestProxy) that
## overrides _get_remaining_time() with an injected lookup table of floats.
## This is the officially documented test simplification for this story and
## tests the exact same branching logic (find min, call stop, return index).
extends GdUnitTestSuite

const AudioManagerScript := preload("res://src/core/audio_manager.gd")


# ── Test proxy for AC-5 ───────────────────────────────────────────────────────
#
# Subclasses AudioManager and overrides _get_remaining_time() so AC-5 can
# exercise the win-steal algorithm with known values without live audio.
# The override is documented as a test simplification per the story watch-out.

class AudioManagerTestProxy extends AudioManagerScript:
	## Injected remaining-time table. Index maps to pool slot.
	## Set before calling _claim_sfx_node(true).
	var mock_remaining_times: Array[float] = []

	func _get_remaining_time(index: int) -> float:
		if mock_remaining_times.size() > index:
			return mock_remaining_times[index]
		return 0.0


# ── helpers ──────────────────────────────────────────────────────────────────

## Creates a fresh AudioManager, adds it to the scene tree (triggers _ready()),
## and returns it. Caller must free() after each test.
func _make_manager() -> Node:
	var manager: Node = AudioManagerScript.new()
	add_child(manager)
	return manager


# ── AC-1: 8 pool nodes, all on SFX bus ───────────────────────────────────────

func test_sfx_pool_creates_exactly_eight_children() -> void:
	# Arrange + Act
	var manager: Node = _make_manager()

	# Count AudioStreamPlayer children only (ignore other potential children).
	var count: int = 0
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			count += 1

	# Assert
	assert_int(count).is_equal(8)
	manager.free()


func test_sfx_pool_all_nodes_assigned_to_sfx_bus() -> void:
	# Arrange + Act
	var manager: Node = _make_manager()

	# Assert every AudioStreamPlayer child has bus == "SFX".
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			assert_str(String(player.bus)).is_equal("SFX")

	manager.free()


func test_sfx_pool_array_has_eight_entries() -> void:
	# Arrange + Act
	var manager: Node = _make_manager()

	# Assert internal pool array length matches POOL_SIZE.
	assert_int(manager._sfx_pool.size()).is_equal(8)
	manager.free()


# ── AC-2: all pool nodes start IDLE ──────────────────────────────────────────

func test_sfx_pool_state_has_eight_entries_after_ready() -> void:
	# Arrange + Act
	var manager: Node = _make_manager()

	assert_int(manager._sfx_pool_state.size()).is_equal(8)
	manager.free()


func test_sfx_pool_all_nodes_start_idle() -> void:
	# Arrange + Act
	var manager: Node = _make_manager()

	# Assert every state slot is false (IDLE).
	for i: int in 8:
		assert_bool(manager._sfx_pool_state[i]).is_false()

	manager.free()


# ── AC-3: fire-and-forget: finished signal resets state to IDLE ───────────────

func test_sfx_pool_on_sfx_finished_resets_state_to_idle() -> void:
	# Arrange
	var manager: Node = _make_manager()
	# Simulate a node being claimed and playing.
	manager._sfx_pool_state[0] = true
	assert_bool(manager._sfx_pool_state[0]).is_true()  # pre-condition

	# Act: emit finished signal directly (headless: play() never fires it).
	manager._sfx_pool[0].finished.emit()

	# Assert: slot returns to IDLE.
	assert_bool(manager._sfx_pool_state[0]).is_false()
	manager.free()


func test_sfx_pool_claim_returns_idle_index_when_available() -> void:
	# Arrange
	var manager: Node = _make_manager()
	# All nodes are IDLE (default after _ready()).

	# Act
	var idx: int = manager._claim_sfx_node(false)

	# Assert: first IDLE node (index 0) is returned.
	assert_int(idx).is_equal(0)
	manager.free()


func test_sfx_pool_claim_returns_first_idle_when_some_are_playing() -> void:
	# Arrange
	var manager: Node = _make_manager()
	# Mark the first two slots as PLAYING.
	manager._sfx_pool_state[0] = true
	manager._sfx_pool_state[1] = true

	# Act
	var idx: int = manager._claim_sfx_node(false)

	# Assert: first IDLE is index 2.
	assert_int(idx).is_equal(2)
	manager.free()


# ── AC-4: pool full + non-win event → -1, no node stopped ────────────────────

func test_sfx_pool_full_non_win_returns_minus_one() -> void:
	# Arrange
	var manager: Node = _make_manager()
	# Mark all 8 slots as PLAYING.
	for i: int in 8:
		manager._sfx_pool_state[i] = true

	# Act
	var idx: int = manager._claim_sfx_node(false)

	# Assert
	assert_int(idx).is_equal(-1)
	manager.free()


func test_sfx_pool_full_non_win_no_node_is_stopped() -> void:
	# Arrange
	var manager: Node = _make_manager()
	for i: int in 8:
		manager._sfx_pool_state[i] = true

	# Act
	manager._claim_sfx_node(false)

	# Assert: all slots remain PLAYING (no stop() was called).
	for i: int in 8:
		assert_bool(manager._sfx_pool_state[i]).is_true()

	manager.free()


# ── AC-5: pool full + win event → steal least remaining time ─────────────────
#
# Uses AudioManagerTestProxy which overrides _get_remaining_time() with a
# known lookup table. This isolates the steal algorithm from live audio state,
# which is unavailable in headless mode. The override targets the same
# extracted method that the production code calls — the branching logic and
# stop() call are exercised identically to a live run.
#
# Documented test simplification per story-002 watch-out.

func test_sfx_pool_full_win_steals_node_with_least_remaining_time() -> void:
	# Arrange
	var proxy := AudioManagerTestProxy.new()
	add_child(proxy)
	# Inject known remaining times. Node 5 has the shortest (0.05 s).
	proxy.mock_remaining_times = [
		1.00,  # 0
		2.00,  # 1
		0.50,  # 2
		0.75,  # 3
		1.50,  # 4
		0.05,  # 5 ← MINIMUM → must be stolen
		1.25,  # 6
		1.75,  # 7
	]
	for i: int in 8:
		proxy._sfx_pool_state[i] = true

	# Act
	var stolen_idx: int = proxy._claim_sfx_node(true)

	# Assert: node 5 (least remaining time) was selected.
	assert_int(stolen_idx).is_equal(5)
	# That slot must now be IDLE (stop() + state reset in _claim_sfx_node).
	assert_bool(proxy._sfx_pool_state[5]).is_false()

	proxy.free()


func test_sfx_pool_full_win_stops_stolen_node_only() -> void:
	# Arrange
	var proxy := AudioManagerTestProxy.new()
	add_child(proxy)
	proxy.mock_remaining_times = [
		1.00, 2.00, 0.50, 0.75, 1.50, 0.05, 1.25, 1.75,
	]
	for i: int in 8:
		proxy._sfx_pool_state[i] = true

	# Act
	var stolen_idx: int = proxy._claim_sfx_node(true)

	# Assert: only the stolen slot becomes IDLE; all others remain PLAYING.
	assert_int(stolen_idx).is_equal(5)
	for i: int in 8:
		if i == stolen_idx:
			assert_bool(proxy._sfx_pool_state[i]).is_false()
		else:
			assert_bool(proxy._sfx_pool_state[i]).is_true()

	proxy.free()


# ── AC-6: silent-fallback mode → pool still initializes ──────────────────────
#
# In silent mode _ready() enters the null-config branch. _init_sfx_pool() must
# still run so state transitions (TR-019) work correctly even without audio.

func test_sfx_pool_initializes_in_silent_mode() -> void:
	# Arrange + Act: add_child() triggers _ready(), which runs _init_sfx_pool()
	# unconditionally even when config is missing (silent mode).
	# The autoload itself is already in silent mode (audio_config.tres absent),
	# so this also exercises the real autoload path. We create a fresh instance
	# to avoid cross-test contamination with the autoload singleton.
	var manager: Node = AudioManagerScript.new()
	add_child(manager)
	# _ready() ran. Whether config loaded or not, pool must exist.

	# Assert: pool is populated.
	assert_int(manager._sfx_pool.size()).is_equal(8)
	assert_int(manager._sfx_pool_state.size()).is_equal(8)
	manager.free()


func test_sfx_pool_silent_mode_all_states_idle() -> void:
	# Arrange + Act
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	# Assert: all slots are IDLE even in silent mode.
	for i: int in 8:
		assert_bool(manager._sfx_pool_state[i]).is_false()

	manager.free()


func test_sfx_pool_silent_mode_children_on_sfx_bus() -> void:
	# Arrange + Act
	var manager: Node = AudioManagerScript.new()
	add_child(manager)

	# Assert: nodes still exist and are on SFX bus (no stream assigned).
	var count: int = 0
	for child: Node in manager.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child as AudioStreamPlayer
			assert_str(String(player.bus)).is_equal("SFX")
			assert_object(player.stream).is_null()
			count += 1
	assert_int(count).is_equal(8)

	manager.free()
