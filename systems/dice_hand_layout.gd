extends RefCounted
## Mirror the existing lower monster hand: deal from the right deck to the left.
const CARD_SIZE := Vector2(136,218)
const RIGHT_EDGE := 1120.0
const LEFT_MARGIN := 24.0
const MAX_STEP := 90.0
const BOTTOM_TUCK := 10.0
const HOVER_LIFT := 26.0
static func position_for(index: int, count: int, height: float) -> Vector2:
	var gap := minf(MAX_STEP,(RIGHT_EDGE-CARD_SIZE.x-LEFT_MARGIN)/maxi(1,count-1))
	return Vector2(RIGHT_EDGE-CARD_SIZE.x-index*gap,maxf(0.0,height-CARD_SIZE.y+BOTTOM_TUCK)-minf(float(index),5.0)*2.0)
static func rotation_for(index: int, count: int) -> float:
	return 0.0 if count<=1 else lerpf(-3.0,4.0,float(index)/float(count-1))
static func base_z(index: int) -> int:
	return index+1
