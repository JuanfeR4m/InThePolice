class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO }

const INTERVALO_REVISAR := 0.5
const TIEMPO_ATASCO := 1.5
const DISTANCIA_ATASCO := 3.0

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
@export var rapidez = 2.0
@export var radio_ver = 6.0
@export var radio_perder = 9.0
@export var puntos: Array[Vector3] = [
	Vector3(-6, 0, -3), Vector3(6, 0, -3)]
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

static func blinn_phong(normal: Vector3, hacia_luz: Vector3, hacia_ojo: Vector3, brillo: float) -> float:
	var n = normal.normalized()
	var l = hacia_luz.normalized()
	var v = hacia_ojo.normalized()
	var h = (l + v).normalized()
	var ndot_h = max(0.0, n.dot(h))
	return pow(ndot_h, brillo)

func _ready() -> void:
	if not viene_de_afuera:
		origen = global_position
	reloj_revisar = randf() * INTERVALO_REVISAR
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
	var ang := randf() * TAU
	var dist := sqrt(randf()) * radio_deambular
	destino_azar = ajustar_a_malla(origen + Vector3(cos(ang), 0.0, sin(ang)) * dist)
	tiempo_ruta = 0.0
	reloj_atasco = 0.0
	ultima_pos = global_position

func revisar_atasco(delta: float) -> void:
	reloj_atasco += delta
	if reloj_atasco < 1.5:
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
		pausa = randf_range(pausa_min, pausa_max)
		detenerse()
		elegir_destino()
		return
	revisar_atasco(delta)
	ir_a(destino_azar)

func _physics_process(delta):
	if not listo:
		return
	quiere_moverse = false
	velocity += get_gravity() * delta
	if enfriamiento > 0.0:
		enfriamiento -= delta
	var distancia := INF
	if objetivo:
		distancia = global_position.distance_to(objetivo.global_position)
	revisar_cercania(delta)
	match estado:
		Estado.PATRULLA:
			if persigue_policia and distancia < radio_ver:
				estado = Estado.PERSEGUIR
				print("lo vio a ", snappedf(distancia, 0.01), " m")
			patrullar(delta)
		Estado.PERSEGUIR:
			if distancia > radio_perder:
				estado = Estado.PATRULLA
				print("lo perdió a ", snappedf(distancia, 0.01), " m")
			ir_a(objetivo.global_position)
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

func ir_a(p, vel := -1.0):
	if vel < 0.0:
		vel = rapidez
	var dir: Vector3
	if usa_malla:
		if agente.target_position.distance_to(p) > 0.3:
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
	anim.play("walk")
