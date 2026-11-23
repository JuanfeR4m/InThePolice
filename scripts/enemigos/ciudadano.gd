class_name Ciudadano
extends CharacterBody3D
## Clase base. Cada tipo hereda y sobrescribe los métodos que empiezan con "_".

signal ladron_atrapado(ciudadano: Ciudadano)
signal ladron_escapo(ciudadano: Ciudadano)

enum EventoTipo { ARRESTO, DISPARO, PELEA, ROBO, SIRENA, PROTESTA }
enum Estado { IDLE, CAMINANDO, HUYENDO, OBSERVANDO, ATACANDO, ROBANDO, PROTESTANDO }
enum Rol { NINGUNO, PELEADOR, CURIOSO, ALEJANDOSE }

@export_group("Movimiento")
@export var velocidad_caminar := 1.5
@export var velocidad_correr := 4.0

@export_group("Percepción")
@export var rango_vision := 8.0
@export var rango_evento := 15.0

@export_group("Conflictos")
## Probabilidad de que este ciudadano vaya a mirar una pelea (si no, se aleja de ella)
@export_range(0.0, 1.0) var probabilidad_mirar := 0.5

@export_group("Modelo")
@export var escala_modelo := 2.7          # Kenney mide ~0.67 → ~1.8 m
@export var rotacion_modelo_y := 180.0    # si se ve de espaldas, pon 0
@export var accesorio: PackedScene        # máscara, gafas, etc.
@export var hueso_accesorio := "head"
@export var accesorio_posicion := Vector3.ZERO
@export var accesorio_rotacion := Vector3.ZERO # en grados

@export_group("Nivel")
## Opcional: a quién "sigue" el nivel (el GeneradorCiudadanos y nivel_1 lo asignan)
@export var objetivo: Node3D

# Los asigna el GeneradorCiudadanos al crear al ciudadano
var origen := Vector3.ZERO        # centro de la zona donde se mueve
var entrada := Vector3.ZERO       # punto al que camina al llegar al parque
var viene_de_afuera := false
var centro_feria := Vector3.ZERO
var limite_feria := 13.0
var rumbo := 0.0
var rapidez := 0.0:
	set(valor):
		rapidez = valor
		velocidad_caminar = valor

const ANIMS_LOOP := ["idle", "walk", "sprint", "crouch", "sit",
	"holding-right", "holding-left", "holding-both",
	"attack-melee-right", "attack-melee-left", "attack-kick-right", "attack-kick-left"]
## Animaciones que alterna mientras pelea (usa las que existan en el modelo)
const ANIMS_GOLPE := ["attack-melee-right", "attack-melee-left", "attack-kick-right"]

var estado: Estado = Estado.IDLE
var jugador: Node3D
var anim: AnimationPlayer

# Ladrón (lo activa GeneradorIncidentes)
var es_ladron := false
var _tiempo_huida := 0.0
var _punto_huida := Vector3.ZERO

# Incidente (lo asigna IncidentePresionado: lee y escribe estas variables)
var incidente: IncidentePresionado = null
var rival: Node3D = null          # contra quién pelea (lo asigna el incidente)
var llego := false                # true cuando ya está en su puesto de pelea
var _rol: Rol = Rol.NINGUNO
var _es_miron := false
var _punto_pelea := Vector3.INF
var _punto_curioso := Vector3.INF
var _centro_curioso := Vector3.ZERO
var _punto_alejarse := Vector3.INF
var _tiempo_alejarse := 0.0
var _anim_golpe := ""
var _prox_golpe := 0.0

var _agente: NavigationAgent3D
var _malla_lista := false
var _prox_revision_malla := 0.0
var _ultimo_destino := Vector3.INF
var _prox_ruta := 0.0

var _iniciado := false
var _ancla := Vector3.ZERO        # centro de su paseo
var _radio_paseo := 6.0
var _destino_paseo := Vector3.INF
var _prox_paseo := 0.0
var _llego_a_entrada := false
var _tiempo_entrando := 0.0

@onready var modelo: Node3D = $Modelo


