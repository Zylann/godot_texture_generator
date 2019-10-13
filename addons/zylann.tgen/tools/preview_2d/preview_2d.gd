extends VBoxContainer

const ColorRangeRemapShader = preload("./color_range_remap.shader")

onready var _min_control = get_node("HBoxContainer/Min")
onready var _max_control = get_node("HBoxContainer/Max")
onready var _texture_rect = get_node("TextureRect")


func _ready():
	var mat = ShaderMaterial.new()
	mat.shader = ColorRangeRemapShader
	mat.set_shader_param("u_min", _min_control.value)
	mat.set_shader_param("u_max", _max_control.value)
	_texture_rect.material = mat


func set_texture(tex):
	_texture_rect.texture = tex


func _on_Min_value_changed(value):
	_texture_rect.material.set_shader_param("u_min", value)


func _on_Max_value_changed(value):
	_texture_rect.material.set_shader_param("u_max", value)
