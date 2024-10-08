@tool
extends Node3D

var pillar_scene = preload("res://House/Pillar/pillar.tscn")
var wall_scene = preload("res://House/Wall/wall.tscn")
var window_scene = preload("res://House/Window/window.glb")
var window_cutout_scene = preload("res://House/Window/cut_out.tscn")
var door_scene = preload("res://House/Window/door.tscn")
var door_cutout_scene = preload("res://House/Window/cut_out_door.tscn")

@export var house_config : House_Config :
	set(value):
		print("config changed")
		house_config = value
		#house_config.changed.connect(build)
		#build()

var t0 : float
var cont : int
var last_pid : Array[int] = []

func _ready():
	#build()
	pass

func build():
	t0 = Time.get_ticks_msec()
	if is_inside_tree() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clean_house()
		for p_id in house_config.pillars.size():
			build_pillar(p_id)
		last_pid.clear()
		cont = 0
		for w in house_config.walls:
			build_wall(w)
		for f in house_config.floors:
			build_floor(f)
		for c in house_config.ceilings:
			build_ceiling(c)
	var h = $House
	if h != null:
		for mesh in $House.get_children():
			mesh.owner = self
	
	print("build in: " + str(Time.get_ticks_msec() - t0) + " msecs.")
		
func clean_house():
	for child in $House.get_children():
		child.queue_free()

func build_pillar(p_id:int):
	var pillar = pillar_scene.instantiate()
	pillar.pillar_id = p_id
	var p_config:Pillar_Config = house_config.pillars[p_id]
	pillar.pillar_config = p_config
	pillar.set_position(p_config.position)
	pillar.set_height(p_config.height)
	pillar.set_width(p_config.width)
	pillar.set_material(p_config.material)
	$House.add_child(pillar)
	pillar.transform_changed.connect(pillar_transform_changed)
	pillar.name = "Pillar_" + str(p_id) + "_" + str(pillar.position) +"   ; p   " + str(randi_range(0, 25))
	if last_pid.size() > 0  and last_pid.has(p_id): # keep pillar selected.
		var selection = EditorInterface.get_selection()
		selection.add_node(pillar)
		last_pid.erase(p_id)
		
	#pillar.owner = $House.owner

func pillar_transform_changed(pillar_id:int,pos:Vector3):
	last_pid.append(pillar_id)
	house_config.pillars[pillar_id].position = pos


func build_wall(wall_config:Wall_Config):
	var wall = wall_scene.instantiate()
	wall.wall_config = wall_config
	var pillar_1 = house_config.pillars[wall_config.pillar_1]
	var pillar_2 = house_config.pillars[wall_config.pillar_2]
	wall.position = (pillar_1.position + pillar_2.position) / 2
	var length = pillar_1.position.distance_to(pillar_2.position)
	wall.set_length(length)
	var height = min(pillar_1.height,pillar_2.height)
	wall.set_height(height)
	var width = min(pillar_1.width, pillar_2.width)
	width *= wall_config.width
	wall.set_width(width)
	wall.set_material(wall_config.material)
	wall.set_inner_material(wall_config.inner_material)
	var wall_angle = (pillar_1.position - pillar_2.position).angle_to(Vector3.FORWARD)
	if pillar_1.position.x > pillar_2.position.x:
		wall_angle = 2 * PI - wall_angle
	wall.rotation = Vector3(0,wall_angle,0)
	for w in wall_config.windows:
		var window = window_scene.instantiate()
		var cutout = window_cutout_scene.instantiate()
		var window_y = w.vertical_position * height
		var window_z = (w.horizontal_position - 0.5) * length
		var window_position = Vector3(0,window_y,window_z)
		window.position = window_position
		cutout.position = window_position
		cutout.material = wall_config.material
		wall.add_child(cutout)
		wall.add_child(window)
	for d in wall_config.doors:
		var door = door_scene.instantiate()
		var cutout = door_cutout_scene.instantiate()
		var door_y = d.vertical_position * height
		var door_z = (d.horizontal_position - 0.5) * length
		var door_position = Vector3(0,door_y,door_z)
		door.position = door_position
		cutout.position = door_position
		cutout.material = wall_config.material
		wall.add_child(cutout)
		wall.add_child(door)
	$House.add_child(wall)
	wall.name = "Wall_" + str(cont) + "   <3   " + str(randi_range(0, 25))
	cont += 1
	

func build_floor(floor_config:Floor_Config):
	var floor = CSGPolygon3D.new()
	floor.material = floor_config.material
	floor.depth = floor_config.thickness
	floor.rotation.x = PI/2
	var floor_poly = PackedVector2Array()
	var height = house_config.pillars[floor_config.perimeter[0]].position.y
	for pillar_id in floor_config.perimeter:
		var pillar = house_config.pillars[pillar_id]
		floor_poly.append(Vector2(pillar.position.x,pillar.position.z))
		if height < pillar.position.y: #get the highest pillar position, so floor will be on stilts if eneven
			height =  pillar.position.y
	floor.polygon = floor_poly #cant append directly to polygon
	floor.position.y = height
	$House.add_child(floor)
	return floor

func build_ceiling(ceiling_config:Floor_Config):
	var ceiling = build_floor(ceiling_config)
	var first_pillar = house_config.pillars[ceiling_config.perimeter[0]]
	var height = first_pillar.position.y + first_pillar.height - ceiling_config.thickness -.001
	for pillar_id in ceiling_config.perimeter:
		var pillar = house_config.pillars[pillar_id]
		var curr_height = pillar.position.y + pillar.height - ceiling_config.thickness -.001
		if height > curr_height: #get the lowest top position, so ceiling wont be floating if uneven
			height =  curr_height
	ceiling.position.y = height
	

func _on_visibility_changed():
	build()
