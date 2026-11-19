class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO }

const INTERVALO_REVISAR := 0.5
const TIEMPO_ATASCO := 1.5
const DISTANCIA_ATASCO := 3.0
const UMBRAL_RUTA := 0.3
const UMBRAL_RUTA_PERSECUCION := 1.0
const GRUPO_CIUDADANOS := "ciudadanos"
const DISTANCIA_SEPARACION := 1.1
const FUERZA_SEPARACION := 3.0
const SHADER_CONTORNO := preload("res://shaders/contorno_defender.gdshader")

@export var objetivo: Node3D
@export var persigue_policia := false
@export var cooldown_pelea := 20.0
@export var patrulla_aleatoria := true
@export var radio_deambular := 25.0
@export var pausa_min := 0.5
@export var pausa_max := 3.0
@export var rapidez_acudir := 4.0
@export var margen_cambio := 4.0
@export var tiempo_max_ruta := 40.0
@export var vida = 100
## Si es true, se le ilumina el borde en verde para saber que hay que defenderlo
@export var es_administrativo := false:
	set(valor):
		es_administrativo = valor
		aplicar_contorno()
@export var rapidez = 2.0
@export var radio_ver = 6.0
@export var radio_perder = 9.0
@export var puntos: Array[Vector3] = [
	Vector3(-6, 0, -3), Vector3(6, 0, -3)]

@export_group("Noche")
## De noche corren (en vez de pasear) entre puntos repartidos por todo el mapa
@export var rapidez_noche := 3.5
@export var centro_noche := Vector3.ZERO
## Los destinos de la noche caen en un anillo entre estos dos radios: lejos del centro
@export var radio_minimo_noche := 10.0
@export var radio_noche := 26.0
@export var pausa_noche_max := 0.3

# Ajustes de avoidance (puedes tocarlos desde el inspector)
@export var radio_avoidance := 0.65
@export var distancia_vecinos := 6.0
@export var max_vecinos := 12
@export var horizonte_agentes := 2.5

@onready var anim = $Modelo/AnimationPlayer
@onready var agente: NavigationAgent3D = $NavigationAgent3D

var estado = Estado.PATRULLA
var punto = 0
var destino_incidente := Vector3.ZERO
var centro_incidente := Vector3.ZERO
var rival: Node3D
var llego := false
var enfriamiento := 0.0
var origen := Vector3.ZERO
var entrada := Vector3.ZERO
var viene_de_afuera := false
var destino_azar := Vector3.ZERO
var pausa := 0.0
var tiempo_ruta := 0.0
var incidente = null
var listo := false
var usa_malla := false
var quiere_moverse := false
var reloj_revisar := 0.0
var reloj_atasco := 0.0
var ultima_pos := Vector3.ZERO
var es_noche := false
var reloj_noche := 0.0
var partida = null

static func blinn_phong(normal: Vector3, hacia_luz: Vector3, hacia_ojo: Vector3, brillo: float) -> float:
	var n = normal.normalized()
	var l = hacia_luz.normalized()
	var v = hacia_ojo.normalized()
	var h = (l + v).normalized()
	var ndot_h = max(0.0, n.dot(h))
	return pow(ndot_h, brillo)

func aplicar_contorno() -> void:
	if not is_inside_tree():
		return
	var material: ShaderMaterial = null
	if es_administrativo:
		material = ShaderMaterial.new()
		material.shader = SHADER_CONTORNO
	for malla in find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_overlay = material

func _ready() -> void:
	aplicar_contorno()
	# Avoidance: conectar la señal y configurar el agente
	if not agente.velocity_computed.is_connected(_al_velocidad_calculada):
		agente.velocity_computed.connect(_al_velocidad_calculada)
	agente.avoidance_enabled = true
	agente.radius = radio_avoidance
	agente.neighbor_distance = distancia_vecinos
	agente.max_neighbors = max_vecinos
	agente.time_horizon_agents = horizonte_agentes
	agente.path_desired_distance = 0.5
	agente.target_desired_distance = 0.5
	agente.avoidance_priority = 0.5

	if not viene_de_afuera:
		origen = global_position
	reloj_revisar = randf() * INTERVALO_REVISAR
	reloj_noche = randf() * INTERVALO_REVISAR
	for i in range(10):
		await get_tree().physics_frame
		var mapa = agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			usa_malla = NavigationServer3D.map_get_regions(mapa).size() > 0
			break
	elegir_destino()
	if viene_de_afuera:
		destino_azar = ajustar_a_malla(entrada)
	listo = true
	if estado == Estado.PATRULLA:
		patrullar(0.0)

func _al_velocidad_calculada(v: Vector3) -> void:
	if quiere_moverse:
		velocity.x = v.x
		velocity.z = v.z

