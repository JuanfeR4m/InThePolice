extends Button

func _ready():
	pivot_offset = size / 2
	mouse_entered.connect(_al_entrar)
	mouse_exited.connect(_al_salir)
	focus_entered.connect(_al_entrar) 
	focus_exited.connect(_al_salir)

func _al_entrar():
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)

func _al_salir():
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)
