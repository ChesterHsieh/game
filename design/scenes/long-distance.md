# Scene: 遠戀 2016–2020

> **Status**: Draft (mechanics phase — playtest pending)
> **Last updated**: 2026-04-27
> **Source of truth**: this file. All generated data files are reconstructable
> from this spec via `/create-scene long-distance`.

---

## 1. Identity

| Field | Value |
|---|---|
| `scene_id` | `long-distance` |
| `display_name` | 遠戀 2016–2020 |
| `narrative_beat` | 從巨城廣場的告白開始，跨越太平洋的四年——用小小的儀式對抗孤獨 |
| `manifest_order` | 3 |
| `phase` | Mid-game |

---

## 2. Seed State (cards on the table at scene start)

```
ju
chester
```

Spawner active from scene start: `courage` spawns every 5 seconds, max 3 on
table at once, uses `rabbit_jump` visual tag.

---

## 3. New Cards (define in this scene — added to cards.tres)

### `courage`
| Field | Value |
|---|---|
| type | feeling |
| display_name | 勇氣 |
| flavor_text | 一晃眼就跳走了。要趁它還在的時候抓住。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/courage.png` |
| visual_tag | `rabbit_jump` |

### `chester_brave_1`
| Field | Value |
|---|---|
| type | feeling |
| display_name | ❤Chester |
| flavor_text | 心跳了一下。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/chester.png` (reuse) |

### `chester_brave_2`
| Field | Value |
|---|---|
| type | feeling |
| display_name | ❤❤Chester |
| flavor_text | 還是不夠。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/chester.png` (reuse) |

### `confession`
| Field | Value |
|---|---|
| type | moment |
| display_name | 告白 |
| flavor_text | 在巨城廣場。十年的朋友，一句話全押上去。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/confession.png` |

### `angry_daddy`
| Field | Value |
|---|---|
| type | person |
| display_name | 怒氣的爸爸 |
| flavor_text | 「妳要去哪裡？」門開了，他追了出來。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/angry_daddy.png` |
| `draggable` | `false` (玩家不能拖 — 它會自己走) |
| `visual_tag` | `angry_walk` |
| `chase_target_card_id` | `ju` |
| `move_speed_px_per_sec` | 30 |
| `sway_angle_deg` | 10 |
| `sway_period_sec` | 0.6 |
| `on_catch` | `consume_both, spawn ju_running` |

### `ju_running`
| Field | Value |
|---|---|
| type | moment |
| display_name | 奴奴奪門而出 |
| flavor_text | 「我一下就會來。」她跳上車，我膽戰心驚。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/ju.png` (reuse, with motion blur overlay) |
| `visual_tag` | `rabbit_jump_fast` |

### `at_her_door`
| Field | Value |
|---|---|
| type | moment |
| display_name | 門口對峙 |
| flavor_text | 膽戰心驚。我壯起膽量，跟他爸好好溝通。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/at_her_door.png` |

### `fathers_door`
| Field | Value |
|---|---|
| type | moment |
| display_name | 那個晚上 |
| flavor_text | 「我為什麼要聽你解釋。」那是我跟她爸最後一次說話。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/fathers_door.png` |

### `silent_decade`
| Field | Value |
|---|---|
| type | feeling |
| display_name | 沉默的十年 |
| flavor_text | 「我為什麼要聽你解釋。」那天之後，他爸再也沒跟我說過一句話。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/silent_decade.png` (greyish/faded edge) |
| `draggable` | `false` (immovable — 不能被拖、不能被組合) |
| `carry_forward` | `[board-games, germany, save-for-italy, italy, tenth-anniversary]` |
| `resolved_in_scene` | `tenth-anniversary` |

### `nunu_crying`
| Field | Value |
|---|---|
| type | inside_joke |
| display_name | 奴奴哭哭 |
| flavor_text | 公園的長椅，泣不成聲。我只能在旁邊等她說完。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/ju.png` (reuse) |

### `rearview_mirror`
| Field | Value |
|---|---|
| type | moment |
| display_name | 後視鏡裡的她 |
| flavor_text | 我不會開車。她一個人把整條路開完了。我只能坐在副駕，看著鏡子裡的她。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/rearview_mirror.png` |

### `atlanta`
| Field | Value |
|---|---|
| type | place |
| display_name | 亞特蘭大 |
| flavor_text | 四年都在這裡。離她一萬公里。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/atlanta.png` |

