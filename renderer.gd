
# Renderer performing a series of steps over viewports in order to get a final result.
# It knows nothing about the graph (which is only used to generate the said steps).
# Rendering may take several frames to complete.

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
var _image_cache = {}
# TODO Image reload option


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
		emit_signal("progress_notified", 0.0)


func _setup_pass(i):
	#print("Setting up pass ", i)
	var rs = _render_steps[i]
	var vi = _viewports[i]
	
	var mat = vi.sprite.material
	mat.shader = rs.shader
	
	# Assign textures
	for uniform_name in rs.texture_uniforms:
		var source = rs.texture_uniforms[uniform_name]
		
		var tex
		if source.render_step_index != -1:
			# Textures coming from other viewports
			assert(source.render_step_index >= 0)
			assert(source.render_step_index < len(_render_steps))
			var prev_viewport = _viewports[source.render_step_index]
			tex = prev_viewport.viewport.get_texture()
		
		elif source.file_path != "":
			# Textures coming from files
			tex = _load_image_texture(source.file_path)
		
		mat.set_shader_param(uniform_name, tex)
	
	# Tell viewport to render once
	vi.viewport.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
	vi.viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	
	# TODO Setup composition passes


func _load_image_texture(file_path):
	if _image_cache.has(file_path):
		return _image_cache[file_path]
	var im = Image.new()
	var err = im.load(file_path)
	if err != OK:
		printerr("Could not load image ", file_path, ", error ", err)
		return null
	var tex = ImageTexture.new()
	tex.create_from_image(im, Texture.FLAG_FILTER | Texture.FLAG_REPEAT)
	_image_cache[file_path] = tex
	return tex


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

