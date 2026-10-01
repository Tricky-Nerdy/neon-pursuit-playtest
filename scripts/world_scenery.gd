@tool
extends Node3D
# Authored coastline and district dressing. Terrain is baked once at world creation.
const OUTLINE := [Vector2(-10,610),Vector2(-250,600),Vector2(-450,500),Vector2(-625,370),Vector2(-850,320),Vector2(-965,120),Vector2(-930,-160),Vector2(-805,-310),Vector2(-725,-430),Vector2(-720,-660),Vector2(-520,-890),Vector2(-210,-910),Vector2(-10,-800),Vector2(100,-690),Vector2(290,-620),Vector2(470,-590),Vector2(630,-410),Vector2(620,-240),Vector2(840,-140),Vector2(920,70),Vector2(915,340),Vector2(775,480),Vector2(645,445),Vector2(560,300),Vector2(500,330),Vector2(390,510),Vector2(250,580),Vector2(180,550),Vector2(90,600)]
const LAKE := [Vector2(-185,-425),Vector2(-90,-455),Vector2(-15,-375),Vector2(-65,-305),Vector2(-140,-310),Vector2(-195,-370)]
var coast
var noise := FastNoiseLite.new()
var terrain_mesh: MeshInstance3D
var prop_count := 0
var terrain_peak := 0.0
var batched_prop_groups := 0
var scenes: Dictionary = {}
var prop_roots: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func is_land(point: Vector2) -> bool:
    return Geometry2D.is_point_in_polygon(point,PackedVector2Array(OUTLINE)) and not Geometry2D.is_point_in_polygon(point,PackedVector2Array(LAKE))

func _edge_distance(point: Vector2, polygon: Array) -> float:
    var nearest := INF
    for i in polygon.size():
        nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])))
    return nearest

func ground_height(point: Vector2) -> float:
    var road: float = coast.road_distance(Vector3(point.x,0,point.y))
    var shore := minf(_edge_distance(point,OUTLINE),_edge_distance(point,LAKE))
    var mountain := 0.0
    for peak in [Vector3(-420,-555,165),Vector3(-240,-610,185),Vector3(130,-385,140),Vector3(-630,-300,115),Vector3(455,-330,125)]:
        var distance := point.distance_to(Vector2(peak.x,peak.y))
        mountain = maxf(mountain,peak.z*exp(-distance*distance/26000.0))
    var rolling := maxf(0,noise.get_noise_2d(point.x,point.y)*15+8)
    if (point.x > -470 and point.x < 360 and point.y > 120 and point.y < 555):
        rolling = 0.0
        mountain = 0.0
    var height := (mountain+rolling)*smoothstep(34,105,road)*smoothstep(8,55,shore)
    return lerpf(-1.8,height-0.16,smoothstep(0,18,shore))

