@tool
extends Node3D
class_name CoastMap

const KNOTS := [Vector3(0,0,470),Vector3(-270,0,440),Vector3(-500,0,240),Vector3(-690,0,80),Vector3(-740,0,-160),Vector3(-530,0,-50),Vector3(-430,0,-180),Vector3(-370,0,-360),Vector3(-570,0,-530),Vector3(-450,0,-730),Vector3(-140,0,-760),Vector3(-40,0,-500),Vector3(130,0,-560),Vector3(320,0,-420),Vector3(560,0,-130),Vector3(730,0,-20),Vector3(760,0,230),Vector3(630,0,350),Vector3(500,0,180),Vector3(400,0,230),Vector3(270,0,400)]
const Scenery = preload("res://scripts/world_scenery.gd")
var scenery: Node3D

var curve := Curve3D.new()
var shortcut := Curve3D.new()
var route := PackedVector3Array()
var road_samples := PackedVector3Array()
var road_markings: Array[Dictionary] = []
var boost_pads: Array[Vector3] = []
var length := 0.0
var materials: Dictionary = {}
var landmark_count := 0
var roads: Array[Curve3D] = []
var circuits: Array[Curve3D] = []
var circuit_names := ["COAST", "HARBOR", "CANYON", "AIRFIELD"]
var navigation := AStar3D.new()
var road_widths := [42.0,30.0,34.0,34.0,34.0]
var district_roads: Array[Curve3D] = []
var event_sites: Array[Vector3] = []
var world_environment: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var textured_sky: ShaderMaterial
var sun_light: DirectionalLight3D
var street_lights: Array[OmniLight3D] = []
var overhang_lamp_material: StandardMaterial3D
var time_of_day := 180.0 # Start just after sunrise.
var _world_built := false
@export_category("Day / Night Cycle")
@export_range(30.0, 900.0, 10.0, "suffix:s") var day_duration_seconds := 210.0
@export_range(30.0, 900.0, 10.0, "suffix:s") var night_duration_seconds := 120.0

func _ready() -> void:
	if _world_built:
		return
	_world_built = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build_curves()
	_build_district_roads()
	_environment()
	_island()
	_road(curve, 42.0, true)
	_road(shortcut, 30.0, false)
	for district in district_roads:
		_road(district,34.0,false)
	scenery.populate(self)
	_batch_boxes()
	_build_navigation()
	if Engine.is_editor_hint():
		time_of_day = day_duration_seconds * 0.5
	advance_day_night(0.0)

func advance_day_night(delta: float) -> void:
	var cycle_seconds := day_duration_seconds + night_duration_seconds
	time_of_day = fmod(time_of_day + delta, cycle_seconds)
	var daylight := time_of_day < day_duration_seconds
	var sun_t := (time_of_day / day_duration_seconds) if daylight else ((time_of_day - day_duration_seconds) / night_duration_seconds)
	var elevation := lerpf(-12.0, 62.0, sin(sun_t * PI)) if daylight else -16.0
	sun_light.rotation_degrees = Vector3(-elevation, lerpf(-118.0, 62.0, sun_t), 0.0)
	var warm := clampf(sin(sun_t * PI), 0.0, 1.0) if daylight else 0.0
	sun_light.light_energy = lerpf(0.04, 1.35, warm)
	sun_light.light_color = Color(0.30, 0.42, 0.72).lerp(Color(1.0, 0.91, 0.76), warm)
	world_environment.environment.ambient_light_energy = lerpf(0.45, 0.70, warm)
	world_environment.environment.ambient_light_color = Color(0.30, 0.38, 0.58).lerp(Color(0.65, 0.72, 0.80), warm)
	sky_material.sky_top_color = Color(0.008, 0.018, 0.065).lerp(Color(0.12, 0.32, 0.55), warm)
	sky_material.sky_horizon_color = Color(0.035, 0.06, 0.16).lerp(Color(0.75, 0.84, 0.88), warm)
	sky_material.ground_horizon_color = Color(0.025, 0.045, 0.09).lerp(Color(0.60, 0.72, 0.75), warm)
	sky_material.ground_bottom_color = Color(0.008, 0.012, 0.035).lerp(Color(0.17, 0.26, 0.32), warm)
	world_environment.environment.fog_light_color = Color(0.08, 0.13, 0.28).lerp(Color(0.57, 0.72, 0.8), warm)
	if textured_sky != null:
		textured_sky.set_shader_parameter("zenith", sky_material.sky_top_color)
		textured_sky.set_shader_parameter("horizon", sky_material.sky_horizon_color)
		textured_sky.set_shader_parameter("ground", sky_material.ground_bottom_color)
		textured_sky.set_shader_parameter("cloud_color", Color(0.09,0.12,0.22).lerp(Color(0.96,0.94,0.88), warm))
		textured_sky.set_shader_parameter("daylight", warm)
	var lamps_on := not daylight or warm < 0.18
	for lamp in street_lights:
		lamp.visible = lamps_on
	if overhang_lamp_material != null:
		overhang_lamp_material.emission_enabled = lamps_on

