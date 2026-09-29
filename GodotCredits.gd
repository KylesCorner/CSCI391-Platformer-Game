extends Control


@export var fade_time: float = 0.75


func _ready() -> void:
	#
	# Fill the entire viewport.
	#
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	#
	# Hidden until the player dies.
	#
	visible = false


func _build_ui() -> void:
	#
	# ============================================================
	# BACKGROUND
	# ============================================================
	#
	var background := ColorRect.new()

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.color = Color(
		0.015,
		0.015,
		0.02,
		0.97
	)

	add_child(background)


	#
	# ============================================================
	# CENTER EVERYTHING
	# ============================================================
	#
	var center := CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.add_child(center)


	#
	# ============================================================
	# MAIN PANEL
	# ============================================================
	#
	var panel := PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		500.0,
		460.0
	)

	center.add_child(panel)


	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color(
		0.06,
		0.06,
		0.075,
		1.0
	)

	panel_style.border_color = Color(
		0.28,
		0.28,
		0.34,
		1.0
	)

	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2

	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12

	panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)


	#
	# ============================================================
	# PANEL PADDING
	# ============================================================
	#
	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		50
	)

	margin.add_theme_constant_override(
		"margin_right",
		50
	)

	margin.add_theme_constant_override(
		"margin_top",
		40
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		40
	)

	panel.add_child(margin)


	#
	# ============================================================
	# VERTICAL CONTENT
	# ============================================================
	#
	var content := VBoxContainer.new()

	content.alignment = BoxContainer.ALIGNMENT_CENTER

	content.add_theme_constant_override(
		"separation",
		10
	)

	margin.add_child(content)


	#
	# ============================================================
	# TITLE
	# ============================================================
	#
	var title := Label.new()

	title.text = "CRAPPY PLATFORMER"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		34
	)

	content.add_child(title)


	var subtitle := Label.new()

	subtitle.text = "CREDITS"

	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle.add_theme_font_size_override(
		"font_size",
		18
	)

	subtitle.modulate = Color(
		0.7,
		0.7,
		0.75,
		1.0
	)

	content.add_child(subtitle)


	_add_spacer(
		content,
		18.0
	)


	#
	# ============================================================
	# ART
	# ============================================================
	#
	_add_credit_section(
		content,
		"ART",
		"Kyle... Kinda"
	)


	_add_spacer(
		content,
		10.0
	)


	#
	# ============================================================
	# SOUND
	# ============================================================
	#
	_add_credit_section(
		content,
		"SOUND EFFECTS",
		"Replace Me"
	)


	_add_spacer(
		content,
		20.0
	)


	#
	# ============================================================
	# THANK YOU
	# ============================================================
	#
	var thanks := Label.new()

	thanks.text = "Thanks for playing!"

	thanks.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	thanks.add_theme_font_size_override(
		"font_size",
		18
	)

	content.add_child(thanks)


	_add_spacer(
		content,
		15.0
	)


	#
	# ============================================================
	# RESTART BUTTON
	# ============================================================
	#
	var restart_button := Button.new()

	restart_button.text = "Restart"

	restart_button.custom_minimum_size = Vector2(
		220.0,
		45.0
	)

	restart_button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	restart_button.pressed.connect(
		_on_restart_pressed
	)

	content.add_child(restart_button)


	#
	# ============================================================
	# QUIT BUTTON
	# ============================================================
	#
	var quit_button := Button.new()

	quit_button.text = "Quit"

	quit_button.custom_minimum_size = Vector2(
		220.0,
		45.0
	)

	quit_button.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER
	)

	quit_button.pressed.connect(
		_on_quit_pressed
	)

	content.add_child(quit_button)


func _add_credit_section(
	parent: VBoxContainer,
	heading: String,
	name_text: String
) -> void:
	var heading_label := Label.new()

	heading_label.text = heading

	heading_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	heading_label.add_theme_font_size_override(
		"font_size",
		15
	)

	heading_label.modulate = Color(
		0.65,
		0.65,
		0.72,
		1.0
	)

	parent.add_child(
		heading_label
	)


	var name_label := Label.new()

	name_label.text = name_text

	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	name_label.add_theme_font_size_override(
		"font_size",
		23
	)

	parent.add_child(
		name_label
	)


func _add_spacer(
	parent: VBoxContainer,
	height: float
) -> void:
	var spacer := Control.new()

	spacer.custom_minimum_size = Vector2(
		0.0,
		height
	)

	parent.add_child(
		spacer
	)


func show_credits() -> void:
	visible = true

	modulate.a = 0.0

	var tween := create_tween()

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		fade_time
	)


func hide_credits() -> void:
	visible = false


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
