class_name AIClient
extends Node

signal response_received(result: Dictionary)
signal error_occurred(error_message: String)

enum Provider { OLLAMA, OPENAI }

var provider: Provider = Provider.OLLAMA
var base_url: String = "http://localhost:11434"
var api_key: String = ""
var model: String = "qwen2.5:3b"
var _http_request: HTTPRequest

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 120
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func configure_ollama(url: String = "http://localhost:11434", model_name: String = "qwen2.5:3b") -> void:
	provider = Provider.OLLAMA
	base_url = url
	model = model_name

func configure_openai(key: String, model_name: String = "gpt-4o-mini", url: String = "https://api.openai.com/v1") -> void:
	provider = Provider.OPENAI
	api_key = key
	model = model_name
	base_url = url

func chat(messages: Array, format: Variant = null) -> void:
	match provider:
		Provider.OLLAMA:
			_chat_ollama(messages, format)
		Provider.OPENAI:
			_chat_openai(messages, format)

func check_health() -> void:
	if provider == Provider.OLLAMA:
		var err := _http_request.request(base_url + "/api/version")
		if err != OK:
			error_occurred.emit("无法连接到 Ollama，请确认 Ollama 已启动。")
	else:
		response_received.emit({"status": "openai_configured"})

func list_models() -> void:
	if provider == Provider.OLLAMA:
		var err := _http_request.request(base_url + "/api/tags")
		if err != OK:
			error_occurred.emit("无法获取模型列表。")
	else:
		response_received.emit({"models": [{"name": model}]})

func _chat_ollama(messages: Array, format: Variant) -> void:
	var body: Dictionary = {
		"model": model,
		"messages": messages,
		"stream": false,
	}
	if format != null:
		body["format"] = format

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := base_url + "/api/chat"

	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		error_occurred.emit("Ollama 请求失败，错误码: %s" % err)

func _chat_openai(messages: Array, format: Variant) -> void:
	var body: Dictionary = {
		"model": model,
		"messages": messages,
	}
	if format != null and format is Dictionary:
		body["response_format"] = {"type": "json_schema", "json_schema": {"name": "response", "schema": format}}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
	])
	var url := base_url + "/chat/completions"

	var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		error_occurred.emit("OpenAI 请求失败，错误码: %s" % err)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		error_occurred.emit("网络请求失败 (result: %s)" % result)
		return

	var body_text := body.get_string_from_utf8()

	if response_code != 200:
		error_occurred.emit("服务器返回 %s: %s" % [response_code, body_text.substr(0, 200)])
		return

	var json := JSON.new()
	if json.parse(body_text) != OK:
		error_occurred.emit("JSON 解析失败")
		return

	var data: Dictionary = json.data
	var normalized := _normalize_response(data)
	response_received.emit(normalized)

func _normalize_response(data: Dictionary) -> Dictionary:
	match provider:
		Provider.OLLAMA:
			return {
				"content": String(data.get("message", {}).get("content", "")),
				"model": String(data.get("model", "")),
				"done": bool(data.get("done", true)),
				"raw": data,
			}
		Provider.OPENAI:
			var choices: Array = data.get("choices", [])
			var content := ""
			if not choices.is_empty():
				content = String(choices[0].get("message", {}).get("content", ""))
			return {
				"content": content,
				"model": String(data.get("model", "")),
				"done": true,
				"raw": data,
			}
		_:
			return {"content": "", "model": "", "done": true, "raw": data}

func generate_game_logic(prompt: String, object_data: Dictionary) -> void:
	var system_msg := """你是 Lite2D Studio 的 AI 游戏逻辑助手。用户会描述想要的游戏行为，你需要返回 JSON 格式的对象属性更新。

当前对象数据：
%s

请返回如下 JSON 格式：
{
  "updates": {
    "属性路径": 值,
    "behaviors/movement": {"enabled": true, "speed": 120.0, ...}
  },
  "notes": ["给用户的说明1", "给用户的说明2"]
}

只返回 JSON，不要其他内容。""" % JSON.stringify(object_data, "  ")

	var messages := [
		{"role": "system", "content": system_msg},
		{"role": "user", "content": prompt},
	]

	var schema: Dictionary = {
		"type": "object",
		"properties": {
			"updates": {"type": "object"},
			"notes": {"type": "array", "items": {"type": "string"}},
		},
		"required": ["updates", "notes"],
	}

	chat(messages, schema)
