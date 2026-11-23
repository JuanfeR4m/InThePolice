class_name IncidentePresionado
extends Node3D

signal resuelto(incidente: IncidentePresionado)
signal escalado(incidente: IncidentePresionado)

enum Modo { MANTENER, ESPICHAR, JUNTOS, ESPICHAR_JUNTOS, ALTERNAR, SECUENCIA }

const TIEMPO_RESOLVER := 3.0
const TIEMPO_ALERTA := 10.0
const TIEMPO_LIMITE := 15.0
const COLOR_NORMAL := Color("F2B632")
const COLOR_ALERTA := Color("D63A3A")
# El dibujo del anillo es amarillo; este tinte lo vuelve rojo al entrar en alerta
const TINTE_ANILLO_ALERTA := Color(0.9, 0.12, 0.12)
const VELOCIDAD_ALERTA := 10.0
const PELEADORES := 2
const RADIO_FORMACION := 1.0
const CURIOSOS := 3
const DISTANCIA_MIRAR := 2.2
const RADIO_RECLUTAR := 70.0
const RADIO_CURIOSOS := 40.0
const ESPERA_MAXIMA := 25.0
const INTERVALO_RECLUTAR := 1.0
const PRESIONES := 12
const CAIDA_PRESIONES := 0.25
const VENTANA_JUNTOS := 0.3
const SECUENCIA := [1, 2, 2, 1, 2]

@export var modo := Modo.MANTENER
@export var escena_pelea: PackedScene

@onready var anillo: AnimatedSprite3D = $Anillo
@onready var zona: Area3D = $Zona
@onready var alerta: MeshInstance3D = $Alerta
@onready var indicador: MeshInstance3D = $Indicador
@onready var aviso: AvisoTecla = $Indicador/Aviso

var puestos: Array = []
var puestos_curiosos: Array = []
var nube_pelea: Node3D
var reclutados := false
var iniciado := false
var espera_llegada := 0.0
var reloj_reclutar := 0.0
var jugador1_cerca := false
var jugador2_cerca := false
var progreso := 0.0
var paso := 0
var ultimo := 0
var reloj1 := 0.0
var reloj2 := 0.0
var espera := 0.0
var en_rojo := false
var material_alerta: ShaderMaterial
var material_indicador: ShaderMaterial

func _ready() -> void:
	add_to_group("incidentes")
	puestos.resize(PELEADORES)
	puestos_curiosos.resize(CURIOSOS)
	material_alerta = alerta.material_override.duplicate()
	alerta.material_override = material_alerta
	material_indicador = indicador.material_override.duplicate()
	indicador.material_override = material_indicador
	anillo.visible = false
	var nube_hija := get_node_or_null("Pelea")
	if nube_hija != null:
		nube_hija.visible = false
	alerta.visible = false
	indicador.visible = false
	aviso.configurar(modo, modo == Modo.MANTENER or modo == Modo.JUNTOS)
	zona.monitoring = false

func _process(delta: float) -> void:
	reloj_reclutar -= delta
	if reloj_reclutar <= 0.0:
		reloj_reclutar = INTERVALO_RECLUTAR
		reclutar()
	if not iniciado:
		revisar_llegada(delta)
		return
	espera += delta
	if espera >= TIEMPO_LIMITE:
		escalado.emit(self)
		queue_free()
		return
	if espera >= TIEMPO_ALERTA and not en_rojo:
		en_rojo = true
		pasar_a_rojo()
	actualizar_progreso(delta)
	var cerca := jugador1_cerca or jugador2_cerca
	alerta.visible = not cerca
	indicador.visible = cerca
	material_indicador.set_shader_parameter("progreso", progreso)
	if progreso >= 1.0:
		resuelto.emit(self)
		queue_free()
		return
	if cerca:
		actualizar_aviso()

func esta_mas_cerca(a: Node3D, b: Node3D) -> bool:
	return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)

func ordenar_por_cercania(lista: Array[Node3D]) -> void:
	lista.sort_custom(esta_mas_cerca)

func peleadores_activos() -> Array:
	var activos := []
	for p in puestos:
		if is_instance_valid(p) and p.incidente == self:
			activos.append(p)
	return activos

