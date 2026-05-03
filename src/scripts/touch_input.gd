extends Node

# Mobile / web touch input — split-screen virtual controls.
# Touch left half of screen → p1_left, right half → p1_right.
# Listens at scene root level via _input(); no UI to manage.

var _left_active: bool = false
var _right_active: bool = false


func _ready() -> void:
	var is_touch_platform: bool = OS.has_feature("mobile") or OS.has_feature("web")
	if not is_touch_platform:
		queue_free()
		return


func _ui_is_capturing() -> bool:
	# If any UI Control currently has keyboard focus (e.g. the join-code
	# LineEdit), we MUST NOT translate the tap into a virtual driving button.
	# Otherwise the tap that opens the on-screen keyboard would also press
	# p1_left and the menu would feel broken.
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	var focused: Control = vp.gui_get_focus_owner()
	return focused != null


func _unhandled_input(event: InputEvent) -> void:
	# We use _unhandled_input here (not _input) so taps that hit a Button or
	# LineEdit are consumed by the GUI first and never reach the driving
	# pseudo-buttons. This is what stops the menu from feeling possessed.
	if _ui_is_capturing():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var screen_w: float = float(get_viewport().get_visible_rect().size.x)
		var is_left_half: bool = touch.position.x < screen_w * 0.5
		if touch.pressed:
			if is_left_half and not _left_active:
				Input.action_press("p1_left")
				_left_active = true
			elif not is_left_half and not _right_active:
				Input.action_press("p1_right")
				_right_active = true
		else:
			# Released — release whichever side this finger was on
			if is_left_half and _left_active:
				Input.action_release("p1_left")
				_left_active = false
			elif not is_left_half and _right_active:
				Input.action_release("p1_right")
				_right_active = false
	elif event is InputEventScreenDrag:
		# Allow dragging from one half to the other (tap-and-slide)
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var screen_w: float = float(get_viewport().get_visible_rect().size.x)
		var is_left_half: bool = drag.position.x < screen_w * 0.5
		if is_left_half:
			if _right_active:
				Input.action_release("p1_right")
				_right_active = false
			if not _left_active:
				Input.action_press("p1_left")
				_left_active = true
		else:
			if _left_active:
				Input.action_release("p1_left")
				_left_active = false
			if not _right_active:
				Input.action_press("p1_right")
				_right_active = true