### `video_call`
| Field | Value |
|---|---|
| type | object |
| display_name | 晚上十點視訊 |
| flavor_text | 台灣的早晨，亞特蘭大的夜。一個固定的時間，把日子綁在一起。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/video_call.png` |

### `obra_dinn`
| Field | Value |
|---|---|
| type | object |
| display_name | 奧伯拉丁的回歸 |
| flavor_text | 跨越太平洋，兩個人一起推理死因。解謎比思念更有用。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/obra_dinn.png` |

### `lights_on`
| Field | Value |
|---|---|
| type | feeling |
| display_name | 開著燈 |
| flavor_text | 一個人睡覺，客廳的燈必須開著。有她在，就可以關了。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/lights_on.png` |

### `too_lonely`
| Field | Value |
|---|---|
| type | feeling |
| display_name | 快撐不下去 |
| flavor_text | 四年。工作、疫情、還有太孤單。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/too_lonely.png` |

### `surviving_distance`
| Field | Value |
|---|---|
| type | feeling |
| display_name | 撐過去的力量 |
| flavor_text | 不是不辛苦，是辛苦也沒放手。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/surviving_distance.png` |

### `reunion`
| Field | Value |
|---|---|
| type | moment |
| display_name | 回台灣 |
| flavor_text | 2020。終於可以回來了。 |
| scene_id | `long-distance` |
| art_path | `res://assets/cards/reunion.png` |

> Cards referenced but already defined elsewhere — do NOT re-define:
> `ju`, `chester`

---

## 4. Puzzle Graph (recipes — added to recipes.tres, scene-scoped)

Readable summary:

```
[Spawner]
generator : (every 5s, max 3) → spawns courage with rabbit_jump tag

[告白支線 — 三段勇氣堆疊]
brave-1     : courage + chester           → chester_brave_1   [merge, no keeps]
brave-2     : courage + chester_brave_1   → chester_brave_2   [merge, keeps: —]
confess     : courage + chester_brave_2   → confession        [merge, keeps: chester]

[那個晚上 — 怒爸追逐 → 奪門而出 → 對峙]
fathers-spawn : ju + confession           → spawns: angry_daddy  [additive, keeps: ju]
                                            (angry_daddy auto-chases ju, ±10° sway)

[chase collision — 非 recipe，是 card-visual layer 的 catch behavior]
collision   : angry_daddy ⟶ ju            → consumes both, spawns: ju_running
                                            (no bar effect — 純情境演出)

at-door     : ju_running + chester        → at_her_door       [merge, keeps: chester]
fathers     : at_her_door + chester       → fathers_door      [merge, keeps: ju, chester,
                                                                spawns: silent_decade]
nunu        : ju + fathers_door           → nunu_crying       [merge, keeps: ju]

[silent_decade 不可拖、不可組 — 只是靜靜在桌上，carry-forward 到所有後續場景，
 直到 tenth-anniversary 才有食譜化解]

[澳洲 2015]
australia   : nunu_crying + chester       → rearview_mirror   [merge, keeps: chester]

[各自起飛]
to-atlanta  : ju + rearview_mirror        → atlanta           [merge, keeps: ju, chester]

[遠戀日常]
videocall   : ju + atlanta                → video_call        [additive, spawns: video_call, keeps: ju, atlanta]
obradinn    : video_call + chester        → obra_dinn         [merge, keeps: chester]
lights      : video_call + ju             → lights_on         [merge, keeps: ju]
surviving   : obra_dinn + lights_on       → surviving_distance [merge, keeps: —]

[低谷]
lonely      : atlanta + chester           → too_lonely        [merge, keeps: chester]

[重聚]
reunion     : surviving_distance + too_lonely → reunion       [merge, keeps: —]
```

### `brave-1`
| Field | Value |
|---|---|
| id | `brave-1` |
| card_a | `courage` |
| card_b | `chester` |
| template | `merge` |
| result_card | `chester_brave_1` |
| keeps | `chester` |
| emote | `heart` |

