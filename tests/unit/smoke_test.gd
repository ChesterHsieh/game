## Smoke test — proves gdUnit4 toolchain + helpers + autoimport all work.
##
## This is the minimum viable test that exercises the test harness end-to-end.
## If this test fails, no other test in the suite can be trusted.
##
## Run locally:  godot --headless --script tests/gdunit4_runner.gd
## CI:           .github/workflows/tests.yml (gdUnit4-action)
extends GdUnitTestSuite


# --- Framework functional ----------------------------------------------------

func test_gdunit_basic_arithmetic_passes() -> void:
	# Arrange
	var a := 2
	var b := 3

	# Act
	var sum := a + b

	# Assert
	assert_that(sum).is_equal(5)


func test_gdunit_string_assertion_passes() -> void:
	# Arrange
	var project_name := "Moments"

	# Assert
	assert_str(project_name).is_equal("Moments")
	assert_str(project_name).has_length(7)


# --- Domain helpers loadable (class_name auto-import works) -------------------

func test_game_assertions_value_in_range_passes_for_valid_bar_value() -> void:
	# Arrange
	var bar_value := 45.0
	var bar_max := 100.0

	# Act + Assert — if GameAssertions class_name resolves, this line compiles
	GameAssertions.assert_in_range(bar_value, 0.0, bar_max, "test_bar")
	GameAssertions.assert_bar_value(bar_value, bar_max)

	# Reach here = helpers are importable and functional
	assert_bool(true).is_true()


func test_game_assertions_card_state_accepts_valid_state() -> void:
	# Assert — Idle is in CARD_ENGINE_STATES (Card Engine GDD §FSM)
	GameAssertions.assert_valid_card_state("Idle")
	assert_bool(true).is_true()
