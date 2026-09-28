extends RefCounted
class_name MissionRules

const NAMES := ["FREE ROAM","BAY SPRINT","COAST CIRCUIT","CHECKPOINT RUSH","PURSUIT","DRIFT RUSH","ELIMINATION","SPEED TRIAL"]
const DETAILS := [
    "Cruise four districts with roaming pilots.",
    "Race two rivals to a short route finish.",
    "One complete lap. Four drivers. Three medals.",
    "Chain gates before the countdown runs out.",
    "Clear the route, then lose the police for six seconds.",
    "Slide through corners. Release to bank the combo.",
    "Every 20 seconds the last pilot is eliminated.",
    "Six speed traps. Hit their targets using boost."
]

static func gate_count(mode: int, length: float) -> int:
    var lap := maxi(8,ceili(length/105.0))
    match mode:
        1: return maxi(6,ceili(lap*0.55))
        2: return lap
        3: return maxi(8,ceili(lap*0.7))
        4: return maxi(6,ceili(lap*0.4))
        7: return 6
    return 0

static func checkpoint_seconds(segment_length: float, level: int) -> float:
    return segment_length/(48.0+level*3.0)

static func drift_target(length: float, level: int) -> float:
    return 1450.0+level*200.0

static func speed_target(level: int, trap: int) -> float:
    return 225.0+level*10.0+trap*7.0

static func medal(mode: int, time: float, distance: float, place: int, score: float, goal: float, heat: float, traps: int) -> int:
    if mode == 1 or mode == 2:
        return 3 if place == 1 else 2 if place <= 3 else 1
    if mode == 5:
        return 3 if score >= goal*1.8 else 2 if score >= goal*1.3 else 1
    if mode == 7:
        return 3 if traps >= 6 else 2 if traps >= 5 else 1
    if mode == 4:
        return 3 if heat < 10 else 2 if heat < 35 else 1
    if mode == 6:
        return 3
    var average := distance/maxf(time,0.01)
    return 3 if average > 85 else 2 if average > 65 else 1
