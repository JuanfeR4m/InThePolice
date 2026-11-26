class_name Juego
extends Node

signal tiempo_agotado
signal ira_llena

enum Fase { DIA, NOCHE, AMANECER }

@export var duracion_dia := 100.0
@export var duracion_noche := 80.0
@export var duracion_amanecer := 15.0
## Teclas de prueba: I sube la Ira, K la baja, L quita un administrativo.
## Déjalo en false al jugar de verdad (L es también la patada del jugador 2).
@export var teclas_de_prueba := false

var fase: Fase = Fase.DIA
var tiempo_restante := 195.0
var ira := 0.0
var administrativos := 10
var mensaje := ""

var _t := 0.0
var _l_antes := false
var _terminada := false


func _ready() -> void:
	add_to_group("juego")
	tiempo_restante = _duracion_total()


func _duracion_total() -> float:
	return maxf(duracion_dia + duracion_noche + duracion_amanecer, 0.0)


func _physics_process(delta: float) -> void:
	if _terminada:
		return

	_t += delta
	tiempo_restante = maxf(_duracion_total() - _t, 0.0)

	var antes := fase
	if _t < duracion_dia:
		fase = Fase.DIA
	elif _t < duracion_dia + duracion_noche:
		fase = Fase.NOCHE
	else:
		fase = Fase.AMANECER

	if fase != antes:
		mensaje = "Cae la noche" if fase == Fase.NOCHE else "Amanece"

	_procesar_teclas_prueba(delta)
	_evaluar_condiciones_fin()


func _procesar_teclas_prueba(delta: float) -> void:
	if not teclas_de_prueba:
		return
	if Input.is_key_pressed(KEY_I):
		ira = minf(ira + 30.0 * delta, 100.0)
	if Input.is_key_pressed(KEY_K):
		ira = maxf(ira - 30.0 * delta, 0.0)

	var l_ahora := Input.is_key_pressed(KEY_L)
	if l_ahora and not _l_antes:
		administrativos = maxi(administrativos - 1, 0)
	_l_antes = l_ahora


func _evaluar_condiciones_fin() -> void:
	if ira >= 100.0:
		_terminada = true
		ira_llena.emit()
	elif tiempo_restante <= 0.0:
		_terminada = true
		tiempo_agotado.emit()