func build_terrain(map) -> void:
    coast = map
    rng.seed = 481702
    noise.seed = 491
    noise.frequency = 0.012
    var points := PackedVector2Array()
    for polygon in [OUTLINE,LAKE]:
        for i in polygon.size():
            var a: Vector2 = polygon[i]
            var b: Vector2 = polygon[(i+1)%polygon.size()]
            var count := ceili(a.distance_to(b)/22.0)
            for j in count:
                points.append(a.lerp(b,float(j)/count))
    for z in range(-900,620,26):
        for x in range(-960,930,26):
            var point := Vector2(x+ rng.randf_range(-5,5),z+rng.randf_range(-5,5))
            if is_land(point) and _edge_distance(point,OUTLINE) > 10 and _edge_distance(point,LAKE) > 10:
                points.append(point)
    # Road-edge samples hold the terrain flat beneath the complete road ribbon.
    for road in coast.roads:
        for d in range(0,int(road.get_baked_length()),18):
            var at: Vector3 = road.sample_baked(d,true)
            var ahead: Vector3 = road.sample_baked(minf(d+3,road.get_baked_length()),true)
            var side := Vector3((ahead-at).z,0,-(ahead-at).x).normalized()
            for offset in [-30.0,0.0,30.0]:
                var p: Vector3 = at+side*offset
                if is_land(Vector2(p.x,p.z)):
                    points.append(Vector2(p.x,p.z))
    var indices := Geometry2D.triangulate_delaunay(points)
    var positions := PackedVector3Array()
    for p in points:
        var h := ground_height(p)
        terrain_peak = maxf(terrain_peak,h)
        positions.append(Vector3(p.x,h,p.y))
    var triangles := PackedInt32Array()
    var normals := PackedVector3Array()
    normals.resize(positions.size())
    for i in range(0,indices.size(),3):
        var center := (points[indices[i]]+points[indices[i+1]]+points[indices[i+2]])/3
        if not is_land(center):
            continue
        var a := indices[i]
        var b := indices[i+1]
        var c := indices[i+2]
        var normal := -(positions[b]-positions[a]).cross(positions[c]-positions[a])
        if normal.y < 0:
            var swap := b
            b = c
            c = swap
            normal = -normal
        triangles.append_array(PackedInt32Array([a,b,c]))
        for index in [a,b,c]:
            normals[index] += normal
    var colors := PackedColorArray()
    for i in positions.size():
        normals[i] = normals[i].normalized()
        var p := points[i]
        var height := positions[i].y
        var shore := minf(_edge_distance(p,OUTLINE),_edge_distance(p,LAKE))
        var color := Color(0.24,0.34,0.20).lerp(Color(0.35,0.43,0.25),clampf(noise.get_noise_2d(p.x,p.y)+0.5,0,1))
        if p.y < -150:
            color = Color(0.35,0.37,0.28).lerp(Color(0.48,0.38,0.27),clampf(height/100,0,1))
        var rock_blend := maxf(1-smoothstep(0.65,0.92,normals[i].y),smoothstep(70,125,height))
        color = color.lerp(Color(0.48,0.47,0.42),rock_blend)
        color = Color(0.68,0.66,0.48).lerp(color,smoothstep(12,30,shore))
        colors.append(color)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = positions
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = triangles
    var landscape := ArrayMesh.new()
    landscape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    terrain_mesh = MeshInstance3D.new()
    terrain_mesh.name = "SculptedCoast"
    terrain_mesh.mesh = landscape
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.96
    terrain_mesh.material_override = mat
    add_child(terrain_mesh)
    terrain_mesh.create_trimesh_collision()
    for polygon in [OUTLINE,LAKE]:
        var edge := Curve3D.new()
        for p in polygon:
            edge.add_point(Vector3(p.x,0,p.y))
        edge.add_point(edge.get_point_position(0))
        coast._ribbon(edge,7,-1.65,Color(0.39,0.66,0.61))

func _asset(name_value: String, at: Vector3, scale_value := 1.0, yaw := 0.0) -> Node3D:
    if not scenes.has(name_value):
        scenes[name_value] = load("res://assets/world/"+name_value+".glb")
    var node: Node3D = scenes[name_value].instantiate()
    node.position = at
    node.scale = Vector3.ONE*scale_value
    node.rotation.y = yaw
    add_child(node)
    prop_count += 1
    prop_roots.append(node)
    return node

func _box(size: Vector3, at: Vector3, color: Color, solid := false, yaw := 0.0) -> void:
    coast.box(size,at,color,yaw,solid)
    prop_count += 1

func _safe(at: Vector3, radius: float) -> bool:
    return is_land(Vector2(at.x,at.z)) and coast.road_distance(at) > radius

func populate(map) -> void:
    coast = map
    _city()
    _harbor()
    _airfield()
    _ridges()
    _roadside()
    _batch_props()
    coast.landmark_count = 14
    for path in coast.circuits:
        coast.event_sites.append(path.sample_baked(40)+Vector3.UP*2.15)

func _city() -> void:
    # Mixed podiums, glass setbacks, balconies and roof equipment; no identical cube skyline.
    for z in range(125,405,50):
        for x in range(0,370,49):
            var at := Vector3(x,0,z)
            if not _safe(at,43):
                continue
            var h := rng.randf_range(18,78)
            var w := rng.randf_range(19,27)
            var tone := Color(0.40,0.48,0.49).lerp(Color(0.65,0.60,0.49),rng.randf())
            _box(Vector3(w+7,7,30),at+Vector3.UP*3.5,tone,true)
            _box(Vector3(w,h,24),at+Vector3.UP*(h/2+7),Color(0.10,0.25,0.30),true)
            for y in range(10,int(h+7),5):
                _box(Vector3(w+1,0.55,25),at+Vector3.UP*y,tone)
                for xx in [-0.32,0.0,0.32]:
                    _box(Vector3(0.5,4.5,24.4),at+Vector3(w*xx,y+2.3,0),tone)
            _box(Vector3(w*0.72,6,18),at+Vector3.UP*(h+10),tone)
            _box(Vector3(6,3,7),at+Vector3(3,h+14,0),Color(0.27,0.33,0.34))
            _box(Vector3(w+15,0.15,38),at+Vector3.UP*0.02,Color(0.51,0.53,0.49))
    # Arcaded waterfront market.
    for i in 8:
        var at := Vector3(-225+i*29,0,520)
        if not _safe(at,38): continue
        _box(Vector3(22,8,16),at+Vector3.UP*4,Color(0.65,0.64,0.52),true)
        _box(Vector3(24,0.8,23),at+Vector3.UP*8.4,Color(0.18,0.46,0.47))
        for side in [-1,1]:
            _box(Vector3(0.6,7,0.6),at+Vector3(side*9,3.5,-11),Color(0.78,0.72,0.57))
    _asset("lighthouse",Vector3(807,ground_height(Vector2(807,380)),380),1.3)
    coast._sign("BREAKWATER CITY",42,Vector3(175,21,80),PI)