func add_overhang_light(fixture_at: Vector3, yaw: float) -> void:
	if overhang_lamp_material == null:
		overhang_lamp_material = StandardMaterial3D.new()
		overhang_lamp_material.albedo_color = Color(1.0,0.89,0.68)
		overhang_lamp_material.emission = Color(1.0,0.82,0.55)
		overhang_lamp_material.emission_energy_multiplier = 2.0
	var panel := box(Vector3(3.4,0.08,0.75), fixture_at + Vector3.DOWN * 0.24, Color.WHITE, yaw)
	panel.material_override = overhang_lamp_material
	var lamp := OmniLight3D.new()
	lamp.name = "OverhangLight%d" % street_lights.size()
	lamp.position = fixture_at + Vector3.DOWN * 0.35
	lamp.light_color = Color(1.0,0.82,0.55)
	lamp.light_energy = 4.0
	lamp.omni_range = 30.0
	lamp.omni_attenuation = 1.0
	lamp.shadow_enabled = false
	add_child(lamp)
	street_lights.append(lamp)

func _open_curve(points: Array[Vector3]) -> Curve3D:
	var path := Curve3D.new()
	path.bake_interval = 5
	for i in points.size():
		var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])*0.15
		path.add_point(points[i],-tangent,tangent)
	return path

