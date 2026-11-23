class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO, HUIR, LADRON }

signal ladron_atrapado(ciudadano: Ciudadano)
signal ladron_escapo(ciudadano: Ciudadano)

const INTERVALO_REVISAR := 0.5
const TIEMPO_ATASCO := 1.2
const DISTANCIA_ATASCO := 3.0
const UMBRAL_RUTA := 0.3
const UMBRAL_RUTA_PERSECUCION := 0.8
const GRUPO_CIUDADANOS := "ciudadanos"
const DISTANCIA_SEPARACION := 1.5
const FUERZA_SEPARACION := 5.2
const VELOCIDAD_GIRO := 11.0
const DISTANCIA_RAYO_OBSTACULO := 1.65
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
@export var distancia_encarar := 1.8
@export var puntos: Array[Vector3] = [
	Vector3(-6, 0, -3), Vector3(6, 0, -3)]

@export_group("Hostilidad")
@export var rapidez_perseguir := 5.5
@export var ataca_policia := false
@export var danio_policia := 1

@export_group("Ladron")
## Velocidad del ladron: menor que la de correr de los jugadores (7), asi que alcanzarlo es posible
@export var rapidez_ladron := 5.5

@export_group("Miedo")
@export var se_asusta := false
@export var radio_miedo := 7.0
@export var rapidez_huida := 5.0

@export_group("Noche")
@export var rapidez_noche := 3.8
@export var centro_noche := Vector3.ZERO
@export var radio_minimo_noche := 10.0
@export var radio_noche := 26.0
@export var pausa_noche_max := 1.4

@export var radio_avoidance := 0.85
@export var distancia_vecinos := 7.5
@export var max_vecinos := 16
@export var horizonte_agentes := 3.2

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
var rol_nocturno := 0
var empuje_externo := Vector3.ZERO
var reloj_impacto := 0.0
var angulo_vigilancia := 0.0
var oculto_en_cobertura := false
var es_ladron := false
var reloj_huida_ladron := 0.0
var reloj_robo := 0.0
var reloj_destino_ladron := 0.0
var destino_ladron := Vector3.ZERO

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
	if es_ladron:
		material = ShaderMaterial.new()
		material.shader = SHADER_CONTORNO
		material.set_shader_parameter("color_contorno", COLOR_LADRON)
		material.set_shader_parameter("grosor", 0.035)
		material.set_shader_parameter("velocidad_pulso", 9.0)
	elif es_administrativo and contorno_visible:
		material = ShaderMaterial.new()
		material.shader = SHADER_CONTORNO
	for malla in find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_overlay = material

func mostrar_contorno_noche() -> void:
	contorno_visible = true
	aplicar_contorno()

func _ready() -> void:
	factor_ritmo = randf_range(0.9, 1.15)
	fase_flanqueo = [-1.0, 0.0, 1.0][randi() % 3]
	rol_nocturno = randi() % 3
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
	agente.path_desired_distance = 0.6
	agente.target_desired_distance = 0.6
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
		var sep := calcular_separacion() * 0.35
		velocity.x = v.x + sep.x
		velocity.z = v.z + sep.z

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

func llego_a(p: Vector3, tolerancia := 0.55) -> bool:
	if distancia_plana(p) < tolerancia:
		return true
	return usa_malla and agente.is_navigation_finished() and distancia_plana(p) < 2.2

func tiene_linea_vision(objetivo_pos: Vector3) -> bool:
	var espacio := get_world_3d().direct_space_state
	var inicio := global_position + Vector3.UP * 1.1
	var fin := objetivo_pos + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(inicio, fin)
	query.exclude = [self]
	var res := espacio.intersect_ray(query)
	if res.is_empty():
		return true
	var collider = res.get("collider")
	return collider != null and (collider == objetivo or (collider is Node and (collider.is_in_group("jugador") or collider.is_in_group("manifestantes"))))

