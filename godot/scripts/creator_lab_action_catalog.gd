extends RefCounted
class_name CreatorLabActionCatalog

const FROZEN_STATES := ["idle", "walk", "dash", "jump", "hurt", "dead"]
const REQUIRED_ACTIONS := [
	{
		"action_id": "idle",
		"category": "utility",
		"state_context": "idle",
		"visual_role": "upright neutral loop",
		"backing": "move:idle",
		"required_this_wave": true,
	},
	{
		"action_id": "walk",
		"category": "locomotion",
		"state_context": "walk",
		"visual_role": "locomotion loop",
		"backing": "move:walk",
		"required_this_wave": true,
	},
		{
			"action_id": "dash",
			"category": "locomotion",
			"state_context": "dash",
			"visual_role": "forward burst pose",
			"backing": "move:dash",
			"required_this_wave": true,
		},
		{
			"action_id": "run",
			"category": "locomotion",
			"state_context": "walk",
			"visual_role": "fast locomotion loop",
			"backing": "move:run",
			"required_this_wave": true,
		},
		{
			"action_id": "turn",
			"category": "locomotion",
			"state_context": "idle",
			"visual_role": "facing change transition",
			"backing": "move:turn",
			"required_this_wave": true,
		},
	{
		"action_id": "jump_start",
		"category": "locomotion",
		"state_context": "jump",
		"visual_role": "takeoff pose",
		"backing": "coverage:jump",
		"required_this_wave": true,
	},
	{
		"action_id": "jump_air",
		"category": "locomotion",
		"state_context": "jump",
		"visual_role": "airborne pose",
		"backing": "coverage:jump",
		"required_this_wave": true,
	},
	{
		"action_id": "jump_land",
		"category": "locomotion",
		"state_context": "jump",
		"visual_role": "landing pose",
		"backing": "coverage:jump",
		"required_this_wave": true,
	},
	{
		"action_id": "basic_punch",
		"category": "combat",
		"state_context": "idle",
		"visual_role": "attack pose",
		"backing": "move:basic_punch",
		"required_this_wave": true,
	},
		{
			"action_id": "basic_kick",
			"category": "combat",
			"state_context": "idle",
			"visual_role": "attack pose",
			"backing": "move:basic_kick",
			"required_this_wave": true,
		},
		{
			"action_id": "heavy_punch",
			"category": "combat",
			"state_context": "idle",
			"visual_role": "heavy attack pose",
			"backing": "move:heavy_punch",
			"required_this_wave": true,
		},
		{
			"action_id": "round_kick",
			"category": "combat",
			"state_context": "idle",
			"visual_role": "wide kick attack pose",
			"backing": "move:round_kick",
			"required_this_wave": true,
		},
		{
			"action_id": "guard",
			"category": "combat",
			"state_context": "idle",
			"visual_role": "defensive hold pose",
			"backing": "move:guard",
			"required_this_wave": true,
		},
	{
		"action_id": "dash_attack",
		"category": "combat",
		"state_context": "dash",
		"visual_role": "context attack pose",
		"backing": "move-or-placeholder:dash_attack",
		"required_this_wave": true,
	},
	{
		"action_id": "jump_attack",
		"category": "combat",
		"state_context": "jump",
		"visual_role": "context attack pose",
		"backing": "move-or-placeholder:jump_attack",
		"required_this_wave": true,
	},
	{
		"action_id": "hurt_light",
		"category": "reaction",
		"state_context": "hurt",
		"visual_role": "short recoil",
		"backing": "coverage-or-move:hurt_light",
		"required_this_wave": true,
	},
	{
		"action_id": "hurt_heavy",
		"category": "reaction",
		"state_context": "hurt",
		"visual_role": "strong recoil",
		"backing": "coverage-or-move:hurt_heavy",
		"required_this_wave": true,
	},
	{
		"action_id": "knockdown",
		"category": "reaction",
		"state_context": "hurt",
		"visual_role": "falling/down pose",
		"backing": "coverage-or-move:knockdown",
		"required_this_wave": true,
	},
	{
		"action_id": "get_up",
		"category": "reaction",
		"state_context": "hurt",
		"visual_role": "rising transition",
		"backing": "coverage-or-move:get_up",
		"required_this_wave": true,
	},
		{
			"action_id": "dead",
			"category": "reaction",
			"state_context": "dead",
			"visual_role": "final defeated pose",
			"backing": "coverage-or-move:dead",
			"required_this_wave": true,
		},
		{
			"action_id": "stun",
			"category": "reaction",
			"state_context": "hurt",
			"visual_role": "stunned loop pose",
			"backing": "move:stun",
			"required_this_wave": true,
		},
		{
			"action_id": "win_pose",
			"category": "utility",
			"state_context": "idle",
			"visual_role": "victory pose",
			"backing": "move:win_pose",
			"required_this_wave": true,
		},
	]


static func required_actions() -> Array:
	return REQUIRED_ACTIONS.duplicate(true)


static func action_ids() -> Array:
	var ids: Array = []
	for entry in REQUIRED_ACTIONS:
		ids.append(str(entry["action_id"]))
	return ids


static func action_for(action_id: String) -> Dictionary:
	for entry in REQUIRED_ACTIONS:
		if str(entry["action_id"]) == action_id:
			return entry.duplicate(true)
	return {}


static func backing_move_id(entry: Dictionary) -> String:
	var backing := str(entry.get("backing", ""))
	var parts := backing.split(":", false, 1)
	if parts.size() < 2:
		return ""
	return str(parts[1])


static func backing_kind(entry: Dictionary) -> String:
	var backing := str(entry.get("backing", ""))
	var parts := backing.split(":", false, 1)
	if parts.is_empty():
		return ""
	return str(parts[0])


static func visual_role_for(action_id: String) -> String:
	return str(action_for(action_id).get("visual_role", ""))


static func validate() -> Array:
	var errors: Array = []
	var seen := {}
	for entry in REQUIRED_ACTIONS:
		var action_id := str(entry.get("action_id", ""))
		if action_id.is_empty():
			errors.append("catalog action_id missing")
		if seen.has(action_id):
			errors.append("duplicate catalog action_id %s" % action_id)
		seen[action_id] = true
		if not FROZEN_STATES.has(str(entry.get("state_context", ""))):
			errors.append("%s has invalid state_context %s" % [action_id, str(entry.get("state_context", ""))])
		if str(entry.get("visual_role", "")).strip_edges().is_empty():
			errors.append("%s has missing visual_role" % action_id)
		if not bool(entry.get("required_this_wave", false)):
			errors.append("%s is not required_this_wave" % action_id)
	return errors
