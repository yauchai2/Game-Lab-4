extends Control

const RENDER_SIZE := Vector2i(960, 540)
const CAMPFIRE := preload("res://diorama/CampfireDiorama.tscn")

@onready var canvas: SubViewportContainer = $PixelCanvas
@onready var world: SubViewport = $PixelCanvas/World

func _ready() -> void:
	world.size = RENDER_SIZE
	var lakeside := CAMPFIRE.instantiate()
	lakeside.hud_parent = self
	world.add_child(lakeside)
	resized.connect(_place_canvas)
	_place_canvas()

func _place_canvas() -> void:
	var fit := minf(size.x / RENDER_SIZE.x, size.y / RENDER_SIZE.y)
	canvas.size = Vector2(RENDER_SIZE)
	canvas.scale = Vector2.ONE * fit
	canvas.position = ((size - Vector2(RENDER_SIZE) * fit) * 0.5).round()
