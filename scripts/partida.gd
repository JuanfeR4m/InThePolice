extends Node

enum Estado { JUGANDO, GANO, PERDIO }

@export var tiempo_limite = 30.0
@export var gana_con_tiempo = false
@export var metas = 3
@export var noche_en = 80.0

var estado = Estado.JUGANDO
var tiempo = 0.0
var hechas = 0
var noche_avisada = false


func _ready():
	tiempo = tiempo_limite


func _physics_process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		avisar_meta()

	if estado != Estado.JUGANDO:
		return

	tiempo = maxf(tiempo - delta, 0.0)


	if not noche_avisada and tiempo < noche_en:
		noche_avisada = true
		print("cae la noche")

	if tiempo <= 0.001:
		if gana_con_tiempo:
			ganar()
		else:
			perder("se acabó el tiempo")


func avisar_meta():
	if estado != Estado.JUGANDO:
		return
	hechas += 1
	print("meta ", hechas, " de ", metas)
	if metas > 0 and hechas >= metas:
		ganar()


func ganar():
	terminar(Estado.GANO, "ganó")


func perder(motivo):
	terminar(Estado.PERDIO, motivo)


func terminar(nuevo, motivo):
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	print("fin: ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " (", motivo, ")")
	get_tree().paused = true
