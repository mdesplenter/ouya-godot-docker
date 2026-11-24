extends Node2D

# Virtual Controller - Godot 2.1 (Godot-for-OUYA) port of the OUYA SDK example
# https://github.com/mdesplenter/ouya-sdk-examples/tree/master/Html5/VirtualController
#
# Shows up to 4 controllers. Every pressed button or moved stick lights up the
# matching layer of the controller image, and the raw values are printed below it.
#
# Godot-for-OUYA has a built-in mapping for "OUYA Game Controller", so the OUYA
# buttons arrive as Godot's standard JOY_* constants:
#   O = JOY_BUTTON_0   U = JOY_BUTTON_2   Y = JOY_BUTTON_3   A = JOY_BUTTON_1
#   L1/R1 = JOY_L/JOY_R  L2/R2 = JOY_L2/JOY_R2 (+ axis 6/7 at 0 or 1)
#   L3/R3 = JOY_L3/JOY_R3  D-pad = JOY_DPAD_*  MENU = JOY_START
#   left stick = axis 0/1, right stick = axis 2/3
# The same constants work for XInput pads on Windows, so it also runs on the PC.

const MAX_CONTROLLERS = 4
const SIZE = 336                 # all controller images are 336x336 layers
const AXIS_SCALER = 4.0          # how far a stick image moves (pixels), as in the SDK example
const STICK_ANGLE = 135.0        # the controller image is drawn at an angle; rotate stick input to match
const DEAD_ZONE = 0.25
const MENU_HOLD = 1.0            # the OUYA sends MENU down+up at once; keep it lit for 1 second
const BACKGROUND = Color(0.392, 0.584, 0.929)   # CornflowerBlue, as in the SDK example

# --- OUYA controller mapping -------------------------------------------------
# Godot-for-OUYA numbers a controller's axes by sorting Android's motion ranges,
# so the raw axis numbers depend on what the controller/firmware reports. Its
# built-in mapping uses rightx:a6, righty:a7, which on some consoles is one axis
# off (right stick up/down shows as left/right, left/right does nothing).
# Fix it by setting the right stick's raw axes below. Find the right numbers in
# RAW MODE: hold L1 + R1 and press Y (same again to go back).
const OUYA_GUID = "4f5559412047616d6520436f6e74726f"   # "OUYA Game Contro" in hex
const OUYA_RIGHT_X = 5    # built-in mapping: 6
const OUYA_RIGHT_Y = 6    # built-in mapping: 7

const RAW_AXES = 14
const RAW_BUTTONS = 35
var raw_mode = false
var raw_label

# top-left corner of each controller image on the 1280x720 screen (2x2 grid)
const ORIGINS = [Vector2(152, 0), Vector2(792, 0), Vector2(152, 360), Vector2(792, 360)]

var tex = {
	"controller": preload("res://controller/controller.png"),
	"o": preload("res://controller/o.png"),
	"u": preload("res://controller/u.png"),
	"y": preload("res://controller/y.png"),
	"a": preload("res://controller/a.png"),
	"lb": preload("res://controller/lb.png"),
	"rb": preload("res://controller/rb.png"),
	"lt": preload("res://controller/lt.png"),
	"rt": preload("res://controller/rt.png"),
	"dpad_up": preload("res://controller/dpad_up.png"),
	"dpad_down": preload("res://controller/dpad_down.png"),
	"dpad_left": preload("res://controller/dpad_left.png"),
	"dpad_right": preload("res://controller/dpad_right.png"),
	"menu": preload("res://controller/menu.png"),
	"l_stick": preload("res://controller/l_stick.png"),
	"r_stick": preload("res://controller/r_stick.png"),
	"thumbl": preload("res://controller/thumbl.png"),
	"thumbr": preload("res://controller/thumbr.png")
}

var states = []       # current state per controller (Dictionary)
var last_states = []  # state that was last drawn, to redraw only on change
var menu_timer = []
var labels = []
var stick_cos
var stick_sin

