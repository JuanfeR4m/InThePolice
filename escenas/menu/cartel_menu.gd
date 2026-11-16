extends Node3D

signal jugar
signal opciones
signal salir

const COLOR_NORMAL := Color(0.1, 0.25, 0.6)
const COLOR_HOVER := Color(0.95, 0.8, 0.2)
const TEXTO_NORMAL := Color(1, 1, 1)
const TEXTO_HOVER := Color(0.1, 0.1, 0.1)

@onready var areas: Array = [$OpcionJugar, $OpcionOpciones, $OpcionSalir]

var seleccion := 0
var materiales: Array = []


func _ready() -> void:
	get_viewport().physics_object_picking = true

	for i in areas.size():
		var area: Area3D = areas[i]
		var placa: MeshInstance3D = area.get_node("Placa")
		var mat := (placa.get_surface_override_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		placa.set_surface_override_material(0, mat)
		materiales.append(mat)

		area.mouse_entered.connect(_seleccionar.bind(i))
		area.input_event.connect(_on_input_event.bind(i))

	_actualizar_visual()


func _seleccionar(i: int) -> void:
	if i == seleccion:
		return
	seleccion = i
	_actualizar_visual()


func _actualizar_visual() -> void:
	for i in areas.size():
		var activo: bool = i == seleccion
		var area: Node3D = areas[i]
		var texto: Label3D = area.get_node("Texto")

		materiales[i].albedo_color = COLOR_HOVER if activo else COLOR_NORMAL
		texto.modulate = TEXTO_HOVER if activo else TEXTO_NORMAL

		var escala: float = 1.1 if activo else 1.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(area, "scale", Vector3(escala, escala, escala), 0.15)


func _on_input_event(_camara: Node, evento: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, i: int) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_elegir(i)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_down"):
		_seleccionar((seleccion + 1) % areas.size())
	elif evento.is_action_pressed("ui_up"):
		_seleccionar(posmod(seleccion - 1, areas.size()))
	elif evento.is_action_pressed("ui_accept"):
		_elegir(seleccion)


func _elegir(i: int) -> void:
	match i:
		0:
			jugar.emit()
		1:
			opciones.emit()
		2:
			salir.emit()
