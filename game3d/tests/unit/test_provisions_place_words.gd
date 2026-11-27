## LE-407: the texts that send the player to the provisions crates name the place the crates really stand by —
## the named harbour spot nearest to HARBOUR_SPOTS["provisions"] in the code — and no other one.
extends GutTest

const HARBOUR := preload("res://scripts/harbour.gd")

## Keys spoken about the crates, and whether Mara herself says them (then "by Mara" reads "next to me").
const KEYS := {
	"GOAL_BUY_PROVISIONS": false,
	"FLOW_NEED_PROVISIONS": false,
	"MARA_PROVISIONS_FIRST": true,
	"TALK_MARA_FIRST_6": true,
}

## How each spot that could stand next to the crates is named: [ru, en].
const PLACE_WORDS := {
	"mara": ["Мар", "Mara"],
	"mara_self": ["рядом со мной", "next to me"],
	"ship": ["причал", "pier"],
	"debt": ["сундук", "chest"],
	"ferry": ["пакетбот", "packet boat"],
}


func _nearest_spot() -> String:
	var at: Vector3 = HARBOUR.HARBOUR_SPOTS["provisions"][0]
	var best := ""
	var best_d := INF
	for id: String in HARBOUR.HARBOUR_SPOTS:
		if id == "provisions":
			continue
		var d: float = at.distance_to(HARBOUR.HARBOUR_SPOTS[id][0])
		if d < best_d:
			best_d = d
			best = id
	return best


## The [ru, en] of a key, read from the row that starts with it in strings.csv or talk.csv.
func _texts(key: String) -> Array:
	for path: String in ["res://i18n/strings.csv", "res://i18n/talk.csv"]:
		var f := FileAccess.open(path, FileAccess.READ)
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() >= 3 and row[0] == key:
				return [row[1], row[2]]
	return []


func test_the_nearest_spot_has_a_name_in_the_words() -> void:
	assert_has(PLACE_WORDS, _nearest_spot(), "no words for the spot nearest to the crates: " + _nearest_spot())


func test_provisions_texts_name_the_nearest_spot() -> void:
	var nearest := _nearest_spot()
	if not PLACE_WORDS.has(nearest):
		return
	for key: String in KEYS:
		var texts := _texts(key)
		assert_eq(texts.size(), 2, "no ru/en row for " + key)
		if texts.size() != 2:
			continue
		var place: String = nearest + "_self" if KEYS[key] and PLACE_WORDS.has(nearest + "_self") else nearest
		for i: int in 2:
			assert_string_contains(texts[i], PLACE_WORDS[place][i], false)


func test_provisions_texts_name_no_other_spot() -> void:
	var nearest := _nearest_spot()
	for key: String in KEYS:
		var texts := _texts(key)
		for spot: String in PLACE_WORDS:
			if spot == nearest or spot == nearest + "_self" or spot.begins_with("mara"):
				continue  # Mara's lines start with her name; "Mara" alone is no place
			for i: int in texts.size():
				assert_false(texts[i].to_lower().contains(PLACE_WORDS[spot][i].to_lower()),
					"%s names %s, but the crates stand by %s" % [key, spot, nearest])
