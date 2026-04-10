# PROTOTYPE - NOT FOR PRODUCTION
# Draws status bars + hint glow on top of all other nodes
# Date: 2026-03-27

extends Node2D

const BAR_W       = 20.0
const BAR_H       = 160.0
const BAR_PADDING = 16.0

var bar_values: Dictionary = {}
var hint_alpha: float      = 0.0
var max_bar: float         = 100.0

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
		# Border
		draw_rect(Rect2(bx, by, BAR_W, BAR_H), Color(0.8, 0.8, 0.8, 0.5), false, 1.5)

		# Hint glow — tight frame around the bar
		if hint_alpha > 0.01:
			var pad = 5.0
			var gc  = bar_colors[i]
			# Outer soft halo
			draw_rect(Rect2(bx - pad * 2.5, by - pad * 2.5, BAR_W + pad * 5, BAR_H + pad * 5),
				Color(gc.r, gc.g, gc.b, hint_alpha * 0.3), false, 4.0)
			# Inner sharp frame
			draw_rect(Rect2(bx - pad, by - pad, BAR_W + pad * 2, BAR_H + pad * 2),
				Color(gc.r, gc.g, gc.b, hint_alpha), false, 2.0)
