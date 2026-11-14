## Language button: switches the locale and follows it (a method, not a lambda, so the connection dies with the button).
class_name LangButton
extends Button

var code := "ru"


func _init(locale_code: String) -> void:
	code = locale_code
	text = "LANG_" + code.to_upper()
	toggle_mode = true
	name = "Lang_" + code


func _ready() -> void:
	button_pressed = Locale.current() == code
	pressed.connect(func() -> void: Locale.set_locale(code))
	Locale.locale_changed.connect(_on_locale)


func _on_locale(c: String) -> void:
	set_pressed_no_signal(c == code)
