class_name AvisoTecla
extends Node3D

const SALTO := 0.08
const VELOCIDAD := 5.0
const BAJADA := 0.12
const SIMBOLOS := ["o", "o", "+", "+", "/", ""]
const ACCIONES := ["MANTÉN", "ESPICHA x12", "MANTENGAN\nLOS DOS", "ESPICHEN\nLOS DOS x12", "ALTERNEN x12", ""]
const NOMBRES := ["", "E", "ENTER"]
const COLOR_MANTENER := Color("5FB88B")
const COLOR_ESPICHAR := Color("F2B632")

@onready var tecla1: MeshInstance3D = $Tecla1
@onready var tecla2: MeshInstance3D = $Tecla2
@onready var simbolo: Label3D = $Simbolo
@onready var accion: Label3D = $Accion

var altura := 0.0
var material1: ShaderMaterial
var material2: ShaderMaterial

func _ready() -> void:
	altura = position.y
	material1 = tecla1.material_override.duplicate()
	tecla1.material_override = material1
	material2 = tecla2.material_override.duplicate()
	tecla2.material_override = material2

func _process(_delta: float) -> void:
	position.y = altura + sin(Time.get_ticks_msec() / 1000.0 * VELOCIDAD) * SALTO

func configurar(modo: int, mantener: bool) -> void:
	simbolo.text = SIMBOLOS[modo]
	accion.text = ACCIONES[modo]
	var color := COLOR_ESPICHAR
	if mantener:
		color = COLOR_MANTENER
	accion.modulate = color
	material1.set_shader_parameter("color_resalte", color)
	material2.set_shader_parameter("color_resalte", color)

func mostrar_estado(presiona1: bool, presiona2: bool, siguiente: int) -> void:
	material1.set_shader_parameter("resaltada", siguiente != 2)
	material2.set_shader_parameter("resaltada", siguiente != 1)
	bajar(tecla1, presiona1)
	bajar(tecla2, presiona2)

func mostrar_secuencia(secuencia: Array, paso: int) -> void:
	var nombres := PackedStringArray()
	for i in range(paso, secuencia.size()):
		var tecla: int = secuencia[i]
		nombres.append(NOMBRES[tecla])
	accion.text = " ".join(nombres)

func bajar(tecla: MeshInstance3D, presionada: bool) -> void:
	tecla.position.y = 0.0
	if presionada:
		tecla.position.y = -BAJADA
