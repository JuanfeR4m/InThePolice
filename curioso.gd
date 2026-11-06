extends CharacterBody3D

enum Estado { EN_PUESTO, INVESTIGAR, MIRAR, VOLVER }

@export var rapidez: float = 2.0
@export var tiempo_mirar: float = 3.0
# Se detiene antes del punto: ahí puede estar el jugador, y chocarían.
@export var llega_a: float = 1.0

var estado = Estado.EN_PUESTO
var puesto = Vector3.ZERO
var ruido_en = Vector3.ZERO
var reloj: float = 0.0

@onready var anim = $Modelo/AnimationPlayer

func _ready():
	add_to_group("oyentes")
	puesto = global_position

func _physics_process(delta):
	velocity += get_gravity() * delta
	
	if reloj == null:
		reloj = 0.0
	reloj = maxf(reloj - delta, 0.0)
	
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
		
	match estado:
		Estado.EN_PUESTO:
			frenar()
		Estado.INVESTIGAR:
			ir_a(ruido_en)
		Estado.MIRAR:
			frenar()
		Estado.VOLVER:
			ir_a(puesto)
			
	move_and_slide()

func decidir():
	match estado:
		Estado.INVESTIGAR:
			if distancia_a(ruido_en) < llega_a:
				return Estado.MIRAR
		Estado.MIRAR:
			if reloj <= 0.001:
				return Estado.VOLVER
		Estado.VOLVER:
			if distancia_a(puesto) < 0.1:
				return Estado.EN_PUESTO
	return estado

func cambiar_a(nuevo):
	estado = nuevo
	print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " en ", global_position.snappedf(0.01))
	if estado == Estado.MIRAR:
		reloj = tiempo_mirar

# Un ruido nuevo lo interrumpe en cualquier estado.
func oir(punto):
	ruido_en = punto
	if estado != Estado.INVESTIGAR:
		cambiar_a(Estado.INVESTIGAR)

func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("walk")

func frenar():
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play("idle")

func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
