extends CanvasLayer

@onready var reloj = $Reloj
@onready var barra_ira = $BarraIra
@onready var admins = $Administrativos
@onready var mensaje = $Mensaje

var juego: Juego
var _ultimo_mensaje := ""
var _t_mensaje := 0.0


func _ready():
	juego = get_tree().get_first_node_in_group("juego")


func _process(delta):
	if juego == null:
		return

	reloj.text = str(ceili(juego.tiempo_restante))
	barra_ira.value = juego.ira
	admins.text = "Salvados: " + str(juego.administrativos)

	# el mensaje se muestra 2 segundos y se borra
	if juego.mensaje != _ultimo_mensaje:
		_ultimo_mensaje = juego.mensaje
		mensaje.text = _ultimo_mensaje
		_t_mensaje = 2.0
	_t_mensaje = maxf(_t_mensaje - delta, 0.0)
	if _t_mensaje == 0.0:
		mensaje.text = ""
		
