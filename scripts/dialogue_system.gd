class_name DialogueSystem
extends RefCounted

## Multi-turn branching dialogue data model.
## Each dialogue is a tree of nodes — text, choices, set-flag, end.

enum NodeType {
	TEXT,       # Display speaker text, then advance to next
	CHOICE,     # Show multiple options for user to pick
	SET_FLAG,   # Set a global flag and continue
	CONDITION,  # Branch based on a flag
	END,        # End dialogue
}

static func create_dialogue(title: String = "") -> Dictionary:
	return {
		"id": "dlg_%s" % Time.get_ticks_msec(),
		"title": title,
		"start_node": "node_0",
		"nodes": {
			"node_0": create_text_node("角色", "你好！"),
		},
	}

static func create_text_node(speaker: String, text: String, next_id: String = "", portrait: String = "") -> Dictionary:
	return {
		"type": NodeType.TEXT,
		"speaker": speaker,
		"text": text,
		"portrait": portrait,
		"next": next_id,
	}

static func create_choice_node(prompt_text: String, choices: Array[Dictionary] = []) -> Dictionary:
	return {
		"type": NodeType.CHOICE,
		"prompt": prompt_text,
		"choices": choices,
	}

static func create_choice_option(label: String, next_id: String = "") -> Dictionary:
	return {"label": label, "next": next_id}

static func create_set_flag_node(flag_name: String, value: bool = true, next_id: String = "") -> Dictionary:
	return {
		"type": NodeType.SET_FLAG,
		"flag": flag_name,
		"value": value,
		"next": next_id,
	}

static func create_condition_node(flag_name: String, true_next: String = "", false_next: String = "") -> Dictionary:
	return {
		"type": NodeType.CONDITION,
		"flag": flag_name,
		"true_next": true_next,
		"false_next": false_next,
	}

static func create_end_node() -> Dictionary:
	return {"type": NodeType.END}

# --- Helpers ---

static func add_node(dialogue: Dictionary, node_id: String, node_data: Dictionary) -> void:
	dialogue["nodes"][node_id] = node_data

static func next_node_id(dialogue: Dictionary) -> String:
	return "node_%s" % dialogue["nodes"].size()

## Build a simple linear dialogue from text array.
## texts: Array of [speaker, text] pairs.
static func build_linear(title: String, texts: Array) -> Dictionary:
	var dlg := create_dialogue(title)
	dlg["nodes"] = {}
	for i in texts.size():
		var pair = texts[i]
		var speaker: String = pair[0] if pair is Array and pair.size() > 0 else "???"
		var text: String = pair[1] if pair is Array and pair.size() > 1 else ""
		var next_id := "node_%d" % (i + 1) if i < texts.size() - 1 else ""
		dlg["nodes"]["node_%d" % i] = create_text_node(speaker, text, next_id)
	dlg["start_node"] = "node_0"
	return dlg

## Build a dialogue with one choice branch.
static func build_with_choice(title: String, intro_speaker: String, intro_text: String, choice_prompt: String, options: Array) -> Dictionary:
	var dlg := create_dialogue(title)
	dlg["nodes"] = {}
	dlg["nodes"]["node_0"] = create_text_node(intro_speaker, intro_text, "node_1")
	var choices: Array[Dictionary] = []
	for i in options.size():
		var opt = options[i]
		var label: String = opt[0] if opt is Array else String(opt)
		var response: String = opt[1] if opt is Array and opt.size() > 1 else ""
		var response_id := "resp_%d" % i
		choices.append(create_choice_option(label, response_id))
		dlg["nodes"][response_id] = create_text_node(intro_speaker, response)
	dlg["nodes"]["node_1"] = create_choice_node(choice_prompt, choices)
	dlg["start_node"] = "node_0"
	return dlg
