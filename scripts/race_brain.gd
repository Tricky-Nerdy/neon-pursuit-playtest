@tool
extends RefCounted
class_name RaceBrain

const PROFILES := [
    {"name":"KITE", "pace":0.91, "reserve":36.0, "lane":-5.0},
    {"name":"EMBER", "pace":1.0, "reserve":16.0, "lane":5.0},
    {"name":"MICA", "pace":0.96, "reserve":25.0, "lane":-1.8},
    {"name":"VOLT", "pace":1.04, "reserve":12.0, "lane":2.0}
]
var ship: HoverShip
var map: CoastMap
var profile := 0
var level := 1
var role := "race"
var state := "FOLLOW"
var path := Curve3D.new()
var path_length := 1.0
var progress := 0.0
var last_offset := 0.0
var lane := 0.0
var lane_goal := 0.0
var lane_timer := 0.0
var stuck_time := 0.0
var recovery_time := 0.0
var replan_time := 0.0
var seen_age := 0.0
var last_seen := Vector3.ZERO
var target_speed := 0.0
var recoveries := 0
var overtakes := 0
var boosts := 0
var path_replans := 0
var was_boosting := false
var boost_cooldown := 0.0
var active := true
var finished := false
var contact_cooldown := 0.0
var last_state := "FOLLOW"
var finish_time := -1.0
var race_time := 0.0

func setup(body: HoverShip, world: CoastMap, personality: int) -> void:
    ship = body
    map = world
    profile = posmod(personality,PROFILES.size())
    lane = PROFILES[profile].lane
    lane_goal = lane

func begin(route: Curve3D, offset: float, job: String, difficulty: int) -> void:
    path = route
    path_length = path.get_baked_length()
    last_offset = fposmod(offset,path_length)
    progress = offset
    role = job
    level = difficulty
    state = "PATROL" if job == "patrol" else "FOLLOW"
    active = true
    finished = false
    finish_time = -1
    race_time = 0
    stuck_time = 0
    recovery_time = 0
    replan_time = profile*0.16
    seen_age = 0
    recoveries = 0
    overtakes = 0
    boosts = 0
    path_replans = 0
    was_boosting = false
    boost_cooldown = 0
    ship.input_accel = false
    ship.input_boost = false
    ship.input_brake = false

func sample(offset: float) -> Vector3:
    var distance := clampf(offset,0,path_length) if role == "police" else fposmod(offset,path_length)
    return path.sample_baked(distance,true)+Vector3.UP*2.15

func offset_at(position: Vector3) -> float:
    return path.get_closest_offset(Vector3(position.x,0,position.z))

func _record_progress(offset: float, delta: float) -> void:
    var change := wrapf(offset-last_offset,-path_length*0.5,path_length*0.5)
    # No credit for a teleport, shortcut across a self-crossing or reverse lap.
    if absf(change) <= maxf(12.0,(absf(ship.forward_speed)+25)*delta*2):
        progress += change
    last_offset = offset

func tick(delta: float, pack: Array[Node3D], player: HoverShip) -> void:
    if not active:
        ship.input_accel = false
        ship.input_boost = false
        ship.input_brake = true
        return
    race_time += delta
    contact_cooldown = maxf(0,contact_cooldown-delta)
    lane_timer = maxf(0,lane_timer-delta)
    replan_time -= delta
    boost_cooldown = maxf(0,boost_cooldown-delta)
    if role == "police":
        _police_plan(delta,player)
    var offset := offset_at(ship.position)
    if role != "police":
        _record_progress(offset,delta)
    var lookahead := clampf(18+absf(ship.forward_speed)*0.32,22,53)
    var target := sample(offset+lookahead)
    var next := sample(offset+lookahead+30)
    var along := (next-target).normalized()
    var side := Vector3(along.z,0,-along.x)
    _choose_lane(pack,player,delta,along,side)
    target += side*lane
    var offroad_distance := map.road_distance(ship.position)
    if role == "police" and offroad_distance > 24:
        # Rejoin the nearest road before attempting another interception.
        target = map.closest_road_point(ship.position)+Vector3.UP*2.15
    var to_target := target-ship.position
    var desired := atan2(-to_target.x,-to_target.z)
    var error := wrapf(desired-ship.heading,-PI,PI)
    var near_direction := (sample(offset+8)-sample(offset)).normalized()
    var far_direction := (next-target+side*lane).normalized()
    var bend := absf(near_direction.signed_angle_to(far_direction,Vector3.UP))
    var pace: float = PROFILES[profile].pace*(0.88+0.025*level)
    target_speed = minf(float(HoverShip.CRAFT[ship.craft_index].speed)*pace, sqrt(70.0/maxf(bend/45.0,0.002)))
    if role == "patrol":
        target_speed *= 0.72
    elif role == "police":
        target_speed *= 1.08
    if absf(error) > 0.7:
        target_speed = minf(target_speed,35)
    if absf(error) > 1.4:
        target_speed = 14
    if map.road_distance(ship.position) > 23:
        target_speed = minf(target_speed,30)
    if role == "police":
        target_speed = minf(target_speed,maxf(8,(path_length-offset)*0.65))
    ship.steer_axis = clampf(-error*2.15,-1,1)
    ship.input_drift = bend > 0.6 and ship.forward_speed > 48 and absf(error) < 1.1
    ship.input_brake = ship.forward_speed > target_speed+5
    ship.input_accel = not ship.input_brake
    var clear := _traffic_gap(pack,player) > 22
    var reserve: float = 6.0 if was_boosting else float(PROFILES[profile].reserve)+25.0
    var boosting := role != "patrol" and boost_cooldown <= 0 and bend < 0.22 and absf(error) < 0.16 and clear and ship.boost_fuel > reserve
    var boost_limit: float = HoverShip.CRAFT[ship.craft_index].speed*(1.05+0.08*level)
    if ship.forward_speed > boost_limit:
        boosting = false
    if offroad_distance > 23 or (role == "police" and path_length-offset < 90):
        boosting = false
    ship.input_boost = boosting
    if boosting:
        ship.input_brake = false
        ship.input_accel = true
    if boosting and not was_boosting:
        boosts += 1
    if was_boosting and not boosting:
        boost_cooldown = 0.8
    was_boosting = boosting
    if _traffic_gap(pack,player) < 6:
        ship.input_brake = true
        ship.input_accel = false
        ship.input_boost = false
    _recover(delta,error)
    ship.surface_factor = 0.55 if map.road_distance(ship.position) > 26 else 1.0

