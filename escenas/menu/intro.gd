extends CanvasLayer

signal intro_terminada

const ESPERA = 1.0
const DURACION_FADE = 0.5

@onready var video = $VideoStreamPlayer

func _on_video_stream_player_finished():
	await get_tree().create_timer(ESPERA).timeout
	var tween = create_tween()
	tween.tween_property(video, "modulate:a", 0.0, DURACION_FADE)
	await tween.finished
	intro_terminada.emit()
	queue_free()