func _ready() -> void:
	add_to_group("ciudadanos")
	_es_miron = randf() < probabilidad_mirar
	# Agrega tu jugador al grupo "jugador" desde el editor
	jugador = get_tree().get_first_node_in_group("jugador")

	modelo.scale = Vector3.ONE * escala_modelo
	modelo.rotation_degrees.y = rotacion_modelo_y

	anim = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for n in ANIMS_LOOP:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	_colocar_accesorio()

	# Camina por la malla de navegación del nivel (si no hay malla, va en línea recta)
	_agente = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if _agente == null:
		_agente = NavigationAgent3D.new()
		_agente.name = "NavigationAgent3D"
		add_child(_agente)
	_agente.avoidance_enabled = false
	_agente.path_desired_distance = 0.5
	_agente.target_desired_distance = 0.5


func _physics_process(delta: float) -> void:
	if not _iniciado:
		# El generador pone la posición DESPUÉS de add_child, por eso se calcula aquí
		_iniciado = true
		_ancla = centro_feria if viene_de_afuera else global_position
		_radio_paseo = limite_feria if viene_de_afuera else 6.0

	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	if es_ladron:
		_huir_como_ladron(delta)
	elif _rol != Rol.NINGUNO:
		_comportamiento_incidente(delta)
	elif jugador and _jugador_en_vision():
		_reaccionar_al_jugador()
	elif _entrando(delta):
		estado = Estado.CAMINANDO
		mover_hacia(entrada, velocidad_caminar)
	else:
		_comportamiento_idle()

	move_and_slide()
	_actualizar_animacion()


# ---------- A sobrescribir en cada hijo ----------
## Por defecto: pasea por su zona. Los hijos lo sobrescriben.
func _comportamiento_idle() -> void:
	_pasear()

func _reaccionar_al_jugador() -> void:
	pass

func reaccionar_a_evento(_evento: EventoTipo, _origen: Vector3) -> void:
	pass

## Devuelve el nombre de una animación o "" para usar idle/walk/sprint según la velocidad.
func _animacion_por_estado() -> String:
	return ""


# ---------- Ladrón ----------
## Está libre para que lo recluten (pelea, robo): no está ocupado con otra cosa.
func disponible() -> bool:
	return not es_ladron and incidente == null and _rol == Rol.NINGUNO \
		and estado in [Estado.IDLE, Estado.CAMINANDO, Estado.OBSERVANDO]

## Lo convierte en ladrón: huye durante `tiempo` segundos
func volverse_ladron(tiempo: float) -> void:
	_salir_de_incidente()
	es_ladron = true
	_tiempo_huida = tiempo
	estado = Estado.ROBANDO
	# Punto de escape lejos del jugador (o del centro del paseo si no hay jugador)
	var desde := jugador.global_position if jugador else _ancla
	var dir := global_position - desde
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	_punto_huida = global_position + dir.normalized() * 40.0

## Llamar desde el jugador cuando alcanza al ladrón
func atrapar() -> void:
	if not es_ladron:
		return
	es_ladron = false
	ladron_atrapado.emit(self)
	queue_free()

func _huir_como_ladron(delta: float) -> void:
	_tiempo_huida -= delta
	if _tiempo_huida <= 0.0:
		es_ladron = false
		ladron_escapo.emit(self)
		queue_free()
		return
	estado = Estado.HUYENDO
	mover_hacia(_punto_huida, velocidad_correr)


# ---------- Incidentes (pelea, curiosos, gente que se aleja) ----------
## IncidentePresionado lo llama para reclutar un peleador en su puesto.
func ir_a_pelea(punto: Vector3, inc: IncidentePresionado) -> void:
	_salir_de_incidente()
	incidente = inc
	_rol = Rol.PELEADOR
	_punto_pelea = punto
	llego = false
	estado = Estado.CAMINANDO

## El incidente lo llama cuando termina (o se cancela) la pelea.
func terminar_pelea() -> void:
	_salir_de_incidente()

## ¿Va a mirar una pelea (true) o se aleja de ella (false)? Los hijos pueden sobrescribirlo.
func puede_mirar() -> bool:
	return _es_miron and not es_ladron and incidente == null and _rol == Rol.NINGUNO