func evadir_obstaculos_locales(dir_deseada: Vector3) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	var origen_rayo := global_position + Vector3.UP * 0.75
	var dir_norm := dir_deseada.normalized()
	var izq := dir_norm.rotated(Vector3.UP, 0.55)
	var der := dir_norm.rotated(Vector3.UP, -0.55)
	var izq_abierta := dir_norm.rotated(Vector3.UP, 1.15)
	var der_abierta := dir_norm.rotated(Vector3.UP, -1.15)

	var rayos := [dir_norm, izq, der, izq_abierta, der_abierta]
	var pesos := [1.4, 1.0, 1.0, 0.7, 0.7]
	var desvio := Vector3.ZERO

	for i in range(rayos.size()):
		var r_dir: Vector3 = rayos[i]
		var dist_check: float = DISTANCIA_RAYO_OBSTACULO if i < 3 else DISTANCIA_RAYO_OBSTACULO * 0.75
		var query := PhysicsRayQueryParameters3D.create(origen_rayo, origen_rayo + r_dir * dist_check)
		query.exclude = [self]
		var hit := espacio.intersect_ray(query)
		if not hit.is_empty():
			var collider = hit.get("collider")
			if collider is Node and (collider.is_in_group(GRUPO_CIUDADANOS) or collider.is_in_group("jugador") or collider.is_in_group("manifestantes")):
				continue
			var normal: Vector3 = hit.get("normal", Vector3.ZERO)
			normal.y = 0.0
			var dist_hit := origen_rayo.distance_to(hit["position"])
			var urgencia := clampf((dist_check - dist_hit) / dist_check, 0.0, 1.0)
			var tangente := Vector3(-r_dir.z, 0.0, r_dir.x)
			if normal.length() > 0.01 and tangente.dot(normal) < 0.0:
				tangente = -tangente
			desvio += (normal * 0.7 + tangente * 0.9).normalized() * urgencia * pesos[i]

	return desvio

func buscar_cobertura_nocturna(amenaza: Node3D) -> Vector3:
	var mejor_pos := global_position
	var mejor_puntaje := -INF
	var poli := buscar_policia()
	for i in range(10):
		var ang := (TAU / 10.0) * i + randf_range(-0.2, 0.2)
		var dist := randf_range(6.0, 15.0)
		var candidato := ajustar_a_malla(global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist)
		var puntaje := candidato.distance_to(amenaza.global_position) * 1.4
		if poli != null:
			puntaje -= candidato.distance_to(poli.global_position) * 0.8
		var espacio := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(candidato + Vector3.UP * 1.1, amenaza.global_position + Vector3.UP * 1.1)
		q.exclude = [self]
		if not espacio.intersect_ray(q).is_empty():
			puntaje += 12.0
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_pos = candidato
	return mejor_pos

func elegir_destino() -> void:
	if not is_inside_tree():
		return
	var ang := randf() * TAU
	if es_noche:
		if es_administrativo or se_asusta:
			var amenaza := amenaza_cercana(radio_miedo * 2.2)
			if amenaza != null:
				destino_azar = buscar_cobertura_nocturna(amenaza)
			else:
				var poli := buscar_policia()
				if poli != null and randf() < 0.65:
					destino_azar = ajustar_a_malla(poli.global_position + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(3.5, 7.5))
				else:
					var dist_n := randf_range(radio_minimo_noche, radio_noche)
					destino_azar = ajustar_a_malla(centro_noche + Vector3(cos(ang), 0.0, sin(ang)) * dist_n)
		elif persigue_policia:
			var poli := buscar_policia()
			if poli != null and randf() < 0.5:
				var ang_emboscada := ang + (rol_nocturno - 1) * 1.2
				destino_azar = ajustar_a_malla(poli.global_position + Vector3(cos(ang_emboscada), 0.0, sin(ang_emboscada)) * randf_range(9.0, 16.0))
			else:
				var dist_n := randf_range(radio_minimo_noche, radio_noche)
				destino_azar = ajustar_a_malla(centro_noche + Vector3(cos(ang), 0.0, sin(ang)) * dist_n)
		else:
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
	if global_position.distance_to(ultima_pos) < 0.35:
		elegir_destino()
	ultima_pos = global_position