func curiosos_activos() -> Array:
	var activos := []
	for c in puestos_curiosos:
		if is_instance_valid(c) and c.incidente == self:
			activos.append(c)
	return activos

func puesto_libre(lista: Array, i: int) -> bool:
	var c = lista[i]
	return not is_instance_valid(c) or c.incidente != self

func indice_libre(lista: Array) -> int:
	for i in lista.size():
		if puesto_libre(lista, i):
			return i
	return -1

func posicion_puesto(i: int) -> Vector3:
	var angulo := TAU * i / PELEADORES
	return global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * RADIO_FORMACION

func posicion_mirar(i: int) -> Vector3:
	var angulo := PI / 2.0 + TAU * i / CURIOSOS
	return global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * DISTANCIA_MIRAR

func indice_cercano(c: Node3D) -> int:
	var mejor := -1
	var menor := INF
	for i in PELEADORES:
		if not puesto_libre(puestos, i):
			continue
		var d := c.global_position.distance_squared_to(posicion_puesto(i))
		if d < menor:
			menor = d
			mejor = i
	return mejor

func acepta_peleador(c: Node3D) -> bool:
	return not iniciado and indice_libre(puestos) != -1 \
		and c.global_position.distance_to(global_position) <= RADIO_RECLUTAR

func acepta_curioso(c: Node3D) -> bool:
	return iniciado and indice_libre(puestos_curiosos) != -1 \
		and c.global_position.distance_to(global_position) <= RADIO_CURIOSOS

func inscribir_peleador(c: Node3D) -> bool:
	var i := indice_cercano(c)
	if i == -1:
		return false
	puestos[i] = c
	c.ir_a_pelea(posicion_puesto(i), self)
	actualizar_rivales()
	return true

func inscribir_curioso(c: Node3D) -> bool:
	var i := indice_libre(puestos_curiosos)
	if i == -1:
		return false
	puestos_curiosos[i] = c
	c.curiosear(posicion_mirar(i), global_position, self)
	return true

func liberar(c: Node3D) -> void:
	for i in puestos.size():
		if puestos[i] == c:
			puestos[i] = null
	for i in puestos_curiosos.size():
		if puestos_curiosos[i] == c:
			puestos_curiosos[i] = null
	actualizar_rivales()

func actualizar_rivales() -> void:
	var activos := peleadores_activos()
	for i in activos.size():
		if activos.size() > 1:
			activos[i].rival = activos[(i + 1) % activos.size()]
		else:
			activos[i].rival = null

func reclutar() -> void:
	if not iniciado:
		var candidatos: Array[Node3D] = []
		for c in get_tree().get_nodes_in_group("ciudadanos"):
			if c.has_method("disponible") and c.disponible() \
			and c.global_position.distance_to(global_position) <= RADIO_RECLUTAR:
				candidatos.append(c)
		ordenar_por_cercania(candidatos)
		for c in candidatos:
			if not inscribir_peleador(c):
				break
		reclutados = true
		return
	var mirones: Array[Node3D] = []
	for c in get_tree().get_nodes_in_group("ciudadanos"):
		if c.has_method("puede_mirar") and c.puede_mirar() \
		and c.global_position.distance_to(global_position) <= RADIO_CURIOSOS:
			mirones.append(c)
	ordenar_por_cercania(mirones)
	for c in mirones:
		if not inscribir_curioso(c):
			break

func llegaron_todos() -> bool:
	var activos := peleadores_activos()
	if activos.size() < PELEADORES:
		return false
	for p in activos:
		if not p.llego:
			return false
	return true

func revisar_llegada(delta: float) -> void:
	if not reclutados:
		return
	espera_llegada += delta
	if llegaron_todos():
		iniciar()
	elif espera_llegada >= ESPERA_MAXIMA:
		queue_free()

func iniciar() -> void:
	iniciado = true
	anillo.visible = true
	zona.monitoring = true
	mostrar_pelea()

