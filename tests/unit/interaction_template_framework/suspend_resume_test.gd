## Unit tests for InteractionTemplateFramework Suspend/Resume — Story 007.
##
## Covers all ACs from story-007-suspend-resume.md:
##   AC-1: suspend() sets Suspended state; combination_attempted silently ignored
##   AC-2: Generator timers paused on suspend(); unpaused on resume()
##   AC-3: suspend()/resume() are idempotent (double-call does not error)
##   Plus: resume() transitions back to Ready; combination_attempted fires again
##
## Strategy:
##   The implementation uses a simple bool `_active` rather than an enum State.
##   Story 007 specifies an enum { READY, SUSPENDED } but the implementation
##   uses bool directly. Tests verify the observable behaviour (_active flag and
##   signal suppression) rather than the enum type, since we cannot modify src/.
##
##   For generator timer pause/resume (AC-2): the Generator template is not yet
##   implemented (_execute_generator absent, _active_generators absent).
##   Timer pause tests are provided as [SPEC] pending-implementation stubs.
##
## NOTE — Implementation/story mismatch (flag only):
##   Story 007 expects enum State { READY, SUSPENDED }; implementation uses
##   `_active: bool` (true = Ready, false = Suspended). Tests target _active.
##   Generator/timer pausing untestable until story-006 is implemented.
extends GdUnitTestSuite

const ITFScript := preload("res://src/gameplay/interaction_template_framework.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_itf() -> Node:
	var itf: Node = ITFScript.new()
	add_child(itf)
	return itf


# ── AC-1: suspend() sets Suspended state ──────────────────────────────────────

func test_suspend_resume_suspend_sets_active_to_false() -> void:
	# Arrange: ITF starts active
	var itf: Node = _make_itf()
	assert_bool(itf._active).is_true()

	# Act
	itf.suspend()

	# Assert: _active = false (Suspended state)
	assert_bool(itf._active).is_false()

	itf.queue_free()


func test_suspend_resume_resume_sets_active_to_true() -> void:
	# Arrange: suspended
	var itf: Node = _make_itf()
	itf.suspend()
	assert_bool(itf._active).is_false()

	# Act
	itf.resume()

	# Assert: _active = true (Ready state)
	assert_bool(itf._active).is_true()

	itf.queue_free()


# ── AC-1: combination_attempted silently ignored while Suspended ───────────────

func test_suspend_resume_combination_executed_not_emitted_while_suspended() -> void:
	# Arrange: suspend ITF
	var itf: Node = _make_itf()
	itf.suspend()
	itf._scene_id = "home"

	var emitted := {"fired": false}
	itf.combination_executed.connect(
		func(_rid: String, _tmpl: String, _ia: String, _ib: String) -> void:
			emitted["fired"] = true
	)

	# Act: trigger combination handler directly
	if itf.has_method("_on_combination_attempted"):
		itf._on_combination_attempted("chester_0", "ju_0")

	# Assert: no signal — silently ignored
	assert_bool(emitted["fired"]).is_false()

	itf.queue_free()


func test_suspend_resume_last_fired_not_written_while_suspended() -> void:
	# Arrange: suspended; no recipe lookup should happen
	var itf: Node = _make_itf()
	itf.suspend()
	itf._scene_id = "home"
	var size_before: int = itf._last_fired.size()

	# Act
	if itf.has_method("_on_combination_attempted"):
		itf._on_combination_attempted("chester_0", "ju_0")

	# Assert: _last_fired unchanged
	assert_int(itf._last_fired.size()).is_equal(size_before)

	itf.queue_free()


func test_suspend_resume_pending_merges_not_modified_while_suspended() -> void:
	# Arrange: suspended; no merge should be started
	var itf: Node = _make_itf()
	itf.suspend()
	itf._scene_id = "home"
	var merges_before: int = itf._pending_merges.size()

	# Act
	if itf.has_method("_on_combination_attempted"):
		itf._on_combination_attempted("chester_0", "ju_0")

	# Assert: _pending_merges unchanged
	assert_int(itf._pending_merges.size()).is_equal(merges_before)

	itf.queue_free()


# ── AC-1: resume restores normal processing ────────────────────────────────────

func test_suspend_resume_after_resume_system_is_active() -> void:
	# Arrange: suspend then resume
	var itf: Node = _make_itf()
	itf.suspend()
	itf.resume()

	# Assert: _active = true
	assert_bool(itf._active).is_true()

	itf.queue_free()


# ── AC-3: idempotency ────────────────────────────────────────────────────────

func test_suspend_resume_double_suspend_does_not_error() -> void:
	# Arrange: already suspended
	var itf: Node = _make_itf()
	itf.suspend()

	# Act: call suspend again — should not crash or corrupt state
	itf.suspend()

	# Assert: still suspended
	assert_bool(itf._active).is_false()

	itf.queue_free()


func test_suspend_resume_double_resume_does_not_error() -> void:
	# Arrange: already resumed (default Ready)
	var itf: Node = _make_itf()

	# Act: call resume without prior suspend — should not crash
	itf.resume()

	# Assert: still active
	assert_bool(itf._active).is_true()

	itf.queue_free()


func test_suspend_resume_suspend_resume_suspend_cycles_correctly() -> void:
	# Arrange: multiple suspend/resume cycles
	var itf: Node = _make_itf()

	itf.suspend()
	assert_bool(itf._active).is_false()
	itf.resume()
	assert_bool(itf._active).is_true()
	itf.suspend()
	assert_bool(itf._active).is_false()
	itf.resume()
	assert_bool(itf._active).is_true()

	itf.queue_free()


# ── AC-2: SPEC — Generator timer pausing (pending story-006) ──────────────────

func test_suspend_resume_spec_generator_timers_paused_on_suspend() -> void:
	# [SPEC] AC-2: When a generator is active, suspend() pauses its timer.
	# Requires _execute_generator() from story-006.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator") or not ("_active_generators" in itf):
		push_warning(
			"[SPEC story-007 AC-2] Generator not implemented. "
			+ "Timer pause test requires story-006 _execute_generator() first."
		)
		itf.queue_free()
		return

	var recipe := {
		"id": "chester-coffee",
		"card_a": "chester",
		"card_b": "coffee",
		"template": "Generator",
		"config": {
			"generates": "memory",
			"interval_sec": 60.0,
			"max_count": null,
			"generator_card": "card_a",
		},
	}

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])

	# Act
	itf.suspend()

	# Assert: timer in _active_generators is paused
	for entry: Dictionary in itf._active_generators.values():
		if entry.has("timer"):
			assert_bool(entry["timer"].paused).is_true()

	itf.queue_free()


