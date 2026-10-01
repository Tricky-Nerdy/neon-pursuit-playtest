extends RefCounted
# Authored subjects, rather than arbitrary free-roam spawn points.
const VIEWS := [
    {"name":"coast-day", "road":0, "near":Vector3(180,0,465)},
    {"name":"harbor-day", "road":0, "near":Vector3(0,0,470), "camera":Vector3(-130,95,705), "target":Vector3(-35,5,555)},
    {"name":"canyon-day", "road":2, "near":Vector3(-235,0,-175), "reverse":true},
    {"name":"airfield-day", "road":3, "near":Vector3(-325,0,300), "camera":Vector3(-385,100,430), "target":Vector3(-230,18,255)},
    {"name":"coast-night", "road":0, "near":Vector3(180,0,465), "night":true},
    {"name":"world-map", "road":0, "near":Vector3(180,0,465), "camera":Vector3(0,1450,180), "target":Vector3(0,0,-150)}
]

static func road_pose(world, view: Dictionary) -> Transform3D:
    var road: Curve3D = world.roads[view.road]
    var offset := road.get_closest_offset(view.near)
    var at := road.sample_baked(offset, true)
    var next := road.sample_baked(minf(offset + 5.0, road.get_baked_length()), true)
    var direction := next - at
    if view.get("reverse", false):
        direction = -direction
    var heading := atan2(-direction.x, -direction.z)
    return Transform3D(Basis(Vector3.UP, heading), at + Vector3.UP * 2.15)
