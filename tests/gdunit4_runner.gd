# GdUnit4 test runner — DEPRECATED stub
#
# This legacy script pointed at `res://addons/gdunit4/GdUnitRunner.gd`, which
# does not exist in gdUnit4 4.x. The addon ships its own CLI runner.
#
# Use the official shell entrypoint instead:
#
#     GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
#       ./addons/gdUnit4/runtest.sh -a tests/
#
# Or a single suite:
#
#     GODOT_BIN=... ./addons/gdUnit4/runtest.sh -a tests/unit/smoke_test.gd
#
# This stub remains so legacy callers get a clear error message instead of
# a silent "GdUnit4 not found" crash.
extends SceneTree


func _init() -> void:
	push_error("tests/gdunit4_runner.gd is deprecated. Run gdUnit4 via "
		+ "addons/gdUnit4/runtest.sh — see file header for exact command.")
	quit(1)
