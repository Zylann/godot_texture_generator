
const _node_families = [

	# Must only have outputs
	"input",
	
	# Must only have inputs
	"output",
	
	# Can be batched with other operations as a single shader
	"operation",
	
	# Cannot be done with just a shader,
	# requires to complete the full image first and then apply the transformation.
	# Typically spawns an intermediate render.
	"composition"
]

const _node_types = {
	
	# Inputs
	"TextureCoordinates": preload("./nodes/texture_coordinates.gd"),
	
	# Operations
	"Multiply": preload("./nodes/multiply.gd"),
	"Sin": preload("./nodes/sin.gd"),
	"Wave": preload("./nodes/wave.gd"),
	"Clamp": preload("./nodes/clamp.gd"),
	"Texture": preload("./nodes/texture.gd"),
	"Construct": preload("./nodes/construct.gd"),
	"Separate": preload("./nodes/separate.gd"),
	"PerlinNoise": preload("./nodes/perlin_noise.gd"),

	# Compositions
	"GaussianBlur": preload("./nodes/gaussian_blur.gd"),
	"DirectionalBlur": preload("./nodes/directional_blur.gd"),
	"BumpToNormal": preload("./nodes/bump_to_normal.gd"),

	# Outputs
	"Output": {
		"family": "output",
		"category": "Output",
		"inputs": [
			{"name": "color", "type": "color", "default": Color(0,0,0,1)}
		],
		"params": [],
		"outputs": []
	}
}


static func get_type_by_name(type_name):
	return _node_types[type_name]


static func get_node_types():
	return _node_types


static func check():
	for type_name in _node_types:
		var type = _node_types[type_name]
		
		assert(_node_families.has(type.family))
		assert(typeof(type.category) == TYPE_STRING)
		assert(typeof(type.family) == TYPE_STRING)
		assert(typeof(type.params) == TYPE_ARRAY)
		
		if type.family == "input":
			assert(len(type.outputs) > 0)
			
		elif type.family == "output":
			assert(len(type.inputs) > 0)
		
		else:
			assert(len(type.inputs) > 0)
			assert(len(type.outputs) > 0)
		
