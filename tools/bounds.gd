extends SceneTree
func _init():
	for n in ["ship-pirate-medium","ship-pirate-large","ship-large","ship-medium","ship-small","ship-wreck","tower-complete-large","structure-platform-dock","chest","palm-straight","rocks-a","cannon","barrel","castle-gate","structure","tower-watch","platform-planks"]:
		var s = load("res://assets/models/pirate/%s.glb" % n)
		if s == null: print(n," fail"); continue
		var inst = s.instantiate()
		var aabb = AABB(); var first = true
		for m in inst.find_children("*","MeshInstance3D",true,false):
			var a = m.get_aabb()
			var t = Transform3D(); var p = m
			while p and p != inst: t = p.transform * t; p = p.get_parent()
			a = t * a
			if first: aabb = a; first = false
			else: aabb = aabb.merge(a)
		print(n, " size=", aabb.size, " pos=", aabb.position)
	quit()
