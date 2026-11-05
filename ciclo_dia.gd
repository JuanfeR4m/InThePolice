class_name CicloDia
extends Node

const NARANJA := Color(1.0, 0.55, 0.3)
const HORAS_DIA := 24.0
const HORA_AMANECER := 6.0
const GRADOS_POR_HORA := 15.0

@export var hora := 9.0
@export var duracion_dia := 266.7
@export var pausado := false

func avanzar(dt: float) -> void:
	if not pausado:
		hora = fposmod(hora + HORAS_DIA * dt / duracion_dia, HORAS_DIA)

static func elevacion(h: float) -> float:
	return (h - HORA_AMANECER) * GRADOS_POR_HORA

static func factor_sol(h: float) -> float:
	return maxf(0.0, sin(deg_to_rad(elevacion(h))))

static func color_sol(h: float) -> Color:
	return NARANJA.lerp(Color.WHITE, factor_sol(h))
	
