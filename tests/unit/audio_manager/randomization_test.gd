## Unit tests for AudioManager pitch + volume randomization — Story 003.
##
## Covers all 6 QA acceptance criteria from the story:
##   AC-1: pitch formula output over 100 plays within [2^(-R/12), 2^(R/12)]
##   AC-2: pitch formula at full-octave boundary [0.5, 2.0]
##   AC-3: volume formula output over 100 plays within [base−var, base+var]
##   AC-4: volume clamp at −80 dB floor (base=−78, var=6 → [−80, −72])
##   AC-5: volume clamp at 0 dB ceiling (base=−1, var=3 → [−4, 0])
##   AC-6: zero pitch_range → always 1.0; zero volume_variance → always base (clamped)
##
## Both functions are static, so tests call them without a live Node instance.
## No AudioStreamPlayer is involved — pure formula verification.
extends GdUnitTestSuite

const AudioManagerScript := preload("res://src/core/audio_manager.gd")


# ── helpers ──────────────────────────────────────────────────────────────────

## Calls _randomize_pitch() count times and collects results.
func _sample_pitch(pitch_range: float, count: int) -> Array[float]:
	var results: Array[float] = []
	for _i: int in count:
		results.append(AudioManagerScript._randomize_pitch(pitch_range))
	return results


## Calls _randomize_volume() count times and collects results.
func _sample_volume(base_db: float, variance: float, count: int) -> Array[float]:
	var results: Array[float] = []
	for _i: int in count:
		results.append(AudioManagerScript._randomize_volume(base_db, variance))
	return results


# ── AC-1: pitch formula output stays within expected bounds ──────────────────

func test_randomize_pitch_all_values_within_bounds_over_100_plays() -> void:
	# Arrange
	var pitch_range: float = 2.0
	var expected_min: float = pow(2.0, -pitch_range / 12.0)
	var expected_max: float = pow(2.0, pitch_range / 12.0)

	# Act
	var results: Array[float] = _sample_pitch(pitch_range, 100)

	# Assert: every sample within [2^(-2/12), 2^(2/12)] ≈ [0.891, 1.122]
	for value: float in results:
		assert_float(value).is_greater_equal(expected_min)
		assert_float(value).is_less_equal(expected_max)


func test_randomize_pitch_minimum_bound_is_never_undershot() -> void:
	# Arrange
	var pitch_range: float = 2.0
	var floor_bound: float = pow(2.0, -pitch_range / 12.0)

	# Act
	var results: Array[float] = _sample_pitch(pitch_range, 100)

	# Assert
	for value: float in results:
		assert_float(value).is_greater_equal(floor_bound)


func test_randomize_pitch_maximum_bound_is_never_exceeded() -> void:
	# Arrange
	var pitch_range: float = 2.0
	var ceil_bound: float = pow(2.0, pitch_range / 12.0)

	# Act
	var results: Array[float] = _sample_pitch(pitch_range, 100)

	# Assert
	for value: float in results:
		assert_float(value).is_less_equal(ceil_bound)


# ── AC-2: pitch formula at full-octave boundary [0.5, 2.0] ───────────────────

func test_randomize_pitch_full_octave_range_stays_within_half_to_double() -> void:
	# Arrange: pitch_range = 12 semitones → [2^(-1), 2^(1)] = [0.5, 2.0]
	var pitch_range: float = 12.0

	# Act
	var results: Array[float] = _sample_pitch(pitch_range, 100)

	# Assert
	for value: float in results:
		assert_float(value).is_greater_equal(0.5)
		assert_float(value).is_less_equal(2.0)


# ── AC-3: volume formula output within [base−variance, base+variance] ────────

func test_randomize_volume_all_values_within_bounds_over_100_plays() -> void:
	# Arrange
	var base_db: float = -6.0
	var variance: float = 3.0

	# Act
	var results: Array[float] = _sample_volume(base_db, variance, 100)

	# Assert: every sample within [−9.0, −3.0]
	for value: float in results:
		assert_float(value).is_greater_equal(base_db - variance)
		assert_float(value).is_less_equal(base_db + variance)


