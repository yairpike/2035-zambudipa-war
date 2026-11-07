class_name SMSave
extends RefCounted
## Finished story missions, one id per line in user://campaign.save.

const PATH: String = "user://campaign.save"
const IDB_JS: String = "(function(payload){if(!self.indexedDB)return;var openReq=indexedDB.open('asean2031',1);openReq.onupgradeneeded=function(){if(!openReq.result.objectStoreNames.contains('saves'))openReq.result.createObjectStore('saves');};openReq.onsuccess=function(){var tx=openReq.result.transaction('saves','readwrite');tx.objectStore('saves').put(payload,'campaign');};})(%s);"
const PULL_JS: String = "(function(){window.__campaignReady=false;window.__campaignSave='';if(!self.indexedDB){window.__campaignReady=true;return;}var openReq=indexedDB.open('asean2031',1);openReq.onupgradeneeded=function(){if(!openReq.result.objectStoreNames.contains('saves'))openReq.result.createObjectStore('saves');};openReq.onerror=function(){window.__campaignReady=true;};openReq.onsuccess=function(){try{var tx=openReq.result.transaction('saves','readonly');var req=tx.objectStore('saves').get('campaign');req.onerror=function(){window.__campaignReady=true;};req.onsuccess=function(){var v=req.result;window.__campaignSave=(v==null)?'':String(v);window.__campaignReady=true;};}catch(e){window.__campaignReady=true;}};})();"

static var _web_pull: bool = false
static var _web_done: bool = false

static func clear() -> void:
	var abs_path: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(abs_path)

static func finished() -> PackedStringArray:
	if not FileAccess.file_exists(PATH):
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PATH).split("\n", false):
		var id: String = line.strip_edges()
		if id != "" and not out.has(id):
			out.append(id)
	return out

static func has(id: String) -> bool:
	return finished().has(id)

static func mark(id: String) -> void:
	if id == "" or not SMCampaign.ids().has(id) or has(id):
		return
	var have: PackedStringArray = finished()
	have.append(id)
	var handle: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if handle == null:
		return
	for item: String in have:
		handle.store_line(item)
	handle.close()
	_mirror_web(have)

static func idb_script() -> String:
	return IDB_JS

static func pull_web() -> void:
	if not OS.has_feature("web") or _web_pull or _web_done:
		return
	_web_pull = true
	JavaScriptBridge.eval(PULL_JS)

static func poll_web() -> bool:
	if not OS.has_feature("web"):
		return true
	if _web_done:
		return true
	if not _web_pull:
		pull_web()
		return false
	if not bool(JavaScriptBridge.eval("window.__campaignReady===true")):
		return false
	apply_payload(str(JavaScriptBridge.eval("String(window.__campaignSave||'')")))
	_web_done = true
	return true

static func apply_payload(raw: String) -> void:
	var text: String = raw.strip_edges()
	if text == "":
		return
	var head: String = text.substr(0, 1)
	if head != "[" and head != "{" and head != "\"":
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed is String:
		var inner: String = str(parsed).strip_edges()
		if inner == "":
			return
		var inner_head: String = inner.substr(0, 1)
		if inner_head != "[" and inner_head != "{":
			return
		parsed = JSON.parse_string(inner)
	if not (parsed is Array):
		return
	var rows: Array = parsed as Array
	var have: PackedStringArray = finished()
	var changed: bool = false
	for item: Variant in rows:
		var id: String = str(item).strip_edges()
		if id != "" and SMCampaign.ids().has(id) and not have.has(id):
			have.append(id)
			changed = true
	if not changed:
		return
	var handle: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if handle == null:
		return
	for item: String in have:
		handle.store_line(item)
	handle.close()

static func _mirror_web(have: PackedStringArray) -> void:
	if not OS.has_feature("web"):
		return
	var payload: String = JSON.stringify(have)
	var js: String = IDB_JS % JSON.stringify(payload)
	JavaScriptBridge.eval(js)