## IncidentePresionado lo llama para que vaya a `punto` y mire hacia `centro`.
func curiosear(punto: Vector3, centro: Vector3, inc: IncidentePresionado) -> void:
	_salir_de_incidente()
	incidente = inc
	_rol = Rol.CURIOSO
	_punto_curioso = punto
	_centro_curioso = centro
	estado = Estado.CAMINANDO

func dejar_de_curiosear() -> void:
	_salir_de_incidente()

## Se aleja corriendo de una pelea y luego vuelve a su vida normal.
func alejarse_de(punto: Vector3, distancia: float = 14.0) -> void:
	if es_ladron or incidente != null or _rol != Rol.NINGUNO:
		return
	var dir := global_position - punto
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_rol = Rol.ALEJANDOSE
	_punto_alejarse = global_position + dir.normalized() * distancia
	_tiempo_alejarse = 8.0
	estado = Estado.HUYENDO

func _salir_de_incidente() -> void:
	var inc := incidente
	incidente = null
	rival = null
	llego = false
	_rol = Rol.NINGUNO
	_punto_pelea = Vector3.INF
	_punto_curioso = Vector3.INF
	_punto_alejarse = Vector3.INF
	_anim_golpe = ""
	if estado == Estado.ATACANDO or estado == Estado.OBSERVANDO or estado == Estado.HUYENDO:
		estado = Estado.IDLE
	# Libera su puesto (si el incidente se está borrando, él mismo se encarga)
	if is_instance_valid(inc) and not inc.is_queued_for_deletion():
		inc.liberar(self)

func _comportamiento_incidente(delta: float) -> void:
	# Si el incidente desapareció sin avisar, vuelve a la normalidad
	if _rol != Rol.ALEJANDOSE and not is_instance_valid(incidente):
		_salir_de_incidente()
		return
	match _rol:
		Rol.PELEADOR:
			_pelear()
		Rol.CURIOSO:
			_mirar_incidente()
		Rol.ALEJANDOSE:
			_alejarse(delta)

func _pelear() -> void:
	if not llego:
		var falta := Vector2(global_position.x - _punto_pelea.x, global_position.z - _punto_pelea.z).length()
		if falta > 0.6:
			estado = Estado.CAMINANDO
			# Corre: el incidente solo espera unos segundos a que lleguen
			mover_hacia(_punto_pelea, velocidad_correr)
			return
		llego = true
	estado = Estado.ATACANDO
	if is_instance_valid(rival):
		mirar(rival.global_position)
	else:
		mirar(incidente.global_position)

func _mirar_incidente() -> void:
	var falta := Vector2(global_position.x - _punto_curioso.x, global_position.z - _punto_curioso.z).length()
	if falta > 0.6:
		estado = Estado.CAMINANDO
		mover_hacia(_punto_curioso, velocidad_caminar)
	else:
		estado = Estado.OBSERVANDO
		mirar(_centro_curioso)

func _alejarse(delta: float) -> void:
	_tiempo_alejarse -= delta
	var falta := Vector2(global_position.x - _punto_alejarse.x, global_position.z - _punto_alejarse.z).length()
	if _tiempo_alejarse <= 0.0 or falta < 1.0:
		_salir_de_incidente()
		return
	estado = Estado.HUYENDO
	mover_hacia(_punto_alejarse, velocidad_correr)


# ---------- Animación ----------
func _actualizar_animacion() -> void:
	if anim == null:
		return
	var nombre := ""
	if _rol == Rol.PELEADOR and llego:
		nombre = _animacion_golpe()
	if nombre == "":
		nombre = _animacion_por_estado()
	if nombre == "":
		var v := _velocidad_horizontal()
		if v > velocidad_caminar * 1.5:
			nombre = "sprint"
		elif v > 0.1:
			nombre = "walk"
		else:
			nombre = "idle"
	if anim.has_animation(nombre) and anim.current_animation != nombre:
		anim.play(nombre, 0.15)

## Cambia de golpe cada tanto mientras pelea ("" si el modelo no tiene animaciones de ataque)
func _animacion_golpe() -> String:
	var ahora := _ahora()
	if _anim_golpe == "" or ahora >= _prox_golpe:
		_prox_golpe = ahora + randf_range(0.8, 1.6)
		var opciones := ANIMS_GOLPE.filter(func(n): return anim.has_animation(n))
		_anim_golpe = opciones.pick_random() if not opciones.is_empty() else ""
	return _anim_golpe

