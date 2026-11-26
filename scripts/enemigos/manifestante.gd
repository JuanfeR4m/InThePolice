extends CharacterBody3D

enum Estado { VIGILAR, ACERCARSE, AVISO, GOLPE, RECARGA, HUIR }

enum Perfil { ATACANTE, FLANQUEADOR }

const GRUPO = "manifestantes"
const INTERVALO_OBJETIVO = 0.4

@export_group("Comportamiento")
@export var perfil: Perfil = Perfil.ATACANTE

@export var siempre_persigue = true
@export var radio_ver = 14.0

@export var radio_perder = 35.0

@export var radio_alerta = 14.0

@export var anticipa = true

@export_group("Movimiento")

@export var rapidez = 2.0
@export var rapidez_perseguir = 6.0
@export var rapidez_huida = 5.5
@export var rapidez_orbita = 2.8
@export var radio_deambular = 6.0

@export_group("Ataque")
@export var rango_ataque = 1.5
@export var tiempo_aviso = 0.35
@export var tiempo_recarga = 0.9
@export var alcance_golpe = 1.8
@export var danio = 1

@export_group("Vida")
@export var vida = 100.0
@export var vida_huida = 30.0

@export var regen_huida = 8.0

@export_group("Pruebas")
## Con true, la tecla Enter le hace daño (solo para probar)
@export var tecla_prueba = false
@export var danio_prueba = 25.0

var estado = Estado.VIGILAR
var reloj = 0.0
var jugador = null
var origen = Vector3.ZERO
var destino_azar = Vector3.ZERO
var pausa = 0.0
var tiempo_ruta = 0.0
var vida_max = 100.0
var alertado = false
var reloj_objetivo = 0.0
var orbita_dir = 1.0
var lado_flanqueo = 1.0
var listo = false
var usa_malla = false
var quiere_moverse = false

@onready var anim = $Modelo/AnimationPlayer
var agente: NavigationAgent3D


func _ready():
	add_to_group(GRUPO)
	add_to_group("enemigos_de_dia")   # se van al caer la noche (AmbienteNoche)
	origen = global_position
	destino_azar = origen
	vida_max = vida
	lado_flanqueo = 1.0 if randf() < 0.5 else -1.0
	orbita_dir = 1.0 if randf() < 0.5 else -1.0
	pausa = randf_range(0.0, 2.0)

	agente = get_node_or_null("NavigationAgent3D")
	if agente == null:
		agente = NavigationAgent3D.new()
		agente.name = "NavigationAgent3D"
		add_child(agente)
	agente.avoidance_enabled = true
	agente.radius = 0.65
	agente.neighbor_distance = 6.0
	agente.max_neighbors = 12
	agente.time_horizon_agents = 2.5
	agente.path_desired_distance = 0.5
	agente.target_desired_distance = 0.5
	agente.avoidance_priority = 0.5
	if not agente.velocity_computed.is_connected(_al_velocidad_calculada):
		agente.velocity_computed.connect(_al_velocidad_calculada)

	
	for i in range(10):
		await get_tree().physics_frame
		var mapa = agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			usa_malla = NavigationServer3D.map_get_regions(mapa).size() > 0
			break
	listo = true


func _al_velocidad_calculada(v: Vector3):
	if quiere_moverse:
		velocity.x = v.x
		velocity.z = v.z


func _physics_process(delta):
	if not listo:
		return
	if not usa_malla:
		usa_malla = NavigationServer3D.map_get_regions(agente.get_navigation_map()).size() > 0

	quiere_moverse = false
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)

	
	if estado != Estado.AVISO and estado != Estado.GOLPE:
		reloj_objetivo -= delta
		if reloj_objetivo <= 0.0 or not is_instance_valid(jugador):
			reloj_objetivo = INTERVALO_OBJETIVO + randf() * 0.2
			jugador = elegir_policia()

	# BORRAR antes del commit
	if tecla_prueba and Input.is_action_just_pressed("ui_accept"):
		recibir_golpe(danio_prueba)

	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)

	match estado:
		Estado.VIGILAR:
			vigilar(delta)
		Estado.ACERCARSE:
			ir_a(punto_de_ataque(), rapidez_perseguir)
		Estado.AVISO:
			frenar("interact-right")
			mirar_hacia(jugador.global_position)
		Estado.GOLPE:
			frenar("attack-melee-right")
			mirar_hacia(jugador.global_position)
			golpear()
		Estado.RECARGA:
			orbitar()
		Estado.HUIR:
			huir(delta)

	move_and_slide()