func ouya_mapping():
	return OUYA_GUID + ",OUYA Game Controller,leftx:a1,lefty:a3,rightx:a" + str(OUYA_RIGHT_X) + ",righty:a" + str(OUYA_RIGHT_Y) + ",dpdown:b12,rightstick:b8,rightshoulder:b10,start:b-86,dpleft:b13,lefttrigger:b15,x:b2,dpup:b11,leftstick:b7,leftshoulder:b9,y:b3,a:b0,dpright:b14,righttrigger:b16,b:b1,"

func _ready():
	var radians = deg2rad(STICK_ANGLE)
	stick_cos = cos(radians)
	stick_sin = sin(radians)
	for p in range(MAX_CONTROLLERS):
		states.append({})
		last_states.append(null)
		menu_timer.append(0.0)
		var label = Label.new()
		label.set_pos(ORIGINS[p] + Vector2(0, 292))
		label.set_size(Vector2(SIZE, 40))
		label.set_align(Label.ALIGN_CENTER)
		add_child(label)
		labels.append(label)
	raw_label = Label.new()
	raw_label.set_pos(Vector2(40, 30))
	raw_label.set_size(Vector2(1200, 660))
	raw_label.hide()
	add_child(raw_label)
	Input.add_joy_mapping(ouya_mapping(), true)
	set_process(true)
	set_process_input(true)

func _input(ev):
	# MENU comes as a press and release in the same frame, so polling would miss it
	if ev.type == InputEvent.JOYSTICK_BUTTON and ev.pressed and ev.button_index == JOY_START:
		if ev.device < MAX_CONTROLLERS:
			menu_timer[ev.device] = MENU_HOLD
	elif ev.type == InputEvent.KEY and ev.pressed and ev.scancode == KEY_MENU:
		# if the console delivers MENU as a key instead of a joystick button
		menu_timer[0] = MENU_HOLD
	if ev.type == InputEvent.JOYSTICK_BUTTON and ev.pressed:
		print("device ", ev.device, " button ", ev.button_index)
		# L1 + R1 + Y toggles raw mode (raw L1/R1 are 9/10, mapped they are JOY_L/JOY_R; Y is 3 in both)
		if ev.button_index == 3:
			var l1 = JOY_L
			var r1 = JOY_R
			if raw_mode:
				l1 = 9
				r1 = 10
			if Input.is_joy_button_pressed(ev.device, l1) and Input.is_joy_button_pressed(ev.device, r1):
				_set_raw_mode(not raw_mode)

func _set_raw_mode(on):
	raw_mode = on
	if on:
		# without a mapping Godot passes the raw Android button and axis numbers through
		Input.remove_joy_mapping(OUYA_GUID)
		raw_label.show()
	else:
		Input.add_joy_mapping(ouya_mapping(), true)
		raw_label.hide()
		for p in range(MAX_CONTROLLERS):
			last_states[p] = null
	for label in labels:
		label.set_hidden(on)
	update()

func _process_raw():
	var t = "RAW MODE  (L1 + R1 + Y = back)\n"
	t += "Move one stick or trigger at a time and see which axis changes.\n"
	t += "Then set OUYA_RIGHT_X / OUYA_RIGHT_Y at the top of main.gd.\n"
	for p in range(MAX_CONTROLLERS):
		var jname = Input.get_joy_name(p)
		if jname == "":
			continue
		t += "\nP" + str(p + 1) + "  " + jname + "  " + Input.get_joy_guid(p) + "\n"
		for i in range(RAW_AXES):
			t += "a" + str(i) + " " + _fmt(Input.get_joy_axis(p, i)) + "    "
			if i == 6:
				t += "\n"
		t += "\nbuttons:"
		for b in range(RAW_BUTTONS):
			if Input.is_joy_button_pressed(p, b):
				t += " b" + str(b)
		t += "\n"
	if t != raw_label.get_text():
		raw_label.set_text(t)

func _process(delta):
	if raw_mode:
		_process_raw()
		return
	var changed = false
	for p in range(MAX_CONTROLLERS):
		menu_timer[p] = max(0.0, menu_timer[p] - delta)
		states[p] = _read_state(p)
		if str(states[p]) != str(last_states[p]):
			last_states[p] = states[p]
			_update_label(p)
			changed = true
	if changed:
		update()

