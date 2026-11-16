extends Node3D

@onready var personaje1: Node = $Escenario/Personaje
@onready var personaje2: Node = $Escenario/Personaje2
@onready var cartel: Node3D = $Escenario/CartelMenu
@onready var logo: Control = $UI/Logo

@export var excluir: Array[String] = ["RESET", "caminar", "correr"]
@export_range(0.1, 2.0, 0.05) var velocidad_animacion := 0.6

const ESCENA_JUEGO := "res://nivel_1.tscn"


func _ready() -> void:
	_configurar_personaje(personaje1, 0.0)
	_configurar_personaje(personaje2, randf_range(0.4, 1.2))
	_configurar_ui()


func _configurar_personaje(personaje: Node, retraso: float) -> void:
	_bloquear_controles(personaje)

	var anim := personaje.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		push_warning("No encontré AnimationPlayer en " + personaje.name)
		return

	anim.speed_scale = velocidad_animacion

	var lista: Array[String] = []
	for nombre in anim.get_animation_list():
		if String(nombre) in excluir:
			continue
		anim.get_animation(nombre).loop_mode = Animation.LOOP_NONE
		lista.append(String(nombre))

	if lista.is_empty():
		push_warning("Sin animaciones válidas en " + personaje.name)
		return

	anim.animation_finished.connect(func(_n): _reproducir_aleatoria(anim, lista))

	await get_tree().create_timer(retraso).timeout
	_reproducir_aleatoria(anim, lista)


func _reproducir_aleatoria(anim: AnimationPlayer, lista: Array[String]) -> void:
	var opciones := lista.duplicate()
	if opciones.size() > 1:
		opciones.erase(String(anim.current_animation))
	anim.play(opciones.pick_random(), 0.3)


func _bloquear_controles(personaje: Node) -> void:
	personaje.set_process(false)
	personaje.set_physics_process(false)
	personaje.set_process_input(false)
	personaje.set_process_unhandled_input(false)
	personaje.set_process_unhandled_key_input(false)
	if "velocity" in personaje:
		personaje.velocity = Vector3.ZERO


func _configurar_ui() -> void:
	cartel.jugar.connect(func(): get_tree().change_scene_to_file(ESCENA_JUEGO))
	cartel.opciones.connect(_abrir_opciones)
	cartel.salir.connect(func(): get_tree().quit())

	await get_tree().process_frame
	logo.pivot_offset = logo.size / 2
	var tw := create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _abrir_opciones() -> void:
	print("Opciones")
