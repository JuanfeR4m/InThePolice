class_name Juego
extends Node

enum Fase { DIA, NOCHE, AMANECER }

@export var duracion_dia := 100.0
@export var duracion_noche := 80.0
@export var duracion_amanecer := 15.0

var fase = Fase.DIA
var tiempo_restante := 195.0
var ira := 0.0
var administrativos := 10
var mensaje := ""

var _t := 0.0
var _l_antes := false


func _ready():
	add_to_group("juego")


func _physics_process(delta):
	_t += delta
	tiempo_restante = maxf(duracion_dia + duracion_noche + duracion_amanecer - _t, 0.0)

	var antes = fase
	if _t < duracion_dia:
		fase = Fase.DIA
	elif _t < duracion_dia + duracion_noche:
		fase = Fase.NOCHE
	else:
		fase = Fase.AMANECER

	if fase != antes:
		mensaje = "Cae la noche" if fase == Fase.NOCHE else "Amanece"

	# teclas de prueba (borrar después)
	if Input.is_key_pressed(KEY_I):
		ira = minf(ira + 30.0 * delta, 100.0)
	if Input.is_key_pressed(KEY_K):
		ira = maxf(ira - 30.0 * delta, 0.0)

	var l_ahora = Input.is_key_pressed(KEY_L)
	if l_ahora and not _l_antes:
		administrativos = maxi(administrativos - 1, 0)
	_l_antes = l_ahora
