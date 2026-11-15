class_name Ciudadano
extends CharacterBody3D

enum Estado { PATRULLA, PERSEGUIR, ACUDIR, PELEA, CURIOSO }

const GRUPO := "ciudadanos"
const SIN_DESTINO := Vector3(1e9, 1e9, 1e9)
const INTERVALO_REVISAR := 0.5
const FRAMES_ESPERA_MALLA := 30
const VELOCIDAD_GIRO := 8.0
const INTENTOS_DESTINO := 12
const TOLERANCIA_MALLA := 1.0
const DISTANCIA_ENTRE_DESTINOS := 2.0
const RADIO_SEPARACION := 1.1
const FUERZA_SEPARACION := 2.0
const RADIO_ESQUIVE_PERSONAS := 1.6   # NUEVO
const DISTANCIA_PUESTO := 1.0         # NUEVO
const RADIO_SOLAPE := 0.6             # NUEVO
const TIEMPO_SOLAPE := 1.5            # NUEVO
const TOLERANCIA_PASO := 0.5
const TOLERANCIA_ESQUINA := 0.25
const REFRESCO_RUTA := 1.0
const INTERVALO_PROGRESO := 2.0
const PROGRESO_MINIMO := 0.8
const DISTANCIA_ATASCO := 3.0
const TIEMPO_MAX_INCIDENTE := 60.0
const LARGO_RAYO := 1.2
const ALTURA_RAYO := 0.5
const ANGULO_RAYO := 0.6
const SUAVIZADO_GIRO := 8.0

@export var objetivo: Node3D
@export var persigue_policia := false
@export var cooldown_pelea := 20.0
@export var patrulla_aleatoria := true
@export var radio_deambular := 25.0
@export var pausa_min := 0.5
@export var pausa_max := 3.0
@export var rapidez_acudir := 3.0
@export var margen_cambio := 4.0
@export var tiempo_max_ruta := 40.0
@export var evitar_obstaculos := true
@export_flags_3d_physics var capas_obstaculo := 1
@export var depurar := false
@export var vida = 100
@export var rapidez = 2.0
@export var radio_ver = 6.0
@export var radio_perder = 9.0
@export var puntos: Array[Vector3] = [
	Vector3(-6, 0, -3), Vector3(6, 0, -3)]
@onready var anim = $Modelo/AnimationPlayer

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
var destino_azar := SIN_DESTINO
var pausa := 0.0
var tiempo_ruta := 0.0
var incidente = null
var listo := false
var usa_malla := false
var reloj_revisar := 0.0
var reloj_malla := 0.0
var reloj_incidente := 0.0
var reloj_solape := 0.0   # NUEVO
var tiempo_sin_malla := 0.0
var avisado_malla := false
var reloj_depurar := 0.0
# Seguimiento de ruta propio
var ruta := PackedVector3Array()
var indice_ruta := 0
var destino_ruta := SIN_DESTINO
var reloj_ruta := 0.0
var ruta_agotada := false
# Detector de progreso
var quiere_avanzar := false
var reloj_progreso := 0.0
var pos_progreso := Vector3.ZERO
# Esquive
var dir_mov := Vector3.ZERO
var lado_esquive := 0

static func blinn_phong(normal: Vector3, hacia_luz: Vector3, hacia_ojo: Vector3, brillo: float) -> float:
	var n = normal.normalized()
	var l = hacia_luz.normalized()
	var v = hacia_ojo.normalized()
	var h = (l + v).normalized()
	var ndot_h = max(0.0, n.dot(h))
	return pow(ndot_h, brillo)

func _ready() -> void:
	add_to_group(GRUPO)
	if not viene_de_afuera:
		origen = global_position
	reloj_revisar = randf() * INTERVALO_REVISAR
	for i in range(FRAMES_ESPERA_MALLA):
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		if malla_sirve():
			break
	usa_malla = malla_sirve()
	elegir_destino()
	if viene_de_afuera:
		destino_azar = ajustar_a_malla(entrada)
	pos_progreso = global_position
	listo = true

