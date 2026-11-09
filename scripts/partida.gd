extends Node

enum Estado { JUGANDO, GANO }

@export var tiempo_limite = 180.0
@export var metas = 0
@export var noche_en = 80.0
@export var espera_reinicio = 15.0

@export var sistema_sol: SistemaSol
@export var hora_inicio = 9.0
@export var hora_atardecer = 18.0
@export var hora_fin = 21.0

static var intentos = 1
static var mejor = 0.0

var estado = Estado.JUGANDO
var tiempo = 0.0
var hechas = 0
var noche_avisada = false
var reloj = 0.0


func _ready():
	tiempo = tiempo_limite
	print("intento ", intentos, " · mejor tiempo ", snappedf(mejor, 0.01))


func _physics_process(delta):
	if estado != Estado.JUGANDO:
		reloj -= delta
		if reloj <= 0.001:
			reiniciar()
		return

	tiempo = maxf(tiempo - delta, 0.0)
	actualizar_sol()

	if not noche_avisada and tiempo < noche_en:
		noche_avisada = true
		print("cae la noche")

	if tiempo <= 0.001:
		ganar()


func actualizar_sol():
	if sistema_sol == null:
		return
	var transcurrido = tiempo_limite - tiempo
	var dia = tiempo_limite - noche_en
	var hora
	if transcurrido < dia:
		hora = lerpf(hora_inicio, hora_atardecer, transcurrido / dia)
	else:
		hora = lerpf(hora_atardecer, hora_fin, (transcurrido - dia) / noche_en)
	sistema_sol.ciclo.hora = hora


func avisar_meta():
	if estado != Estado.JUGANDO:
		return
	hechas += 1
	print("meta ", hechas, " de ", metas)
	if metas > 0 and hechas >= metas:
		ganar()


func ganar():
	terminar(Estado.GANO, "ganó")


func terminar(nuevo, motivo):
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	print("fin: ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " (", motivo, ")")
	get_tree().paused = true
	reloj = espera_reinicio
	var usado = tiempo_limite - tiempo
	if estado == Estado.GANO and (mejor == 0.0 or usado < mejor):
		mejor = usado


func reiniciar():
	intentos += 1
	get_tree().paused = false
	get_tree().reload_current_scene()