func _curve_part(path: Curve3D, start: float, finish: float, reverse := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	var span := finish-start
	if span < 0:
		span += path.get_baked_length()
	var count := maxi(2,ceili(span/10.0))
	for i in count+1:
		var offset := start+span*i/count
		if offset > path.get_baked_length():
			offset -= path.get_baked_length()
		points.append(path.sample_baked(offset,true))
	if reverse:
		points.reverse()
	return points

func _combine(parts: Array[PackedVector3Array]) -> Curve3D:
	var result := Curve3D.new()
	result.bake_interval = 5
	var last := Vector3.INF
	for points in parts:
		for point in points:
			if last.is_finite() and last.distance_to(point) < 0.1:
				continue
			result.add_point(point)
			last = point
	return result

func _build_district_roads() -> void:
	var canyon := _open_curve([Vector3(-370,0,-360),Vector3(-220,0,-305),Vector3(-235,0,-175),Vector3(-60,0,-125),Vector3(45,0,-285),Vector3(185,0,-210),Vector3(320,0,-420)])
	var airfield := _open_curve([Vector3(-500,0,240),Vector3(-400,0,160),Vector3(-325,0,300),Vector3(-165,0,310),Vector3(-95,0,190),Vector3(-180,0,75)])
	var boulevard := _open_curve([Vector3(180,0,45),Vector3(260,0,130),Vector3(220,0,270),Vector3(270,0,400)])
	district_roads = [canyon,airfield,boulevard]
	roads = [curve,shortcut,canyon,airfield,boulevard]
	var west := curve.get_closest_offset(Vector3(-530,0,-50))
	var east := curve.get_closest_offset(Vector3(500,0,180))
	var north_west := curve.get_closest_offset(Vector3(-370,0,-360))
	var north_east := curve.get_closest_offset(Vector3(320,0,-420))
	var runway := curve.get_closest_offset(Vector3(-500,0,240))
	var shortcut_join := shortcut.get_closest_offset(Vector3(-180,0,75))
	var city_join := shortcut.get_closest_offset(Vector3(180,0,45))
	var bay_join := curve.get_closest_offset(Vector3(270,0,400))
	circuits = [curve,
		_combine([_curve_part(curve,0,west),_curve_part(shortcut,0,city_join),_curve_part(boulevard,0,boulevard.get_baked_length()),_curve_part(curve,bay_join,length)]),
		_combine([_curve_part(curve,west,north_west),_curve_part(canyon,0,canyon.get_baked_length()),_curve_part(curve,north_east,east),_curve_part(shortcut,0,shortcut.get_baked_length(),true)]),
		_combine([_curve_part(airfield,0,airfield.get_baked_length()),_curve_part(shortcut,0,shortcut_join,true),_curve_part(curve,runway,west,true)])]
	for path in circuits:
		if path.get_point_position(0).distance_to(path.get_point_position(path.point_count-1)) > 0.1:
			path.add_point(path.get_point_position(0))

func _build_navigation() -> void:
	var grid: Dictionary = {}
	var road_ids: Dictionary = {}
	for road_index in roads.size():
		var path := roads[road_index]
		var count := ceili(path.get_baked_length()/24.0)
		var first := navigation.get_available_point_id()
		var previous := -1
		for i in count+1:
			var at := path.sample_baked(path.get_baked_length()*i/count,true)
			var id := navigation.get_available_point_id()
			navigation.add_point(id,at)
			road_ids[id] = road_index
			if previous >= 0:
				navigation.connect_points(previous,id)
			previous = id
			var cell := Vector2i(floori(at.x/36),floori(at.z/36))
			for x in range(-1,2):
				for z in range(-1,2):
					for neighbor in grid.get(cell+Vector2i(x,z),[]):
						if road_ids[neighbor] != road_index and at.distance_to(navigation.get_point_position(neighbor)) < 34:
							navigation.connect_points(id,neighbor)
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(id)
		if path.get_point_position(0).distance_to(path.get_point_position(path.point_count-1)) < 1:
			navigation.connect_points(first,previous)

func navigation_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := navigation.get_closest_point(Vector3(from.x,0,from.z))
	var end := navigation.get_closest_point(Vector3(to.x,0,to.z))
	return navigation.get_point_path(start,end)

func closest_road_point(at: Vector3) -> Vector3:
	var flat := Vector3(at.x,0,at.z)
	var result := curve.get_closest_point(flat)
	for path in roads:
		var point := path.get_closest_point(flat)
		if point.distance_squared_to(flat) < result.distance_squared_to(flat):
			result = point
	return result

func _batch_boxes() -> void:
	var batches: Dictionary = {}
	for child in get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.material_override is StandardMaterial3D:
			var key: String = str(child.material_override.get_instance_id())
			if not batches.has(key):
				batches[key] = {"material":child.material_override,"transforms":[]}
			var pose: Transform3D = child.transform
			pose.basis = pose.basis.scaled_local(child.mesh.size)
			batches[key].transforms.append(pose)
			remove_child(child)
			child.queue_free()
	for batch in batches.values():
		var instance := MultiMeshInstance3D.new()
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		mesh.mesh = cube
		mesh.instance_count = batch.transforms.size()
		for index in mesh.instance_count:
			mesh.set_instance_transform(index,batch.transforms[index])
		instance.multimesh = mesh
		instance.material_override = batch.material
		instance.set_meta("review_transforms",batch.transforms)
		add_child(instance)

func _build_curves() -> void:
	curve.bake_interval = 6.0
	for i in KNOTS.size() + 1:
		var at: Vector3 = KNOTS[i % KNOTS.size()]
		var tangent: Vector3 = (KNOTS[(i + 1) % KNOTS.size()] - KNOTS[posmod(i - 1, KNOTS.size())]) * 0.16
		curve.add_point(at, -tangent, tangent)
	length = curve.get_baked_length()
	for i in 32:
		route.append(curve.sample_baked(length * i / 32.0) + Vector3.UP * 2.15)
	shortcut.add_point(Vector3(-530,0,-50), Vector3.ZERO, Vector3(130,0,90))
	shortcut.add_point(Vector3(-180,0,75), Vector3(-110,0,0), Vector3(100,0,0))
	shortcut.add_point(Vector3(180,0,45), Vector3(-120,0,15), Vector3(110,0,-15))
	shortcut.add_point(Vector3(500,0,180), Vector3(-130,0,-90), Vector3.ZERO)
	for i in 20:
		road_samples.append(curve.sample_baked(length*i/20.0))
	for i in 8:
		road_samples.append(shortcut.sample_baked(shortcut.get_baked_length()*i/8.0))
	event_sites = [curve.sample_baked(length*0.04),curve.sample_baked(length*0.22),curve.sample_baked(length*0.43),curve.sample_baked(length*0.68)]

func _road(path: Curve3D, width: float, main: bool) -> void:
	var road_length := path.get_baked_length()
	var steps := int(road_length/14.0)
	var asphalt := mat(Color(0.07,0.075,0.09),0.78)
	var edge := mat(Color(0.78,0.82,0.86),0.62)
	var line := mat(Color(0.0,0.9,0.85),0.36,true)
	var distance := 0.0
	var stripe_positions: Array[Vector3] = []
	for i in steps:
		var d0 := road_length*i/steps
		var d1 := road_length*(i+1)/steps
		var p0 := path.sample_baked(d0,true)
		var p1 := path.sample_baked(d1,true)
		var mid := (p0+p1)*0.5 + Vector3.UP*0.06
		var yaw := atan2(p1.x-p0.x,p1.z-p0.z)
		box(Vector3(width,0.12,p0.distance_to(p1)+0.7),mid,Color.WHITE,yaw,false,false,asphalt)
		if not _near_foreign_road_junction(path, mid):
			for side in [-1,1]:
				var lateral := Vector3(cos(yaw),0,-sin(yaw))*width*0.45*side
				box(Vector3(0.34,0.05,p0.distance_to(p1)+0.5),mid+lateral+Vector3.UP*0.08,Color.WHITE,yaw,false,false,edge)
			if i%2==0:
				stripe_positions.append(mid+Vector3.UP*0.09)
				box(Vector3(0.28,0.045,p0.distance_to(p1)*0.55),mid+Vector3.UP*0.09,Color.WHITE,yaw,false,true,line)
		distance += p0.distance_to(p1)
	road_markings.append({"road":path,"stripes":stripe_positions})
	if main:
		for i in 8:
			var at := sample(length * (i + 0.45) / 8.0)
			at.y = 0.2
			boost_pads.append(at)
			var yaw := heading_at(length * (i + 0.45) / 8.0)
			box(Vector3(14,0.08,11), at, Color(0.04,0.36,0.40), yaw)
			for z in 3:
				var shift := Vector3(sin(yaw),0,cos(yaw)) * (z-1) * 3.0
				box(Vector3(10-z*1.5,0.1,0.65), at + shift + Vector3.UP * 0.06, Color(0.0,0.95,0.85), yaw, false, true)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_material = sky_mat
	sky_mat.sky_top_color = Color(0.12,0.32,0.55)
	sky_mat.sky_horizon_color = Color(0.75,0.84,0.88)
	sky_mat.ground_horizon_color = Color(0.60,0.72,0.75)
	sky_mat.ground_bottom_color = Color(0.17,0.26,0.32)
	# Build a seamless panoramic cloud texture in memory. Unlike the old flat
	# XZ projection, the shader samples it as an equirectangular sky texture so
	# the detail wraps the full horizon like a conventional textured skybox.
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.frequency = 0.009
	noise.fractal_octaves = 5
	var clouds := NoiseTexture2D.new()
	clouds.width = 2048
	clouds.height = 1024
	clouds.seamless = true
	clouds.noise = noise
	var sky_shader := Shader.new()
	sky_shader.code = """shader_type sky;
uniform sampler2D panorama : repeat_enable, filter_linear_mipmap;
uniform vec4 zenith : source_color;
uniform vec4 horizon : source_color;
uniform vec4 ground : source_color;
uniform vec4 cloud_color : source_color;
uniform float daylight = 1.0;
const float PI = 3.14159265359;
void sky() {
    vec3 dir = normalize(EYEDIR);
    float longitude = atan(dir.z, dir.x) / (2.0 * PI) + 0.5;
    float latitude = asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5;
    vec2 uv = vec2(longitude, latitude);
    float altitude = max(dir.y, 0.0);
    vec3 base = mix(horizon.rgb, zenith.rgb, pow(altitude, 0.45));
    float detail = texture(panorama, uv).r;
    float broad = texture(panorama, vec2(uv.x * 0.5 + TIME * 0.0006, uv.y)).r;
    float cover = smoothstep(0.47, 0.70, mix(detail, broad, 0.35));
    cover *= smoothstep(-0.02, 0.16, dir.y) * mix(0.32, 0.82, daylight);
    vec3 upper = mix(base, cloud_color.rgb, cover);
    COLOR = dir.y >= 0.0 ? upper : ground.rgb;
}
"""
	textured_sky = ShaderMaterial.new()
	textured_sky.shader = sky_shader
	textured_sky.set_shader_parameter("panorama", clouds)
	textured_sky.set_shader_parameter("zenith", sky_mat.sky_top_color)
	textured_sky.set_shader_parameter("horizon", sky_mat.sky_horizon_color)
	textured_sky.set_shader_parameter("ground", sky_mat.ground_bottom_color)
	textured_sky.set_shader_parameter("cloud_color", Color(0.96,0.94,0.88))
	textured_sky.set_shader_parameter("daylight", 1.0)
	sky.sky_material = textured_sky
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.fog_enabled = false
	env.fog_density = 0.0
	env.fog_light_color = Color(0.57,0.72,0.8)
	world.environment = env
	world_environment = world
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-28,0)
	sun.light_color = Color(1,0.91,0.76)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1200.0
	add_child(sun)
	sun_light = sun
	scenery = Scenery.new()
