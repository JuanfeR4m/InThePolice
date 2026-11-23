extends Node

enum Estado { JUGANDO, GANO, PERDIO }

const PANTALLA_FIN := preload("res://scripts/mundo/fin_partida.gd")
const ESCENA_MENU := "res://escenas/main.tscn"

const MINIMO_SALVADOS := 5
const TOTAL_ADMINISTRATIVOS := 10


@export var ira_maxima_pierde := true

@export var tiempo_limite = 180.0
@export var metas = 0
@export var noche_en = 80.0

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
var motivo_fin := ""
var hud = null
var generador_incidentes = null


func _ready():
	tiempo = tiempo_limite
	print("intento ", intentos, " · mejor tiempo ", snappedf(mejor, 0.01))


func _physics_process(delta):
	if estado != Estado.JUGANDO:
		return

	tiempo = maxf(tiempo - delta, 0.0)
	actualizar_sol()
	sincronizar_hud()
	conectar_ira()
	revisar_administrativos()
	if estado != Estado.JUGANDO:
		return

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
	var j = _juego()
	if j != null and j.administrativos < MINIMO_SALVADOS:
		perder("Se perdieron demasiados administrativos")
		return
	terminar(Estado.GANO, "Llegaron al amanecer con el edificio a salvo")



func perder(motivo: String):
	terminar(Estado.PERDIO, motivo)



func sincronizar_hud():
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
		if hud == null:
			return
		hud.tiempo_total = tiempo_limite
	hud.tiempo = tiempo


func conectar_ira():
	if generador_incidentes != null:
		return
	generador_incidentes = get_parent().get_node_or_null("GeneradorIncidentes")
	if generador_incidentes != null:
		generador_incidentes.ira_cambio.connect(_al_cambiar_ira)


func _al_cambiar_ira(valor):
	if hud != null:
		hud.poner_ira(valor)
	if ira_maxima_pierde and valor >= generador_incidentes.IRA_MAXIMA:
		perder("La Ira llegó al máximo: se ignoraron demasiados incidentes")


func revisar_administrativos():
	var j = _juego()
	if j != null and j.administrativos < MINIMO_SALVADOS:
		perder("Se perdieron 6 administrativos")


func _juego():
	return get_tree().get_first_node_in_group("juego")


func terminar(nuevo, texto):
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	motivo_fin = texto
	print("fin: ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " (", texto, ")")
	get_tree().paused = true
	var usado = tiempo_limite - tiempo
	if estado == Estado.GANO and (mejor == 0.0 or usado < mejor):
		mejor = usado
	_sonido_fin()
	_mostrar_pantalla(usado)


func _sonido_fin():
	var hud_actual = get_tree().get_first_node_in_group("hud")
	if hud_actual != null:
		hud_actual.detener_tiempo()
	var audio = get_parent().get_node_or_null("AudioPartida")
	if audio == null or audio.get("p_inicio") == null:
		return
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	if estado == Estado.GANO:
		audio.victoria()
	else:
		audio.derrota()


func _mostrar_pantalla(usado):
	var j = _juego()
	var pantalla = PANTALLA_FIN.new()
	pantalla.configurar({
		"gano": estado == Estado.GANO,
		"motivo": motivo_fin,
		"salvados": j.administrativos if j != null else -1,
		"total_administrativos": TOTAL_ADMINISTRATIVOS,
		"tiempo_usado": usado,
		"mejor_tiempo": mejor,
	})
	pantalla.reintentar.connect(reiniciar)
	pantalla.ir_al_menu.connect(volver_al_menu)
	get_parent().add_child(pantalla)


func reiniciar():
	intentos += 1
	get_tree().paused = false
	get_tree().reload_current_scene()


func volver_al_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_MENU)
