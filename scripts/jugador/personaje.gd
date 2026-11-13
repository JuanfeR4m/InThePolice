extends CharacterBody3D

enum Estado { QUIETO, CAMINAR, CORRER, RESOLVIENDO }
const RAPIDEZ = [0.0, 4.0, 7.0, 0.5]

@export var camara: Camera3D
@export var speed_caminar: float = 4.0
@export var speed_correr: float = 7.0
@export var tiempo_arranque: float = 0.25
@export var sufijo: String = ""
@export var color_uniforme: Color = Color(1, 1, 1)
@onready var anim = $Modelo/AnimationPlayer

var multiplicador: float = 1.0
var empuje = Vector3.ZERO
var accion = ""
var avance = Vector3.ZERO
var estado = Estado.QUIETO
var ruido = 0.0


func _ready():
	# El segundo jugador usa las acciones con sufijo "2" (move_left2, correr2, etc.)
	if name == "Personaje2":
		sufijo = "2"
	print(name, " sufijo = '", sufijo, "'")
	if camara == null:
		camara = get_viewport().get_camera_3d()
	if color_uniforme != Color(0.153, 1.0, 0.0, 1.0):
		aplicar_color(color_uniforme)


func aplicar_color(color: Color):
	for malla in find_children("*", "MeshInstance3D", true, false):
		for i in malla.get_surface_override_material_count():
			var mat = malla.get_active_material(i)
			if mat is StandardMaterial3D:
				var nuevo = mat.duplicate()
				nuevo.albedo_color = color
				malla.set_surface_override_material(i, nuevo)


func _physics_process(delta):
	velocity += get_gravity() * delta

	var input_dir = Input.get_vector("move_left" + sufijo, "move_right" + sufijo,
		"move_up" + sufijo, "move_down" + sufijo)
	var entrada = Vector3(input_dir.x, 0.0, input_dir.y)
	var giro_cam = camara.global_rotation.y
	var direction = entrada.rotated(Vector3.UP, giro_cam).normalized()

	var corre = Input.is_action_pressed("correr" + sufijo)
	var speed = speed_correr if corre else speed_caminar
	var objetivo = direction * speed * multiplicador
	var paso = speed / tiempo_arranque * delta

	avance = avance.move_toward(objetivo, paso)

	velocity.x = avance.x + empuje.x
	velocity.z = avance.z + empuje.z

	if direction.length() > 0:
		basis = Basis.looking_at(direction)

	move_and_slide()
	var antes = estado
	estado = elegir_estado()
	if estado == Estado.RESOLVIENDO:
		multiplicador = RAPIDEZ[estado] / speed
	else:
		multiplicador = 1.0
	if estado != antes:
		print(name, " estado ", Estado.keys()[estado], " · rapidez máxima ", RAPIDEZ[estado], " m/s")
	animar()


func elegir_estado():
	if Input.is_action_pressed("interactuar" + sufijo):
		return Estado.RESOLVIENDO
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	if rapidez > speed_caminar + 0.1:
		return Estado.CORRER
	return Estado.CAMINAR


func animar():
	if accion != "":
		anim.play(accion)
		return
	match estado:
		Estado.QUIETO:
			anim.play("idle")
		Estado.CAMINAR:
			anim.play("walk")
		Estado.RESOLVIENDO:
			anim.play("idle")
		Estado.CORRER:
			anim.play("sprint")
