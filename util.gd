
static func get_node_in_parents(node, klass):
	while node != null:
		node = node.get_parent()
		if node != null and node is klass:
			return node
	return null


static func angle_tessellate(p_points, p_radius):
	
	if len(p_points) <= 2:
		return p_points
	
	var points = []
	
	points.append(p_points[0])
	
	for i in range(1, len(p_points) - 1):

		var a = p_points[i - 1];
		var b = p_points[i];
		var c = p_points[i + 1];
		
		var radius = p_radius
		var da = b.distance_to(a)
		var dc = b.distance_to(c)
		radius = min(radius, da)
		radius = min(radius, dc)
		
		var ba = (a - b).normalized()
		var bc = (c - b).normalized()
		
		#var radius = 30.0#pointsInfo[i].cornerRadius;
		
		var bo = (ba + bc).normalized()
		var o = b + bo * radius
		
		var t_mid = atan2(-bo.y, -bo.x)
		var a_ba_bc = abs(ba.angle_to(bc))
		var t_span = PI - a_ba_bc
		
		var steps = int(rad2deg(t_span)) / 4 + 1
		var t_step = t_span / float(steps)
		
		# Determine in which direction points will be created (must be from A to C)
		var t_begin = t_mid - t_span / 2.0
		var v = Vector2(cos(t_begin), sin(t_begin))
		if abs(v.dot(ba)) > 0.0001:
			t_begin = t_mid + t_span / 2.0
			t_step = -t_step

		var r = radius * cos(t_span / 2.0)
		
		var t = t_begin
		for s in steps+1:
			var p = Vector2(o.x + r * cos(t), o.y + r * sin(t))
			points.append(p)
			t += t_step
	
	points.append(p_points[-1])
	return points

