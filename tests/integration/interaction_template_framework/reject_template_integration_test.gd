## Integration tests for the Reject template — requires scene tree + autoloads.
## Skipped until gdUnit4 scene-setup scaffolding is in place (tracked in code review
## for story-008). Stub kept so the scenarios are not lost.
##
## AC-1: Both cards pushed away, neither removed from table.
## AC-3: combination_executed signal is NOT emitted.
##
## To activate: replace each pending_test_ prefix with test_ and wire up
## a minimal CardNode scene with CardSpawning + CardEngine autoloads.

extends GdUnitTestSuite


func pending_test_reject_pushes_both_cards_neither_consumed() -> void:
	# Setup: spawn two cards at known positions via CardSpawning
	# Action: emit combination_attempted with a "reject" recipe registered
	# Assert: both cards still exist in CardSpawning after the push tween
	# Assert: both cards have moved away from their original positions
	pass


func pending_test_reject_does_not_emit_combination_executed() -> void:
	# Setup: connect a spy listener to ITF.combination_executed
	# Action: trigger the reject template via combination_attempted
	# Assert: spy listener was never called
	pass


func pending_test_reject_cooldown_blocks_second_attempt() -> void:
	# Setup: fire a reject recipe once (writes _last_fired)
	# Action: emit combination_attempted for the same pair immediately
	# Assert: on_combination_failed is called (normal bounce), emote NOT re-emitted
	pass
