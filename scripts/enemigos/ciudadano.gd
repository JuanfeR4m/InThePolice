class_name Ciudadano
extends CharacterBody3D
## Clase base. Cada tipo hereda y sobrescribe los métodos que empiezan con "_".

signal ladron_atrapado(ciudadano: Ciudadano)
signal ladron_escapo(ciudadano: Ciudadano)

enum EventoTipo { ARRESTO, DISPARO, PELEA, ROBO, SIRENA, PROTESTA }
enum Estado { IDLE, CAMINANDO, HUYENDO, OBSERVANDO, ATACANDO, ROBANDO, PROTESTANDO }
enum Rol { NINGUNO, PELEADOR, CURIOSO, ALEJANDOSE, ATACANTE }

## A esta distancia (m) del puesto se considera que ya llegó
const DIST_LLEGADA := 0.6
## Si la ruta ya terminó (el puesto no se puede alcanzar del todo), basta con estar tan cerca
const DIST_LLEGADA_BLOQUEADO := 2.0
## Un policía que toca al ladrón a esta distancia (m) lo atrapa
const RADIO_CAPTURA := 1.4
## Si quiere moverse y casi no avanza durante este tiempo (s), se considera atascado
const TIEMPO_ATASCADO := 1.2
const COLOR_LADRON := Color(0.95, 0.15, 0.15)
## Margen (m) extra sobre `limite_feria` hasta donde puede llegar quien ya está adentro
## (la cerca está a 15 m del centro y el límite es 13: así nadie atraviesa la cerca)
const MARGEN_FERIA := 1.0
## Contorno verde brillante de los ciudadanos que hay que defender de noche
const SHADER_CONTORNO := preload("res://shaders/contorno_defender.gdshader")
## Ataque nocturno a los administrativos (los verdes)
const DIST_GOLPE := 1.2
const INTERVALO_GOLPE := 1.2
const GOLPES_PARA_CAER := 3
## Tras calmarlo un policía, tarda esto (s) en volver a atacar
const ENFRIAMIENTO_ATAQUE := 12.0
const FRASES_ATAQUE := ["¡Mi trámite era a las 9!", "¡Quiero hablar con el gerente!", "¡Me cobraron dos veces!",
	"¡Por la fila de 3 horas!", "¡Ventanilla cerrada, ¿en serio?!", "¡Sellen ESTO!"]
# Tinte rojo según la Ira (Juego.ira): empieza a notarse desde IRA_TINTE_MIN
const IRA_TINTE_MIN := 20.0
const TINTE_MAX := 0.45
# Con mucha Ira, un atacante a veces empuja al policía en vez de dejarse calmar
const EMPUJON_ESPERA := 4.0
const EMPUJON_PROB_MAX := 0.6
const FRASE_EMPUJON := "¡Quítese!"
const FRASES_CALMA := ["Ya, ya... perdón", "Mejor me voy a comer algo", "Fue la rabia, jefe", "Tampoco era para tanto"]
const FUERZA_VUELO := 11.0
const FRENADO_VUELO := 7.5
const TIEMPO_CAIDO := 4.0
const TIEMPO_LEVANTARSE := 0.8
const DANIO_EMPUJON := 1
const DISTANCIA_AGARRE := 1.0
const SEGUIMIENTO_AGARRE := 8.0
const DISTANCIA_SOLTAR := 3.0
const ANIM_VOLANDO := "fall"
const ANIM_CAIDO := "die"
const ANIM_LEVANTARSE := "sit"

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
var _prox_huida := 0.0
var _marca_ladron: Label3D = null

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
var _entrada_ajustada := Vector3.INF   # `entrada` ya pegada a la malla (se calcula una vez)
var _t_atascado := 0.0
var _ambiente: Node = null
var _adentro := false             # true cuando ya entró a la feria: de ahí no vuelve a salir

