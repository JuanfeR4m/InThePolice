class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO, HUIR }

signal ladron_atrapado(ciudadano: Ciudadano)
signal ladron_escapo(ciudadano: Ciudadano)

const INTERVALO_REVISAR := 0.5
const TIEMPO_ATASCO := 1.5
const DISTANCIA_ATASCO := 3.0

const TRAMO_MIN := 8.0
const TRAMO_MAX := 20.0
const GIRO_MAX := PI / 3.0
const PROBABILIDAD_PAUSA := 0.2

const SHADER_CONTORNO := preload("res://shaders/contorno_defender.gdshader")
const COLOR_LADRON := Color(0.95, 0.1, 0.1)
const RADIO_CAPTURA := 1.3
const INTERVALO_HUIDA := 0.8
const DISTANCIA_HUIDA := 14.0
const DURACION_ROBO := 0.7

@export var objetivo: Node3D
@export var persigue_policia := false
@export var cooldown_pelea := 20.0
@export var patrulla_aleatoria := true
@export var radio_deambular := 25.0
# La feria es un cuadrado: los ciudadanos nunca eligen destinos fuera de él
@export var centro_feria := Vector3.ZERO
@export var limite_feria := 13.0
@export var pausa_min := 0.5
@export var pausa_max := 3.0
@export var rapidez_acudir := 4.0
@export var margen_cambio := 4.0
@export var tiempo_max_ruta := 40.0
@export var vida = 100
@export var rapidez = 2.0
## Velocidad del ladron: menor que la de correr de los jugadores (7), asi que alcanzarlo es posible
@export var rapidez_huida := 5.5
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
var rumbo := randf() * TAU
var ya_entro := false
var es_ladron := false
var reloj_huida := 0.0
var reloj_robo := 0.0
var reloj_destino_huida := 0.0
var destino_huida := Vector3.ZERO

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
	agente.avoidance_priority = randf()
	ignorar_otros_ciudadanos()
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
	p = limitar_a_feria(p)
	if usa_malla:
		var mapa = agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			return limitar_a_feria(NavigationServer3D.map_get_closest_point(mapa, p))
	return p

func distancia_plana(p: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(p.x, p.z))

func llego_a(p: Vector3, tolerancia := 0.5) -> bool:
	if distancia_plana(p) < tolerancia:
		return true
	return usa_malla and agente.is_navigation_finished() and distancia_plana(p) < 2.5

func ignorar_otros_ciudadanos() -> void:
	for otro in get_tree().get_nodes_in_group("ciudadanos"):
		if otro != self and otro is CharacterBody3D:
			add_collision_exception_with(otro)
			otro.add_collision_exception_with(self)


func limitar_a_feria(p: Vector3) -> Vector3:
	p.x = clampf(p.x, centro_feria.x - limite_feria, centro_feria.x + limite_feria)
	p.z = clampf(p.z, centro_feria.z - limite_feria, centro_feria.z + limite_feria)
	return p

func dentro_de_feria(p: Vector3, holgura := 0.0) -> bool:
	return absf(p.x - centro_feria.x) <= limite_feria + holgura \
		and absf(p.z - centro_feria.z) <= limite_feria + holgura


func contener_en_feria() -> void:
	if not ya_entro:
		ya_entro = dentro_de_feria(global_position)
		return
	if dentro_de_feria(global_position):
		return
	var dentro := limitar_a_feria(global_position)
	global_position.x = dentro.x
	global_position.z = dentro.z
	velocity.x = 0.0
	velocity.z = 0.0

func elegir_destino(dar_la_vuelta := false) -> void:
	if dar_la_vuelta:
		rumbo += randf_range(PI * 0.6, PI * 1.4)
	else:
		rumbo += randf_range(-GIRO_MAX, GIRO_MAX)
	var tramo := randf_range(TRAMO_MIN, TRAMO_MAX)
	var dir := Vector3(cos(rumbo), 0.0, sin(rumbo))
	var candidato := global_position + dir * tramo

	if absf(candidato.x - centro_feria.x) > limite_feria:
		dir.x = -dir.x
	if absf(candidato.z - centro_feria.z) > limite_feria:
		dir.z = -dir.z
	rumbo = atan2(dir.z, dir.x)
	candidato = limitar_a_feria(global_position + dir * tramo)
	destino_azar = ajustar_a_malla(candidato)
	tiempo_ruta = 0.0
	reloj_atasco = 0.0
	ultima_pos = global_position

func revisar_atasco(delta: float) -> void:
	reloj_atasco += delta
	if reloj_atasco < 1.5:
		return
	reloj_atasco = 0.0
	if global_position.distance_to(ultima_pos) < 0.3:
		elegir_destino(true)
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
		elegir_destino()
		if randf() < PROBABILIDAD_PAUSA:
			pausa = randf_range(pausa_min, pausa_max)
			detenerse()
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
		Estado.HUIR:
			huir(delta)
		Estado.PELEA:
			frenar()
			forcejear()
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
	contener_en_feria()

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

