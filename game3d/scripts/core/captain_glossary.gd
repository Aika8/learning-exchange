## «Словарь капитана»: the in-game glossary fills up as lessons introduce terms (world bible §6). Terms come from
## `GET /bff/game/glossary` (docs/lore/glossary.yaml, ADR-0012); the book only keeps which ids are unlocked, in order.
class_name CaptainGlossary
extends RefCounted

signal unlocked(id: String)

var terms: Dictionary = {}  ## id → GlossaryTerm {id, real{ru,en}, lore{ru,en}, definition{ru,en}}
var opened: Array[String] = []


func load_terms(list: Array) -> void:
	for t: Variant in list:
		if t is Dictionary and (t as Dictionary).has("id"):
			terms[str(t["id"])] = t


## Unlocks a term; returns true the first time. Unknown ids are kept too (the server list may arrive later).
func unlock(id: String) -> bool:
	if opened.has(id):
		return false
	opened.append(id)
	unlocked.emit(id)
	return true


func unlock_all(ids: Array) -> Array[String]:
	var fresh: Array[String] = []
	for id: Variant in ids:
		if unlock(str(id)):
			fresh.append(str(id))
	return fresh


## Rows for the book in a locale: [{id, real, lore, definition}], unlocked order, unknown ids skipped.
func rows(locale: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in opened:
		if not terms.has(id):
			continue
		var t: Dictionary = terms[id]
		out.append({"id": id, "real": _pick(t.get("real", {}), locale), "lore": _pick(t.get("lore", {}), locale),
			"definition": _pick(t.get("definition", {}), locale)})
	return out


func real_name(id: String, locale: String) -> String:
	return _pick(terms.get(id, {}).get("real", {}), locale) if terms.has(id) else id


static func _pick(names: Variant, locale: String) -> String:
	if names is Dictionary:
		return str(names.get(locale, names.get("ru", "")))
	return ""
