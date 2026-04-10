# PROTOTYPE - NOT FOR PRODUCTION
# Draws status bars + threshold line + sustain hold glow
# Date: 2026-03-27

extends Node2D

const BAR_W       = 20.0
const BAR_H       = 160.0
const BAR_PADDING = 16.0

var bar_values:    Dictionary = {}
var hint_alpha:    float      = 0.0
var max_bar:       float      = 100.0
var threshold:     float      = 60.0
var sustain_timer: float      = 0.0
var sustain_max:   float      = 5.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bar_values.is_empty():
		return

	var bar_names  = ["chester", "ju"]
	var bar_colors = [Color(0.4, 0.6, 0.9), Color(0.9, 0.5, 0.6)]
	var vh         = get_viewport().get_visible_rect().size.y
	var base_x     = 20.0

	for i in 2:
		var bx   = base_x + i * (BAR_W + BAR_PADDING)
		var val  = bar_values.get(bar_names[i], 0.0)
		var fill = (val / max_bar) * BAR_H
		var by   = vh - BAR_PADDING - BAR_H

		# Background
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.15, 0.15, 0.15, 0.6))
		# Fill (bottom up)
		if fill > 0:
			draw_rect(Rect2(bx, by + BAR_H - fill, BAR_W, fill), bar_colors[i])
		# Threshold line — yellow dashed mark
		var threshold_y = by + BAR_H - (threshold / max_bar) * BAR_H
		draw_line(Vector2(bx - 3, threshold_y), Vector2(bx + BAR_W + 3, threshold_y),
			Color(1.0, 1.0, 0.4, 0.8), 1.5)
		# Border
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.8, 0.8, 0.8, 0.5), false, 1.5)

	# Sustain hold glow — golden frame when both bars above threshold
	if sustain_timer > 0.0:
		var progress = clamp(sustain_timer / sustain_max, 0.0, 1.0)
		for i in 2:
			var bx = base_x + i * (BAR_W + BAR_PADDING)
			var by = vh - BAR_PADDING - BAR_H
			draw_rect(Rect2(bx - 4, by - 4, BAR_W + 8, BAR_H + 8),
				Color(1.0, 0.92, 0.3, 0.25 + progress * 0.55), false, 3.0)