func ajustar_a_malla(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	if usa_malla:
		var mapa = agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			return NavigationServer3D.map_get_closest_point(mapa, p)
	return p

func distancia_plana(p: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(p.x, p.z))

func llego_a(p: Vector3, tolerancia := 0.5) -> bool:
	if distancia_plana(p) < tolerancia:
		return true
	return usa_malla and agente.is_navigation_finished() and distancia_plana(p) < 2.5

func elegir_destino() -> void:
	if not is_inside_tree():
		return
	var ang := randf() * TAU
	if es_noche:
		# Anillo alrededor del centro: nadie se queda amontonado en medio
		var dist_n := randf_range(radio_minimo_noche, radio_noche)
		destino_azar = ajustar_a_malla(centro_noche + Vector3(cos(ang), 0.0, sin(ang)) * dist_n)
	else:
		var dist := sqrt(randf()) * radio_deambular
		destino_azar = ajustar_a_malla(origen + Vector3(cos(ang), 0.0, sin(ang)) * dist)
	tiempo_ruta = 0.0
	reloj_atasco = 0.0
	ultima_pos = global_position

func revisar_atasco(delta: float) -> void:
	reloj_atasco += delta
	if reloj_atasco < TIEMPO_ATASCO:
		return
	reloj_atasco = 0.0
	if global_position.distance_to(ultima_pos) < 0.3:
		elegir_destino()
	ultima_pos = global_position

func atascado_cerca(delta: float) -> bool:
	reloj_atasco += delta
	if reloj_atasco < TIEMPO_ATASCO:
		return false
	reloj_atasco = 0.0
	var quieto := global_position.distance_to(ultima_pos) < 0.3
	ultima_pos = global_position
	return quieto and distancia_plana(destino_incidente) < DISTANCIA_ATASCO

func patrullar(delta: float) -> void:
	if not patrulla_aleatoria:
		# Patrulla fija: si se atasca, pasa al siguiente punto
		reloj_atasco += delta
		if reloj_atasco >= TIEMPO_ATASCO:
			reloj_atasco = 0.0
			if global_position.distance_to(ultima_pos) < 0.3:
				punto = (punto + 1) % puntos.size()
			ultima_pos = global_position
		ir_a(puntos[punto])
		if distancia_plana(puntos[punto]) < 0.3:
			punto = (punto + 1) % puntos.size()
		return
	if pausa > 0.0:
		pausa -= delta
		reloj_atasco = 0.0
		ultima_pos = global_position
		detenerse()
		return
	tiempo_ruta += delta
	if llego_a(destino_azar, 0.6) or tiempo_ruta > tiempo_max_ruta:
		pausa = randf_range(0.0, pausa_noche_max) if es_noche else randf_range(pausa_min, pausa_max)
		detenerse()
		elegir_destino()
		return
	revisar_atasco(delta)
	ir_a(destino_azar, rapidez_noche if es_noche else -1.0)

func actualizar_noche(delta: float) -> void:
	reloj_noche -= delta
	if reloj_noche > 0.0:
		return
	reloj_noche = INTERVALO_REVISAR
	if partida == null or not is_instance_valid(partida):
		partida = get_tree().get_first_node_in_group("partida")
		if partida == null:
			return
	var noche: bool = partida.tiempo > 0.0 and partida.tiempo < partida.noche_en
	if noche and not es_noche:
		es_noche = true
		if estado == Estado.PATRULLA:
			pausa = 0.0
			elegir_destino()

func actualizar_prioridad_avoidance() -> void:
	# Los que están quietos peleando o mirando pesan más: los demás los rodean
	# También cuenta como quieto el que está en pausa: los demás lo rodean
	var quieto := not quiere_moverse or estado == Estado.PELEA or (estado == Estado.CURIOSO and llego)
	agente.avoidance_priority = 1.0 if quieto else 0.5

func separar_de_vecinos() -> void:
	# Empuje suave: si alguien (ciudadano o curioso) está muy cerca, se aleja
	var empuje := Vector3.ZERO
	for nodo in get_tree().get_nodes_in_group(GRUPO_CIUDADANOS):
		var otro := nodo as Node3D
		if otro == null or otro == self:
			continue
		var d := global_position - otro.global_position
		d.y = 0.0
		var dist := d.length()
		if dist >= DISTANCIA_SEPARACION:
			continue
		if dist < 0.01:
			d = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			dist = maxf(d.length(), 0.01)
		empuje += d / dist * ((DISTANCIA_SEPARACION - dist) / DISTANCIA_SEPARACION)
	velocity.x += empuje.x * FUERZA_SEPARACION
	velocity.z += empuje.z * FUERZA_SEPARACION

func _physics_process(delta):
	if not listo:
		return
	# Si el navmesh tardó en cargar, reintentar
	if not usa_malla:
		var mapa = agente.get_navigation_map()
		usa_malla = NavigationServer3D.map_get_regions(mapa).size() > 0
	quiere_moverse = false
	velocity += get_gravity() * delta
	if enfriamiento > 0.0:
		enfriamiento -= delta
	var distancia := INF
	if objetivo:
		distancia = global_position.distance_to(objetivo.global_position)
	revisar_cercania(delta)
	actualizar_noche(delta)
	match estado:
		Estado.PATRULLA:
			if persigue_policia and distancia < radio_ver:
				estado = Estado.PERSEGUIR
				print("lo vio a ", snappedf(distancia, 0.01), " m")
			patrullar(delta)
		Estado.PERSEGUIR:
			if distancia > radio_perder or not objetivo:
				estado = Estado.PATRULLA
				print("lo perdió a ", snappedf(distancia, 0.01), " m")
			else:
				ir_a(objetivo.global_position, -1.0, UMBRAL_RUTA_PERSECUCION)
		Estado.ACUDIR:
			if llego_a(destino_incidente) or atascado_cerca(delta):
				llego = true
				estado = Estado.PELEA
			else:
				ir_a(destino_incidente, rapidez_acudir)
		Estado.PELEA:
			detenerse()
			var mira := destino_incidente
			if is_instance_valid(rival):
				mira = rival.global_position
			mirar_hacia(mira)
		Estado.CURIOSO:
			if persigue_policia and distancia < radio_ver:
				soltar_incidente()
				estado = Estado.PERSEGUIR
			else:
				if not llego and (llego_a(destino_incidente) or atascado_cerca(delta)):
					llego = true
				if llego:
					detenerse()
					mirar_hacia(centro_incidente)
				else:
					ir_a(destino_incidente, rapidez_acudir)
	actualizar_prioridad_avoidance()
	separar_de_vecinos()
	move_and_slide()

func revisar_cercania(delta: float) -> void:
	reloj_revisar -= delta
	if reloj_revisar > 0.0:
		return
	reloj_revisar = INTERVALO_REVISAR
	var yendo_a_pelear: bool = estado == Estado.ACUDIR and not llego
	var yendo_a_mirar: bool = estado == Estado.CURIOSO and not llego
	if not (yendo_a_pelear or yendo_a_mirar):
		return
	if incidente == null or not is_instance_valid(incidente):
		return
	var d_actual := global_position.distance_to(incidente.global_position)
	var mejor = null
	var mejor_d := d_actual - margen_cambio
	for inc in get_tree().get_nodes_in_group("incidentes"):
		if inc == incidente:
			continue
		var d := global_position.distance_to(inc.global_position)
		if d >= mejor_d:
			continue
		var acepta: bool = (yendo_a_pelear and inc.acepta_peleador(self)) \
			or (yendo_a_mirar and inc.acepta_curioso(self))
		if acepta:
			mejor = inc
			mejor_d = d
	if mejor == null:
		return
	incidente.liberar(self)
	if yendo_a_pelear:
		mejor.inscribir_peleador(self)
	else:
		mejor.inscribir_curioso(self)
	print(name, " cambia a ", mejor.name, " (", snappedf(d_actual, 0.1), " -> ", snappedf(mejor_d, 0.1), " m)")

func detenerse() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if agente.avoidance_enabled:
		agente.velocity = Vector3.ZERO
	anim.stop()

func mirar_hacia(punto_mira: Vector3) -> void:
	var dir := punto_mira - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		basis = Basis.looking_at(dir.normalized())

func disponible() -> bool:
	return listo and estado == Estado.PATRULLA and enfriamiento <= 0.0

func puede_mirar() -> bool:
	return listo and estado == Estado.PATRULLA

func ir_a_pelea(pos: Vector3, inc) -> void:
	incidente = inc
	destino_incidente = ajustar_a_malla(pos)
	llego = false
	reloj_atasco = 0.0
	ultima_pos = global_position
	estado = Estado.ACUDIR

func curiosear(puesto: Vector3, centro: Vector3, inc) -> void:
	incidente = inc
	destino_incidente = ajustar_a_malla(puesto)
	centro_incidente = centro
	llego = false
	reloj_atasco = 0.0
	ultima_pos = global_position
	estado = Estado.CURIOSO

func soltar_incidente() -> void:
	if incidente != null and is_instance_valid(incidente):
		incidente.liberar(self)
	incidente = null

func terminar_pelea() -> void:
	rival = null
	llego = false
	incidente = null
	if estado == Estado.ACUDIR or estado == Estado.PELEA:
		enfriamiento = cooldown_pelea
		pausa = 0.0
		estado = Estado.PATRULLA
		elegir_destino()

func dejar_de_curiosear() -> void:
	incidente = null
	llego = false
	if estado == Estado.CURIOSO:
		pausa = 0.0
		estado = Estado.PATRULLA
		elegir_destino()

func recibir_golpe(danio, direccion = Vector3.ZERO):
	print("recibir_golpe llamado, vida antes: ", vida)
	if vida <= 0:
		print(name, " ya está en 0")
		return
	vida = max(vida - danio, 0)
	global_position += direccion * 3.0
	print(name, ": resistencia ", vida)

func ir_a(p, vel := -1.0, umbral := UMBRAL_RUTA):
	if vel < 0.0:
		vel = rapidez
	var dir: Vector3
	if usa_malla:
		if agente.target_position.distance_to(p) > umbral:
			agente.target_position = p
		dir = agente.get_next_path_position() - global_position
	else:
		dir = p - global_position
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
	anim.play("sprint" if es_noche and vel >= rapidez_noche else "walk")