### `brave-2`
| Field | Value |
|---|---|
| id | `brave-2` |
| card_a | `courage` |
| card_b | `chester_brave_1` |
| template | `merge` |
| result_card | `chester_brave_2` |
| keeps | — |
| emote | `heart` |

### `confess`
| Field | Value |
|---|---|
| id | `confess` |
| card_a | `courage` |
| card_b | `chester_brave_2` |
| template | `merge` |
| result_card | `confession` |
| keeps | `chester` |
| emote | `spark` |

### `fathers-spawn`
| Field | Value |
|---|---|
| id | `fathers-spawn` |
| card_a | `ju` |
| card_b | `confession` |
| template | `additive` |
| spawns | `[angry_daddy]` |
| keeps | `ju` |
| emote | `exclaim` |

> When `angry_daddy` enters the table it begins ChaseBehavior (see Section 15
> for engine TR). It walks toward `ju` at 30 px/sec while swaying ±10°. On
> collision with `ju`, both cards are consumed and `ju_running` is spawned.
> This is **NOT a recipe** — it's card-visual catch behavior.

### `at-door`
| Field | Value |
|---|---|
| id | `at-door` |
| card_a | `ju_running` |
| card_b | `chester` |
| template | `merge` |
| result_card | `at_her_door` |
| keeps | `chester` |
| emote | `sweat` |

### `fathers`
| Field | Value |
|---|---|
| id | `fathers` |
| card_a | `at_her_door` |
| card_b | `chester` |
| template | `merge` |
| result_card | `fathers_door` |
| spawns | `[silent_decade]` |
| keeps | `ju, chester` |
| emote | `exclaim` |

### `nunu`
| Field | Value |
|---|---|
| id | `nunu` |
| card_a | `ju` |
| card_b | `fathers_door` |
| template | `merge` |
| result_card | `nunu_crying` |
| keeps | `ju` |
| emote | `sweat` |

### `australia`
| Field | Value |
|---|---|
| id | `australia` |
| card_a | `nunu_crying` |
| card_b | `chester` |
| template | `merge` |
| result_card | `rearview_mirror` |
| keeps | `chester` |
| emote | `heart` |

### `to-atlanta`
| Field | Value |
|---|---|
| id | `to-atlanta` |
| card_a | `ju` |
| card_b | `rearview_mirror` |
| template | `merge` |
| result_card | `atlanta` |
| keeps | `ju, chester` |
| emote | `sweat` |

### `videocall`
| Field | Value |
|---|---|
| id | `videocall` |
| card_a | `ju` |
| card_b | `atlanta` |
| template | `additive` |
| spawns | `[video_call]` |
| keeps | `ju, atlanta` |
| emote | `ok` |

### `obradinn`
| Field | Value |
|---|---|
| id | `obradinn` |
| card_a | `video_call` |
| card_b | `chester` |
| template | `merge` |
| result_card | `obra_dinn` |
| keeps | `chester` |
| emote | `question` |

### `lights`
| Field | Value |
|---|---|
| id | `lights` |
| card_a | `video_call` |
| card_b | `ju` |
| template | `merge` |
| result_card | `lights_on` |
| keeps | `ju` |
| emote | `heart` |

### `surviving`
| Field | Value |
|---|---|
| id | `surviving` |
| card_a | `obra_dinn` |
| card_b | `lights_on` |
| template | `merge` |
| result_card | `surviving_distance` |
| keeps | — |
| emote | `spark` |

### `lonely`
| Field | Value |
|---|---|
| id | `lonely` |
| card_a | `atlanta` |
| card_b | `chester` |
| template | `merge` |
| result_card | `too_lonely` |
| keeps | `chester` |
| emote | `zzz` |

### `reunion`
| Field | Value |
|---|---|
| id | `reunion` |
| card_a | `surviving_distance` |
| card_b | `too_lonely` |
| template | `merge` |
| result_card | `reunion` |
| keeps | — |
| emote | `heart` |

### `courage-spawner` (generator template)
| Field | Value |
|---|---|
| id | `courage-spawner` |
| template | `generator` |
| spawn_card | `courage` |
| spawn_interval_sec | 5.0 |
| max_concurrent | 3 |
| visual_tag | `rabbit_jump` |
| active_from | scene start |