func atascado_cerca(delta: float) -> bool:
	reloj_atasco += delta
	if reloj_atasco < TIEMPO_ATASCO:
		return false
	reloj_atasco = 0.0
	var quieto := global_position.distance_to(ultima_pos) < 0.35
	ultima_pos = global_position
	return quieto and distancia_plana(destino_incidente) < DISTANCIA_ATASCO

func patrullar(delta: float) -> void:
	if not patrulla_aleatoria:
		reloj_atasco += delta
		if reloj_atasco >= TIEMPO_ATASCO:
			reloj_atasco = 0.0
			if global_position.distance_to(ultima_pos) < 0.35:
				punto = (punto + 1) % puntos.size()
			ultima_pos = global_position
		var vel_ruta: float = (rapidez_noche if es_noche else rapidez) * factor_ritmo
		ir_a(puntos[punto], vel_ruta)
		if distancia_plana(puntos[punto]) < 0.4:
			punto = (punto + 1) % puntos.size()
		return
	if pausa > 0.0:
		pausa -= delta
		reloj_atasco = 0.0
		ultima_pos = global_position
		detenerse()
		if es_noche:
			angulo_vigilancia += delta * 2.2
			rotation.y += sin(angulo_vigilancia) * 0.9 * delta
		return
	tiempo_ruta += delta
	if llego_a(destino_azar, 0.7) or tiempo_ruta > tiempo_max_ruta:
		var base_pausa := randf_range(0.4, pausa_noche_max) if es_noche else randf_range(pausa_min, pausa_max)
		pausa = base_pausa * clampf(factor_ritmo, 0.8, 1.3)
		angulo_vigilancia = randf() * TAU
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

func alertar_cercanos(radio := 8.5, asustar_tambien := false) -> void:
	var alcance := radio * (1.25 if es_noche else 1.0)
	for nodo in get_tree().get_nodes_in_group(GRUPO_CIUDADANOS):
		var otro := nodo as Ciudadano
		if otro == null or otro == self or not is_instance_valid(otro):
			continue
		if global_position.distance_to(otro.global_position) > alcance:
			continue
		if asustar_tambien and (otro.es_administrativo or otro.se_asusta) and otro.estado == Estado.PATRULLA:
			otro.destino_huida = otro.punto_de_refugio(self)
			otro.reloj_miedo = 2.0
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
	var dist := hacia.length()
	if dist > 2.2:
		var lateral := Vector3(-hacia.z, 0.0, hacia.x).normalized()
		var amplitud := 2.4 if es_noche else 1.2
		var dir_flanco := (float(rol_nocturno - 1) if es_noche else fase_flanqueo)
		p += lateral * (dir_flanco * amplitud)
	return ajustar_a_malla(p)