func frenar() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if agente.avoidance_enabled:
		agente.velocity = Vector3.ZERO

func detenerse() -> void:
	frenar()
	anim.stop()

# ---------- Animaciones de pelea segun como se resuelve el incidente ----------
func animaciones_del_modo(modo: int) -> Array[String]:
	# [brazo izquierdo, brazo derecho]: cada peleador usa uno. Cambia los nombres a gusto.
	match modo:
		IncidentePresionado.Modo.MANTENER:
			return ["attack-melee-left", "attack-melee-right"]
		IncidentePresionado.Modo.ESPICHAR:
			return ["attack-kick-left", "attack-kick-right"]
		IncidentePresionado.Modo.JUNTOS:
			return ["interact-left", "interact-right"]
		IncidentePresionado.Modo.ESPICHAR_JUNTOS:
			return ["holding-both", "holding-both"]
		IncidentePresionado.Modo.ALTERNAR:
			return ["holding-left", "holding-right"]
		IncidentePresionado.Modo.SECUENCIA:
			return ["emote-no", "emote-no"]
	return ["attack-melee-left", "attack-melee-right"]

func forcejear() -> void:
	var modo := IncidentePresionado.Modo.MANTENER
	var avance := 0.0
	if is_instance_valid(incidente):
		modo = incidente.modo
		avance = clampf(incidente.progreso, 0.0, 1.0)
	var lado := get_instance_id() % 2
	var nombre: String = animaciones_del_modo(modo)[lado]
	if not anim.has_animation(nombre):
		return
	# Entre mas avanza el progreso, mas cansados pelean
	anim.speed_scale = lerpf(1.6, 0.5, avance)
	anim.play(nombre)

# ---------- Ladron ----------
func aplicar_contorno() -> void:
	var material: ShaderMaterial = null
	if es_ladron:
		material = ShaderMaterial.new()
		material.shader = SHADER_CONTORNO
		material.set_shader_parameter("color_contorno", COLOR_LADRON)
		material.set_shader_parameter("grosor", 0.035)
		material.set_shader_parameter("velocidad_pulso", 9.0)
	for malla in find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_overlay = material

func volverse_ladron(tiempo: float) -> void:
	es_ladron = true
	reloj_huida = tiempo
	reloj_robo = DURACION_ROBO
	reloj_destino_huida = 0.0
	soltar_incidente()
	estado = Estado.HUIR
	aplicar_contorno()

func jugador_mas_cercano() -> Node3D:
	var mejor: Node3D = null
	var menor := INF
	for nodo in get_tree().get_nodes_in_group("jugador"):
		var jugador := nodo as Node3D
		if jugador == null:
			continue
		var d := distancia_plana(jugador.global_position)
		if d < menor:
			menor = d
			mejor = jugador
	return mejor

func elegir_destino_huida(perseguidor: Node3D) -> void:
	# Prueba 8 direcciones al azar y se queda con la que lo deja mas lejos del jugador
	# (asi no se arrincona contra el borde de la feria)
	var mejor := Vector3.ZERO
	var mejor_puntaje := -INF
	for i in 8:
		var angulo := randf() * TAU
		var dir := Vector3(cos(angulo), 0.0, sin(angulo))
		var candidato := ajustar_a_malla(global_position + dir * DISTANCIA_HUIDA)
		if distancia_plana(candidato) < 4.0:
			continue
		var puntaje := distancia_plana(candidato)
		if perseguidor != null:
			puntaje = Vector2(candidato.x, candidato.z).distance_to(
				Vector2(perseguidor.global_position.x, perseguidor.global_position.z))
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor = candidato
	if mejor_puntaje == -INF:
		mejor = ajustar_a_malla(centro_feria)
	destino_huida = mejor

func huir(delta: float) -> void:
	# Primero agarra lo robado (pick-up) y recien despues sale corriendo
	if reloj_robo > 0.0:
		reloj_robo -= delta
		frenar()
		anim.speed_scale = 1.0
		if anim.has_animation("pick-up"):
			anim.play("pick-up")
		return
	reloj_huida -= delta
	if reloj_huida <= 0.0:
		escapar()
		return
	var perseguidor := jugador_mas_cercano()
	if perseguidor != null and distancia_plana(perseguidor.global_position) <= RADIO_CAPTURA:
		atrapar()
		return
	reloj_destino_huida -= delta
	if reloj_destino_huida <= 0.0 or llego_a(destino_huida, 1.0):
		reloj_destino_huida = INTERVALO_HUIDA
		elegir_destino_huida(perseguidor)
	ir_a(destino_huida, rapidez_huida)

func atrapar() -> void:
	ladron_atrapado.emit(self)
	queue_free()

func escapar() -> void:
	ladron_escapo.emit(self)
	queue_free()

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
	p = limitar_a_feria(p)
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
	anim.speed_scale = 1.0
	anim.play("sprint" if estado == Estado.HUIR else "walk")
