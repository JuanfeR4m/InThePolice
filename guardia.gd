extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR }

@export var rapidez = 2.0
@export var espera = 0.5
@export var ruta: Array[Vector3] = [Vector3.ZERO, Vector3(6, 0, 0), Vector3(6, 0, -5)]

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0

@onready var anim = $Modelo/AnimationPlayer


func _ready():
	for d in ruta:
		puntos.append(global_position + d)


func _physics_process(delta):
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)

	var nuevo = decidir()
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ",
			Engine.get_physics_frames(), " en ",
			global_position.snappedf(0.01))

	match estado:
		Estado.PATRULLAR:
			patrullar()
		Estado.ESPERAR:
			frenar()

	move_and_slide()


func decidir():
	if reloj > 0.001:
		return Estado.ESPERAR
	return Estado.PATRULLAR


func patrullar():
	var destino = puntos[indice]
	if distancia_a(destino) < 0.1:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino)


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
