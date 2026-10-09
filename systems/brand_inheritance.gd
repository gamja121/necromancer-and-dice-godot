extends RefCounted

const TYPES = ["critical","vampire","combo","freeze","poison","guard","summon","counter","healing","lightspeed"]

static func validate(brand) -> bool:
	if not brand is Dictionary or not str(brand.get("type","")) in TYPES: return false
	if not brand.get("bless") is Array or not brand.get("curse") is Array: return false
	if brand.bless.size()>2 or brand.curse.size()>1 or brand.bless.size()+brand.curse.size()==0: return false
	var seen: Array = []
	for value in brand.bless+brand.curse:
		if not (value is int or value is float) or float(value)!=floor(float(value)): return false
		var face = int(value)
		if face<1 or face>6 or face in seen: return false
		seen.append(face)
	return true

static func normalize(unit: Dictionary, definitions: Dictionary) -> Array:
	var cleaned: Array = []
	for brand in unit.get("brands",[]):
		if validate(brand):
			cleaned.append({"type":str(brand.type),"bless":brand.bless.map(func(n): return int(n)),"curse":brand.curse.map(func(n): return int(n))})
	if cleaned.is_empty(): return []
	var base_types: Array = definitions.get(unit.get("slug",""),{}).get("brands",[])
	var base_curse: Array = cleaned[0].curse if cleaned[0].type in base_types else []
	var result: Array = []
	for i in range(cleaned.size()):
		if result.size()>=3: break
		var brand: Dictionary = cleaned[i].duplicate(true)
		brand.bless = brand.bless.filter(func(n): return not n in base_curse)
		brand.curse = base_curse.duplicate() if i==0 else []
		if not brand.bless.is_empty() or not brand.curse.is_empty(): result.append(brand)
	return result

static func blessing(receiver: Dictionary, source: Dictionary, definitions: Dictionary) -> Dictionary:
	if not validate(source): return {}
	var cursed: Array = []
	for brand in normalize(receiver,definitions): cursed.append_array(brand.curse)
	var faces: Array = source.bless.map(func(n): return int(n)).filter(func(n): return not n in cursed)
	faces.sort()
	return {} if faces.is_empty() else {"type":str(source.type),"bless":faces,"curse":[]}