func _harbor() -> void:
    # A stepped sea wall, connected piers, container yard and working cranes.
    _box(Vector3(200,5,18),Vector3(30,-0.7,574),Color(0.34,0.40,0.42))
    for i in 4:
        var at := Vector3(-50+i*48,0,610)
        _box(Vector3(10,2,86),at+Vector3(0,-0.6,0),Color(0.39,0.46,0.47))
        for z in [-33,0,33]:
            _box(Vector3(2,9,2),at+Vector3(0,-4,z),Color(0.19,0.27,0.29))
        _asset("yacht",at+Vector3(14,-1.7,18),0.9,0.1*i)
    for i in 3:
        var at := Vector3(-370-i*54,0,390-i*31)
        if _safe(at,45):
            _asset("crane",at,0.8,-0.5)
    for i in 30:
        var at := Vector3(-430+(i%6)*21,0,320+(i/6)*14)
        if not _safe(at,37): continue
        var h := 5.5 if i%3 != 0 else 11.0
        var color: Color = [Color(0.68,0.28,0.16),Color(0.18,0.43,0.49),Color(0.65,0.56,0.29)][i%3]
        _box(Vector3(18,h,9),at+Vector3.UP*h/2,color,true)
        for rib in 7:
            _box(Vector3(0.22,h,9.25),at+Vector3(-8+rib*2.6,h/2,0),color.lightened(0.13))
    coast._sign("PORT AURORA",38,Vector3(-365,18,415),0.2)

func _airfield() -> void:
    _box(Vector3(110,0.12,72),Vector3(-260,0.02,345),Color(0.15,0.19,0.20))
    for i in 8:
        _box(Vector3(8,0.02,1),Vector3(-302+i*12,0.1,355),Color(0.85,0.74,0.48))
    _box(Vector3(75,18,46),Vector3(-275,9,190),Color(0.43,0.52,0.53),true)
    _box(Vector3(68,13,1),Vector3(-275,6.5,166),Color(0.065,0.12,0.14))
    for i in 9:
        _box(Vector3(1,20,49),Vector3(-309+i*8.5,10,190),Color(0.7,0.7,0.61))
    _box(Vector3(11,65,11),Vector3(-175,32.5,235),Color(0.47,0.57,0.56),true)
    _box(Vector3(26,10,26),Vector3(-175,65,235),Color(0.08,0.28,0.34))
    _box(Vector3(30,2,30),Vector3(-175,71,235),Color(0.67,0.7,0.62))
    _asset("radar",Vector3(-175,73,235),0.9)
    coast._sign("SKYPORT / DRIFT",36,Vector3(-270,19,325),PI)

