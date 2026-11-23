class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO, HUIR }

const INTERVALO_REVISAR := 0.5
const TIEMPO_ATASCO := 1.5
const DISTANCIA_ATASCO := 3.0
const UMBRAL_RUTA := 0.3
const UMBRAL_RUTA_PERSECUCION := 1.0
const GRUPO_CIUDADANOS := "ciudadanos"
const DISTANCIA_SEPARACION := 1.35
const FUERZA_SEPARACION := 4.2
const VELOCIDAD_GIRO := 10.0
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
@export var vida := 100
@export var es_administrativo := false:
	set(valor):
		es_administrativo = valor
		aplicar_contorno()
@export var rapidez := 2.0
@export var radio_ver := 12.0
@export var radio_perder := 20.0
@export var distancia_encarar := 1.75
@export var puntos: Array[Vector3] = [
	Vector3(-6, 0, -3), Vector3(6, 0, -3)]

@export_group("Hostilidad")
@export var rapidez_perseguir := 5.5
@export var ataca_policia := false
@export var danio_policia := 1

@export_group("Miedo")
@export var se_asusta := false
@export var radio_miedo := 7.0
@export var rapidez_huida := 5.0

@export_group("Noche")
@export var rapidez_noche := 3.5
@export var centro_noche := Vector3.ZERO
@export var radio_minimo_noche := 10.0
@export var radio_noche := 26.0
@export var pausa_noche_max := 0.3

@export var radio_avoidance := 0.75
@export var distancia_vecinos := 6.5
@export var max_vecinos := 14
@export var horizonte_agentes := 2.8

@onready var anim = $Modelo/AnimationPlayer
@onready var agente: NavigationAgent3D = $NavigationAgent3D

var estado := Estado.PATRULLA
var punto := 0
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
var contorno_visible := false
var reloj_noche := 0.0
var partida = null
var reloj_objetivo := 0.0
var reloj_golpe := 0.0
var lado_golpe := false
var destino_huida := Vector3.ZERO
var reloj_miedo := 0.0
var factor_ritmo := 1.0
var fase_flanqueo := 0.0
var empuje_externo := Vector3.ZERO
var reloj_impacto := 0.0

static func blinn_phong(normal: Vector3, hacia_luz: Vector3, hacia_ojo: Vector3, brillo: float) -> float:
	var n := normal.normalized()
	var l := hacia_luz.normalized()
	var v := hacia_ojo.normalized()
	var h := (l + v).normalized()
	var ndot_h := maxf(0.0, n.dot(h))
	return pow(ndot_h, brillo)

func reproducir_anim(nombre: String, forzar := false) -> void:
	if anim == null or not anim.has_animation(nombre):
		return
	if forzar or anim.current_animation != nombre:
		anim.play(nombre)

func aplicar_contorno() -> void:
	if not is_inside_tree():
		return
	var material: ShaderMaterial = null
	if es_administrativo and contorno_visible:
		material = ShaderMaterial.new()
		material.shader = SHADER_CONTORNO
	for malla in find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_overlay = material

func mostrar_contorno_noche() -> void:
	contorno_visible = true
	aplicar_contorno()

func _ready() -> void:
	factor_ritmo = randf_range(0.88, 1.14)
	fase_flanqueo = randf_range(-1.0, 1.0)
	var ambiente = get_tree().get_first_node_in_group("ambiente_noche")
	if ambiente != null and ambiente.activa:
		contorno_visible = true
	aplicar_contorno()
	if not agente.velocity_computed.is_connected(_al_velocidad_calculada):
		agente.velocity_computed.connect(_al_velocidad_calculada)
	agente.avoidance_enabled = true
	agente.radius = radio_avoidance
	agente.neighbor_distance = distancia_vecinos
	agente.max_neighbors = max_vecinos
	agente.time_horizon_agents = horizonte_agentes
	agente.path_desired_distance = 0.55
	agente.target_desired_distance = 0.55
	agente.avoidance_priority = 0.5

	if not viene_de_afuera:
		origen = global_position
	reloj_revisar = randf() * INTERVALO_REVISAR
	reloj_noche = randf() * INTERVALO_REVISAR
	for i in range(10):
		await get_tree().physics_frame
		var mapa := agente.get_navigation_map()
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
		var mapa := agente.get_navigation_map()
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
		reloj_atasco += delta
		if reloj_atasco >= TIEMPO_ATASCO:
			reloj_atasco = 0.0
			if global_position.distance_to(ultima_pos) < 0.3:
				punto = (punto + 1) % puntos.size()
			ultima_pos = global_position
		ir_a(puntos[punto], rapidez * factor_ritmo)
		if distancia_plana(puntos[punto]) < 0.35:
			punto = (punto + 1) % puntos.size()
		return
	if pausa > 0.0:
		pausa -= delta
		reloj_atasco = 0.0
		ultima_pos = global_position
		detenerse()
		return
	tiempo_ruta += delta
	if llego_a(destino_azar, 0.65) or tiempo_ruta > tiempo_max_ruta:
		var base_pausa := randf_range(0.0, pausa_noche_max) if es_noche else randf_range(pausa_min, pausa_max)
		pausa = base_pausa * clampf(factor_ritmo, 0.8, 1.3)
		detenerse()
		elegir_destino()
		return
	revisar_atasco(delta)
	var vel_patrulla: float = (rapidez_noche if es_noche else rapidez) * factor_ritmo
	ir_a(destino_azar, vel_patrulla)