# ---------- Malla y ruta ----------

func malla_sirve() -> bool:
	if not is_inside_tree():
		return false
	var m := get_world_3d().navigation_map
	return NavigationServer3D.map_get_iteration_id(m) > 0 \
		and not NavigationServer3D.map_get_regions(m).is_empty()

func ajustar_a_malla(p: Vector3) -> Vector3:
	if usa_malla and is_inside_tree():
		return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)
	return p

func distancia_plana(p: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(p.x, p.z))

func distancia_a_punto(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func calcular_ruta(p: Vector3) -> void:
	ruta = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, p, true)
	indice_ruta = 0
	destino_ruta = p
	reloj_ruta = REFRESCO_RUTA
	ruta_agotada = false

func direccion_hacia(p: Vector3) -> Vector3:
	if not usa_malla:
		return p - global_position
	if destino_ruta.distance_to(p) > 0.5 or ruta.is_empty() or reloj_ruta <= 0.0:
		calcular_ruta(p)
	if ruta.is_empty():
		return p - global_position
	while indice_ruta < ruta.size() - 1 and distancia_plana(ruta[indice_ruta]) < TOLERANCIA_ESQUINA:
		indice_ruta += 1
	var paso := ruta[indice_ruta]
	if indice_ruta == ruta.size() - 1 and distancia_plana(paso) < TOLERANCIA_PASO:
		ruta_agotada = true
	return paso - global_position

func llego_a(p: Vector3, tolerancia := 0.5) -> bool:
	if distancia_plana(p) < tolerancia:
		return true
	return usa_malla and ruta_agotada \
		and destino_ruta.distance_to(p) < 0.5 \
		and distancia_plana(p) < DISTANCIA_ATASCO

func alcanzable(p: Vector3) -> bool:
	var camino := NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, p, true)
	if camino.is_empty():
		return false
	return distancia_a_punto(camino[camino.size() - 1], p) < 1.5

func destino_ocupado(p: Vector3) -> bool:
	if not is_inside_tree():
		return false
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as Ciudadano
		if otro == null or otro == self or not otro.is_inside_tree():
			continue
		if otro.destino_azar.distance_to(p) < DISTANCIA_ENTRE_DESTINOS:
			return true
	return false

func elegir_destino() -> void:
	if not is_inside_tree():
		return
	var elegido := SIN_DESTINO
	var nivel := 0
	for n in 2:
		for i in INTENTOS_DESTINO:
			var ang := randf() * TAU
			var dist := sqrt(randf()) * radio_deambular
			var crudo := origen + Vector3(cos(ang), 0.0, sin(ang)) * dist
			var p := ajustar_a_malla(crudo)
			if n == 0 and usa_malla:
				if distancia_a_punto(p, crudo) > TOLERANCIA_MALLA:
					continue
				if not alcanzable(p):
					continue
			if destino_ocupado(p):
				continue
			elegido = p
			nivel = n
			break
		if elegido != SIN_DESTINO:
			break
	if elegido == SIN_DESTINO:
		var a := randf() * TAU
		elegido = ajustar_a_malla(global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(4.0, 8.0))
		nivel = 2
	if depurar and nivel > 0:
		print(name, ": destino de nivel ", nivel)
	destino_azar = elegido
	tiempo_ruta = 0.0
	ruta = PackedVector3Array()
	reloj_progreso = 0.0
	pos_progreso = global_position

# ---------- Puestos de incidente (NUEVO) ----------

func puesto_ocupado(p: Vector3) -> bool:
	if not is_inside_tree():
		return false
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as Ciudadano
		if otro == null or otro == self or not otro.is_inside_tree():
			continue
		var parado: bool = otro.estado == Estado.PELEA or otro.estado == Estado.CURIOSO
		var yendo: bool = otro.estado == Estado.ACUDIR
		if not (parado or yendo):
			continue
		if distancia_a_punto(otro.destino_incidente, p) < DISTANCIA_PUESTO:
			return true
		if parado and distancia_a_punto(otro.global_position, p) < DISTANCIA_PUESTO:
			return true
	return false

