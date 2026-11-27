extends Node

const PRESIONES := 20
const CAIDA_REANIMAR := 0.1
const TIEMPO_AYUDA := 3.0
const INVULNERABLE_REANIMADO := 2.0
const ALTURA_TEXTO := 3.0
const TAMANO_TEXTO := 56
const COLOR_TEXTO := Color(0.8, 0.8, 0.8)

@export var vida = 3
@export var invulnerable = 1.0

@onready var pj = get_parent()
@onready var vida_maxima = vida

var reloj = 0.0
var progreso = 0.0
var texto: Label3D = null

func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)
	if pj.desmayado:
		reanimar(delta)

func recibir_golpe(danio):
	if pj.desmayado or reloj > 0.001:
		return
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	print(pj.name, " vida: ", vida)
	if vida == 0:
		desmayar()

func desmayar():
	pj.desmayado = true
	progreso = 0.0
	pj.poner_gris(true)
	texto = Label3D.new()
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.no_depth_test = true
	texto.pixel_size = 0.008
	texto.font_size = TAMANO_TEXTO
	texto.modulate = COLOR_TEXTO
	texto.position = Vector3(0.0, ALTURA_TEXTO, 0.0)
	pj.add_child(texto)

func reanimar(delta):
	if hay_ayuda():
		progreso += delta / TIEMPO_AYUDA
	else:
		progreso = maxf(progreso - CAIDA_REANIMAR * delta, 0.0)
	if Input.is_action_just_pressed(pj._accion("interactuar")):
		progreso += 1.0 / PRESIONES
	texto.text = "Reanimar %d%%" % int(progreso * 100.0)
	if progreso >= 1.0:
		levantar()

func hay_ayuda():
	for nodo in get_tree().get_nodes_in_group("jugador"):
		if nodo == pj or nodo.desmayado:
			continue
		var distancia = Vector2(nodo.global_position.x - pj.global_position.x,
				nodo.global_position.z - pj.global_position.z).length()
		if distancia <= pj.RADIO_AYUDA and Input.is_action_pressed(nodo._accion("interactuar")):
			return true
	return false

func levantar():
	pj.desmayado = false
	pj.poner_gris(false)
	vida = vida_maxima
	progreso = 0.0
	reloj = INVULNERABLE_REANIMADO
	texto.queue_free()
	texto = null
