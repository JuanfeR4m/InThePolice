extends Sprite3D
# Triángulo flotante sobre cada policía para distinguirlos de los ciudadanos.
# Policía 1 = naranja, Policía 2 = verde.

const P1 = preload("res://assets/hud/marcador_policia_p1.png")
const P2 = preload("res://assets/hud/marcador_policia_p2.png")

@export var altura: float = 2.9
@export var amplitud: float = 0.12
@export var velocidad: float = 3.0

var t: float = 0.0


func _ready():
	# el personaje decide si es el 1 o el 2 en su propio _ready (corre después del de sus hijos)
	_elegir_color.call_deferred()
	position.y = altura


func _elegir_color():
	var padre = get_parent()
	if padre.is_in_group("jugador2") or padre.name == "Personaje2":
		texture = P2
	else:
		texture = P1


func _process(delta):
	t += delta
	position.y = altura + sin(t * velocidad) * amplitud