func puesto_libre(base: Vector3) -> Vector3:
	var mejor := ajustar_a_malla(base)
	if not puesto_ocupado(mejor):
		return mejor
	for radio in [1.0, 1.8, 2.6]:
		var inicio := randf() * TAU
		for k in 8:
			var ang := inicio + TAU * k / 8.0
			var p := ajustar_a_malla(base + Vector3(cos(ang), 0.0, sin(ang)) * radio)
			if puesto_ocupado(p):
				continue
			if usa_malla and not alcanzable(p):
				continue
			return p
	return mejor

func solapado() -> bool:
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as Node3D
		if otro == null or otro == self:
			continue
		if distancia_a_punto(otro.global_position, global_position) < RADIO_SOLAPE:
			return true
	return false

func reubicar_curioso() -> void:
	reloj_solape = 0.0
	destino_incidente = puesto_libre(global_position)
	llego = false
	ruta = PackedVector3Array()
	reloj_progreso = 0.0
	pos_progreso = global_position

# ---------- Esquive de obstáculos ----------

func rayo(dir: Vector3, largo: float) -> Dictionary:
	var desde := global_position + Vector3.UP * ALTURA_RAYO
	var consulta := PhysicsRayQueryParameters3D.create(desde, desde + dir * largo, capas_obstaculo)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not golpe.is_empty() and golpe["collider"] is CharacterBody3D:
		return {}
	return golpe

func peso_rayo(desde: Vector3, golpe: Dictionary, largo: float) -> float:
	return 1.0 - clampf(desde.distance_to(golpe["position"]) / largo, 0.0, 1.0)

func esquivar(dir: Vector3) -> Vector3:
	if not evitar_obstaculos or not is_inside_tree():
		return dir
	var desde := global_position + Vector3.UP * ALTURA_RAYO
	var lado_a := dir.rotated(Vector3.UP, ANGULO_RAYO)
	var lado_b := dir.rotated(Vector3.UP, -ANGULO_RAYO)
	var largo_lado := LARGO_RAYO * 0.8
	var hc := rayo(dir, LARGO_RAYO)
	var ha := rayo(lado_a, largo_lado)
	var hb := rayo(lado_b, largo_lado)
	if hc.is_empty() and ha.is_empty() and hb.is_empty():
		lado_esquive = 0
		return dir
	var giro := Vector3.ZERO
	if not ha.is_empty():
		giro += lado_b * peso_rayo(desde, ha, largo_lado)
	if not hb.is_empty():
		giro += lado_a * peso_rayo(desde, hb, largo_lado)
	if not hc.is_empty():
		var n: Vector3 = hc["normal"]
		n.y = 0.0
		if n.length() > 0.01:
			n = n.normalized()
			var t := Vector3(-n.z, 0.0, n.x)
			if t.dot(dir) < 0.0:
				t = -t
			if absf(t.dot(dir)) < 0.25:
				if lado_esquive == 0:
					lado_esquive = 1 if randf() < 0.5 else -1
				t = dir.rotated(Vector3.UP, lado_esquive * PI * 0.5)
			giro += t * peso_rayo(desde, hc, LARGO_RAYO) * 1.5
	var resultado := dir + giro * 1.5
	resultado.y = 0.0
	if resultado.length() < 0.05:
		return dir
	return resultado.normalized()

# ---------- Esquive de personas (NUEVO) ----------

