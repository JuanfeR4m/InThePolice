extends Node

## Ruta de la carpeta de sonidos
@export var carpeta: String = "res://assets/sonidos/"
@export var volumen_musica_db: float = -8.0
@export var volumen_efectos_db: float = 0.0

var p_inicio: AudioStreamPlayer
var p_musica: AudioStreamPlayer
var p_fin: AudioStreamPlayer
var terminada: bool = false


func _ready():
	
	await get_tree().process_frame
	var menu = get_tree().get_first_node_in_group("menu_inicio")
	if menu != null:
		await menu.iniciar

	p_inicio = _crear_player("inicio_partida.mp3", volumen_efectos_db)
	p_musica = _crear_player("instrumental.mp3", volumen_musica_db)
	p_fin = _crear_player("fin_partida.mp3", volumen_efectos_db)

	
	if p_musica.stream is AudioStreamMP3:
		p_musica.stream.loop = true

	
	p_inicio.finished.connect(_empezar_musica)
	if p_inicio.stream != null:
		p_inicio.play()
	else:
		_empezar_musica()

	
	await get_tree().process_frame
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.tiempo_agotado.connect(derrota)
		hud.ira_llena.connect(derrota)


func _crear_player(archivo: String, volumen: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	var ruta = carpeta + archivo
	if ResourceLoader.exists(ruta):
		p.stream = load(ruta)
	else:
		push_warning("No se encontró el sonido: " + ruta)
	p.volume_db = volumen
	add_child(p)
	return p


func _empezar_musica():
	if terminada or p_musica.stream == null:
		return
	p_musica.play()



func derrota():
	_terminar("fin_partida.mp3")



func victoria():
	_terminar("fin_partida2.mp3")


func _terminar(archivo: String):
	if terminada:
		return
	terminada = true
	p_inicio.stop()
	p_musica.stop()
	var ruta = carpeta + archivo
	if ResourceLoader.exists(ruta):
		p_fin.stream = load(ruta)
		p_fin.play()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.detener_tiempo()
