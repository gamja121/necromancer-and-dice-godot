extends Translation
## Display-only catalog. Source strings, unit IDs and save receipts stay canonical.
const CATALOG = "res://data/localization/en.json"
const CACHE_LIMIT = 4096
var catalog: Dictionary = {}
var patterns: Array[Dictionary] = []
var fragments: Array[String] = []
var cache: Dictionary = {}
var private_names: Dictionary = {}
var private_signature := ""
var placeholder := RegEx.new()

func _init() -> void:
	set_locale("en")
	placeholder.compile("%(?:[-+0 #]*[0-9]*(?:\\.[0-9]+)?[sdf]|%)")
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if data is Dictionary: catalog = data
	for key in catalog:
		var source := str(key)
		var slots := placeholder.search_all(source)
		var has_value := false
		for slot in slots:
			if slot.get_string()!="%%": has_value=true
		if has_value:
			var expression := "^"
			var cursor := 0
			var weight := source.length()
			for slot in slots:
				expression += escape_pattern(source.substr(cursor,slot.get_start()-cursor))
				var token := slot.get_string()
				if token=="%%": expression += "%"
				elif token.ends_with("s"): expression += "([\\s\\S]*?)"
				elif token.ends_with("d"): expression += "([-+]?\\d+)"
				else: expression += "([-+]?\\d+(?:\\.\\d+)?)"
				weight -= token.length()
				cursor = slot.get_end()
			expression += escape_pattern(source.substr(cursor))+"$"
			var regex := RegEx.new()
			if regex.compile(expression)==OK:
				var inline_regex := RegEx.new()
				inline_regex.compile(expression.substr(1,expression.length()-2))
				patterns.append({"regex":regex,"inline":inline_regex,"numeric":not source.contains("%s"),"target":str(catalog[key]),"weight":weight})
		elif source.length()>1 and has_korean(source): fragments.append(source)
	patterns.sort_custom(func(a,b): return int(a.weight)>int(b.weight))
	fragments.sort_custom(func(a,b): return a.length()>b.length())

static func has_korean(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if (code>=0xAC00 and code<=0xD7A3) or (code>=0x3130 and code<=0x318F): return true
	return false

static func escape_pattern(value: String) -> String:
	var result := ""
	for character in value:
		if character in ["\\",".","^","$","*","+","?","(",")","[","]","{","}","|"]: result += "\\"
		result += character
	return result

func _get_message(source: StringName, _context: StringName = &"") -> StringName:
	refresh_private_names()
	return StringName(translate_message(str(source)))

func translate_message(source: String, depth: int = 0) -> String:
	if depth>0 and private_names.has(source): return source
	if catalog.has(source): return str(catalog[source])
	if not has_korean(source) or depth>4: return source
	if cache.has(source): return str(cache[source])
	var result := source
	for pattern in patterns:
		var matched: RegExMatch = pattern.regex.search(source)
		if matched==null: continue
		var target: String = pattern.target
		var cursor := 0
		var group := 1
		result = ""
		for slot in placeholder.search_all(target):
			result += target.substr(cursor,slot.get_start()-cursor)
			if slot.get_string()=="%%": result += "%"
			else:
				result += translate_message(matched.get_string(group),depth+1)
				group += 1
			cursor = slot.get_end()
		result += target.substr(cursor)
		break
	if result==source:
		# Joined effect summaries and multi-line tooltips reuse catalog phrases.
		for pattern in patterns:
			if not pattern.numeric: continue
			for _iteration in range(16):
				var piece: RegExMatch=pattern.inline.search(result)
				if piece==null: break
				var translated := translate_message(piece.get_string(),depth+1)
				if translated==piece.get_string(): break
				result=result.left(piece.get_start())+translated+result.substr(piece.get_end())
		for phrase in fragments:
			if result.contains(phrase): result=result.replace(phrase,str(catalog[phrase]))
	if cache.size()>=CACHE_LIMIT: cache.clear()
	cache[source]=result
	return result


func refresh_private_names() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree==null: return
	var session := tree.root.get_node_or_null("RunSession")
	var names: Dictionary={}
	if session!=null and session.world!=null:
		for unit in session.world.roster:
			if unit.has("nickname"): names[str(unit.nickname)]=true
	var signature := str(names)
	if signature!=private_signature:
		private_signature=signature
		private_names=names
		cache.clear()