func esquivar_personas(dir: Vector3) -> Vector3:
	var giro := Vector3.ZERO
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as Node3D
		if otro == null or otro == self:
			continue
		var rel := otro.global_position - global_position
		rel.y = 0.0
		var d := rel.length()
		if d > RADIO_ESQUIVE_PERSONAS or d < 0.01:
			continue
		var frente := dir.dot(rel / d)
		if frente < 0.3:
			continue
		var lateral := Vector3(-dir.z, 0.0, dir.x)
		if lateral.dot(rel) > 0.0:
			lateral = -lateral
		giro += lateral * (1.0 - d / RADIO_ESQUIVE_PERSONAS) * frente
	if giro.length() < 0.01:
		return dir
	var resultado := dir + giro * 1.5
	resultado.y = 0.0
	if resultado.length() < 0.05:
		return dir
	return resultado.normalized()

# ---------- Movimiento ----------

func ir_a(p: Vector3, vel := -1.0) -> void:
	if vel < 0.0:
		vel = rapidez
	quiere_avanzar = true
	var dir := direccion_hacia(p)
	dir.y = 0.0
	if dir.length() < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	dir = esquivar(dir.normalized())
	dir = esquivar_personas(dir)
	if dir_mov.length() < 0.05:
		dir_mov = dir
	else:
		dir_mov = dir_mov.lerp(dir, clampf(get_physics_process_delta_time() * SUAVIZADO_GIRO, 0.0, 1.0))
	if dir_mov.length() < 0.05:
		dir_mov = dir
	dir = dir_mov.normalized()
	velocity.x = dir.x * vel
	velocity.z = dir.z * vel
	girar_hacia(dir)
	anim.play("walk")

func detenerse() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	anim.stop()

func girar_hacia(dir: Vector3) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	var paso := clampf(get_physics_process_delta_time() * VELOCIDAD_GIRO, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, yaw, paso)

func mirar_hacia(punto_mira: Vector3) -> void:
	var dir := punto_mira - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		girar_hacia(dir.normalized())

func aplicar_separacion() -> void:
	var empuje := Vector3.ZERO
	for nodo in get_tree().get_nodes_in_group(GRUPO):
		var otro := nodo as Node3D
		if otro == null or otro == self:
			continue
		var d := global_position - otro.global_position
		d.y = 0.0
		var l := d.length()
		if l >= RADIO_SEPARACION:
			continue
		if l < 0.01:
			var a := randf() * TAU
			empuje += Vector3(cos(a), 0.0, sin(a))
		else:
			empuje += d / l * (RADIO_SEPARACION - l) / RADIO_SEPARACION
	if empuje.length() > 1.0:
		empuje = empuje.normalized()
	velocity.x += empuje.x * FUERZA_SEPARACION
	velocity.z += empuje.z * FUERZA_SEPARACION

# ---------- Atascos y seguridad ----------

func revisar_progreso(delta: float) -> bool:
	if not quiere_avanzar:
		reloj_progreso = 0.0
		pos_progreso = global_position
		return false
	reloj_progreso += delta
	if reloj_progreso < INTERVALO_PROGRESO:
		return false
	reloj_progreso = 0.0
	var movido := distancia_plana(pos_progreso)
	pos_progreso = global_position
	return movido < PROGRESO_MINIMO

func al_atascarse() -> void:
	if depurar:
		print(name, ": atascado en ", Estado.keys()[estado], ", cambia de plan")
	ruta = PackedVector3Array()
	lado_esquive = -lado_esquive if lado_esquive != 0 else 0
	match estado:
		Estado.PATRULLA:
			elegir_destino()
		Estado.ACUDIR:
			if distancia_plana(destino_incidente) < DISTANCIA_ATASCO:
				llego = true
				estado = Estado.PELEA
		Estado.CURIOSO:
			if distancia_plana(destino_incidente) < DISTANCIA_ATASCO:
				llego = true

func vigilar_incidente(delta: float) -> void:
	if estado != Estado.ACUDIR and estado != Estado.PELEA and estado != Estado.CURIOSO:
		reloj_incidente = 0.0
		return
	reloj_incidente += delta
	var desaparecio: bool = incidente != null and not is_instance_valid(incidente)
	if desaparecio or reloj_incidente > TIEMPO_MAX_INCIDENTE:
		if depurar:
			print(name, ": salió de un estado de incidente sin salida")
		volver_a_patrulla()

