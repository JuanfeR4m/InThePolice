@tool
class_name AmbienteNoche
extends Node3D
## Ambientación de la noche de InThePolice.
## La escena ambiente_noche.tscn tiene los hijos:
##   Fuegos  -> instancias de fuego.tscn (llamas, humo y luz). Muévelas donde quieras.
##   Basura  -> piezas sueltas (MeshInstance3D). Agrega, borra o mueve las que quieras.
## Todo empieza oculto; este script lo prende cuando cae la noche.
## Además oscurece el cielo, mete niebla, tumba casetas/bancas/canecas y hace
## parpadear las luces. Con la tecla N se ve la noche sin esperar.
##
## Uso: arrastra ambiente_noche.tscn como hijo de Main.

## 1.0 = desorden total, 0.0 = casi nada
@export_range(0.0, 1.0) var desorden := 1.0
## Si es true, el desorden depende de la Ira (Juego.ira)
@export var usar_ira := false
## Marca esto en el editor para ver los fuegos y la basura sin correr el juego.
## Desmárcalo antes de guardar/jugar (al jugar se ocultan solos igual).
@export var vista_previa := false:
	set(v):
		vista_previa = v
		if Engine.is_editor_hint() and is_inside_tree():
			_poner_previa(v)
## Tecla N para ver la noche sin esperar (desactivar al entregar)
@export var tecla_prueba := true

@export_group("Cielo y niebla")
@export var color_cielo := Color("0B0E22")
@export var color_horizonte := Color("2A2448")
@export var densidad_niebla := 0.012
@export var duracion_transicion := 4.0

@export_group("Referencias (se buscan solas si están vacías)")
@export var sistema_sol: SistemaSol
@export var parque: Node3D
@export var fuegos: Node3D
@export var basura: Node3D

const ESCENA_POLVO := preload("res://escenas/efectos/polvo.tscn")

var activa := false
var _t := 0.0
var _partida: Node
# cada luz: [OmniLight3D, energia_base, fase, amplitud]
var _luces: Array = []


func _poner_previa(v: bool) -> void:
	var f := get_node_or_null("Fuegos")
	if f != null:
		for fuego in f.get_children():
			if fuego is Node3D:
				fuego.visible = v
				for p in fuego.find_children("*", "CPUParticles3D", true, false):
					(p as CPUParticles3D).emitting = v
	var b := get_node_or_null("Basura")
	if b != null:
		for pieza in b.get_children():
			if pieza is Node3D:
				pieza.visible = v


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_poner_previa(false)
	set_process(false)
	var raiz: Node = owner if owner != null else get_parent()
	if sistema_sol == null:
		sistema_sol = raiz.find_child("SistemaSol", true, false) as SistemaSol
	if parque == null:
		parque = raiz.find_child("Parque", true, false) as Node3D
	if fuegos == null:
		fuegos = get_node_or_null("Fuegos") as Node3D
	if basura == null:
		basura = get_node_or_null("Basura") as Node3D
	_partida = get_tree().get_first_node_in_group("partida")
	if sistema_sol != null:
		sistema_sol.cambio_noche.connect(_on_cambio_noche)
	if parque == null:
		push_warning("AmbienteNoche: no encontré el nodo Parque")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# La noche empieza cuando a la Partida le quedan "noche_en" segundos
	if activa or _partida == null:
		return
	if _partida.tiempo > 0.0 and _partida.tiempo < _partida.noche_en:
		iniciar_noche()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if tecla_prueba and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_N:
		iniciar_noche()


func _on_cambio_noche(es_noche: bool) -> void:
	if es_noche:
		iniciar_noche()


func iniciar_noche() -> void:
	if activa:
		return
	activa = true
	set_process(true)

	var d := desorden
	if usar_ira:
		var juego := get_tree().get_first_node_in_group("juego")
		if juego != null:
			d = clampf(0.4 + 0.6 * float(juego.ira) / 100.0, 0.0, 1.0)

	_cielo_y_niebla()
	_parpadear_luces()
	_tumbar_mobiliario(d)
	_encender_fuegos()
	_mostrar_basura(d)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for e in _luces:
		var luz: OmniLight3D = e[0]
		if not is_instance_valid(luz):
			continue
		var f: float = e[2]
		var v := sin(_t * 13.0 + f) * sin(_t * 7.3 + f * 2.0)
		luz.light_energy = maxf(0.0, float(e[1]) * (1.0 + float(e[3]) * v))


# ---------------------------------------------------------------- cielo

func _cielo_y_niebla() -> void:
	if sistema_sol == null or sistema_sol.entorno == null:
		return
	var env := sistema_sol.entorno.environment
	env.fog_enabled = true
	env.fog_light_color = color_horizonte
	env.fog_density = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(env, "fog_density", densidad_niebla, duracion_transicion)
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var m := env.sky.sky_material as ProceduralSkyMaterial
		tw.tween_property(m, "sky_top_color", color_cielo, duracion_transicion)
		tw.tween_property(m, "sky_horizon_color", color_horizonte, duracion_transicion)
		tw.tween_property(m, "ground_horizon_color", color_horizonte, duracion_transicion)
		tw.tween_property(m, "ground_bottom_color", color_cielo, duracion_transicion)