func _traffic_gap(pack: Array[Node3D], player: HoverShip) -> float:
    var nearest := INF
    var forward := Vector3(-sin(ship.heading),0,-cos(ship.heading))
    var actors: Array[Node3D] = pack.duplicate()
    if player != null and not actors.has(player):
        actors.append(player)
    for other in actors:
        if other == ship or not other.visible:
            continue
        var relative := other.position-ship.position
        var ahead := relative.dot(forward)
        var lateral := absf(relative.dot(Vector3(forward.z,0,-forward.x)))
        if ahead > 0 and lateral < 4.5:
            nearest = minf(nearest,ahead)
    return nearest

func _choose_lane(pack: Array[Node3D], player: HoverShip, delta: float, forward: Vector3, side: Vector3) -> void:
    if lane_timer <= 0 and _traffic_gap(pack,player) < 32:
        var best_lane := lane
        var best_score := -INF
        var actors: Array[Node3D] = pack.duplicate()
        if player != null and not actors.has(player):
            actors.append(player)
        for candidate in [-8.0,0.0,8.0]:
            var score := 0.0
            for other in actors:
                if other == ship or not other.visible:
                    continue
                var relative := other.position-ship.position
                if absf(relative.dot(forward)) < 38:
                    score -= maxf(0,12-absf(relative.dot(side)-(candidate-lane)))*3
            score -= absf(candidate-lane)*0.2
            if score > best_score:
                best_score = score
                best_lane = candidate
        if absf(best_lane-lane_goal) > 2:
            overtakes += 1
        lane_goal = best_lane
        lane_timer = 1.5
        state = "PASS" if role != "police" else state
    elif lane_timer <= 0:
        lane_goal = PROFILES[profile].lane
        if role != "police":
            state = "FOLLOW" if role == "race" else "PATROL"
    lane = move_toward(lane,lane_goal,delta*5)

func _recover(delta: float, error: float) -> void:
    if absf(ship.forward_speed) < 3 and ship.input_accel:
        stuck_time += delta
    else:
        stuck_time = maxf(0,stuck_time-delta)
    if stuck_time > 1.4 and recovery_time <= 0:
        recovery_time = 1.2
        stuck_time = 0
        recoveries += 1
    if recovery_time > 0:
        recovery_time -= delta
        ship.input_accel = false
        ship.input_boost = false
        ship.input_brake = true
        ship.steer_axis = signf(error)
        state = "RECOVER"

func _police_plan(delta: float, player: HoverShip) -> void:
    var distance := ship.position.distance_to(player.position)
    var visible_target := distance < 180
    if visible_target:
        var query := PhysicsRayQueryParameters3D.create(ship.position,player.position,1)
        query.exclude = [ship.get_rid(),player.get_rid()]
        visible_target = ship.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
    if visible_target:
        seen_age = 0
        last_seen = player.position
    else:
        seen_age += delta
    state = ("INTERCEPT" if profile%2 == 1 and distance > 55 else "CHASE") if visible_target else "SEARCH"
    if replan_time > 0:
        return
    replan_time = 0.7+profile*0.11
    var target := last_seen
    if visible_target:
        # Half the squad follows; half predicts a road interception point.
        if profile%2 == 1 and distance > 55:
            var direction := Vector3(-sin(player.heading),0,-cos(player.heading))
            target = map.closest_road_point(player.position+direction*clampf(player.forward_speed*1.6,45,160))
            state = "INTERCEPT"
        else:
            target = map.closest_road_point(player.position)
    elif seen_age > 4:
        var search_direction := Vector3(cos(seen_age*0.6+profile),0,sin(seen_age*0.6+profile))
        target = map.closest_road_point(last_seen+search_direction*80)
    var points := map.navigation_path(ship.position,target)
    if points.size() < 3:
        return
    var plan := Curve3D.new()
    for point in points:
        plan.add_point(point)
    # Extend through the destination so police do not turn around at a wrap.
    var end_direction := (points[points.size()-1]-points[points.size()-2]).normalized()
    plan.add_point(map.closest_road_point(points[points.size()-1]+end_direction*70))
    path = plan
    path_length = path.get_baked_length()
    last_offset = offset_at(ship.position)
    path_replans += 1
