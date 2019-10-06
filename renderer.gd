extends Node

class ViewportInfo:
	var viewport = null
	var sprite = null

signal progress_notified(progress)


var _render_steps = []
var _current_step_index = 0
var _viewports = []
var _resolution = Vector2(256, 256)
var _dummy_texture = null
var _wait_frames = 0


func _ready():
	# Always have at least one viewport.
	# The latest viewport must always remain the same.
	_viewports.append(_create_viewport())


func _get_dummy_texture():
	if _dummy_texture == null:
		var im = Image.new()
		im.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color(0,0,0))
		var tex = ImageTexture.new()
		tex.create_from_image(im, 0)
		_dummy_texture = tex
	return _dummy_texture


func submit(render_steps):
	_render_steps = render_steps.duplicate(false)

	_current_step_index = 0
	set_process(true)
	
	# TODO There must be a way to re-use viewports
	while len(_render_steps) > len(_viewports):
		_viewports.push_front(_create_viewport())
	
	if len(_render_steps) > 0:
		_setup_pass(0)
		_wait_frames = 1


func _setup_pass(i):
	#print("Setting up pass ", i)
	var rs = _render_steps[i]
	var vi = _viewports[i]
	vi.sprite.material.shader = rs.shader
	vi.viewport.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
	vi.viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	emit_signal("progress_notified", 0.0)
	
	# TODO Setup composition passes


func _create_viewport():
	var vp = Viewport.new()
	vp.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
	vp.render_target_update_mode = Viewport.UPDATE_ONCE
	vp.size = _resolution
	add_child(vp)
	
	var sprite = Sprite.new()
	sprite.centered = false
	sprite.texture = _get_dummy_texture()
	sprite.material = ShaderMaterial.new()
	sprite.scale = vp.size / sprite.texture.get_size()
	vp.add_child(sprite)
	
	var vi = ViewportInfo.new()
	vi.viewport = vp
	vi.sprite = sprite
	return vi


func _process(delta):
	
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	
	_current_step_index += 1
	if _current_step_index < len(_render_steps):
		_setup_pass(_current_step_index)
		emit_signal("progress_notified", _current_step_index / float(len(_render_steps)))
	else:
		set_process(false)
		emit_signal("progress_notified", 1.0)
	

# TODO Multiple outputs
func get_texture():
	return _viewports[-1].viewport.get_texture()