func volver_a_patrulla() -> void:
	if estado == Estado.ACUDIR or estado == Estado.PELEA:
		enfriamiento = cooldown_pelea
	soltar_incidente()
	rival = null
	llego = false
	pausa = 0.0
	reloj_incidente = 0.0
	estado = Estado.PATRULLA
	elegir_destino()

func vigilar_malla(delta: float) -> void:
	if usa_malla:
		return
	reloj_malla -= delta
	if reloj_malla > 0.0:
		return
	reloj_malla = 0.5
	usa_malla = malla_sirve()
	if usa_malla:
		if estado == Estado.PATRULLA:
			elegir_destino()
		return
	tiempo_sin_malla += 0.5
	if tiempo_sin_malla >= 5.0 and not avisado_malla:
		avisado_malla = true
		print(name, ": sin malla de navegación tras 5 s, camina en línea recta")

# ---------- Comportamiento ----------

func patrullar(delta: float) -> void:
	if not patrulla_aleatoria:
		ir_a(puntos[punto])
		if distancia_plana(puntos[punto]) < 0.3:
			punto = (punto + 1) % puntos.size()
		return
	if pausa > 0.0:
		pausa -= delta
		detenerse()
		return
	tiempo_ruta += delta
	if llego_a(destino_azar, 0.6) or tiempo_ruta > tiempo_max_ruta:
		pausa = randf_range(pausa_min, pausa_max)
		detenerse()
		elegir_destino()
		return
	ir_a(destino_azar)

func _physics_process(delta):
	if not listo:
		return
	quiere_avanzar = false
	reloj_ruta -= delta
	velocity += get_gravity() * delta
	if enfriamiento > 0.0:
		enfriamiento -= delta
	vigilar_malla(delta)
	vigilar_incidente(delta)
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
			if llego_a(destino_incidente):
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
				if not llego and llego_a(destino_incidente):
					llego = true
				if llego:
					detenerse()
					mirar_hacia(centro_incidente)
					if solapado():
						reloj_solape += delta
						if reloj_solape >= TIEMPO_SOLAPE:
							reubicar_curioso()
					else:
						reloj_solape = 0.0
				else:
					ir_a(destino_incidente, rapidez_acudir)
	aplicar_separacion()
	move_and_slide()
	if revisar_progreso(delta):
		al_atascarse()
	if depurar:
		reloj_depurar -= delta
		if reloj_depurar <= 0.0:
			reloj_depurar = 1.0
			print(name, " | ", Estado.keys()[estado], " | malla=", usa_malla,
				" | vel=", snappedf(Vector2(velocity.x, velocity.z).length(), 0.01),
				" | ruta=", indice_ruta, "/", ruta.size(),
				" | a destino=", snappedf(distancia_plana(destino_azar), 0.1),
				" | esquive=", lado_esquive, " | solape=", snappedf(reloj_solape, 0.1))

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

# ---------- Interfaz con los incidentes ----------

func disponible() -> bool:
	return listo and estado == Estado.PATRULLA and enfriamiento <= 0.0

func puede_mirar() -> bool:
	return listo and estado == Estado.PATRULLA

func ir_a_pelea(pos: Vector3, inc) -> void:
	incidente = inc
	destino_incidente = puesto_libre(pos)
	llego = false
	ruta = PackedVector3Array()
	reloj_incidente = 0.0
	reloj_solape = 0.0
	reloj_progreso = 0.0
	pos_progreso = global_position
	estado = Estado.ACUDIR

func curiosear(puesto: Vector3, centro: Vector3, inc) -> void:
	incidente = inc
	destino_incidente = puesto_libre(puesto)
	centro_incidente = centro
	llego = false
	ruta = PackedVector3Array()
	reloj_incidente = 0.0
	reloj_solape = 0.0
	reloj_progreso = 0.0
	pos_progreso = global_position
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
