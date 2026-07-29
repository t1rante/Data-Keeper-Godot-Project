extends Line2D

var target1: Node2D = null
var target2: Node2D = null
var drag = false
var cor = Color.RED

func definir_alvos(a: Node2D, b: Node2D):
	target1 = a
	target2 = b
	points = [Vector2.ZERO, Vector2.ZERO]

func _process(_delta):
	if is_instance_valid(target1) and is_instance_valid(target2):
		points[0] = to_local(target1.global_position)
		points[1] = to_local(target2.global_position)

func _mouse_perto_da_linha():
	if points.size() < 2:
		return false
	var mouse = get_local_mouse_position()
	var a = points[0]
	var b = points[1]
	var ab = b - a
	var am = mouse - a
	var t = clamp(am.dot(ab) / ab.dot(ab), 0.0, 1.0)
	var ponto_mais_proximo = a + t * ab
	return mouse.distance_to(ponto_mais_proximo) < 10.0

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _mouse_perto_da_linha() and not Input.is_key_pressed(KEY_SHIFT):
			modulate = cor
		
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if _mouse_perto_da_linha() and not modulate != cor:
			queue_free()
			
			
func salvar_conexao():
	if not is_instance_valid(target1) or not is_instance_valid(target2):
		return

	var dados_atuais = {}
	if FileAccess.file_exists("user://savegame.json"):
		var file = FileAccess.open("user://savegame.json", FileAccess.READ)
		dados_atuais = JSON.parse_string(file.get_as_text())
		file.close()

	if not dados_atuais.has("conexoes"):
		dados_atuais["conexoes"]=[]

	var nova_con_dados = {
		"de": target1.id_objeto,
		"para": target2.id_objeto
	}

	if not nova_con_dados in dados_atuais["conexoes"]:
		dados_atuais["conexoes"].append(nova_con_dados)

	var file_w = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file_w.store_string(JSON.stringify(dados_atuais, "\t"))
	file_w.close()