func actualizar_noche(delta: float) -> void:
	reloj_noche -= delta
	if reloj_noche > 0.0:
		return
	reloj_noche = INTERVALO_REVISAR
	var noche := false
	var hay_reloj := false
	var juego = get_tree().get_first_node_in_group("juego")
	if juego != null and "fase" in juego:
		hay_reloj = true
		noche = juego.fase == Juego.Fase.NOCHE
	else:
		if partida == null or not is_instance_valid(partida):
			partida = get_tree().get_first_node_in_group("partida")
		if partida != null:
			hay_reloj = true
			noche = partida.tiempo > 0.0 and partida.tiempo < partida.noche_en
	if not hay_reloj:
		return
	if noche and not es_noche:
		es_noche = true
		mostrar_contorno_noche()
		if estado == Estado.PATRULLA:
			pausa = 0.0
			elegir_destino()
	elif not noche and es_noche:
		es_noche = false
		contorno_visible = false
		aplicar_contorno()
		if estado == Estado.PATRULLA:
			pausa = 0.0
			elegir_destino()

func actualizar_objetivo(delta: float) -> void:
	reloj_objetivo -= delta
	if reloj_objetivo > 0.0 and is_instance_valid(objetivo):
		return
	reloj_objetivo = 0.4
	var mejor := buscar_policia()
	if mejor != null:
		objetivo = mejor