## Administrativo: ciudadano marcado de noche con contorno verde (hay que defenderlo)
var es_administrativo := false
var caido := false               # administrativo que ya no aguantó más y renunció
var _golpes := 0
var _objetivo_ataque: Ciudadano = null
var _prox_golpe_ataque := 0.0
var _no_ataca_hasta := 0.0
var _marca_ataque: Label3D = null
var _material_ira: StandardMaterial3D = null
var _prox_empujon := 0.0
var _inmune_calma_hasta := 0.0
var _prox_tinte := 0.0
var empujado := false
var agarrado_por: Node3D = null
var _impulso := Vector3.ZERO
var _tiempo_caido := 0.0
var _anim_caida := ""

@onready var modelo: Node3D = $Modelo


func _ready() -> void:
	add_to_group("ciudadanos")
	# Los ciudadanos no se bloquean entre sí (capa 2), pero sí chocan con el mundo y los policías (capa 1).
	# Sin esto, un peleador ya parado en su puesto le cierra el paso al otro y la pelea se cancela.
	collision_layer = 2
	collision_mask = 1
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
	# La malla del nivel flota ~0.5 m sobre el suelo y el agente mide en 3D: con 0.5 nunca daba por
	# alcanzado un punto de ruta y se quedaba oscilando. 1.0 deja margen (la llegada fina la decide
	# _llego_a(), que mide en el plano).
	_agente.path_desired_distance = 1.0
	_agente.target_desired_distance = 1.0


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

	_actualizar_jugador()
	if is_instance_valid(agarrado_por):
		_ser_llevado()
	elif empujado:
		_estar_caido(delta)
	elif es_ladron:
		_huir_como_ladron(delta)
	elif _rol != Rol.NINGUNO:
		_comportamiento_incidente(delta)
	elif es_administrativo and _huir_de_atacante():
		pass   # corre lejos de quien lo persigue
	elif jugador and not _es_de_noche() and _jugador_en_vision():
		_reaccionar_al_jugador()
	elif _entrando(delta):
		estado = Estado.CAMINANDO
		mover_hacia(_entrada_en_malla(), velocidad_caminar)
	else:
		_comportamiento_idle()

	var pedida := Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_encerrar_en_feria()
	_revisar_atasco(delta, pedida)
	_actualizar_tinte_ira()
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
	return not empujado and not is_instance_valid(agarrado_por) and not es_ladron and incidente == null and _rol == Rol.NINGUNO \
		and estado in [Estado.IDLE, Estado.CAMINANDO, Estado.OBSERVANDO]

## Lo convierte en ladrón: huye durante `tiempo` segundos y se marca para que los policías lo vean
func volverse_ladron(tiempo: float) -> void:
	_salir_de_incidente()
	es_ladron = true
	_tiempo_huida = tiempo
	_prox_huida = 0.0
	estado = Estado.ROBANDO
	_poner_marca_ladron()
	print("%s se volvió ladrón (huye %.0f s)" % [name, tiempo])

## Se llama cuando un policía alcanza al ladrón (lo hace el propio ladrón al sentirlo cerca)
func atrapar() -> void:
	if not es_ladron:
		return
	es_ladron = false
	print("%s fue atrapado" % name)
	ladron_atrapado.emit(self)
	queue_free()

func _huir_como_ladron(delta: float) -> void:
	_tiempo_huida -= delta
	var policia := _policia_mas_cercano()
	# ¿Lo alcanzó algún policía?
	if policia != null and _distancia_plana(policia.global_position) <= RADIO_CAPTURA:
		atrapar()
		return
	if _tiempo_huida <= 0.0:
		es_ladron = false
		print("%s escapó" % name)
		ladron_escapo.emit(self)
		queue_free()
		return
	estado = Estado.HUYENDO
	var ahora := _ahora()
	if ahora >= _prox_huida or _distancia_plana(_punto_huida) < 1.0:
		_prox_huida = ahora + 0.4
		_punto_huida = _elegir_punto_de_huida(policia)
	mover_hacia(_punto_huida, velocidad_correr)

