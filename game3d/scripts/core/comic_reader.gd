## Pattern: Iterator — a cursor over one talk. A step shows the next balloon; when a panel has said everything the
## next panel appears; when the page is full the next page starts. See docs/adr/0027-game3d-talk-as-comic-pages.md
class_name ComicReader
extends RefCounted

var _beats: Array[Vector3i] = []  ## (page, panel, balloons shown in that panel)
var _at := 0
var _pages: Array = []


func _init(talk: Dictionary) -> void:
	_pages = talk.get("pages", [])
	for p in _pages.size():
		var panels: Array = _pages[p].get("panels", [])
		for q in panels.size():
			var lines: Array = panels[q].get("lines", [])
			for n in range(1, maxi(lines.size(), 1) + 1):
				_beats.append(Vector3i(p, q, mini(n, lines.size())))


func pages() -> int:
	return _pages.size()


func page() -> int:
	return _beats[_at].x if not _beats.is_empty() else 0


func panels() -> Array:
	return _pages[page()].get("panels", []) if not _pages.is_empty() else []


## How many balloons of panel `index` of the current page are shown: −1 = the panel is not drawn yet.
func shown(index: int) -> int:
	var b := _beats[_at]
	if index > b.y:
		return -1
	if index == b.y:
		return b.z
	return (panels()[index].get("lines", []) as Array).size()


func last() -> bool:
	return _at >= _beats.size() - 1


## True when the next step turns the page or ends the talk.
func page_full() -> bool:
	return last() or _beats[_at + 1].x != _beats[_at].x


## Moves on; false when the talk is over.
func step() -> bool:
	if last():
		return false
	_at += 1
	return true
