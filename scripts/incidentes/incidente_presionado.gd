class_name IncidentePresionado
extends Node3D

signal resuelto(incidente: IncidentePresionado)
signal escalado(incidente: IncidentePresionado)

const TIEMPO_RESOLVER := 3.0
const TIEMPO_ALERTA := 10.0
const TIEMPO_LIMITE := 15.0
const COLOR_NORMAL := Color("F2B632")
const COLOR_ALERTA := Color("D63A3A")
const VELOCIDAD_ALERTA := 10.0

@onready var anillo: MeshInstance3D = $Anillo
@onready var alerta: MeshInstance3D = $Alerta
@onready var indicador: MeshInstance3D = $Indicador

var peleadores: Array[Node3D] = []
var jugador1_cerca := false
var jugador2_cerca := false
var progreso := 0.0
var espera := 0.0
var en_rojo := false
var material_anillo := StandardMaterial3D.new()
var material_alerta: ShaderMaterial
var material_indicador: ShaderMaterial

func _ready() -> void:
	material_anillo.albedo_color = COLOR_NORMAL
	anillo.material_override = material_anillo
	material_alerta = alerta.material_override.duplicate()
	alerta.material_override = material_alerta
	material_indicador = indicador.material_override.duplicate()
	indicador.material_override = material_indicador

func _process(delta: float) -> void:
	espera += delta
	if espera >= TIEMPO_LIMITE:
		escalado.emit(self)
		queue_free()
		return
	if espera >= TIEMPO_ALERTA and not en_rojo:
		en_rojo = true
		pasar_a_rojo()
	if estan_resolviendo():
		progreso += delta
	else:
		progreso = 0.0
	var cerca := jugador1_cerca or jugador2_cerca
	alerta.visible = not cerca
	indicador.visible = cerca
	material_indicador.set_shader_parameter("progreso", progreso / TIEMPO_RESOLVER)
	if progreso >= TIEMPO_RESOLVER:
		resuelto.emit(self)
		queue_free()

func pasar_a_rojo() -> void:
	material_anillo.albedo_color = COLOR_ALERTA
	material_alerta.set_shader_parameter("color_relleno", COLOR_ALERTA)
	material_alerta.set_shader_parameter("velocidad", VELOCIDAD_ALERTA)
	material_indicador.set_shader_parameter("color_centro", COLOR_ALERTA)

func estan_resolviendo() -> bool:
	if jugador1_cerca and Input.is_action_pressed("interactuar1"):
		return true
	if jugador2_cerca and Input.is_action_pressed("interactuar2"):
		return true
	return false

func _on_zona_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador1"):
		jugador1_cerca = true
	if body.is_in_group("jugador2"):
		jugador2_cerca = true

func _on_zona_body_exited(body: Node3D) -> void:
	if body.is_in_group("jugador1"):
		jugador1_cerca = false
	if body.is_in_group("jugador2"):
		jugador2_cerca = false
