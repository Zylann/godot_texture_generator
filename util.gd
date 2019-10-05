
static func get_node_in_parents(node, klass):
	while node != null:
		node = node.get_parent()
		if node != null and node is klass:
			return node
	return null