## Elige hacia dónde correr: el punto (dentro de la feria) más lejos del policía más cercano
func _elegir_punto_de_huida(policia: Node3D) -> Vector3:
	var desde := policia.global_position if policia != null else _ancla
	var mejor := global_position
	var mejor_d := -1.0
	var base := randf() * TAU
	for i in 12:
		var ang := base + TAU * i / 12.0
		var p := global_position + Vector3(cos(ang), 0.0, sin(ang)) * 7.0
		p.x = clampf(p.x, centro_feria.x - limite_feria, centro_feria.x + limite_feria)
		p.z = clampf(p.z, centro_feria.z - limite_feria, centro_feria.z + limite_feria)
		var d := Vector2(p.x - desde.x, p.z - desde.z).length()
		if d > mejor_d:
			mejor_d = d
			mejor = p
	return _sobre_malla(mejor)

func _policia_mas_cercano() -> Node3D:
	var mejor: Node3D = null
	var menor := INF
	for nodo in get_tree().get_nodes_in_group("jugador"):
		var p := nodo as Node3D
		if p == null or p.desmayado:
			continue
		var d := _distancia_plana(p.global_position)
		if d < menor:
			menor = d
			mejor = p
	return mejor

## `jugador` es el policía de pie más cercano (antes era siempre el jugador 1).
## Si los dos están desmayados se queda con el último que tenía.
func _actualizar_jugador() -> void:
	var cercano := _policia_mas_cercano()
	if cercano != null:
		jugador = cercano

func _distancia_plana(punto: Vector3) -> float:
	return Vector2(global_position.x - punto.x, global_position.z - punto.z).length()

## Cartel rojo flotante sobre el ladrón, visible desde cualquier ángulo y a través de objetos
func _poner_marca_ladron() -> void:
	if is_instance_valid(_marca_ladron):
		return
	var marca := Label3D.new()
	marca.name = "MarcaLadron"
	marca.text = "¡LADRÓN!"
	marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marca.no_depth_test = true
	marca.fixed_size = false
	marca.pixel_size = 0.009
	marca.font_size = 64
	marca.outline_size = 16
	marca.modulate = COLOR_LADRON
	marca.outline_modulate = Color(0.1, 0.0, 0.0)
	marca.position = Vector3(0.0, 2.7, 0.0)
	add_child(marca)
	_marca_ladron = marca


# ---------- Incidentes (pelea, curiosos, gente que se aleja) ----------
## IncidentePresionado lo llama para reclutar un peleador en su puesto.
func ir_a_pelea(punto: Vector3, inc: IncidentePresionado) -> void:
	_salir_de_incidente()
	incidente = inc
	_rol = Rol.PELEADOR
	_punto_pelea = _sobre_malla(_punto_en_feria(punto))   # la pelea nunca queda fuera de la cerca
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
	_punto_curioso = _sobre_malla(punto)
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
	_objetivo_ataque = null
	if is_instance_valid(_marca_ataque):
		_marca_ataque.queue_free()
	_marca_ataque = null
	if estado == Estado.ATACANDO or estado == Estado.OBSERVANDO or estado == Estado.HUYENDO:
		estado = Estado.IDLE
	# Libera su puesto (si el incidente se está borrando, él mismo se encarga)
	if is_instance_valid(inc) and not inc.is_queued_for_deletion():
		inc.liberar(self)

func _comportamiento_incidente(delta: float) -> void:
	# Si el incidente desapareció sin avisar, vuelve a la normalidad
	if (_rol == Rol.PELEADOR or _rol == Rol.CURIOSO) and not is_instance_valid(incidente):
		_salir_de_incidente()
		return
	match _rol:
		Rol.PELEADOR:
			_pelear()
		Rol.CURIOSO:
			_mirar_incidente()
		Rol.ALEJANDOSE:
			_alejarse(delta)
		Rol.ATACANTE:
			_atacar_objetivo()

func _pelear() -> void:
	if not llego:
		if not _llego_a(_punto_pelea):
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
	if not _llego_a(_punto_curioso):
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


## De noche el policía deja de importarles: solo les interesan los administrativos (los verdes)
func _es_de_noche() -> bool:
	if not is_instance_valid(_ambiente):
		_ambiente = get_tree().get_first_node_in_group("ambiente_noche")
	return _ambiente != null and _ambiente.get("activa") == true


# ---------- Ataque nocturno: los ciudadanos rabiosos van por los administrativos ----------
func es_atacante() -> bool:
	return _rol == Rol.ATACANTE