func _ridges() -> void:
    var rock_scene := load("res://assets/coast_rocks.glb") as PackedScene
    for i in 70:
        var p := Vector2(rng.randf_range(-720,550),rng.randf_range(-780,-120))
        var at := Vector3(p.x,0,p.y)
        if not _safe(at,80): continue
        var rock: Node3D = rock_scene.instantiate()
        rock.position = Vector3(p.x,ground_height(p),p.y)
        rock.scale = Vector3.ONE*rng.randf_range(0.32,0.8)
        rock.rotation.y = rng.randf_range(0,TAU)
        add_child(rock)
        coast._rock_collision(rock)
        prop_count += 1
    # Ridge tunnel follows the actual curve; sidewalls remain outside every junction.
    var start: float = coast.curve.get_closest_offset(Vector3(-450,0,-730))
    for i in 12:
        var d := start+20+i*11
        var at: Vector3 = coast.sample(d)
        var yaw: float = coast.heading_at(d)
        var side := Vector3(cos(yaw),0,-sin(yaw))
        for sign_value in [-1,1]:
            var wall: Vector3 = at+side*29*sign_value
            if coast.road_distance(wall) > 24:
                _box(Vector3(4,22,12),wall+Vector3.UP*7,Color(0.32,0.37,0.38),true,yaw)
        _box(Vector3(62,3,12),at+Vector3.UP*18,Color(0.32,0.37,0.38),false,yaw)
        coast.box(Vector3(40,0.2,0.5),at+Vector3.UP*16.3,Color(0.3,0.82,0.87),yaw,false,true)
    coast._sign("RIDGE TUNNEL",35,coast.sample(start)+Vector3.UP*15,coast.heading_at(start))
    for i in 3:
        var p := Vector2(390+i*43,-500)
        _asset("radar",Vector3(p.x,ground_height(p),p.y),1.5,rng.randf_range(0,TAU))
    # Forest clusters reinforce local scale; keep full crown clearance beside roads.
    for i in 460:
        var p := Vector2(rng.randf_range(-850,850),rng.randf_range(-830,540))
        var at := Vector3(p.x,0,p.y)
        if not _safe(at,39) or _edge_distance(p,OUTLINE) < 25 or ground_height(p) > 115: continue
        if noise.get_noise_2d(p.x+800,p.y) < -0.12: continue
        var name_value := "pine" if p.y < -100 else "palm"
        _asset(name_value,Vector3(p.x,ground_height(p),p.y),rng.randf_range(0.65,1.25),rng.randf_range(0,TAU))

func _roadside() -> void:
    for road in coast.roads:
        for d in range(20,int(road.get_baked_length())-20,55):
            var at: Vector3 = road.sample_baked(d,true)
            var ahead: Vector3 = road.sample_baked(d+5,true)
            var side := Vector3((ahead-at).z,0,-(ahead-at).x).normalized()
            var yaw := atan2(-(ahead-at).x,-(ahead-at).z)
            for sign_value in [-1,1]:
                var point: Vector3 = at+side*30*sign_value
                if not _safe(point,26): continue
                _box(Vector3(0.5,8,0.5),point+Vector3.UP*4,Color(0.19,0.28,0.3),false,yaw)
                var fixture_at: Vector3 = point-side*sign_value*1.7+Vector3.UP*8
                _box(Vector3(4,0.4,1),fixture_at,Color(0.64,0.79,0.75),false,yaw)
                coast.add_overhang_light(fixture_at,yaw)
            # Segmented guardrails, with breaks at road junctions.
            if int(d)%110 < 55:
                for sign_value in [-1,1]:
                    var rail: Vector3 = at+side*25*sign_value
                    if coast.road_distance(rail) < 23: continue
                    _box(Vector3(0.5,1.1,22),rail+Vector3.UP*1.2,Color(0.54,0.61,0.59),false,yaw)
    for side in [-1,1]:
        var at := Vector3(25,0,470+side*62)
        if not _safe(at,35): continue
        for row in 5:
            _box(Vector3(76,2,6),at+Vector3(0,2+row*2,side*row*6),Color(0.36,0.49,0.49))
        _box(Vector3(80,1.5,34),at+Vector3(0,17,side*12),Color(0.12,0.36,0.39))
    coast._sign("AURORA / BROKEN COAST",52,Vector3(-25,22,474),coast.heading_at(0))

func _collect_meshes(node: Node3D, groups: Dictionary) -> void:
    if node is MeshInstance3D:
        var key := str(node.mesh.get_instance_id())
        if not groups.has(key):
            groups[key] = {"mesh":node.mesh,"material":node.material_override,"transforms":[]}
        groups[key].transforms.append(global_transform.affine_inverse()*node.global_transform)
    for child in node.get_children():
        if child is Node3D:
            _collect_meshes(child,groups)

func _batch_props() -> void:
    var groups: Dictionary = {}
    for node in prop_roots:
        _collect_meshes(node,groups)
    batched_prop_groups = groups.size()
    for group in groups.values():
        var instance := MultiMeshInstance3D.new()
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = group.mesh
        multi.instance_count = group.transforms.size()
        for i in multi.instance_count:
            multi.set_instance_transform(i,group.transforms[i])
        instance.multimesh = multi
        instance.material_override = group.material
        instance.set_meta("review_transforms",group.transforms)
        add_child(instance)
    for node in prop_roots:
        remove_child(node)
        node.queue_free()
    prop_roots.clear()
