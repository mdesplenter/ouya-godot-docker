extends Node2D

# Starter scene: shows which OUYA controller buttons / axes Godot sees,
# so you can build your input map from real values.

# --- OUYA controller mapping -------------------------------------------------
# Godot-for-OUYA's built-in mapping has the right stick one axis off on some
# consoles. This replaces it, so the OUYA buttons and sticks arrive as Godot's
# standard JOY_* constants (see HOWTO.md section 7):
#   O = JOY_BUTTON_0   A = JOY_BUTTON_1   U = JOY_BUTTON_2   Y = JOY_BUTTON_3
#   L1/R1 = JOY_L/JOY_R   L3/R3 = JOY_L3/JOY_R3   D-pad = JOY_DPAD_*   MENU = JOY_START
#   left stick = JOY_ANALOG_0_X/_Y, right stick = JOY_ANALOG_1_X/_Y
# If the right stick is wrong on your console, check the raw numbers with RAW MODE
# in games\virtual-controller (hold L1 + R1 and press Y).
const OUYA_GUID = "4f5559412047616d6520436f6e74726f"   # "OUYA Game Contro" in hex
const OUYA_RIGHT_X = 5    # built-in mapping: 6
const OUYA_RIGHT_Y = 6    # built-in mapping: 7

func ouya_mapping():
	return OUYA_GUID + ",OUYA Game Controller,leftx:a1,lefty:a3,rightx:a" + str(OUYA_RIGHT_X) + ",righty:a" + str(OUYA_RIGHT_Y) + ",dpdown:b12,rightstick:b8,rightshoulder:b10,start:b-86,dpleft:b13,lefttrigger:b15,x:b2,dpup:b11,leftstick:b7,leftshoulder:b9,y:b3,a:b0,dpright:b14,righttrigger:b16,b:b1,"

# OUYA names for the mapped buttons and axes, to show on screen
var button_names = {
	JOY_BUTTON_0: "O", JOY_BUTTON_1: "A", JOY_BUTTON_2: "U", JOY_BUTTON_3: "Y",
	JOY_L: "L1", JOY_R: "R1", JOY_L2: "L2", JOY_R2: "R2", JOY_L3: "L3", JOY_R3: "R3",
	JOY_DPAD_UP: "D-pad up", JOY_DPAD_DOWN: "D-pad down",
	JOY_DPAD_LEFT: "D-pad left", JOY_DPAD_RIGHT: "D-pad right", JOY_START: "MENU"}
var axis_names = {
	JOY_ANALOG_0_X: "left stick X", JOY_ANALOG_0_Y: "left stick Y",
	JOY_ANALOG_1_X: "right stick X", JOY_ANALOG_1_Y: "right stick Y",
	JOY_ANALOG_L2: "L2", JOY_ANALOG_R2: "R2"}

var label

func _ready():
	Input.add_joy_mapping(ouya_mapping(), true)

	label = Label.new()
	label.set_pos(Vector2(60, 60))
	label.set_scale(Vector2(2, 2))
	label.set_text("Hello OUYA!\nPress a controller button...")
	add_child(label)
	set_process_input(true)

func _input(event):
	if event.type == InputEvent.JOYSTICK_BUTTON and event.pressed:
		var what = "?"
		if button_names.has(event.button_index):
			what = button_names[event.button_index]
		label.set_text("Device %d  button %d  (%s)" % [event.device, event.button_index, what])
	elif event.type == InputEvent.JOYSTICK_MOTION and abs(event.value) > 0.5:
		var what = "?"
		if axis_names.has(event.axis):
			what = axis_names[event.axis]
		label.set_text("Device %d  axis %d  (%s)  value %.2f" % [event.device, event.axis, what, event.value])
	elif event.type == InputEvent.KEY and event.pressed:
		label.set_text("Key scancode %d" % event.scancode)
