## emote_demo — Kenney emotes-pack 平替視覺驗證
## 循環展示全部 8 種 emote，每張卡片上方彈出氣泡，確認像素風格與遊戲相符
extends Node2D

const EMOTE_NAMES := ["heart", "spark", "ok", "anger", "question", "exclaim", "sweat", "zzz"]
const EMOTE_DIR   := "res://prototypes/bounce-demo/emotes/"

const CARD_W := 88.0
const CARD_H := 112.0
const COLS   := 4
const ROWS   := 2
const PAD_X  := 130.0
const PAD_Y  := 160.0

# pop-in → hold → fade-out 參數（秒）
const POP_SEC  := 0.18
const HOLD_SEC := 1.4
const FADE_SEC := 0.25

var _cards : Array[Node2D] = []


func _ready() -> void:
	_build_bg()
	_build_cards()
	_cycle_all()


func _build_bg() -> void:
	var vp := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.13, 0.12)
	bg.size  = vp
	add_child(bg)

	_lbl("Kenney Emotes — 平替驗證 Demo", Vector2(vp.x * 0.5 - 160, 20), 18, Color(0.95, 0.90, 0.82))
	_lbl("每張卡片循環彈出對應 emote 氣泡  ·  按任意鍵重播", Vector2(vp.x * 0.5 - 195, 48), 13, Color(0.70, 0.65, 0.58))


func _build_cards() -> void:
	var vp    := get_viewport_rect().size
	var start := Vector2(
		vp.x * 0.5 - (COLS - 1) * PAD_X * 0.5,
		vp.y * 0.5 - (ROWS - 1) * PAD_Y * 0.5 + 20
	)

	for i in EMOTE_NAMES.size():
		var col := i % COLS
		var row := i / COLS  # int division intentional
		var pos := start + Vector2(col * PAD_X, row * PAD_Y)
		var card := _make_card(i, pos)
		add_child(card)
		_cards.append(card)


func _cycle_all() -> void:
	for i in EMOTE_NAMES.size():
		# 錯開每張卡的觸發時間，視覺更豐富
		_fire_emote_loop(i, i * 0.35)


func _fire_emote_loop(card_idx: int, initial_delay: float) -> void:
	await get_tree().create_timer(initial_delay).timeout
	while true:
		_show_emote(card_idx)
		await get_tree().create_timer(POP_SEC + HOLD_SEC + FADE_SEC + 0.8).timeout


func _show_emote(card_idx: int) -> void:
	var emote_name : String = EMOTE_NAMES[card_idx]
	var card       : Node2D = _cards[card_idx]
	# Use Image.load_from_file so we don't need .import sidecar files
	var img := Image.load_from_file(ProjectSettings.globalize_path(EMOTE_DIR + emote_name + ".png"))
	if img == null:
		push_warning("emote_demo: missing texture for '%s'" % emote_name)
		return
	var tex := ImageTexture.create_from_image(img)

	# 氣泡容器（跟著卡片位置）
	# 縮小整體尺寸：bubble 36px，sprite 28px → 顆粒感降低
	var bubble := Node2D.new()
	bubble.position = Vector2(0, -CARD_H * 0.5 - 28)
	bubble.scale    = Vector2.ZERO
	card.add_child(bubble)

	# 白色圓形背景
	var bg_rect := ColorRect.new()
	bg_rect.size     = Vector2(24, 24)
	bg_rect.position = Vector2(-12, -12)
	bg_rect.color    = Color(1, 1, 1, 0.92)
	bubble.add_child(bg_rect)

	# emote 圖示（pixel art，關閉濾波）
	var sprite := TextureRect.new()
	sprite.texture               = tex
	sprite.size                  = Vector2(18, 18)
	sprite.position              = Vector2(-9, -9)
	sprite.texture_filter        = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	sprite.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.add_child(sprite)

	# 標籤名稱（debug 用）
	var lbl := Label.new()
	lbl.text     = name
	lbl.position = Vector2(-28, 30)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	bubble.add_child(lbl)

	# 動畫：pop-in → hold → fade-out → 自刪
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2(1.0, 1.0), POP_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD_SEC)
	tw.tween_property(bubble, "modulate:a", 0.0, FADE_SEC)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(bubble.queue_free)


# ── helpers ───────────────────────────────────────────────────────────────────

func _make_card(idx: int, world_pos: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = world_pos

	var shadow := ColorRect.new()
	shadow.size     = Vector2(CARD_W, CARD_H)
	shadow.position = Vector2(-CARD_W * 0.5 + 4, -CARD_H * 0.5 + 5)
	shadow.color    = Color(0, 0, 0, 0.25)
	root.add_child(shadow)

	var bg := ColorRect.new()
	bg.size     = Vector2(CARD_W, CARD_H)
	bg.position = Vector2(-CARD_W * 0.5, -CARD_H * 0.5)
	bg.color    = Color(0.98, 0.97, 0.93)
	root.add_child(bg)

	var name_lbl := Label.new()
	name_lbl.text     = EMOTE_NAMES[idx]
	name_lbl.position = Vector2(-CARD_W * 0.5 + 6, CARD_H * 0.5 - 22)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.35, 0.30, 0.25))
	root.add_child(name_lbl)

	return root


func _lbl(txt: String, pos: Vector2, sz: int, col: Color) -> void:
	var l := Label.new()
	l.text     = txt
	l.position = pos
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	add_child(l)


func _unhandled_key_input(_event: InputEvent) -> void:
	# 重播
	for card in _cards:
		for child in card.get_children():
			if child is Node2D and child != null:
				child.queue_free()
	_cycle_all()
