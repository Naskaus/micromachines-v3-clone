class_name PathUtils
extends RefCounted

# Figure-8 racing path: two tangent ovals.
# Top oval centered at (0, 0, -OVAL_H), bottom at (0, 0, +OVAL_H), tangent at z=0.
# Phase 0 → 0.5: traverse top oval CCW from south (=crossing).
# Phase 0.5 → 1: traverse bottom oval CW from north (=crossing).
# Tangent direction is continuous at the crossing (both go EAST).

const OVAL_A := 100.0
const OVAL_B := 50.0
const OVAL_H := 50.0  # so ovals touch at z=0
const TRACK_HALF_WIDTH := 6.0

# One full lap perimeter (rough Ramanujan approximation × 2 ovals)
const PATH_PERIMETER: float = 2.0 * 235.6  # ≈ 471 m

# Bridge over the crossing — first traversal of crossing per lap goes OVER, Y rises.
const BRIDGE_PHASE_START := 0.95   # ramp-up begins
const BRIDGE_PHASE_END   := 0.05   # ramp-down ends (wraps past 0)
const BRIDGE_HEIGHT      := 5.0    # peak Y in metres at phase=0


# Returns Y offset due to the bridge over the crossing.
# Smooth half-cosine ramp from 0 at phase=0.95 → BRIDGE_HEIGHT at phase=0.0 → 0 at phase=0.05.
static func bridge_y(phase: float) -> float:
	phase = wrapf(phase, 0.0, 1.0)
	var in_window: bool = phase >= BRIDGE_PHASE_START or phase <= BRIDGE_PHASE_END
	if not in_window:
		return 0.0
	# Map phase to t ∈ [0, 1] across the bridge window
	var t: float
	if phase >= BRIDGE_PHASE_START:
		t = (phase - BRIDGE_PHASE_START) / (1.0 - BRIDGE_PHASE_START + BRIDGE_PHASE_END)
	else:
		t = (1.0 - BRIDGE_PHASE_START + phase) / (1.0 - BRIDGE_PHASE_START + BRIDGE_PHASE_END)
	# Half-cosine: 0 → 1 → 0
	return BRIDGE_HEIGHT * 0.5 * (1.0 - cos(t * TAU))


# Returns the world position on the figure-8 racing line at parametric phase [0, 1).
static func path_at(phase: float) -> Vector3:
	phase = wrapf(phase, 0.0, 1.0)
	if phase < 0.5:
		# Top oval CCW from south (crossing is at phase=0).
		# Y rises here on the bridge window; bottom oval crosses at phase=0.5 (NOT in window) so it stays flat at Y=0.
		var t: float = phase / 0.5
		var angle: float = PI * 0.5 - t * TAU
		return Vector3(OVAL_A * cos(angle), bridge_y(phase), -OVAL_H + OVAL_B * sin(angle))
	else:
		# Bottom oval CW from north (crossing is at phase=0.5)
		var t: float = (phase - 0.5) / 0.5
		var angle: float = -PI * 0.5 + t * TAU
		return Vector3(OVAL_A * cos(angle), 0.0, OVAL_H + OVAL_B * sin(angle))


# Tangent direction (unit vector) at the given phase
static func tangent_at(phase: float) -> Vector3:
	var dt: float = 0.001
	var v: Vector3 = path_at(phase + dt) - path_at(phase - dt)
	v.y = 0.0
	if v.length() < 0.0001:
		return Vector3(1, 0, 0)
	return v.normalized()


# Best-guess phase for a given XZ world position. For a figure-8 there can be 2 valid phases
# (the two ovals overlap in x∈[-100, 100]); we pick the closer-fit oval.
static func phase_from_position(pos: Vector3) -> float:
	# Distance to top oval center vs bottom oval center
	var d_top: float = abs(pos.z + OVAL_H)
	var d_bot: float = abs(pos.z - OVAL_H)
	if d_top <= d_bot:
		# Closer to top oval
		var angle: float = atan2((pos.z + OVAL_H) / OVAL_B, pos.x / OVAL_A)
		# Phase: starts at south (angle=π/2) and goes CCW (angle decreases)
		var t: float = wrapf((PI * 0.5 - angle) / TAU, 0.0, 1.0)
		return t * 0.5  # top oval = first half
	else:
		# Closer to bottom oval
		var angle: float = atan2((pos.z - OVAL_H) / OVAL_B, pos.x / OVAL_A)
		# Bottom oval CW from north (angle starts at -π/2 and increases)
		var t: float = wrapf((angle + PI * 0.5) / TAU, 0.0, 1.0)
		return 0.5 + t * 0.5
