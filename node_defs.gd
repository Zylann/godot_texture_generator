
const _node_families = [

	# Must only have outputs
	"input",
	
	# Must only have inputs
	"output",
	
	# Can be batched with other operations as a single shader
	"operation",
	
	# Cannot be done with just a shader,
	# requires to complete the full image first and then apply the transformation
	"composition"
]

const _node_types = {
	"TextureCoordinates": {
		"family": "input",
		"outputs": [
			{"name": "uv", "type": "vec2"}
		],
	},
	"Multiply": {
		"family": "operation",
		"inputs": [
			{"name": "a", "type": "scalar", "default": 1},
			{"name": "b", "type": "scalar", "default": 1}
		],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"GaussianBlur": {
		"family": "composition",
		"inputs": [
			{"name": "in", "type": "scalar", "default": 0}
		],
		"params": [
			{"name": "r", "type": "int", "default": 1}
		],
		"outputs": [
			{"name": "out", "type": "scalar"}
		]
	},
	"Output": {
		"family": "output",
		"inputs": [
			{"name": "color", "type": "scalar", "default": 0}
		]
	},
	"Texture": {
		"family": "operation",
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
	}
}


static func get_type_by_name(type_name):
	return _node_types[type_name]


static func get_node_types():
	return _node_types


static func check():
	for type_name in _node_types:
		var type = _node_types[type_name]
		
		assert(type.has("family"))
		
		if type.family == "input":
			assert(type.has("outputs"))
			assert(len(type.outputs) > 0)
			
		elif type.family == "output":
			assert(type.has("inputs"))
			assert(len(type.inputs) > 0)
		
		else:
			assert(type.has("inputs"))
			assert(type.has("outputs"))
			assert(len(type.inputs) > 0)
			assert(len(type.outputs) > 0)
		