---

## 5. Win Condition (goal config in `assets/data/scenes/long-distance.json`)

| Field | Value |
|---|---|
| type | `spawn_trigger` |
| win_on_spawn | `reunion` |

> The scene completes the moment the `reunion` card is created — narratively
> the act of finally being back together. No status bar; the player progresses
> by working through the recipe chain, and arriving at the final card ends
> the scene.

---

## 6. Left Panel Content (status bars visible during the scene)

None. StatusBarUI stays Dormant for `spawn_trigger` goal type — no bar
renders. (The `connection` bar was removed 2026-04-28 after playtest
showed the recipe-chain progression itself was the satisfying loop;
adding a numeric pressure on top distracted from the narrative beats.)

---

## 7. Bar Effects (`assets/data/bar-effects.json` — recipe_id → bar deltas)

```json
{
  "brave-1":    { "connection": +5 },
  "brave-2":    { "connection": +10 },
  "confess":       { "connection": +25 },
  "fathers-spawn": { "connection": 0 },
  "at-door":       { "connection": +15 },
  "fathers":       { "connection": +20 },
  "nunu":          { "connection": +25 },
  "australia":  { "connection": +20 },
  "to-atlanta": { "connection": -5 },
  "videocall":  { "connection": +5 },
  "obradinn":   { "connection": +25 },
  "lights":     { "connection": +25 },
  "surviving":  { "connection": +30 },
  "lonely":     { "connection": -15 },
  "reunion":    { "connection": +40 }
}
```

> `to-atlanta` and `lonely` are intentionally negative — they represent the
> distance and the loneliness. Players must *go through* them, not avoid them.

---

## 8. Hint System (per-scene timing)

| Field | Value |
|---|---|
| stagnation_sec | 300 |
| level_1_cue | *(TBD — playtest first)* |
| level_2_cue | *(TBD — playtest first)* |

---

## 9. Audio Cues (recipe-triggered SFX + ambient)

| Event | SFX | Notes |
|---|---|---|
| Scene enter | ambient loop | *(TBD — 安靜、帶點思念的背景音、可能淡淡的鋼琴)* |
| `courage` spawn | soft chime | rabbit_jump 落地時的小聲音 |
| `confess` solve | special sting | 第一次大組合，要有重量 |
| `angry_daddy` spawn | low ominous note | 怒爸登場 |
| `angry_daddy` step | soft thump (×sway_period) | 每一步的腳步聲，搭配 ±10° 搖擺 |
| `angry_daddy` catches `ju` | sudden breath / impact | 抓到的瞬間 |
| `at-door` solve | tense breath | 我到了門口 |
| `fathers` solve | tense sting → silence | 不是悲傷，是凝重；之後留白 |
| `silent_decade` settles | none / muted hum | 它就靜靜在桌上 |
| `reunion` solve | warm release | 場景終局 |
| Scene completion | page-turn rustle | default handled by STUI |

---

## 10. Palette Override (Art Bible §4.2)

- `table_tint`: `#F4EEDE` (default Paper Warm)
- `bar_accent`: default

### 10.2 Ambient Background Plate

| Field | Value |
|---|---|
| `ambient.path` | `res://assets/ambient/long-distance.png` |
| `ambient.anchor` | `"full_viewport"` |
| `ambient.alpha` | `0.9` |

> Ambient art direction (LOCKED): two windows side by side — Ju 的早晨
> (台灣，柔和的晨光) / Chester 的夜晚 (亞特蘭大，深藍夜色)。Echoes the
> 「晚上十點視訊」 motif of crossing time zones.

---

## 11. Epilogue Handoff

| Field | Value |
|---|---|
| `next_scene` | `board-games` |
| On completion | `scene_completed` emits; advance to next scene |

### Interstitial Slides

```
interstitial:
  slides:
    - illustration: res://assets/epilogue/long-distance-1.png
      caption: "2020。終於回來了。"
      hold_ms: 4000
```

---

## 12. MUT Contribution (unlock tree)