func buscar_policia() -> Node3D:
	var mejor: Node3D = null
	var mejor_d := INF
	for p in get_tree().get_nodes_in_group("jugador"):
		if not is_instance_valid(p):
			continue
		var d := global_position.distance_squared_to((p as Node3D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = p
	return mejor

func amenaza_cercana(radio: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_d := radio
	for m in get_tree().get_nodes_in_group("manifestantes"):
		if not is_instance_valid(m):
			continue
		var d := global_position.distance_to((m as Node3D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = m
	return mejor

func alertar_cercanos(radio := 8.0, asustar_tambien := false) -> void:
	for nodo in get_tree().get_nodes_in_group(GRUPO_CIUDADANOS):
		var otro := nodo as Ciudadano
		if otro == null or otro == self or not is_instance_valid(otro):
			continue
		if global_position.distance_to(otro.global_position) > radio:
			continue
		if asustar_tambien and (otro.es_administrativo or otro.se_asusta) and otro.estado == Estado.PATRULLA:
			otro.destino_huida = otro.punto_de_refugio(self)
			otro.reloj_miedo = 1.6
			otro.estado = Estado.HUIR
		elif persigue_policia and otro.persigue_policia and otro.estado == Estado.PATRULLA and is_instance_valid(objetivo):
			otro.objetivo = objetivo
			otro.estado = Estado.PERSEGUIR

func punto_de_intercepcion() -> Vector3:
	var p := objetivo.global_position
	if "velocity" in objetivo:
		var vel := Vector3(objetivo.velocity.x, 0.0, objetivo.velocity.z)
		p += vel * clampf(global_position.distance_to(p) / maxf(rapidez_perseguir, 0.1), 0.0, 1.0)
	var hacia := p - global_position
	hacia.y = 0.0
	if hacia.length() > 2.5:
		var lateral := Vector3(-hacia.z, 0.0, hacia.x).normalized()
		p += lateral * (fase_flanqueo * 1.15)
	return p

func punto_de_refugio(amenaza: Node3D) -> Vector3:
	var lejos := global_position - amenaza.global_position
	lejos.y = 0.0
	lejos = lejos.normalized() if lejos.length() > 0.1 else Vector3.RIGHT
	var poli := buscar_policia()
	if poli != null and global_position.distance_to(poli.global_position) < 30.0:
		var detras := poli.global_position - amenaza.global_position
		detras.y = 0.0
		if detras.length() > 0.1:
			return poli.global_position + detras.normalized() * 2.0
	return global_position + lejos * 10.0

func animar_golpe() -> void:
	lado_golpe = not lado_golpe
	var nombre := "attack-melee-right" if lado_golpe else "attack-melee-left"
	if anim != null and anim.has_animation(nombre):
		anim.play(nombre)
		if anim.has_animation("idle"):
			anim.queue("idle")

func atacar_policia(delta: float) -> void:
	reloj_golpe -= delta
	if reloj_golpe > 0.0:
		return
	reloj_golpe = randf_range(0.85, 1.35)
	animar_golpe()
	if not is_instance_valid(objetivo):
		return
	var salud = objetivo.get_node_or_null("Salud")
	if salud != null and salud.has_method("recibir_golpe"):
		salud.recibir_golpe(danio_policia)
	elif objetivo.has_method("recibir_golpe"):
		objetivo.recibir_golpe(danio_policia)

func actualizar_prioridad_avoidance() -> void:
	var quieto := not quiere_moverse or estado == Estado.PELEA or (estado == Estado.CURIOSO and llego)
	agente.avoidance_priority = 1.0 if quieto else 0.5

func calcular_separacion() -> Vector3:
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
		var peso := (DISTANCIA_SEPARACION - dist) / DISTANCIA_SEPARACION
		empuje += (d / dist) * (peso * peso)
	for grupo in ["manifestantes", "jugador"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			var otro := nodo as Node3D
			if otro == null or otro == self:
				continue
			var d := global_position - otro.global_position
			d.y = 0.0
			var dist := d.length()
			var radio_seguridad := DISTANCIA_SEPARACION * 0.9
			if dist >= radio_seguridad or dist < 0.01:
				continue
			var peso := (radio_seguridad - dist) / radio_seguridad
			empuje += (d / dist) * (peso * 0.85)
	return empuje.limit_length(1.5) * FUERZA_SEPARACION

func _physics_process(delta: float) -> void:
	if not listo:
		return
	if not usa_malla:
		var mapa := agente.get_navigation_map()
		usa_malla = NavigationServer3D.map_get_regions(mapa).size() > 0
	quiere_moverse = false
	velocity += get_gravity() * delta

	if reloj_impacto > 0.0:
		reloj_impacto -= delta
		velocity.x = empuje_externo.x
		velocity.z = empuje_externo.z
		empuje_externo = empuje_externo.move_toward(Vector3.ZERO, 18.0 * delta)
		move_and_slide()
		return

	if enfriamiento > 0.0:
		enfriamiento -= delta
	if persigue_policia:
		actualizar_objetivo(delta)
	var distancia := INF
	if is_instance_valid(objetivo):
		distancia = global_position.distance_to(objetivo.global_position)
	revisar_cercania(delta)
	actualizar_noche(delta)

	if (es_administrativo or se_asusta) and (estado == Estado.PATRULLA or estado == Estado.CURIOSO):
		var amenaza := amenaza_cercana(radio_miedo)
		if amenaza != null:
			if estado == Estado.CURIOSO:
				soltar_incidente()
			estado = Estado.HUIR
			destino_huida = punto_de_refugio(amenaza)
			reloj_miedo = 2.0
			alertar_cercanos(7.5, true)

	match estado:
		Estado.PATRULLA:
			if persigue_policia and distancia < radio_ver:
				estado = Estado.PERSEGUIR
				alertar_cercanos(8.0, false)
			patrullar(delta)
		Estado.PERSEGUIR:
			if distancia > radio_perder or not is_instance_valid(objetivo):
				estado = Estado.PATRULLA
			elif distancia < distancia_encarar:
				mirar_hacia(objetivo.global_position, delta)
				if ataca_policia:
					frenar_solo()
					atacar_policia(delta)
				else:
					detenerse()
			else:
				ir_a(punto_de_intercepcion(), rapidez_perseguir * clampf(factor_ritmo, 0.92, 1.12), UMBRAL_RUTA_PERSECUCION)
		Estado.ACUDIR:
			if llego_a(destino_incidente) or atascado_cerca(delta):
				llego = true
				estado = Estado.PELEA
			else:
				ir_a(destino_incidente, rapidez_acudir * factor_ritmo)
		Estado.PELEA:
			frenar_solo()
			var mira := destino_incidente
			if is_instance_valid(rival):
				mira = rival.global_position
			mirar_hacia(mira, delta)
			pelear(delta)
		Estado.HUIR:
			var amenaza := amenaza_cercana(radio_miedo * 1.6)
			if amenaza != null:
				reloj_miedo = 2.0
				destino_huida = punto_de_refugio(amenaza)
			else:
				reloj_miedo -= delta
			if reloj_miedo <= 0.0:
				estado = Estado.PATRULLA
				pausa = 0.0
				elegir_destino()
			else:
				ir_a(destino_huida, rapidez_huida * clampf(factor_ritmo, 0.95, 1.15))
		Estado.CURIOSO:
			if persigue_policia and distancia < radio_ver:
				soltar_incidente()
				estado = Estado.PERSEGUIR
			else:
				if not llego and (llego_a(destino_incidente) or atascado_cerca(delta)):
					llego = true
				if llego:
					detenerse()
					mirar_hacia(centro_incidente, delta)
				else:
					ir_a(destino_incidente, rapidez_acudir * factor_ritmo)

	actualizar_prioridad_avoidance()
	if not quiere_moverse:
		var emp := calcular_separacion()
		if emp.length() > 0.35:
			velocity.x = emp.x * 0.45
			velocity.z = emp.z * 0.45
	move_and_slide()

func pelear(delta: float) -> void:
	reloj_golpe -= delta
	if reloj_golpe > 0.0:
		return
	reloj_golpe = randf_range(0.55, 1.05)
	animar_golpe()

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

func frenar_solo() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if agente.avoidance_enabled:
		agente.velocity = Vector3.ZERO

func detenerse() -> void:
	frenar_solo()
	reproducir_anim("idle")

func mirar_hacia(punto_mira: Vector3, delta := 0.016) -> void:
	var dir := punto_mira - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		var ang_objetivo := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, ang_objetivo, clampf(VELOCIDAD_GIRO * delta, 0.0, 1.0))

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

func recibir_golpe(danio, direccion = Vector3.ZERO) -> void:
	if vida <= 0:
		return
	vida = max(vida - danio, 0)
	var emp := Vector3(direccion.x, 0.0, direccion.z)
	if emp.length() > 0.01:
		empuje_externo = emp.normalized() * 5.5
		reloj_impacto = 0.22
	if anim != null and anim.has_animation("hurt"):
		reproducir_anim("hurt", true)
	if vida <= 35 and (se_asusta or es_administrativo) and estado != Estado.HUIR:
		soltar_incidente()
		estado = Estado.HUIR
		reloj_miedo = 2.5
		destino_huida = global_position + (emp.normalized() * 8.0 if emp.length() > 0.01 else Vector3.BACK * 8.0)

func ir_a(p: Vector3, vel := -1.0, umbral := UMBRAL_RUTA) -> void:
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
	if dir.length() < 0.08:
		velocity.x = 0.0
		velocity.z = 0.0
		if agente.avoidance_enabled:
			agente.velocity = Vector3.ZERO
		reproducir_anim("idle")
		return
	dir = dir.normalized()
	var separacion := calcular_separacion()
	var dir_final := (dir * vel + separacion).limit_length(vel)
	if dir_final.length() < 0.05:
		dir_final = dir * (vel * 0.5)
	quiere_moverse = true
	if agente.avoidance_enabled:
		agente.max_speed = vel
		agente.velocity = dir_final
	else:
		velocity.x = dir_final.x
		velocity.z = dir_final.z
	var ang_objetivo := atan2(-dir_final.x, -dir_final.z)
	rotation.y = lerp_angle(rotation.y, ang_objetivo, clampf(VELOCIDAD_GIRO * get_physics_process_delta_time(), 0.0, 1.0))
	var debe_correr := (es_noche and vel >= rapidez_noche * 0.9) or vel >= 4.5
	reproducir_anim("sprint" if debe_correr else "walk")
