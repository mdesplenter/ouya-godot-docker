extends Node2D

# Starter scene: shows which OUYA controller buttons / axes Godot sees,
# so you can build your input map from real values.

var label

func _ready():
	label = Label.new()
	label.set_pos(Vector2(60, 60))
	label.set_scale(Vector2(2, 2))
	label.set_text("Hello OUYA!\nPress a controller button...")
	add_child(label)
	set_process_input(true)

func _input(event):
	if event.type == InputEvent.JOYSTICK_BUTTON and event.pressed:
		label.set_text("Device %d  button %d" % [event.device, event.button_index])
	elif event.type == InputEvent.JOYSTICK_MOTION and abs(event.value) > 0.5:
		label.set_text("Device %d  axis %d  value %.2f" % [event.device, event.axis, event.value])
	elif event.type == InputEvent.KEY and event.pressed:
		label.set_text("Key scancode %d" % event.scancode)