## ¿Puede ser reclutado para atacar? (libre, no es de los verdes y no lo calmaron hace poco)
func puede_atacar() -> bool:
	return disponible() and not es_administrativo and _ahora() >= _no_ataca_hasta

## GeneradorIncidentes lo llama de noche: este ciudadano se lanza contra un administrativo.
func atacar_administrativo(victima: Ciudadano) -> void:
	_salir_de_incidente()
	_rol = Rol.ATACANTE
	_objetivo_ataque = victima
	estado = Estado.CAMINANDO
	_marca_ataque = _decir(FRASES_ATAQUE.pick_random(), COLOR_LADRON, 0.0)

func _atacar_objetivo() -> void:
	if not is_instance_valid(_objetivo_ataque) or _objetivo_ataque.caido:
		_salir_de_incidente()
		return
	# Si un policía lo toca, se calma (así se defiende a los verdes)
	var policia := _policia_mas_cercano()
	if policia != null and _distancia_plana(policia.global_position) <= RADIO_CAPTURA \
			and _ahora() >= _inmune_calma_hasta:
		if _intentar_empujar(policia):
			return
		calmar(policia)
		return
	var blanco := _objetivo_ataque.global_position
	if _distancia_plana(blanco) > DIST_GOLPE:
		estado = Estado.CAMINANDO
		mover_hacia(blanco, velocidad_correr * 0.9)
		return
	estado = Estado.ATACANDO
	mirar(blanco)
	var ahora := _ahora()
	if ahora >= _prox_golpe_ataque:
		_prox_golpe_ataque = ahora + INTERVALO_GOLPE
		_objetivo_ataque.recibir_golpe()

## Cuanta más Ira acumulada, más probable que el atacante empuje al policía que lo toca.
## Un policía empujado queda aturdido un momento y el atacante no se calma por 1 s
## (la patada sí lo calma siempre).
func _intentar_empujar(policia: Node3D) -> bool:
	var ahora := _ahora()
	if ahora < _prox_empujon:
		return false
	_prox_empujon = ahora + EMPUJON_ESPERA
	if randf() > _ira_normalizada() * EMPUJON_PROB_MAX:
		return false
	if not policia.has_method("empujar"):
		return false
	var dir := policia.global_position - global_position
	dir.y = 0.0
	policia.empujar(dir)
	var salud = policia.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(DANIO_EMPUJON)
	_inmune_calma_hasta = ahora + 1.0
	_decir(FRASE_EMPUJON, COLOR_LADRON, 1.0)
	return true

func _ira_normalizada() -> float:
	var juego = get_tree().get_first_node_in_group("juego")
	if juego == null or not ("ira" in juego):
		return 0.0
	return clampf(float(juego.ira) / 100.0, 0.0, 1.0)

## Un policía lo alcanzó: se le baja la rabia, se aleja y tarda un rato en volver a atacar
func calmar(policia: Node3D) -> void:
	var desde := policia.global_position
	_salir_de_incidente()
	_no_ataca_hasta = _ahora() + ENFRIAMIENTO_ATAQUE
	_decir(FRASES_CALMA.pick_random(), Color(0.55, 0.85, 1.0), 1.6)
	alejarse_de(desde, 10.0)

func recibir_empujon(desde: Vector3) -> bool:
	if empujado or caido or es_administrativo:
		return false
	soltar()
	_salir_de_incidente()
	empujado = true
	_anim_caida = ""
	_tiempo_caido = TIEMPO_CAIDO
	_impulso = global_position - desde
	_impulso.y = 0.0
	if _impulso.length() < 0.1:
		_impulso = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_impulso = _impulso.normalized() * FUERZA_VUELO
	mirar(desde)
	return true

func puede_ser_agarrado() -> bool:
	return not is_instance_valid(agarrado_por) and not empujado and not caido \
		and incidente == null and _rol == Rol.NINGUNO

func ser_agarrado(policia: Node3D) -> void:
	agarrado_por = policia

func soltar() -> void:
	agarrado_por = null
	estado = Estado.IDLE

