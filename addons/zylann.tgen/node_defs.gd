
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
	
	"TextureCoordinates": preload("./nodes/texture_coordinates.gd"),
	"Multiply": preload("./nodes/multiply.gd"),
	
	"Sin": {
		"family": "operation",
		"category": "Math",
		"inputs": [
			{"name": "in", "type": "scalar", "default": 0}
		],
		"params": [],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"Wave": {
		"family": "operation",
		"category": "Shapes",
		"inputs": [
			{"name": "in", "type": "scalar", "default": 0}
		],
		"params": [
			{"name": "frequency", "type": "float", "default": 10.0},
			{"name": "offset", "type": "float", "default": 0.0}
		],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"Clamp": {
		"family": "operation",
		"category": "Math",
		"inputs": [
			{"name": "in", "type": "scalar", "default": 0}
		],
		"params": [
			{"name": "min", "type": "float", "default": 0.0},
			{"name": "max", "type": "float", "default": 1.0}
		],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"GaussianBlur": {
		"family": "composition",
		"category": "Effects",
		"inputs": [
			{"name": "in", "type": "vec4", "default": 0}
		],
		"params": [
			{"name": "r", "type": "int", "default": 10.0}
		],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"Output": {
		"family": "output",
		"category": "Output",
		"inputs": [
			{"name": "color", "type": "color", "default": Color(0,0,0,1)}
		],
		"params": [],
		"outputs": []
	},
	"Texture": {
		"family": "operation",
		"category": "Texture",
		"inputs": [
			# Texture can optionally come from a previous pass, otherwise will be taken from param
			{"name": "texture", "type": "Texture", "default": null},
			{"name": "uv", "type": "vec2"}
		],
		"params": [
		],
		"outputs": [
			{"name": "color", "type": "vec4"}
		]
	},
	"Construct": {
		"family": "operation",
		"category": "Vector",
		"inputs": [
			{"name": "x", "type": "float", "default": 0.0},
			{"name": "y", "type": "float", "default": 0.0},
			{"name": "z", "type": "float", "default": 0.0},
			{"name": "w", "type": "float", "default": 1.0}
		],
		"params": [],
		"outputs": [
			{"name": "v", "type": "vec4"}
		]
	},
	"Separate": {
		"family": "operation",
		"category": "Vector",
		"inputs": [
			{"name": "v", "type": "vec4"}
		],
		"params": [],
		"outputs": [
			{"name": "x", "type": "float"},
			{"name": "y", "type": "float"},
			{"name": "z", "type": "float"},
			{"name": "w", "type": "float"}
		]
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
		
