extends SceneTree
## Unmodified-roster survival baseline. Uses production map, encounter, battle,
## capture, chest and home APIs. Story interactions are not automated here;
## skipped arrivals are counted, not presented as a full-game completion.
const Session = preload("res://systems/run_session.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const TRIALS = 100
const MAX_LAPS = 100
const MAX_ROLLS = 1000
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var lap_total := 0
	var defeats := 0
	var reached_boss := 0
	var boss_wins := 0
	var boss_runs := 0
	var completed_runs := 0
	var failures := 0
	var skipped_events := 0
	var inherit_success := 0
	var patrol_success := 0
	var reward_discards := 0
	for trial in range(TRIALS):
		var session = Session.new()
		session.save_file_path = "user://natural_survival_%d_%d.json" % [OS.get_process_id(),trial]
		root.add_child(session)
		session.start_new_world()
		var world = session.world
		world.rng.seed = 88000 + trial
		var battle_count := 0
		var boss_attempted := false
		for roll_index in range(MAX_ROLLS):
			if not world.run_result.is_empty() or world.laps >= MAX_LAPS: break
			if world.position == 15 and world.lap_ready:
				if not session.enter_home():
					failures += 1
					break
				# Only inherit a legitimately acquired brand card; never mint materials.
				if world.roster.size()>0 and world.brand_cards.size()>0:
					var receiver: Dictionary = {}
					for candidate in world.roster:
						if candidate.brands.size()<3:
							receiver = candidate
							break
					if not receiver.is_empty():
						var inherited: Dictionary = session.inherit_at_home(str(receiver.id),"",str(world.brand_cards[0].id))
						if inherited.get("ok",false): inherit_success += 1
				# Legal, explicit patrol choice. Rest requires an actual unlock.
				var plan: Dictionary = world.patrol_plan.duplicate(true)
				if plan.has("selection"):
					plan.selection["monster"] = 1
					plan.selection["rest"] = 1 if plan.get("rest_unlocked",false) else 0
					var confirmed: Dictionary = session.confirm_patrol(plan)
					if confirmed.get("ok",false): patrol_success += 1
				if not session.leave_home():
					failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
					break
				continue
			var movement: Dictionary = session.prepare_map_roll()
			if not movement.get("ok",false) or not session.complete_map_move():
				failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
				break
			var tile: String = str(world.tiles[world.position])
			if tile=="gem" and world.pending_reward.is_empty():
				session.open_treasure(world.position)
			var mimic: bool = world.pending_reward.get("kind","")=="mimic"
			if (tile in ["monster","rare-monster","boss"] and not world.position in world.cleared) or mimic:
				var ids: Array = []
				var healthy: Array = world.roster.filter(func(u): return int(u.current_hp)>0)
				healthy.sort_custom(func(a,b): return int(a.attack)>int(b.attack))
				for i in range(mini(4,healthy.size())): ids.append(str(healthy[i].id))
				if ids.is_empty():
					failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
					break
				if tile=="boss":
					reached_boss += 1
					boss_attempted = true
				if not session.start_encounter(world.position,ids):
					failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
					break
				var battle = Rules.new(world.definitions,88000+trial*1000+battle_count)
				if not battle.restore(session.encounter.checkpoint):
					failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
					break
				for round_index in range(100):
					if not battle.winner().is_empty(): break
					battle.begin_round()
					for action_index in range(100):
						if battle.next_action().is_empty(): break
				var result: String = battle.winner()
				if result.is_empty() or not session.finish_encounter(battle):
					failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
					break
				battle_count += 1
				if tile=="boss" and result=="ally": boss_wins += 1
				if result=="enemy":
					defeats += 1
					break
				if not world.pending_reward.is_empty() and world.pending_reward.get("kind","")=="capture":
					if not session.select_capture(0):
						failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
						break
					var capture: Dictionary = session.roll_capture()
					if not capture.get("ok",false):
						failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
						break
					if capture.success:
						var claimed: Dictionary = session.claim_reward(str(world.roster[0].id) if world.roster.size()>=8 else "")
						if not claimed.get("ok",false): failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position); break
					else:
						while world.pending_reward.get("phase","")=="retry":
							var retried: Dictionary = session.roll_capture()
							if not retried.get("ok",false):
								failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
								break
						if world.pending_reward.get("phase","")=="success":
							if not session.claim_reward("__new__" if world.roster.size()>=8 else "").get("ok",false): failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position); break
						elif world.pending_reward.get("phase","")=="failed":
							if not session.dismiss_failed_capture(): failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position); break
			elif tile=="gem":
				if world.pending_reward.get("kind","")=="treasure":
					var offers: Array = world.pending_reward.offers
					var chosen := 0
					for i in range(offers.size()):
						if str(offers[i].kind)=="unit" and world.roster.size()<4: chosen=i; break
					if not session.select_treasure(chosen) or not session.prepare_treasure_reward(chosen):
						failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
						break
					var pending: Dictionary = world.pending_reward
					var kind: String = str(pending.reward.kind)
					var capacity: int = 8 if kind=="unit" else (5 if kind=="dice" else 0)
					var inventory: int = world.roster.size() if kind=="unit" else (world.dice_cards.size() if kind=="dice" else world.brand_cards.size())
					if not session.claim_reward((str(world.roster[0].id) if kind=="unit" else str(world.dice_cards[0].id)) if capacity>0 and inventory>=capacity else "").get("ok",false):
						failures += 1; printerr("SURVIVAL FAIL trial=",trial," roll=",roll_index," line=",get_stack()[0].get("line",-1)," pending=",world.pending_reward.get("kind","")," phase=",world.pending_reward.get("phase","")," pos=",world.position)
						break
			elif tile in ["event","forest","altar","village","graveyard","unknown","fortune-teller-camp"]:
				skipped_events += 1
		if boss_attempted: boss_runs += 1
		if world.run_result.is_empty() and world.laps>=MAX_LAPS: completed_runs += 1
		lap_total += world.laps
		print("SURVIVAL trial=",trial," laps=",world.laps," battles=",battle_count," roster=",world.roster.size()," contamination=",world.contamination," boss_attempted=",boss_attempted," ended=",not world.run_result.is_empty())
		for suffix in ["",".tmp"]:
			var p: String = session.save_file_path + suffix
			if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		session.queue_free()
	print("SURVIVAL trials=",TRIALS," mean_laps=",float(lap_total)/TRIALS," defeats=",defeats," boss_encounters=",reached_boss," boss_runs=",boss_runs," boss_wins=",boss_wins," skipped_event_arrivals=",skipped_events," max_laps_reached=",completed_runs," inherited=",inherit_success," patrols=",patrol_success," failures=",failures)
	quit(0 if failures==0 else 1)