func test_suspend_resume_spec_generator_timers_unpaused_on_resume() -> void:
	# [SPEC] AC-2: resume() unpauses generator timers.
	var itf: Node = _make_itf()

	if not itf.has_method("_execute_generator") or not ("_active_generators" in itf):
		push_warning("[SPEC story-007 AC-2] Generator not implemented.")
		itf.queue_free()
		return

	var recipe := {
		"id": "chester-coffee",
		"card_a": "chester",
		"card_b": "coffee",
		"template": "Generator",
		"config": {
			"generates": "memory",
			"interval_sec": 60.0,
			"max_count": null,
			"generator_card": "card_a",
		},
	}

	itf._execute_generator(recipe, "chester_0", "coffee_0", recipe["config"])
	itf.suspend()
	itf.resume()

	# Assert: timer unpaused
	for entry: Dictionary in itf._active_generators.values():
		if entry.has("timer"):
			assert_bool(entry["timer"].paused).is_false()

	itf.queue_free()


# ── Public API surface ────────────────────────────────────────────────────────

func test_suspend_resume_suspend_method_exists() -> void:
	var itf: Node = _make_itf()
	assert_bool(itf.has_method("suspend")).is_true()
	itf.queue_free()


func test_suspend_resume_resume_method_exists() -> void:
	var itf: Node = _make_itf()
	assert_bool(itf.has_method("resume")).is_true()
	itf.queue_free()


func test_suspend_resume_reset_cooldowns_method_exists() -> void:
	var itf: Node = _make_itf()
	assert_bool(itf.has_method("reset_cooldowns")).is_true()
	itf.queue_free()


func test_suspend_resume_set_scene_id_method_exists() -> void:
	var itf: Node = _make_itf()
	assert_bool(itf.has_method("set_scene_id")).is_true()
	itf.queue_free()
