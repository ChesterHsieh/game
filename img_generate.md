
# Image Generation Prompts

這份文件是三個 `/img-*` skill 的 prompt 來源。
每個 skill 會讀取對應 section 並填入參數後呼叫 nano-banana MCP。

---

## 真實照片轉卡通 (`/img-cartoonize`)

用於把現實照片轉換成 Stacklands 風格的卡片素材。

**使用方式**：提供原始照片路徑，skill 會呼叫 `edit_image`。

**Prompt（填入後送出）**：
```
Convert this photo into a minimal cartoon card illustration in the style of the game Stacklands.

Style requirements:
- Single subject only, centered, all background removed
- Thick hand-drawn black outlines with rough crayon/pencil texture
- Exaggerated, slightly wobbly proportions
- Warm muted color palette only
- Naive children's-book aesthetic with paper texture
- Square composition

Negative: no background scenery, no strong color contrast,
no gradients, no shading, no realistic details,
no clean digital lines, no 3D rendering, no text or labels.
```

---

## 概念轉卡片圖 (`/img-card`)

用於從文字概念直接生成卡片圖，不需要原始照片。

**使用方式**：提供概念名稱（`{CONCEPT}`），skill 填入後呼叫 `generate_image`。

**Prompt（填入 `{CONCEPT}` 後送出）**：
```
A minimalist ink-wash card illustration in the style of the game Stacklands,
representing the concept of "{CONCEPT}".

Style requirements:
- Mostly MONOCHROME: soft grey ink on cream parchment, with at MOST one
  very muted earth-tone accent (faded sage, dusty ochre, or pale rust) —
  never saturated, never bright
- Thick hand-drawn black outlines with rough crayon/pencil texture
- Focus on the object or symbol itself — NO anthropomorphism: no faces,
  no eyes, no smiling, no arms, no legs on inanimate objects
- Slightly wobbly hand-drawn proportions, but restrained
- Single subject centered on cream paper texture
- Square composition

Negative: ABSOLUTELY no text, no letters, no Chinese characters, no
Japanese characters, no numbers, no labels, no watermarks, no signatures.
No saturated colors, no strong contrast, no bright palette, no gradients,
no shading, no realistic details, no clean digital lines, no 3D rendering,
no background scenery, no anthropomorphic features on objects.
```

---

## 概念產生背景圖 (`/img-background`)

用於生成場景的全螢幕羊皮紙背景板，四角裝飾暗示場景主題，中央留空供卡片放置。

**使用方式**：提供場景概念（`{SCENE_CONCEPT}`）和四角裝飾描述（`{CORNER_MOTIFS}`），skill 填入後呼叫 `generate_image`。

**Prompt（填入 `{SCENE_CONCEPT}` 和 `{CORNER_MOTIFS}` 後送出）**：
```
Ornamental parchment background plate for a card game — wide landscape
aspect ratio. Aged warm cream parchment paper texture as the base
(#F4EEDE with very subtle tonal variation, no gradients, no strong
color blocks). Fine-line ornamental filigree border frames the full
rectangle in thin warm brown ink — scrollwork, vine curls, leaves.
Decorative corner flourishes SUBTLY weave in abstracted {SCENE_CONCEPT}
concepts as stylized line-art hints only: {CORNER_MOTIFS}, all rendered
as if they are PART of the ornamental filigree itself, NOT placed as
separate objects. The center 70% of the image is completely empty cream
parchment with very subtle paper texture only — this is the gameplay
surface where cards will sit. Overall feeling: vintage recipe book title
plate, ornate but understated, like a tarot card back or medieval herbal
manuscript frontispiece. Ink is soft warm brown, never black, never
harsh.

NEGATIVE: text, letters, numbers, words, names, signatures, watermarks,
any center focal subject, literal objects placed in the middle, strong
color blocks, photographic realism, 3D render, perspective, deep shadows,
human figures, modern UI elements, busy loud patterns, gradient fills
in the center, heavy dark ink, anime, cyberpunk, neon, pixel art. The
center MUST remain empty parchment — if it is not empty the image fails.
```

**場景填入範例**：

| 場景 | `{SCENE_CONCEPT}` | `{CORNER_MOTIFS}` |
|---|---|---|
| coffee-intro | `kitchen-morning` | mortar-and-pestle (top-left), whisk curl (top-right), coffee beans / wheat stalk (bottom-left), steam curl (bottom-right) |
| drive | `car-road-trip` | steering wheel curl (top-left), map fold line (top-right), road sign silhouette (bottom-left), destination flag (bottom-right) |
