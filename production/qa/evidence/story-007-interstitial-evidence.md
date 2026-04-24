# Story 007 — Interstitial Illustration: Test Evidence

**Story**: production/epics/scene-transition-ui/story-007-interstitial-illustration.md
**Type**: Integration (with Visual/Feel component)
**Status**: Not yet collected

## Required walkthrough

### AC-2: Interstitial sequences correctly (normal path)
- [ ] Screenshot: illustration + caption visible during HOLDING
- [ ] Notes: timing ~400ms fade-in → hold → ~400ms fade-out → FADING_IN begins

### AC-3: No config → behaviour unchanged
- [ ] Notes/video: scene without interstitial key transitions identically to pre-Story-007

### AC-5: Reduced-motion path
- [ ] Settings: `stui/reduced_motion_default = true`
- [ ] Notes: panel shows instantly, holds, hides instantly (no fade Tween observed)

### AC-6: Early scene_started cuts interstitial short
- [ ] Notes: configure `hold_ms: 5000.0`, fire scene_started early, verify panel hides and FADING_IN begins within one frame

### AC-7: No interstitial during epilogue
- [ ] Notes: configure epilogue scene with interstitial key, verify panel stays invisible

## Sign-off
- [ ] Lead sign-off (date, name): __________