func _ser_llevado() -> void:
	if _distancia_plana(agarrado_por.global_position) > DISTANCIA_SOLTAR:
		soltar()
		return
	var destino := agarrado_por.global_position - agarrado_por.global_basis.z * DISTANCIA_AGARRE
	var falta := destino - global_position
	velocity.x = falta.x * SEGUIMIENTO_AGARRE
	velocity.z = falta.z * SEGUIMIENTO_AGARRE
	mirar(agarrado_por.global_position)

func _estar_caido(delta: float) -> void:
	_tiempo_caido -= delta
	_impulso = _impulso.move_toward(Vector3.ZERO, FRENADO_VUELO * delta)
	velocity.x = _impulso.x
	velocity.z = _impulso.z
	if _tiempo_caido <= 0.0:
		empujado = false
		estado = Estado.IDLE

func _animar_caida() -> void:
	var nombre := _animacion_caido()
	if nombre == _anim_caida or not anim.has_animation(nombre):
		return
	_anim_caida = nombre
	anim.play(nombre, 0.15)

func _animacion_caido() -> String:
	if _impulso.length() > 0.1:
		return ANIM_VOLANDO
	if _tiempo_caido < TIEMPO_LEVANTARSE:
		return ANIM_LEVANTARSE
	return ANIM_CAIDO

## Administrativo: recibe un golpe; a los GOLPES_PARA_CAER renuncia y se descuenta de los salvados.
## Los atacantes lo llaman sin argumentos. Los disparos de prueba (apuntar.gd) mandan daño y
## dirección: esos se ignoran para que no cuenten como golpe de un atacante.
func recibir_golpe(cuanto := -1, _direccion := Vector3.ZERO) -> void:
	if cuanto >= 0:
		return
	if caido or not es_administrativo:
		return
	_golpes += 1
	if _golpes >= GOLPES_PARA_CAER:
		_renunciar()
	else:
		_decir("¡Auch!", Color(1.0, 0.8, 0.2), 0.8)

func _renunciar() -> void:
	caido = true
	remove_from_group("administrativos")
	_salir_de_incidente()
	_decir("¡RENUNCIO!", Color(1.0, 0.3, 0.3), 1.4)
	var juego = get_tree().get_first_node_in_group("juego")
	if juego != null and "administrativos" in juego:
		juego.administrativos = maxi(int(juego.administrativos) - 1, 0)
	set_physics_process(false)
	get_tree().create_timer(1.4).timeout.connect(queue_free)

## Administrativo: si alguien lo viene persiguiendo de cerca, corre en dirección contraria
func _huir_de_atacante() -> bool:
	for nodo in get_tree().get_nodes_in_group("ciudadanos"):
		var c := nodo as Ciudadano
		if c != null and c._rol == Rol.ATACANTE and c._objetivo_ataque == self \
				and _distancia_plana(c.global_position) < 7.0:
			estado = Estado.HUYENDO
			huir_de(c.global_position, velocidad_correr * 0.8)
			return true
	return false

## Frase flotante sobre la cabeza (duracion 0 = se queda hasta que la borren)
func _decir(texto: String, color: Color, duracion: float = 1.6) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.pixel_size = 0.008
	etiqueta.font_size = 56
	etiqueta.outline_size = 14
	etiqueta.modulate = color
	etiqueta.outline_modulate = Color(0.1, 0.0, 0.0)
	etiqueta.position = Vector3(0.0, 3.1, 0.0)
	add_child(etiqueta)
	if duracion > 0.0:
		get_tree().create_timer(duracion).timeout.connect(func() -> void:
			if is_instance_valid(etiqueta):
				etiqueta.queue_free())
	return etiqueta


# ---------- Animación ----------
func _actualizar_animacion() -> void:
	if anim == null:
		return
	if empujado:
		_animar_caida()
		return
	var nombre := ""
	if (_rol == Rol.PELEADOR and llego) or (_rol == Rol.ATACANTE and estado == Estado.ATACANDO):
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


