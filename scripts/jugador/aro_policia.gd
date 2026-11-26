extends Sprite3D
# Aro de luz en el piso bajo cada policía para distinguirlos de los ciudadanos.
# Policía 1 = naranja, Policía 2 = verde. Gira despacio y late un poquito.

const P1 = preload("res://assets/hud/aro_policia_p1.png")
const P2 = preload("res://assets/hud/aro_policia_p2.png")

@export var velocidad_giro: float = 0.8
@export var pulso: float = 0.05

var t: float = 0.0


func _ready():
	# el personaje decide si es el 1 o el 2 en su propio _ready (corre después del de sus hijos)
	_elegir_color.call_deferred()


func _elegir_color():
	var padre = get_parent()
	if padre.is_in_group("jugador2") or padre.name == "Personaje2":
		texture = P2
	else:
		texture = P1


func _process(delta):
	t += delta
	rotation.y += velocidad_giro * delta
	var e := 1.0 + sin(t * 3.0) * pulso
	scale = Vector3(e, 1.0, e)