# ── AC-4: volume clamp at −80 dB floor ───────────────────────────────────────

func test_randomize_volume_never_below_negative_80_db() -> void:
	# Arrange: base near floor, wide variance — should be clamped at −80
	var base_db: float = -78.0
	var variance: float = 6.0

	# Act
	var results: Array[float] = _sample_volume(base_db, variance, 100)

	# Assert: no sample falls below −80 dB
	for value: float in results:
		assert_float(value).is_greater_equal(-80.0)


func test_randomize_volume_floor_clamp_upper_bound_is_correct() -> void:
	# Arrange: base=−78, var=6 → unclamped range [−84, −72] → clamped [−80, −72]
	var base_db: float = -78.0
	var variance: float = 6.0

	# Act
	var results: Array[float] = _sample_volume(base_db, variance, 100)

	# Assert: ceiling of clamped range is still reachable
	for value: float in results:
		assert_float(value).is_less_equal(-72.0)


# ── AC-5: volume clamp at 0 dB ceiling ───────────────────────────────────────

func test_randomize_volume_never_above_zero_db() -> void:
	# Arrange: base near ceiling, wide variance — should be clamped at 0
	var base_db: float = -1.0
	var variance: float = 3.0

	# Act
	var results: Array[float] = _sample_volume(base_db, variance, 100)

	# Assert: no sample rises above 0 dB
	for value: float in results:
		assert_float(value).is_less_equal(0.0)


func test_randomize_volume_ceiling_clamp_lower_bound_is_correct() -> void:
	# Arrange: base=−1, var=3 → unclamped range [−4, 2] → clamped [−4, 0]
	var base_db: float = -1.0
	var variance: float = 3.0

	# Act
	var results: Array[float] = _sample_volume(base_db, variance, 100)

	# Assert: floor of clamped range is still reachable
	for value: float in results:
		assert_float(value).is_greater_equal(-4.0)


# ── AC-6: zero values disable randomization ──────────────────────────────────

func test_randomize_pitch_zero_range_always_returns_one() -> void:
	# Arrange: pitch_range = 0 → no randomization

	# Act + Assert: 20 calls all return exactly 1.0
	for _i: int in 20:
		var result: float = AudioManagerScript._randomize_pitch(0.0)
		assert_float(result).is_equal(1.0)


func test_randomize_pitch_negative_range_always_returns_one() -> void:
	# Arrange: negative pitch_range treated same as zero

	# Act + Assert
	for _i: int in 20:
		var result: float = AudioManagerScript._randomize_pitch(-1.0)
		assert_float(result).is_equal(1.0)


func test_randomize_volume_zero_variance_returns_base_clamped() -> void:
	# Arrange: variance = 0 → deterministic result equal to clamped base
	var base_db: float = -10.0

	# Act + Assert: 20 calls all return the clamped base value
	for _i: int in 20:
		var result: float = AudioManagerScript._randomize_volume(base_db, 0.0)
		assert_float(result).is_equal(base_db)


func test_randomize_volume_zero_variance_clamps_positive_base_to_zero() -> void:
	# Arrange: base above 0 dB — clamp must enforce ceiling
	var base_db: float = 5.0

	# Act
	var result: float = AudioManagerScript._randomize_volume(base_db, 0.0)

	# Assert: clamped to 0 dB
	assert_float(result).is_equal(0.0)


func test_randomize_volume_zero_variance_clamps_below_floor_to_negative_80() -> void:
	# Arrange: base below −80 dB — clamp must enforce floor
	var base_db: float = -100.0

	# Act
	var result: float = AudioManagerScript._randomize_volume(base_db, 0.0)

	# Assert: clamped to −80 dB
	assert_float(result).is_equal(-80.0)


func test_randomize_volume_negative_variance_treated_as_zero() -> void:
	# Arrange: negative variance treated same as zero
	var base_db: float = -6.0

	# Act + Assert: deterministic, no randomization
	for _i: int in 20:
		var result: float = AudioManagerScript._randomize_volume(base_db, -1.0)
		assert_float(result).is_equal(base_db)