# ---------- Rabia visible: más Ira acumulada, más rojo ----------
func _actualizar_tinte_ira() -> void:
	if es_administrativo or caido:
		return   # los verdes conservan su contorno
	var ahora := _ahora()
	if ahora < _prox_tinte:
		return
	_prox_tinte = ahora + 0.5
	var juego = get_tree().get_first_node_in_group("juego")
	if juego == null or not ("ira" in juego):
		return
	var rabia := clampf((float(juego.ira) - IRA_TINTE_MIN) / (100.0 - IRA_TINTE_MIN), 0.0, 1.0)
	if _material_ira == null:
		if rabia <= 0.0:
			return
		_material_ira = StandardMaterial3D.new()
		_material_ira.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_ira.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for malla in modelo.find_children("*", "MeshInstance3D", true, false):
			(malla as MeshInstance3D).material_overlay = _material_ira
	_material_ira.albedo_color = Color(1.0, 0.1, 0.1, rabia * TINTE_MAX)


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


# ---------- Feria cerrada: entra y no vuelve a salir ----------
func _dentro_de_feria(punto: Vector3) -> bool:
	return absf(punto.x - centro_feria.x) <= limite_feria \
		and absf(punto.z - centro_feria.z) <= limite_feria

## Apenas pisa la feria queda "adentro"; desde entonces no puede pasar de la cerca.
func _encerrar_en_feria() -> void:
	if not viene_de_afuera:
		return
	if not _adentro:
		_adentro = _dentro_de_feria(global_position)
		return
	var l := limite_feria + MARGEN_FERIA
	global_position.x = clampf(global_position.x, centro_feria.x - l, centro_feria.x + l)
	global_position.z = clampf(global_position.z, centro_feria.z - l, centro_feria.z + l)

## ¿Está dentro de la cerca ahora mismo? IncidentePresionado solo recluta peleadores que ya entraron.
func esta_dentro_de_feria() -> bool:
	return _dentro_de_feria(global_position)

## Como _limitar_a_feria, pero siempre (sin importar si ya entró): para puestos de pelea.
func _punto_en_feria(punto: Vector3) -> Vector3:
	punto.x = clampf(punto.x, centro_feria.x - limite_feria, centro_feria.x + limite_feria)
	punto.z = clampf(punto.z, centro_feria.z - limite_feria, centro_feria.z + limite_feria)
	return punto

## Si ya está adentro, ningún destino (huir, alejarse, curiosear...) lo saca de la feria
func _limitar_a_feria(punto: Vector3) -> Vector3:
	if not viene_de_afuera or not _adentro:
		return punto
	punto.x = clampf(punto.x, centro_feria.x - limite_feria, centro_feria.x + limite_feria)
	punto.z = clampf(punto.z, centro_feria.z - limite_feria, centro_feria.z + limite_feria)
	return punto


# ---------- Administrativos (de noche, contorno verde) ----------
## AmbienteNoche lo llama al caer la noche en los ciudadanos elegidos para defender.
func mostrar_contorno_noche() -> void:
	if es_administrativo:
		return
	es_administrativo = true
	add_to_group("administrativos")
	var material := ShaderMaterial.new()
	material.shader = SHADER_CONTORNO
	for malla in modelo.find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_overlay = material


# ---------- Atascos ----------
## `entrada` pegada a la malla, calculada una sola vez cuando la malla ya existe
func _entrada_en_malla() -> Vector3:
	if _entrada_ajustada == Vector3.INF and _hay_malla():
		_entrada_ajustada = _sobre_malla(entrada)
	return entrada if _entrada_ajustada == Vector3.INF else _entrada_ajustada

## Si quiere moverse pero casi no avanza (choca con algo o no hay camino), pide otro destino.
func _revisar_atasco(delta: float, pedida: float) -> void:
	if pedida < 0.3:
		_t_atascado = 0.0
		return
	var real := get_real_velocity()
	if Vector2(real.x, real.z).length() < pedida * 0.25:
		_t_atascado += delta
		if _t_atascado >= TIEMPO_ATASCADO:
			_t_atascado = 0.0
			_al_atascarse()
	else:
		_t_atascado = maxf(_t_atascado - delta, 0.0)

## Los hijos pueden sobrescribirlo (llamando a super()) para elegir otra cosa que hacer.
func _al_atascarse() -> void:
	_ultimo_destino = Vector3.INF   # fuerza ruta nueva
	_prox_ruta = 0.0
	_destino_paseo = Vector3.INF    # y paseo nuevo
	_prox_paseo = 0.0
	if viene_de_afuera and not _llego_a_entrada:
		_llego_a_entrada = true     # deja de insistir con la entrada y sigue con su paseo


