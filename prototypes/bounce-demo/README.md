# bounce-demo

Two sub-demos validating card animation and emote visuals.

## Sub-demos

### 1. bounce_demo.tscn — rabbit_jump 跳躍動畫
**Hypothesis**: Node2D parent + tween on position gives correct arc with child nodes following.  
**Status**: Concluded — validated. Pattern adopted in Card Visual system.

### 2. emote_demo.tscn — Kenney Emotes Pack 平替驗證
**Hypothesis**: Kenney emotes-pack (CC0, pixel style 1) can replace custom emote PNGs with identical filenames and no code changes.

**How to run**:
1. Open Godot 4.3
2. Set main scene to `res://prototypes/bounce-demo/emote_demo.tscn`
3. Run (F5) — 8 cards each cycling their emote bubble continuously
4. Press any key to replay all animations

**Asset mapping** (Kenney pixel_style1.png tilesheet, tile index):

| Emote name | Tile idx | Visual |
|---|---|---|
| heart | 5 | 紅心 |
| spark | 16 | 橘色光芒 |
| ok | 13 | 笑臉 |
| anger | 15 | 憤怒眉 |
| question | 9 | 問號 |
| exclaim | 8 | 驚嘆號 |
| sweat | 12 | 汗滴 |
| zzz | 11 | ZZ |

PNGs cut from tilesheet at 16×16, scaled to 80×80 (NEAREST filter), saved to `emotes/`.

**Status**: In-progress

**Findings** (update after validation):
- [ ] Pixel art style fits Moments visual direction?
- [ ] 80×80 size readable at game resolution?
- [ ] Pop-in animation feels right with Kenney art?
- [ ] Any emotes that need better tile selection?