func punto_de_refugio(amenaza: Node3D) -> Vector3:
	if es_noche:
		return buscar_cobertura_nocturna(amenaza)
	var lejos := global_position - amenaza.global_position
	lejos.y = 0.0
	lejos = lejos.normalized() if lejos.length() > 0.1 else Vector3.RIGHT
	var poli := buscar_policia()
	if poli != null and global_position.distance_to(poli.global_position) < 30.0:
		var detras := poli.global_position - amenaza.global_position
		detras.y = 0.0
		if detras.length() > 0.1:
			return ajustar_a_malla(poli.global_position + detras.normalized() * 2.2)
	return ajustar_a_malla(global_position + lejos * 10.0)

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
	reloj_golpe = randf_range(0.75, 1.25) if es_noche else randf_range(0.9, 1.4)
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
			var radio_seguridad := DISTANCIA_SEPARACION * 0.95
			if dist >= radio_seguridad or dist < 0.01:
				continue
			var peso := (radio_seguridad - dist) / radio_seguridad
			empuje += (d / dist) * peso
	return empuje.limit_length(1.8) * FUERZA_SEPARACION

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

	var radio_deteccion_miedo := radio_miedo * (1.35 if es_noche else 1.0)
	if (es_administrativo or se_asusta) and (estado == Estado.PATRULLA or estado == Estado.CURIOSO):
		var amenaza := amenaza_cercana(radio_deteccion_miedo)
		if amenaza != null:
			if estado == Estado.CURIOSO:
				soltar_incidente()
			estado = Estado.HUIR
			destino_huida = punto_de_refugio(amenaza)
			reloj_miedo = 2.4 if es_noche else 2.0
			alertar_cercanos(8.0, true)

	var radio_ver_actual := radio_ver * (0.75 if es_noche else 1.0)

	match estado:
		Estado.PATRULLA:
			if persigue_policia and distancia < radio_ver_actual and tiene_linea_vision(objetivo.global_position):
				estado = Estado.PERSEGUIR
				alertar_cercanos(9.0, false)
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
				var vel_caza := (rapidez_perseguir * (1.1 if es_noche else 1.0)) * clampf(factor_ritmo, 0.92, 1.12)
				ir_a(punto_de_intercepcion(), vel_caza, UMBRAL_RUTA_PERSECUCION)
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
		Estado.LADRON:
			huir_ladron(delta)
		Estado.HUIR:
			var amenaza := amenaza_cercana(radio_deteccion_miedo * 1.5)
			if amenaza != null:
				reloj_miedo = 2.2
				if llego_a(destino_huida, 1.0):
					destino_huida = punto_de_refugio(amenaza)
			else:
				reloj_miedo -= delta
			if reloj_miedo <= 0.0:
				estado = Estado.PATRULLA
				pausa = 0.3
				elegir_destino()
			elif es_noche and llego_a(destino_huida, 0.9) and amenaza != null and not tiene_linea_vision(amenaza.global_position):
				detenerse()
				mirar_hacia(amenaza.global_position, delta)
			else:
				ir_a(destino_huida, rapidez_huida * clampf(factor_ritmo, 0.95, 1.15))
		Estado.CURIOSO:
			if persigue_policia and distancia < radio_ver_actual and tiene_linea_vision(objetivo.global_position):
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
			velocity.x = emp.x * 0.55
			velocity.z = emp.z * 0.55
	move_and_slide()

# ---------- Ladron ----------
func volverse_ladron(tiempo: float) -> void:
	soltar_incidente()
	es_ladron = true
	reloj_huida_ladron = tiempo
	reloj_robo = DURACION_ROBO
	reloj_destino_ladron = 0.0
	pausa = 0.0
	estado = Estado.LADRON
	aplicar_contorno()

func elegir_destino_ladron(perseguidor: Node3D) -> void:
	# Prueba 8 direcciones al azar y se queda con la que lo deja mas lejos del jugador
	# (asi no se arrincona contra el borde de la feria)
	var mejor := global_position
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
		mejor = ajustar_a_malla(origen)
	destino_ladron = mejor

func huir_ladron(delta: float) -> void:
	# Primero agarra lo robado (pick-up) y recien despues sale corriendo
	if reloj_robo > 0.0:
		reloj_robo -= delta
		frenar_solo()
		reproducir_anim("pick-up")
		return
	reloj_huida_ladron -= delta
	if reloj_huida_ladron <= 0.0:
		escapar()
		return
	var perseguidor := buscar_policia()
	if perseguidor != null and distancia_plana(perseguidor.global_position) <= RADIO_CAPTURA:
		atrapar()
		return
	reloj_destino_ladron -= delta
	if reloj_destino_ladron <= 0.0 or llego_a(destino_ladron, 1.0):
		reloj_destino_ladron = INTERVALO_HUIDA
		elegir_destino_ladron(perseguidor)
	ir_a(destino_ladron, rapidez_ladron)

func atrapar() -> void:
	ladron_atrapado.emit(self)
	queue_free()

func escapar() -> void:
	ladron_escapo.emit(self)
	queue_free()

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
	if vida <= 35 and (se_asusta or es_administrativo) and estado != Estado.HUIR and not es_ladron:
		soltar_incidente()
		estado = Estado.HUIR
		reloj_miedo = 2.5
		destino_huida = ajustar_a_malla(global_position + (emp.normalized() * 8.0 if emp.length() > 0.01 else Vector3.BACK * 8.0))

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
	var evasion_muros := evadir_obstaculos_locales(dir) * vel
	var dir_final := (dir * vel + separacion + evasion_muros).limit_length(vel)
	if dir_final.length() < 0.08:
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
