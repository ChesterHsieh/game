## AudioConfig — typed Resource holding all audio event definitions, music
## crossfade settings, and SFX pool configuration for AudioManager.
##
## This is a data-shape class per ADR-005 §2. No methods beyond engine getters.
## Loaded by AudioManager at startup via ResourceLoader.load() as AudioConfig.
##
## Story 008 seeds the .tres file with actual event data. This class defines
## the schema that Stories 002–007 build on.
##
## Usage:
##   var cfg: AudioConfig = ResourceLoader.load(path) as AudioConfig
##   if cfg == null: push_error(...)
class_name AudioConfig extends Resource

## Crossfade duration in seconds for music transitions.
## Range: [0.1, 5.0] — below 0.1 is jarring, above 5.0 feels sluggish.
@export_range(0.1, 5.0, 0.1) var crossfade_duration: float = 2.0

## Default music volume in dB. Applied to the Music bus at startup.
## Range: [−80, 0].
@export_range(-80.0, 0.0, 0.5) var music_volume_db: float = -12.0

## Number of SFX pool nodes to allocate. Range: [4, 16].
@export_range(4, 16, 1) var sfx_pool_size: int = 8

## SFX event configurations keyed by event name.
## Each value is a Dictionary with keys:
##   stream_paths: Array[String]   — one or more res:// paths (variants)
##   base_volume_db: float         — base volume in dB [−80, 0]
##   volume_variance: float        — max dB deviation [0, 6]
##   pitch_range: float            — semitone variance [0, 12]
##   cooldown_ms: int              — minimum ms between plays [0, 5000]
## Story 008 populates this with the full event table.
@export var sfx_events: Dictionary = {}

## Music track paths keyed by scene_id.
## Value is a res:// path to an .ogg file. Empty string = no music for scene.
## Story 006 reads this when handling scene_loading signals.
@export var music_tracks: Dictionary = {}