- Recipes in this scene count toward `get_discovery_count()`: 15 discoveries
  (告白支線 3 + 那晚對峙支線 4 含 chase collision + 奴奴 1 + 澳洲 1 + 起飛 1 + 遠戀 4 + 低谷 1 + 重聚 1 = 16 if chase counts; using 15 to be conservative — chase is event, not recipe)
- Is this the `final-memory` scene? NO
- Required-for-epilogue? NO

---

## 13. Carry-Forward

- Cards that persist into `board-games`: `ju`, `chester`, `reunion`, `silent_decade`
- `silent_decade` carries forward to **all** subsequent scenes (board-games,
  germany, save-for-italy, italy, tenth-anniversary). Immovable in every scene
  until tenth-anniversary, where a final recipe resolves it.
- Cards consumed and gone: everything else (it's all in the past now)

---

## 14. STUI Transition Override

| Field | Value |
|---|---|
| fold_duration_scale | 1.0 |
| paper_tint | default |
| sfx_variant_id | default |

---

## 15. Scene-Level Constants / Open Questions

- `KNOWN_SCENE_IDS` 需新增 `"long-distance"`
- [ ] **More cards likely to be added after playtest** — current 17 cards / 15
      recipes + 1 spawner + 1 chase behavior; expect 2–4 more after playtest
- [ ] `lonely` 的負向設計需要 playtest 驗證 — 玩家會抗拒組合扣分的食譜嗎？
- [ ] `courage` spawn 5 秒間隔 + max 3 — 需要實機調整節奏
- [ ] Hint cues 等 playtest 後再寫 (level_1_cue / level_2_cue)
- [x] Ambient art direction: **兩扇窗並排** — Ju 的早晨 / Chester 的夜晚，
      呼應「晚上十點視訊」的時差母題

### Engine TRs introduced by this scene (NEW — block implementation)

**TR-LD-1: Card-level `draggable: false` flag**
- Card resource property; when false, card visual ignores pointer drag input
- Used by: `angry_daddy` (it walks autonomously), `silent_decade` (immovable)
- Engine: extend CardEntry with `draggable: bool = true`; CardVisual reads it

**TR-LD-2: ChaseBehavior visual component**
- New CardVisual behavior driven by these CardEntry fields:
  - `chase_target_card_id: String`
  - `move_speed_px_per_sec: float`
  - `sway_angle_deg: float` (rotation oscillation)
  - `sway_period_sec: float`
  - `on_catch: { consume_both: bool, spawn_card_id: String }`
- Each frame: lerp position toward target card; rotation = sin(t·2π/period) · angle
- On Area2D overlap with target: emit catch event → consume both → spawn output
- Catch event is **NOT** a recipe match — it bypasses RecipeDatabase
- New visual_tag value: `angry_walk`

**TR-LD-3: `rabbit_jump_fast` visual_tag variant**
- Faster / higher / wider drift version of `rabbit_jump`
- Used by: `ju_running`
- Engine: extend rabbit_jump with intensity parameter, OR new tag

**TR-LD-4: Cross-scene carry-forward for non-seed cards**
- `silent_decade` must persist in table state across all scenes from
  long-distance through tenth-anniversary
- CardEntry property: `carry_forward: Array[String]` (scene_ids it persists into)
- SceneManager: on scene transition, cards with carry_forward including the
  next scene_id are added to that scene's seed_state
- Tenth-anniversary scene gets a resolution recipe that consumes silent_decade

**TR-LD-5: Recipe `spawns` field can be used alongside `result_card`**
- The `fathers` recipe both produces `fathers_door` AND spawns `silent_decade`
- Confirm RecipeDatabase already supports this; if not, extend

---

## 16. Generated Files (what `/create-scene long-distance` produces / updates)

| File | Change type |
|---|---|
| `assets/data/cards.tres` | append 17 SubResources (excluding ju/chester) |
| `assets/data/recipes.tres` | append 15 SubResources + 1 generator |
| `assets/data/bar-effects.json` | add 15 keys |
| `assets/data/scenes/long-distance.json` | create |
| `assets/data/scene-manifest.tres` | extend `scene_ids` |
| `src/core/card_database.gd` | extend `KNOWN_SCENE_IDS` |
| `design/assets/specs/card-database-assets.md` | add 17 asset specs |
| `src/data/card_entry.gd` | extend with `draggable`, `carry_forward`, chase fields (TR-LD-1, 2, 4) |
| `src/gameplay/card_visual.gd` | implement ChaseBehavior + `rabbit_jump_fast` (TR-LD-2, 3) |
| `src/core/scene_manager.gd` | implement carry-forward (TR-LD-4) |

---

## 17. Validation Checklist

**Referential integrity**
- [ ] Every `seed_cards[*].card_id` exists in cards.tres
- [ ] Every recipe's `card_a` / `card_b` / `result_card` / `spawns` exists
- [ ] Every entry in a recipe's `keeps` array refers to `card_a` or `card_b`
- [ ] Every bar-effects key matches a recipe id
- [ ] Every bar_id in bar-effects is declared in the scene goal's `bars`

**Template well-formedness**
- [ ] All `template` values are lowercase
- [ ] `additive` recipes (`videocall`) have `spawns`
- [ ] `generator` recipe (`courage-spawner`) has `spawn_card`, `spawn_interval_sec`, `max_concurrent`

**Manifest + constants**
- [ ] Scene id is listed in `scene-manifest.tres`
- [ ] Scene id is in `KNOWN_SCENE_IDS`
- [ ] Scene JSON passes `python3 -m json.tool`

**Story integrity**
- [ ] `confession` only reachable via three-stage courage stacking
- [ ] `angry_daddy` only spawns via `fathers-spawn` recipe
- [ ] `ju_running` only spawns via chase collision (not a recipe)
- [ ] `fathers_door` only reachable via `at_her_door + chester`
- [ ] `silent_decade` spawns when `fathers` recipe fires
- [ ] `silent_decade` is `draggable: false` and has no recipes in this scene
- [ ] `nunu_crying` only reachable after `fathers_door`
- [ ] `reunion` requires both `surviving_distance` AND `too_lonely`

**Engine TR pre-checks (must be implemented before scene can run)**
- [ ] TR-LD-1: `CardEntry.draggable` field
- [ ] TR-LD-2: ChaseBehavior on CardVisual (chase + sway + catch)
- [ ] TR-LD-3: `rabbit_jump_fast` visual_tag variant
- [ ] TR-LD-4: `CardEntry.carry_forward` + SceneManager handoff
- [ ] TR-LD-5: Recipe can have both `result_card` AND `spawns`

---

## Feedback / Iteration Log

- 2026-04-27 — Template scaffolded, pending design details
- 2026-04-27 — Mechanics drafted: 14 cards, 13 recipes + 1 generator
  - Confession via 3-stage courage stacking (`rabbit_jump` spawner)
  - Fathers' door / nunu_crying capture the family rejection arc
  - `rearview_mirror` from real photo (澳洲 2015)
  - Negative-bar mechanic (`to-atlanta`, `lonely`) forces player through hardship
  - Win requires reaching 80 connection, typically via `surviving_distance` or `reunion`
- 2026-04-28 — `fathers_door` arc expanded into chase mechanic (Direction 4 + 5)
  - **+4 cards**: `angry_daddy`, `ju_running`, `at_her_door`, `silent_decade`
  - **+3 recipes**: `fathers-spawn`, `at-door`, `fathers` (revised to spawn silent_decade)
  - **New mechanic**: `angry_daddy` chases `ju` via ChaseBehavior (±10° sway, 30 px/sec)
    On collision: consumes both, spawns `ju_running` (rabbit_jump_fast)
  - **New mechanic**: `silent_decade` is immovable, no recipes, carry-forwards to all
    subsequent scenes; only resolved in tenth-anniversary
  - **5 new engine TRs flagged** (Section 15) — must implement before scene runs
  - Total: 17 new cards, 15 recipes + 1 generator + 1 chase behavior
- 2026-04-28 — Open questions triaged
  - Removed: 美國時期再加牌 (decided: no), confession_plaza note (already resolved),
    rearview_mirror art (production task, not design)
  - Locked: Ambient art = two windows side by side (Ju 的早晨 / Chester 的夜晚)
  - Deferred to playtest: hint cues, `lonely` negative-bar validation, courage spawn timing