func decidir():
	if not is_instance_valid(jugador):
		return Estado.VIGILAR
	if estado == Estado.HUIR:
		
		if vida >= vida_max * 0.6:
			return Estado.ACERCARSE
		return Estado.HUIR
	if vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.VIGILAR:
			if siempre_persigue or alertado or distancia() <= radio_ver:
				return Estado.ACERCARSE
		Estado.ACERCARSE:
			if distancia() <= rango_ataque:
				return Estado.AVISO
			if not siempre_persigue and distancia() > radio_perder:
				return Estado.VIGILAR
		Estado.AVISO:
			
			if distancia() > rango_ataque * 1.6:
				return Estado.ACERCARSE
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	var d = snappedf(distancia(), 0.01) if is_instance_valid(jugador) else -1.0
	print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " a ", d, " m")
	match estado:
		Estado.AVISO:
			reloj = tiempo_aviso
		Estado.RECARGA:
			reloj = tiempo_recarga
			orbita_dir = 1.0 if randf() < 0.5 else -1.0
		Estado.VIGILAR:
			alertado = false
			pausa = randf_range(0.5, 2.0)
			tiempo_ruta = 0.0
			destino_azar = origen
		Estado.ACERCARSE:
			if not alertado:
				alertado = true
				alertar_grupo()



func elegir_policia():
	var mejor = null
	var mejor_score = INF
	for p in get_tree().get_nodes_in_group("jugador"):
		if not is_instance_valid(p):
			continue
		var score = global_position.distance_to(p.global_position) + 3.0 * contar_perseguidores(p)
		if p == jugador:
			score -= 2.0  
		if score < mejor_score:
			mejor_score = score
			mejor = p
	return mejor


func contar_perseguidores(p):
	var n = 0
	for m in get_tree().get_nodes_in_group(GRUPO):
		if m != self and is_instance_valid(m) and m.jugador == p and m.esta_atacando():
			n += 1
	return n



func esta_atacando():
	return estado == Estado.ACERCARSE or estado == Estado.AVISO \
		or estado == Estado.GOLPE or estado == Estado.RECARGA


func alertar_grupo():
	for m in get_tree().get_nodes_in_group(GRUPO):
		if m == self or not is_instance_valid(m):
			continue
		if global_position.distance_to(m.global_position) <= radio_alerta:
			m.recibir_alerta()


func recibir_alerta():
	if estado == Estado.VIGILAR:
		alertado = true



func punto_de_ataque() -> Vector3:
	var p = jugador.global_position
	var vel = velocidad_plana(jugador)
	var d = distancia()
	var base = p
	if anticipa:
		base = p + vel * clampf(d / maxf(rapidez_perseguir, 0.1), 0.0, 1.0)
	var radio = rango_ataque * 0.8
	var hacia_mi = global_position - p
	hacia_mi.y = 0.0
	if hacia_mi.length() < 0.1:
		hacia_mi = Vector3.RIGHT
	hacia_mi = hacia_mi.normalized()

	if perfil == Perfil.FLANQUEADOR:
		if d > 7.0:
			
			var lateral = Vector3(-hacia_mi.z, 0.0, hacia_mi.x) * lado_flanqueo
			return base + hacia_mi * 3.0 + lateral * 5.0
		var atras: Vector3
		if vel.length() > 0.5:
			atras = -vel.normalized()
		else:
			atras = jugador.global_transform.basis.z
			atras.y = 0.0
			atras = atras.normalized()
		return base + atras * radio
	return base + hacia_mi * radio



