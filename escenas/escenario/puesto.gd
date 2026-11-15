extends StaticBody3D

@export var color_toldo: Color = Color("F2B632"):
	set(valor):
		color_toldo = valor
		_aplicar_color()


func _ready() -> void:
	_aplicar_color()


func _aplicar_color() -> void:
	if not has_node("Toldo"):
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = color_toldo
	$Toldo.material_override = m
