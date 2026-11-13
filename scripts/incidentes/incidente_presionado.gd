class_name IncidentePresionado
extends Node3D

signal resuelto(incidente: IncidentePresionado)
signal escalado(incidente: IncidentePresionado)

const TIEMPO_RESOLVER := 3.0
const TIEMPO_ALERTA := 10.0
const TIEMPO_LIMITE := 15.0
const COLOR_NORMAL := Color("F2B632")
const COLOR_ALERTA := Color("D63A3A")
const VELOCIDAD_ALERTA := 10.0
const PELEADORES := 2
const RADIO_FORMACION := 1.0
const CURIOSOS := 3
const DISTANCIA_MIRAR_MIN := 1.5
const DISTANCIA_MIRAR_MAX := 2.5
const RADIO_RECLUTAR := 70.0
const RADIO_CURIOSOS := 40.0
const ESPERA_MAXIMA := 25.0
const INTERVALO_RECLUTAR := 1.0

# Arrastra aqui pelea.tscn desde el inspector.
@export var escena_pelea: PackedScene

@onready var anillo: MeshInstance3D = $Anillo
@onready var alerta: MeshInstance3D = $Alerta
@onready var indicador: MeshInstance3D = $Indicador

var puestos: Array = []
var curiosos: Array = []
var nube_pelea: Node3D

# Propiedad de compatibilidad para evitar errores si algún script lee .peleadores
var peleadores: Array:
	get: return peleadores_activos()
	set(v): pass

var reclutados := false
var iniciado := false
var espera_llegada := 0.0
var reloj_reclutar := 0.0
var jugador1_cerca := false
var jugador2_cerca := false
var progreso := 0.0
var espera := 0.0
var en_rojo := false
var material_anillo := StandardMaterial3D.new()
var material_alerta: ShaderMaterial
var material_indicador: ShaderMaterial

func _ready() -> void:
	add_to_group("incidentes")
	puestos.resize(PELEADORES)
	material_anillo.albedo_color = COLOR_NORMAL
	anillo.material_override = material_anillo
	material_alerta = alerta.material_override.duplicate()
	alerta.material_override = material_alerta
	material_indicador = indicador.material_override.duplicate()
	indicador.material_override = material_indicador
	alerta.visible = false
	indicador.visible = false

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
	if estan_resolviendo():
		progreso += delta
	else:
		progreso = 0.0
	var cerca := jugador1_cerca or jugador2_cerca
	alerta.visible = not cerca
	indicador.visible = cerca
	material_indicador.set_shader_parameter("progreso", progreso / TIEMPO_RESOLVER)
	if progreso >= TIEMPO_RESOLVER:
		resuelto.emit(self)
		queue_free()

func ordenar_por_cercania(lista: Array[Node3D]) -> void:
	lista.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))

func peleadores_activos() -> Array:
	var activos := []
	for p in puestos:
		if p != null and is_instance_valid(p) and p.incidente == self:
			activos.append(p)
	return activos

func indice_libre() -> int:
	for i in PELEADORES:
		var p = puestos[i]
		if p == null or not is_instance_valid(p) or p.incidente != self:
			return i
	return -1

func limpiar_curiosos() -> void:
	curiosos = curiosos.filter(func(c):
		return is_instance_valid(c) and c.incidente == self)

func pide_curioso() -> bool:
	limpiar_curiosos()
	return curiosos.size() < CURIOSOS

func acepta_peleador(c: Node3D) -> bool:
	return not iniciado and indice_libre() != -1 \
		and c.global_position.distance_to(global_position) <= RADIO_RECLUTAR

func acepta_curioso(c: Node3D) -> bool:
	return pide_curioso() \
		and c.global_position.distance_to(global_position) <= RADIO_CURIOSOS

func inscribir_peleador(c: Node3D) -> bool:
	var i := indice_libre()
	if i == -1:
		return false
	puestos[i] = c
	var angulo := TAU * i / PELEADORES
	var offset := Vector3(cos(angulo), 0.0, sin(angulo)) * RADIO_FORMACION
	c.ir_a_pelea(global_position + offset, self)
	actualizar_rivales()
	return true

func inscribir_curioso(c: Node3D) -> bool:
	if not pide_curioso():
		return false
	var ang := randf() * TAU
	var dist := randf_range(DISTANCIA_MIRAR_MIN, DISTANCIA_MIRAR_MAX)
	var puesto := global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
	c.curiosear(puesto, global_position, self)
	curiosos.append(c)
	return true

func liberar(c: Node3D) -> void:
	for i in puestos.size():
		if puestos[i] == c:
			puestos[i] = null
	curiosos.erase(c)
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
	var mirones: Array[Node3D] = []
	for c in get_tree().get_nodes_in_group("ciudadanos"):
		if c.has_method("puede_mirar") and c.puede_mirar() \
		and c.global_position.distance_to(global_position) <= RADIO_CURIOSOS:
			mirones.append(c)
	ordenar_por_cercania(mirones)
	for c in mirones:
		if not inscribir_curioso(c):
			break
	reclutados = true

func revisar_llegada(delta: float) -> void:
	if not reclutados:
		return
	espera_llegada += delta
	var activos := peleadores_activos()
	var todos := not activos.is_empty()
	for p in activos:
		if not p.llego:
			todos = false
	if todos or espera_llegada >= ESPERA_MAXIMA:
		iniciado = true
		mostrar_pelea()

# Pone la nube de pelea encima de los peleadores, del tamano de ellos.
# Es hija del incidente: desaparece sola cuando el incidente se resuelve o escala.
func mostrar_pelea() -> void:
	var activos := peleadores_activos()
	if escena_pelea == null or activos.is_empty():
		return
	nube_pelea = escena_pelea.instantiate()
	add_child(nube_pelea)
	nube_pelea.mostrar_sobre(activos)

func _exit_tree() -> void:
	for p in peleadores_activos():
		p.terminar_pelea()
	limpiar_curiosos()
	for c in curiosos:
		c.dejar_de_curiosear()

func pasar_a_rojo() -> void:
	material_anillo.albedo_color = COLOR_ALERTA
	material_alerta.set_shader_parameter("color_relleno", COLOR_ALERTA)
	material_alerta.set_shader_parameter("velocidad", VELOCIDAD_ALERTA)
	material_indicador.set_shader_parameter("color_centro", COLOR_ALERTA)

func estan_resolviendo() -> bool:
	if jugador1_cerca and Input.is_action_pressed("interactuar1"):
		return true
	if jugador2_cerca and Input.is_action_pressed("interactuar2"):
		return true
	return false

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
