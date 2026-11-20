extends Node3D

@export var proporcion_visible_ancho := 0.58
@export var proporcion_visible_alto := 0.62

@export var escala := 1.35

@export var ancho_personaje := 0.9
@export var alto_personaje := 1.9

@export var desplazamiento_y := 0.0
## Transparencia de la nube: baja para que se vean pelear los ciudadanos
@export_range(0.0, 1.0, 0.05) var opacidad := 0.45

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func mostrar_sobre(personajes: Array) -> void:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	var suma := Vector3.ZERO
	var cuantos := 0
	for p in personajes:
		if not (p is Node3D):
			continue
		var pos: Vector3 = p.global_position
		minimo = Vector2(minf(minimo.x, pos.x), minf(minimo.y, pos.z))
		maximo = Vector2(maxf(maximo.x, pos.x), maxf(maximo.y, pos.z))
		suma += pos
		cuantos += 1
	if cuantos == 0:
		push_warning("Pelea: no hay personajes a quienes cubrir.")
		return
	
	var centro := suma / cuantos
	global_position = centro + Vector3(0.0, alto_personaje * 0.5 + desplazamiento_y, 0.0)

	var ancho := maxf(maximo.x - minimo.x, maximo.y - minimo.y) + ancho_personaje
	var alto := alto_personaje
	var textura := sprite.sprite_frames.get_frame_texture("default", 0)
	var px_ancho := ancho * escala / (float(textura.get_width()) * proporcion_visible_ancho)
	var px_alto := alto * escala / (float(textura.get_height()) * proporcion_visible_alto)
	sprite.pixel_size = maxf(px_ancho, px_alto)
	sprite.modulate.a = opacidad