func mostrar_pelea() -> void:
	var activos := peleadores_activos()
	if activos.is_empty():
		return
	if escena_pelea != null:
		nube_pelea = escena_pelea.instantiate()
		add_child(nube_pelea)
	else:
		# En la escena la nube ya viene como nodo hijo "Pelea" (escena_pelea no se asigna)
		nube_pelea = get_node_or_null("Pelea")
	if nube_pelea == null:
		return
	nube_pelea.visible = true
	nube_pelea.mostrar_sobre(activos)

func _exit_tree() -> void:
	for p in peleadores_activos():
		p.terminar_pelea()
	for c in curiosos_activos():
		c.dejar_de_curiosear()

func pasar_a_rojo() -> void:
	anillo.modulate = TINTE_ANILLO_ALERTA
	material_alerta.set_shader_parameter("color_relleno", COLOR_ALERTA)
	material_alerta.set_shader_parameter("velocidad", VELOCIDAD_ALERTA)
	material_indicador.set_shader_parameter("color_centro", COLOR_ALERTA)

func estan_resolviendo() -> bool:
	if jugador1_cerca and Input.is_action_pressed("interactuar1"):
		return true
	if jugador2_cerca and Input.is_action_pressed("interactuar2"):
		return true
	return false

func presiono1() -> bool:
	return jugador1_cerca and Input.is_action_just_pressed("interactuar1")

func presiono2() -> bool:
	return jugador2_cerca and Input.is_action_just_pressed("interactuar2")

func sostienen_los_dos() -> bool:
	return jugador1_cerca and jugador2_cerca \
		and Input.is_action_pressed("interactuar1") \
		and Input.is_action_pressed("interactuar2")

func actualizar_progreso(delta: float) -> void:
	match modo:
		Modo.MANTENER:
			if estan_resolviendo():
				progreso += delta / TIEMPO_RESOLVER
			else:
				progreso = 0.0
		Modo.ESPICHAR:
			progreso = maxf(progreso - CAIDA_PRESIONES * delta, 0.0)
			if presiono1() or presiono2():
				progreso += 1.0 / PRESIONES
		Modo.JUNTOS:
			if sostienen_los_dos():
				progreso += delta / TIEMPO_RESOLVER
			else:
				progreso = 0.0
		Modo.ESPICHAR_JUNTOS:
			progreso = maxf(progreso - CAIDA_PRESIONES * delta, 0.0)
			reloj1 = maxf(reloj1 - delta, 0.0)
			reloj2 = maxf(reloj2 - delta, 0.0)
			if presiono1():
				reloj1 = VENTANA_JUNTOS
			if presiono2():
				reloj2 = VENTANA_JUNTOS
			if reloj1 > 0.0 and reloj2 > 0.0:
				progreso += 1.0 / PRESIONES
				reloj1 = 0.0
				reloj2 = 0.0
		Modo.ALTERNAR:
			progreso = maxf(progreso - CAIDA_PRESIONES * delta, 0.0)
			if presiono1() and ultimo != 1:
				ultimo = 1
				progreso += 1.0 / PRESIONES
			elif presiono2() and ultimo != 2:
				ultimo = 2
				progreso += 1.0 / PRESIONES
		Modo.SECUENCIA:
			var esperado: int = SECUENCIA[paso]
			if (esperado == 1 and presiono1()) or (esperado == 2 and presiono2()):
				paso += 1
			elif presiono1() or presiono2():
				paso = 0
			progreso = float(paso) / SECUENCIA.size()

func siguiente_tecla() -> int:
	match modo:
		Modo.ALTERNAR:
			if ultimo == 1:
				return 2
			if ultimo == 2:
				return 1
		Modo.SECUENCIA:
			var esperado: int = SECUENCIA[paso]
			return esperado
	return 0

func actualizar_aviso() -> void:
	aviso.mostrar_estado(Input.is_action_pressed("interactuar1"), Input.is_action_pressed("interactuar2"), siguiente_tecla())
	if modo == Modo.SECUENCIA:
		aviso.mostrar_secuencia(SECUENCIA, paso)

func _on_zona_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador1"):
		jugador1_cerca = true
	if body.is_in_group("jugador2"):
		jugador2_cerca = true

func _on_zona_body_exited(body: Node3D) -> void:
	if body.is_in_group("jugador1"):
		jugador1_cerca = false
	if body.is_in_group("jugador2"):
		jugador2_cerca = false