# ---------- Utilidades compartidas ----------
func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0

func _jugador_en_vision() -> bool:
	return global_position.distance_to(jugador.global_position) <= rango_vision

func _evento_cerca(punto_evento: Vector3) -> bool:
	return global_position.distance_to(punto_evento) <= rango_evento

func mover_hacia(destino: Vector3, vel: float) -> void:
	destino = _limitar_a_feria(destino)
	var meta := destino
	if _agente != null and _hay_malla():
		var ahora := _ahora()
		if ahora >= _prox_ruta or destino.distance_to(_ultimo_destino) > 1.0:
			_prox_ruta = ahora + 0.3
			_ultimo_destino = destino
			_agente.target_position = destino
		if _agente.is_navigation_finished():
			# La ruta terminó. Si el destino sigue lejos es inalcanzable (hueco de la malla, isla
			# aislada...): ir en línea recta solo lo estrella contra un obstáculo, así que se queda
			# quieto y quien lo llamó elige otro destino (o _revisar_atasco lo pide).
			if _distancia_plana(destino) > DIST_LLEGADA_BLOQUEADO:
				return
		else:
			meta = _agente.get_next_path_position()
	var dir := meta - global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		# La ruta no avanza: si el destino sigue cerca va directo; sin malla no hay otra forma
		var directo := destino - global_position
		directo.y = 0.0
		if directo.length() < DIST_LLEGADA * 0.5:
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

## Mueve `punto` a la zona caminable más cercana (si aún no hay malla lo deja como está)
func _sobre_malla(punto: Vector3) -> Vector3:
	if _agente == null or not _hay_malla():
		return punto
	return NavigationServer3D.map_get_closest_point(_agente.get_navigation_map(), punto)

## ¿Ya llegó a `punto`? También cuenta si la ruta terminó y quedó razonablemente cerca
## (un puesto que no se puede alcanzar del todo no debe dejarlo atascado para siempre).
func _llego_a(punto: Vector3) -> bool:
	var falta := _distancia_plana(punto)
	if falta <= DIST_LLEGADA:
		return true
	return _agente != null and _hay_malla() and _agente.is_navigation_finished() \
		and falta <= DIST_LLEGADA_BLOQUEADO

## true mientras camina desde la entrada del parque hacia su punto de llegada
func _entrando(delta: float) -> bool:
	if not viene_de_afuera or _llego_a_entrada:
		return false
	_tiempo_entrando += delta
	var punto := _entrada_en_malla()
	var falta := Vector2(global_position.x - punto.x, global_position.z - punto.z).length()
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
		var p := _ancla + Vector3(cos(ang), 0.0, sin(ang)) * sqrt(randf()) * _radio_paseo
		if viene_de_afuera:
			# no se sale del cercado (el paseo puede asomarse más allá de las cercas)
			p.x = clampf(p.x, centro_feria.x - limite_feria, centro_feria.x + limite_feria)
			p.z = clampf(p.z, centro_feria.z - limite_feria, centro_feria.z + limite_feria)
		# Sobre la malla: ~1 de cada 4 puntos al azar cae en un hueco (puesto, banca, atracción)
		_destino_paseo = _sobre_malla(p)
	var falta := Vector2(global_position.x - _destino_paseo.x, global_position.z - _destino_paseo.z).length()
	if falta > 1.0:
		estado = Estado.CAMINANDO
		mover_hacia(_destino_paseo, velocidad_caminar)
	else:
		estado = Estado.IDLE

func huir_de(punto_evento: Vector3, vel: float) -> void:
	var dir := global_position - punto_evento
	dir.y = 0.0
	mover_hacia(_sobre_malla(global_position + dir.normalized() * 5.0), vel)

func mirar(blanco: Vector3) -> void:
	var p := Vector3(blanco.x, global_position.y, blanco.z)
	if p.distance_to(global_position) > 0.01:
		look_at(p, Vector3.UP)
