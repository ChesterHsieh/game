extends Node2D

const BASE_Y       := 300.0
const JUMP_H       := 100.0
const RISE_SEC     := 0.28
const FALL_SEC     := 0.52
const DRIFT_MIN    := 35.0
const DRIFT_MAX    := 55.0
const EDGE_MARGIN  := 80.0

var _cards   : Array[Node2D] = []
var _tweens  : Array         = [null, null, null]
var _dirs    : Array[float]  = [-1.0, 0.0, 1.0]
var _jumping : Array[bool]   = [false, false, false]

const ART_COLORS := [
	Color(0.35, 0.65, 0.98),
	Color(0.85, 0.72, 0.60),
	Color(0.45, 0.85, 0.55),
]
const CARD_LABELS := ["rabbit_jump", "static", "rabbit_jump\n(lifts 3s)"]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.13, 0.12)
	bg.size = get_viewport_rect().size
	add_child(bg)

	var hint := Label.new()
	hint.text = "rabbit_jump demo  —  左右兩張跳躍，右側 3s 後拿起暫停"
	hint.position = Vector2(80, 30)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
	add_child(hint)

	var vp_cx := get_viewport_rect().size.x * 0.5
	var offsets := [-160.0, 0.0, 160.0]
	for i in 3:
		var c := _make_card(i, Vector2(vp_cx + offsets[i], BASE_Y))
		add_child(c)
		_cards.append(c)

	_start_hop(0)
	_start_hop(2)

	await get_tree().create_timer(3.0).timeout
	_stop_hop(2)
	_cards[2].scale = Vector2(1.08, 1.08)

	await get_tree().create_timer(2.5).timeout
	_cards[2].scale = Vector2(1.0, 1.0)
	_cards[2].position.y = BASE_Y
	_start_hop(2)


func _make_card(idx: int, pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = pos

	var shadow := ColorRect.new()
	shadow.size = Vector2(88, 112)
	shadow.position = Vector2(-44 + 4, -56 + 5)
	shadow.color = Color(0, 0, 0, 0.3)
	root.add_child(shadow)

	var body := ColorRect.new()
	body.size = Vector2(88, 112)
	body.position = Vector2(-44, -56)
	body.color = Color(0.98, 0.97, 0.93)
	root.add_child(body)

	var art := ColorRect.new()
	art.size = Vector2(60, 58)
	art.position = Vector2(-30, -10)
	art.color = ART_COLORS[idx]
	root.add_child(art)

	var lbl := Label.new()
	lbl.text = CARD_LABELS[idx]
	lbl.position = Vector2(-40, -52)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
	root.add_child(lbl)

	if idx != 1:
		var badge := ColorRect.new()
		badge.size = Vector2(84, 16)
		badge.position = Vector2(-42, -64)
		badge.color = Color(0.1, 0.1, 0.1)
		root.add_child(badge)
		var blbl := Label.new()
		blbl.text = "rabbit_jump"
		blbl.position = Vector2(-40, -64)
		blbl.add_theme_font_size_override("font_size", 10)
		blbl.add_theme_color_override("font_color", Color.WHITE)
		root.add_child(blbl)

	return root


func _start_hop(idx: int) -> void:
	if _jumping[idx]:
		return
	_jumping[idx] = true
	_cards[idx].position.y = BASE_Y
	_do_hop(idx)


func _do_hop(idx: int) -> void:
	if not _jumping[idx]:
		return

	var card := _cards[idx]
	var drift := randf_range(DRIFT_MIN, DRIFT_MAX) * _dirs[idx]
	var next_x: float = card.position.x + drift
	var vp_w := get_viewport_rect().size.x
	if next_x < EDGE_MARGIN or next_x > vp_w - EDGE_MARGIN:
		_dirs[idx] *= -1.0
		drift = randf_range(DRIFT_MIN, DRIFT_MAX) * _dirs[idx]

	var sx: float = card.position.x
	var land_x: float = sx + drift
	var peak_y: float = BASE_Y - JUMP_H

	var t := card.create_tween()
	# 上升：y 到頂點，x 漂一半
	t.set_parallel(true)
	t.tween_property(card, "position:y", peak_y, RISE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:x", sx + drift * 0.5, RISE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.set_parallel(false)
	# 下降：y 回 BASE_Y，x 到落地點
	t.set_parallel(true)
	t.tween_property(card, "position:y", BASE_Y, FALL_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(card, "position:x", land_x, FALL_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.set_parallel(false)
	t.tween_callback(func() -> void:
		_tweens[idx] = null
		if _jumping[idx]:
			_do_hop(idx)
	)
	_tweens[idx] = t


func _stop_hop(idx: int) -> void:
	_jumping[idx] = false
	if _tweens[idx] != null:
		_tweens[idx].kill()
		_tweens[idx] = null
	_cards[idx].position.y = BASE_Y