func _velocidad_horizontal() -> float:
	return Vector2(velocity.x, velocity.z).length()


# ---------- Accesorio (máscara, gafas...) ----------
func _colocar_accesorio() -> void:
	if accesorio == null:
		return
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		push_warning("%s: no encontré Skeleton3D para el accesorio" % name)
		return
	var esqueleto: Skeleton3D = esqueletos[0]
	if esqueleto.find_bone(hueso_accesorio) == -1:
		push_warning("%s: no existe el hueso '%s'" % [name, hueso_accesorio])
		return
	var ancla := BoneAttachment3D.new()
	ancla.bone_name = hueso_accesorio
	esqueleto.add_child(ancla)
	var obj := accesorio.instantiate() as Node3D
	obj.position = accesorio_posicion
	obj.rotation_degrees = accesorio_rotacion
	ancla.add_child(obj)


# ---------- Utilidades compartidas ----------
func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0

func _jugador_en_vision() -> bool:
	return global_position.distance_to(jugador.global_position) <= rango_vision

func _evento_cerca(punto_evento: Vector3) -> bool:
	return global_position.distance_to(punto_evento) <= rango_evento

func mover_hacia(destino: Vector3, vel: float) -> void:
	var meta := destino
	if _agente != null and _hay_malla():
		var ahora := _ahora()
		if ahora >= _prox_ruta or destino.distance_to(_ultimo_destino) > 1.0:
			_prox_ruta = ahora + 0.3
			_ultimo_destino = destino
			_agente.target_position = destino
		if not _agente.is_navigation_finished():
			meta = _agente.get_next_path_position()
	var dir := meta - global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		# La ruta no avanza (sin camino o ya terminó): si el destino sigue lejos, va en línea recta
		var directo := destino - global_position
		directo.y = 0.0
		if directo.length() < 0.8:
			return
		meta = destino
		dir = directo
	dir = dir.normalized()
	velocity.x = dir.x * vel
	velocity.z = dir.z * vel
	mirar(meta)

func _hay_malla() -> bool:
	if _malla_lista:
		return true
	var ahora := _ahora()
	if ahora < _prox_revision_malla:
		return false
	_prox_revision_malla = ahora + 1.0
	var mapa := _agente.get_navigation_map()
	_malla_lista = NavigationServer3D.map_get_iteration_id(mapa) > 0 \
		and not NavigationServer3D.map_get_regions(mapa).is_empty()
	return _malla_lista

## true mientras camina desde la entrada del parque hacia su punto de llegada
func _entrando(delta: float) -> bool:
	if not viene_de_afuera or _llego_a_entrada:
		return false
	_tiempo_entrando += delta
	var falta := Vector2(global_position.x - entrada.x, global_position.z - entrada.z).length()
	if falta < 1.5 or _tiempo_entrando > 25.0:
		_llego_a_entrada = true
		return false
	return true

## Paseo tranquilo: elige un punto cerca de su zona, camina y descansa un rato
func _pasear() -> void:
	var ahora := _ahora()
	if _destino_paseo == Vector3.INF or ahora >= _prox_paseo:
		_prox_paseo = ahora + randf_range(4.0, 9.0)
		var ang := randf() * TAU
		_destino_paseo = _ancla + Vector3(cos(ang), 0.0, sin(ang)) * sqrt(randf()) * _radio_paseo
	var falta := Vector2(global_position.x - _destino_paseo.x, global_position.z - _destino_paseo.z).length()
	if falta > 1.0:
		estado = Estado.CAMINANDO
		mover_hacia(_destino_paseo, velocidad_caminar)
	else:
		estado = Estado.IDLE

func huir_de(punto_evento: Vector3, vel: float) -> void:
	var dir := global_position - punto_evento
	dir.y = 0.0
	mover_hacia(global_position + dir.normalized() * 5.0, vel)

func mirar(blanco: Vector3) -> void:
	var p := Vector3(blanco.x, global_position.y, blanco.z)
	if p.distance_to(global_position) > 0.01:
		look_at(p, Vector3.UP)