func _read_state(p):
	var s = {}
	s["name"] = Input.get_joy_name(p)
	s["o"] = Input.is_joy_button_pressed(p, JOY_BUTTON_0)
	s["a"] = Input.is_joy_button_pressed(p, JOY_BUTTON_1)
	s["u"] = Input.is_joy_button_pressed(p, JOY_BUTTON_2)
	s["y"] = Input.is_joy_button_pressed(p, JOY_BUTTON_3)
	s["l1"] = Input.is_joy_button_pressed(p, JOY_L)
	s["r1"] = Input.is_joy_button_pressed(p, JOY_R)
	s["l3"] = Input.is_joy_button_pressed(p, JOY_L3)
	s["r3"] = Input.is_joy_button_pressed(p, JOY_R3)
	s["up"] = Input.is_joy_button_pressed(p, JOY_DPAD_UP)
	s["down"] = Input.is_joy_button_pressed(p, JOY_DPAD_DOWN)
	s["left"] = Input.is_joy_button_pressed(p, JOY_DPAD_LEFT)
	s["right"] = Input.is_joy_button_pressed(p, JOY_DPAD_RIGHT)
	s["menu"] = menu_timer[p] > 0.0 or Input.is_joy_button_pressed(p, JOY_START)
	s["lx"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_0_X), 0.01)
	s["ly"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_0_Y), 0.01)
	s["rx"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_1_X), 0.01)
	s["ry"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_1_Y), 0.01)
	s["l2"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_L2), 0.01)
	s["r2"] = stepify(Input.get_joy_axis(p, JOY_ANALOG_R2), 0.01)
	# the OUYA triggers come in as buttons (axis 6/7 are then 0 or 1)
	if Input.is_joy_button_pressed(p, JOY_L2):
		s["l2"] = 1.0
	if Input.is_joy_button_pressed(p, JOY_R2):
		s["r2"] = 1.0
	return s

func _update_label(p):
	var s = states[p]
	var title = "P" + str(p + 1) + "  "
	if s["name"] == "":
		title += "(not connected)"
	else:
		title += s["name"]
	labels[p].set_text(title + "\nLS " + _fmt(s["lx"]) + " " + _fmt(s["ly"]) + "   RS " + _fmt(s["rx"]) + " " + _fmt(s["ry"]) + "   L2 " + _fmt(s["l2"]) + "  R2 " + _fmt(s["r2"]))

func _fmt(v):
	var t = str(stepify(v, 0.01))
	if v >= 0:
		t = "+" + t
	return t

func _draw():
	draw_rect(get_viewport_rect(), BACKGROUND)
	if raw_mode:
		return
	for p in range(MAX_CONTROLLERS):
		_draw_controller(p, ORIGINS[p])

func _layer(name, pos):
	draw_texture(tex[name], pos)

func _stick_offset(x, y):
	return Vector2(x * stick_cos - y * stick_sin, x * stick_sin + y * stick_cos) * AXIS_SCALER

func _draw_controller(p, pos):
	var s = states[p]
	if s.empty():
		return
	_layer("controller", pos)
	if s["a"]:
		_layer("a", pos)
	if s["down"]:
		_layer("dpad_down", pos)
	if s["left"]:
		_layer("dpad_left", pos)
	if s["right"]:
		_layer("dpad_right", pos)
	if s["up"]:
		_layer("dpad_up", pos)
	if s["l1"]:
		_layer("lb", pos)
	if s["l2"] > DEAD_ZONE:
		_layer("lt", pos)
	var lpos = pos + _stick_offset(s["lx"], s["ly"])
	if s["l3"]:
		_layer("thumbl", lpos)
	else:
		_layer("l_stick", lpos)
	if s["menu"]:
		_layer("menu", pos)
	if s["o"]:
		_layer("o", pos)
	if s["r1"]:
		_layer("rb", pos)
	if s["r2"] > DEAD_ZONE:
		_layer("rt", pos)
	var rpos = pos + _stick_offset(s["rx"], s["ry"])
	if s["r3"]:
		_layer("thumbr", rpos)
	else:
		_layer("r_stick", rpos)
	if s["u"]:
		_layer("u", pos)
	if s["y"]:
		_layer("y", pos)
