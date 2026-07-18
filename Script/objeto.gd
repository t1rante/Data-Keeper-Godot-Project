extends Sprite2D

var drag = false
var of = Vector2(75,1020)
var textin = ""
var chave_primaria = false
var id_objeto: String = ""
var tipo_objeto = ""
const SAVE_PATH = "user://savegame.json"


signal selecionado(no)

func _ready():
	id_objeto = "obj_" + str(get_instance_id())
	$TextEdit.editable = false
	$TextEdit.connect("text_changed", _on_texto_alterado)
	if has_node("BordaTracejada"):
		gerar_borda_eliptica(100, 60, 32)
		
	if has_node("BolinhaIndicadora"):
		var bolinha = $BolinhaIndicadora
		bolinha.connect("mouse_entered", _on_bolinha_mouse_entered)
		bolinha.connect("mouse_exited", _on_bolinha_mouse_exited)
		bolinha.connect("input_event", _on_bolinha_input_event)
		$BolinhaIndicadora/Sprite2D.visible = false

func _on_bolinha_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Bolinha clicada! Ativando chave primária.")
		alternar_chave_primaria()

func _on_bolinha_mouse_entered():
	$BolinhaIndicadora/Sprite2D.visible = true

func _on_bolinha_mouse_exited():
	if not chave_primaria:
		$BolinhaIndicadora/Sprite2D.visible = false

func atualizar_visual_pk(ativar: bool):
	chave_primaria = ativar
	
	if has_node("BordaTracejada"):
		$BordaTracejada.visible = ativar
		if ativar:
			$BordaTracejada.queue_redraw() 
		
	if has_node("BolinhaIndicadora/Sprite2D"):
		$BolinhaIndicadora/Sprite2D.visible = ativar

func alternar_chave_primaria():
	if chave_primaria:
		chave_primaria = false
		atualizar_visual_pk(false)
		save_game()
		print("Atributo não é mais PK.")
		return

	chave_primaria = true
	atualizar_visual_pk(true)
	save_game()
	
	var gerenciador = get_parent()
	if gerenciador.has_method("limpar_outras_pks"):
		gerenciador.limpar_outras_pks(id_objeto)

func gerar_borda_eliptica(raio_x: float, raio_y: float, num_pontos: int):
	var linha = $BordaTracejada
	linha.clear_points()
	
	for i in range(num_pontos):
		var angulo = i * (2.0 * PI / num_pontos)
		var x = cos(angulo) * raio_x
		var y = sin(angulo) * raio_y
		linha.add_point(Vector2(x, y))

func _on_texto_alterado():
	textin = $TextEdit.text

func _mouse_sobre():
	var mouse = get_global_mouse_position()
	var tamanho = texture.get_size() * scale
	var rect = Rect2(global_position - tamanho / 2, tamanho)
	return rect.has_point(mouse)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		if _mouse_sobre():  # só ativa se o mouse estiver em cima do objeto
			$TextEdit.editable = !$TextEdit.editable
			print("TextEdit Alterado ", $TextEdit.editable)
			_texto_salvo()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.is_key_pressed(KEY_SHIFT) and _mouse_sobre():
			emit_signal("selecionado", self)

func _process(_delta):
	if drag:
		position = get_global_mouse_position() - of

func _on_button_button_down():
	if Input.is_key_pressed(KEY_SHIFT):
		return
	if Input.is_key_pressed(KEY_SPACE):
		return
	drag = true
	of = get_global_mouse_position() - global_position

func _on_button_button_up():
	drag = false

func _texto_salvo():
	if $TextEdit.editable != true:
		print("Texto Salvo: ", textin)
		save_game()

func save_game():
	var dados_atuais = {
		"entidades": {},
		"atributos": {},
		"relacionamentos": {},
		"conexoes": {}
	}
	
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_aux = JSON.parse_string(file.get_as_text())
		if json_aux and json_aux is Dictionary:
			dados_atuais = json_aux

	if not dados_atuais.has("entidades"): dados_atuais["entidades"] = {}
	if not dados_atuais.has("atributos"): dados_atuais["atributos"] = {}
	if not dados_atuais.has("relacionamentos"): dados_atuais["relacionamentos"] = {}
	if not dados_atuais.has("conexoes"): dados_atuais["conexoes"] = {}

	if tipo_objeto != "" and dados_atuais.has(tipo_objeto):
		
		var dados_objeto = {
			"nome": textin,
			"posicao": {"x": global_position.x, "y": global_position.y}
		}
		if tipo_objeto == "entidades" or tipo_objeto == "atributos":
			dados_objeto["cp"] = chave_primaria

		dados_atuais[tipo_objeto][id_objeto] = dados_objeto

		var file_write = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file_write:
			file_write.store_string(JSON.stringify(dados_atuais, "\t"))
			file_write.close()
			print("Sucesso! Salvo em: ", tipo_objeto, " | ID: ", id_objeto)