func orbitar():
	var rad = global_position - jugador.global_position
	rad.y = 0.0
	if rad.length() < 0.1:
		return
	var tang = Vector3(-rad.z, 0.0, rad.x).normalized() * orbita_dir
	var ajuste = rad.normalized() * (rango_ataque * 0.9 - rad.length())
	ir_a(global_position + tang * 1.5 + ajuste, rapidez_orbita)
	mirar_hacia(jugador.global_position)



func vigilar(delta):
	if pausa > 0.0:
		pausa -= delta
		frenar("idle")
		return
	tiempo_ruta += delta
	if distancia_plana(destino_azar) < 0.8 or tiempo_ruta > 12.0:
		var ang = randf() * TAU
		destino_azar = origen + Vector3(cos(ang), 0.0, sin(ang)) * sqrt(randf()) * radio_deambular
		pausa = randf_range(1.0, 3.0)
		tiempo_ruta = 0.0
		return
	ir_a(destino_azar, rapidez)



func huir(delta):
	var lejos = global_position - jugador.global_position
	lejos.y = 0.0
	lejos = lejos.normalized() if lejos.length() > 0.1 else Vector3.RIGHT
	var destino = global_position + lejos * 8.0
	var amigo = companero_a_salvo()
	if amigo != null:
		destino = amigo.global_position
	if distancia() > 8.0:
		vida = minf(vida + regen_huida * delta, vida_max)
	if distancia() > 14.0:
		frenar("idle")
	else:
		ir_a(destino, rapidez_huida)


func companero_a_salvo():
	var mejor = null
	var mejor_d = INF
	var mi_dist = distancia()
	for m in get_tree().get_nodes_in_group(GRUPO):
		if m == self or not is_instance_valid(m) or m.estado == Estado.HUIR:
			continue
		if m.global_position.distance_to(jugador.global_position) <= mi_dist:
			continue
		var d = global_position.distance_to(m.global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = m
	return mejor


# --------------------------------------------------------------------- daño

func recibir_golpe(cuanto, direccion = Vector3.ZERO):
	vida -= cuanto
	global_position += direccion * 1.5
	alertado = true
	print(name, " vida ", vida)
	if vida <= 0:
		print(name, " vencido")
		queue_free()


func golpear():
	if distancia() > alcance_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m")
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null and salud.has_method("recibir_golpe"):
		salud.recibir_golpe(danio)
	elif jugador.has_method("recibir_golpe"):
		jugador.recibir_golpe(danio)


# --------------------------------------------------------- navegación y utilidades

func velocidad_plana(n) -> Vector3:
	if "velocity" in n:
		return Vector3(n.velocity.x, 0.0, n.velocity.z)
	return Vector3.ZERO


func ajustar_a_malla(p: Vector3) -> Vector3:
	if usa_malla:
		var mapa = agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			return NavigationServer3D.map_get_closest_point(mapa, p)
	return p


func ir_a(destino, vel = -1.0):
	if vel < 0.0:
		vel = rapidez
	var dir: Vector3
	if usa_malla:
		var p = ajustar_a_malla(destino)
		if agente.target_position.distance_to(p) > 0.4:
			agente.target_position = p
		dir = agente.get_next_path_position() - global_position
	else:
		dir = destino - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = dir.normalized()
	quiere_moverse = true
	if agente.avoidance_enabled:
		agente.max_speed = vel
		agente.velocity = dir * vel
	else:
		velocity.x = dir.x * vel
		velocity.z = dir.z * vel
	basis = Basis.looking_at(dir)
	tocar("sprint" if vel >= 5.0 else "walk")


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	if agente.avoidance_enabled:
		agente.velocity = Vector3.ZERO
	tocar(animacion)


func tocar(animacion):
	if anim.has_animation(animacion) and anim.current_animation != animacion:
		anim.play(animacion)


func mirar_hacia(punto):
	var dir = punto - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		basis = Basis.looking_at(dir.normalized())


func distancia_plana(p: Vector3):
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(p.x, p.z))


func distancia():
	if not is_instance_valid(jugador):
		return INF
	return distancia_plana(jugador.global_position)