func _parpadear_luces() -> void:
	# Faroles y focos de la feria titilan
	var luces: Array = []
	if parque != null:
		luces.append_array(parque.find_children("*", "OmniLight3D", true, false))
	for foco in get_tree().get_nodes_in_group("focos"):
		luces.append_array(foco.find_children("*", "OmniLight3D", true, false))
	for luz in luces:
		_luces.append([luz, luz.light_energy, randf() * 10.0, 0.25])


# --------------------------------------------------------- casetas caídas

func _tumbar_mobiliario(d: float) -> void:
	if parque == null:
		return
	var puestos: Array[Node3D] = _hijos_3d(parque.get_node_or_null("Puestos"))
	var mobiliario: Array[Node3D] = _hijos_3d(parque.get_node_or_null("Mobiliario"))
	var i := 0

	# Canecas: siempre se caen
	for n in mobiliario:
		if n.name.to_lower().begins_with("caneca"):
			_tumbar(n, 0.2 + i * 0.25, 80.0, 95.0)
			i += 1

	# Casetas: cuántas depende del desorden
	puestos.shuffle()
	var cuantos := ceili(puestos.size() * d)
	for k in cuantos:
		_tumbar(puestos[k], 0.3 + i * 0.3 + randf() * 0.3, 70.0, 95.0)
		i += 1

	# Bancas: la mayoría quedan tiradas
	for n in mobiliario:
		if n.name.to_lower().begins_with("banca") and randf() < 0.75 * d:
			_tumbar(n, 0.4 + randf() * 2.0, 75.0, 95.0)


func _hijos_3d(nodo: Node) -> Array[Node3D]:
	var lista: Array[Node3D] = []
	if nodo == null:
		return lista
	for h in nodo.get_children():
		if h is Node3D:
			lista.append(h)
	return lista


func _tumbar(nodo: Node3D, retraso: float, grados_min: float, grados_max: float) -> void:
	var origen: Transform3D = nodo.global_transform
	var eje := Vector3.FORWARD if randf() < 0.5 else Vector3.RIGHT
	var ang := deg_to_rad(randf_range(grados_min, grados_max))
	if randf() < 0.5:
		ang = -ang
	var base := Basis(Vector3.UP, randf_range(-0.6, 0.6)) * Basis(eje, ang) * origen.basis
	var destino := Transform3D(base, origen.origin)

	# Que la pieza caída quede apoyada en el suelo, no enterrada ni flotando
	var y_antes := _y_minima(nodo, origen)
	var y_despues := _y_minima(nodo, destino)
	if y_antes < INF and y_despues < INF:
		destino.origin.y += y_antes - y_despues

	var tw := create_tween()
	tw.tween_interval(retraso)
	tw.tween_method(_mover.bind(nodo, origen, destino), 0.0, 1.0, randf_range(0.5, 0.8)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_polvo.bind(destino.origin))


func _mover(t: float, nodo: Node3D, origen: Transform3D, destino: Transform3D) -> void:
	if is_instance_valid(nodo):
		nodo.global_transform = origen.interpolate_with(destino, t)


# Punto más bajo (en y global) de las mallas del nodo si estuviera en "xf"
func _y_minima(nodo: Node3D, xf: Transform3D) -> float:
	var minimo := INF
	var inversa := nodo.global_transform.affine_inverse()
	for m in nodo.find_children("*", "MeshInstance3D", true, false):
		var malla := m as MeshInstance3D
		var caja := malla.get_aabb()
		var relativa := inversa * malla.global_transform
		for k in 8:
			var p := xf * (relativa * caja.get_endpoint(k))
			minimo = minf(minimo, p.y)
	return minimo


func _polvo(pos: Vector3) -> void:
	var p: CPUParticles3D = ESCENA_POLVO.instantiate()
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


# ------------------------------------------------------------------ fuego

func _encender_fuegos() -> void:
	if fuegos == null:
		return
	var i := 0
	for fuego in fuegos.get_children():
		if fuego is Node3D:
			get_tree().create_timer(1.0 + i * 0.3).timeout.connect(_prender.bind(fuego))
			i += 1


func _prender(fuego: Node3D) -> void:
	if not is_instance_valid(fuego):
		return
	fuego.show()
	for p in fuego.find_children("*", "CPUParticles3D", true, false):
		(p as CPUParticles3D).emitting = true
	for luz in fuego.find_children("*", "OmniLight3D", true, false):
		_luces.append([luz, (luz as OmniLight3D).light_energy, randf() * 10.0, 0.35])


# ----------------------------------------------------------------- basura

func _mostrar_basura(d: float) -> void:
	if basura == null:
		return
	var piezas := basura.get_children().filter(func(n): return n is Node3D)
	piezas.shuffle()
	var cuantas := int(piezas.size() * d)
	for k in cuantas:
		var pieza: Node3D = piezas[k]
		var y_final := pieza.position.y
		pieza.position.y = y_final + 3.0
		var tw := create_tween()
		tw.tween_interval(randf() * 3.0)
		tw.tween_callback(pieza.show)
		tw.tween_property(pieza, "position:y", y_final, 0.3)
