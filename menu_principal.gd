extends Node3D

signal iniciar

const NIVEL_1 := "res://escenas/nivel_1.tscn"

const RETRASO_MINIMO := 0.4
const RETRASO_MAXIMO := 1.2
const MEZCLA_ANIMACION := 0.3

@onready var personaje1: Node = $Escenario/Personaje
@onready var personaje2: Node = $Escenario/Personaje2
@onready var cartel: Node3D = $Escenario/CartelMenu
@onready var textura: TextureRect = $InterfazMenu/TextureRect

@export var excluir: Array[String] = ["RESET", "caminar", "correr"]
@export_range(0.1, 2.0, 0.05) var velocidad_animacion := 0.4

@export_group("Canvas")
@export var ajustar_canvas := true
@export var tamano_base := Vector2i(1920, 1080)


func _ready() -> void:
	add_to_group("menu_inicio")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	if ajustar_canvas:
		_ajustar_canvas()

	_configurar_personaje(personaje1, 0.0)
	_configurar_personaje(personaje2, randf_range(RETRASO_MINIMO, RETRASO_MAXIMO))
	_configurar_ui()
	_reproducir_textura()


func _ajustar_canvas() -> void:
	var ventana := get_window()
	ventana.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	ventana.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if tamano_base.x > 0 and tamano_base.y > 0:
		ventana.content_scale_size = tamano_base


func _reproducir_textura() -> void:
	var animada := textura.texture as AnimatedTexture
	if animada:
		animada.pause = false


func _configurar_personaje(personaje: Node, retraso: float) -> void:
	_bloquear_controles(personaje)

	var anim := personaje.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		push_warning("No encontré AnimationPlayer en " + personaje.name)
		return

	anim.speed_scale = velocidad_animacion

	var lista: Array[String] = []
	for nombre in anim.get_animation_list():
		if String(nombre).get_file() in excluir:
			continue
		anim.get_animation(nombre).loop_mode = Animation.LOOP_NONE
		lista.append(String(nombre))

	if lista.is_empty():
		push_warning("Sin animaciones válidas en " + personaje.name)
		return

	anim.animation_finished.connect(_al_terminar_animacion.bind(anim, lista))

	await get_tree().create_timer(retraso).timeout
	if not is_inside_tree():
		return
	_reproducir_aleatoria(anim, lista)


func _al_terminar_animacion(_nombre: StringName, anim: AnimationPlayer, lista: Array[String]) -> void:
	_reproducir_aleatoria(anim, lista)


func _reproducir_aleatoria(anim: AnimationPlayer, lista: Array[String]) -> void:
	if not is_instance_valid(anim):
		return
	var opciones := lista.duplicate()
	if opciones.size() > 1:
		opciones.erase(String(anim.current_animation))
	anim.play(opciones.pick_random(), MEZCLA_ANIMACION)


func _bloquear_controles(personaje: Node) -> void:
	personaje.set_process(false)
	personaje.set_physics_process(false)
	personaje.set_process_input(false)
	personaje.set_process_unhandled_input(false)
	personaje.set_process_unhandled_key_input(false)
	if "velocity" in personaje:
		personaje.velocity = Vector3.ZERO


func _configurar_ui() -> void:
	cartel.jugar.connect(_on_jugar)
	cartel.opciones.connect(_abrir_opciones)
	cartel.salir.connect(_on_salir)


func _on_jugar() -> void:
	get_tree().paused = false
	iniciar.emit()
	get_tree().change_scene_to_file(NIVEL_1)


func _abrir_opciones() -> void:
	print("Opciones")


func _on_salir() -> void:
	get_tree().quit()
