
# Renderer performing a series of steps over viewports in order to get a final result.
# It knows nothing about the graph (which is only used to generate the said steps).
# Rendering may take several frames to complete.

extends Node

const BlurShader = preload("./blur.shader")

class ViewportInfo:
	var viewport = null
	var sprite = null
	var post_process_sprite = null

signal progress_notified(progress)


var _render_steps = []
var _current_step_index = 0
var _viewports = []
var _resolution = Vector2(256, 256)
var _dummy_texture = null
var _wait_frames = 0
var _image_cache = {}
var _iteration = 0
# TODO Image reload option


func _ready():
	_viewports.append(_create_viewport())
	set_process(false)


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
	
	# TODO There must be a way to re-use viewports
	while len(_render_steps) > len(_viewports):
		_viewports.push_front(_create_viewport())
	
	if len(_render_steps) > 0:
		_setup_pass(0)
		_wait_frames = 1
		emit_signal("progress_notified", 0.0)
		set_process(true)


func _restart():
	submit(_render_steps)


func _setup_pass(i):
	#print("Setting up pass ", i)
	var rs = _render_steps[i]
	var vi = _viewports[i]
	
	# TODO No function to revert params??
	vi.sprite.material = ShaderMaterial.new()
	vi.sprite.show()
	vi.post_process_sprite.hide()
	
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
	
	_iteration = 0
	
	_process_composition()


func _load_image_texture(file_path):
	if _image_cache.has(file_path):
		return _image_cache[file_path]
	return _force_load_image_texture(file_path)


func _force_load_image_texture(file_path):
	var im = Image.new()
	var err = im.load(file_path)
	if err != OK:
		printerr("Could not load image ", file_path, ", error ", err)
		return null
	var tex = ImageTexture.new()
	tex.create_from_image(im, Texture.FLAG_FILTER | Texture.FLAG_REPEAT)
	_image_cache[file_path] = tex
	return tex


func reload_images():
	var files = _image_cache.keys()
	for file_path in files:
		_force_load_image_texture(file_path)
	_restart()


func _create_viewport():
	var vp = Viewport.new()
	vp.render_target_clear_mode = Viewport.CLEAR_MODE_ONLY_NEXT_FRAME
	vp.render_target_update_mode = Viewport.UPDATE_ONCE
	vp.render_target_v_flip = true
	vp.size = _resolution
	add_child(vp)
	
	var vi = ViewportInfo.new()
	vi.viewport = vp
	vi.sprite = _create_viewport_sprite(vp)
	vi.post_process_sprite = _create_viewport_sprite(vp)
	vi.post_process_sprite.hide()
	return vi


func _create_viewport_sprite(vp):
	var sprite = Sprite.new()
	sprite.centered = false
	sprite.texture = _get_dummy_texture()
	sprite.material = ShaderMaterial.new()
	sprite.scale = vp.size / sprite.texture.get_size()
	vp.add_child(sprite)
	return sprite


func _process(delta):
	
	if _wait_frames > 0:
		_wait_frames -= 1
		return

	_iteration += 1
	
	if _process_composition():
		_current_step_index += 1
		if _current_step_index < len(_render_steps):
			_setup_pass(_current_step_index)
			emit_signal("progress_notified", _current_step_index / float(len(_render_steps)))
		else:
			set_process(false)
			emit_signal("progress_notified", 1.0)
	

func _process_composition():
	var rs = _render_steps[_current_step_index]
	var finished = true
	
	if rs.composition == null:
		return finished
	
	var p = rs.composition.params
	var vi = _viewports[_current_step_index]
		
	match rs.composition.type:
		
		"Pass":
			finished = true
		
		"GaussianBlur":
			var mat = vi.post_process_sprite.material
			
			if _iteration == 0:
				mat.shader = BlurShader
				mat.set_shader_param("u_orientation", 0.0)
				mat.set_shader_param("u_amount", p.r)
				finished = false
				
			elif _iteration == 1:
				mat.set_shader_param("u_orientation", 1.0)
				finished = false
		
		"Erode":
			# TODO
			pass
		
		# TODO Regular drawings?
	
	if not finished:
		vi.sprite.visible = (_iteration < 1)
		vi.post_process_sprite.visible = true
		vi.viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	
	return finished


# TODO Multiple outputs
func get_texture():
	var last = len(_render_steps) - 1
	return _viewports[last].viewport.get_texture()


func get_textures():
	var textures = []
	for vi in _viewports:
		textures.append(vi.viewport.get_texture())
	return textures
