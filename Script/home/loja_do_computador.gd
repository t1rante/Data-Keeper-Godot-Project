extends CanvasLayer
## Loja do computador de casa (Cenas/home/loja_do_computador.tscn): skins,
## móveis e decoração do catálogo (dados/catalogo.json), pagos com o dinheiro
## do trabalho. Comprar já equipa; móveis e decoração podem ser guardados; skin
## sempre tem uma em uso. As regras ficam em jogo.gd; aqui só a tela.
## A prévia da skin é o próprio sprite da caminhada com as cores dela (skins.gd);
## móveis e decoração ainda não têm arte: a prévia é a cor do item.
## Esc ou X fecham.

signal fechou

const Jogo = preload("res://Script/jogo/jogo.gd")
const Catalogo = preload("res://Script/jogo/catalogo.gd")
const PixelArt = preload("res://Script/home/pixel_art.gd")
const Skins = preload("res://Script/jogo/skins.gd")

const COR_DO_CARTAO := Color(0.16, 0.12, 0.36, 1)
const COR_DO_TEXTO := Color(0.91, 0.93, 1, 1)
const FONTE := preload("res://assets/04b_19/04B_19__.TTF")

var tipo := "skin"


func _ready() -> void:
	%Fechar.pressed.connect(fechar)
	for aba in %Abas.get_children():
		aba.pressed.connect(mostrar_tipo.bind(str(aba.name).to_lower()))
	mostrar_tipo(tipo)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fechar()


func fechar() -> void:
	fechou.emit()
	queue_free()


func mostrar_tipo(novo_tipo: String) -> void:
	tipo = novo_tipo
	for aba in %Abas.get_children():
		aba.button_pressed = str(aba.name).to_lower() == tipo
	_montar()


## Compra, usa ou guarda o item do cartão.
func agir(id: String) -> void:
	var item := Catalogo.item(id)
	if not Jogo.tem(id):
		var erro := Jogo.comprar(id)
		%Aviso.text = erro if erro != "" else "Comprou %s por %s." % [item.nome, Jogo.reais(int(round(item.preco * 100)))]
	elif Jogo.equipado(id):
		Jogo.guardar(id)
		%Aviso.text = "%s guardado." % item.nome
	else:
		Jogo.equipar(id)
		%Aviso.text = "%s em uso." % item.nome
	_montar()


func _montar() -> void:
	%Saldo.text = Jogo.reais(Jogo.centavos)
	for cartao in %Grade.get_children():
		cartao.queue_free()
	for item in Catalogo.do_tipo(tipo):
		%Grade.add_child(_cartao(item))


func _cartao(item: Dictionary) -> PanelContainer:
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_DO_CARTAO
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(10)
	if Jogo.equipado(item.id):
		estilo.border_color = Color("5cfff1")
		estilo.set_border_width_all(3)
	cartao.add_theme_stylebox_override("panel", estilo)
	cartao.custom_minimum_size = Vector2(272, 150)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	cartao.add_child(linha)
	linha.add_child(_previa(item))

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 4)
	linha.add_child(coluna)
	coluna.add_child(_rotulo(item.nome, 15, Color.WHITE))
	var descricao := _rotulo(str(item.get("descricao", "")), 12, Color(COR_DO_TEXTO, 0.75))
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(descricao)
	var preco := int(round(item.preco * 100))
	coluna.add_child(_rotulo("de graça" if preco == 0 else Jogo.reais(preco), 15, Color("5cfff1")))

	var botao := Button.new()
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.add_theme_font_override("font", FONTE)
	botao.add_theme_font_size_override("font_size", 16)
	botao.add_theme_color_override("font_color", Color(0.4862745, 0.60784316, 1))
	botao.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	botao.add_theme_color_override("font_disabled_color", Color(0.4862745, 0.60784316, 1, 0.35))
	for estado in [["normal", Color(0.24, 0.19, 0.5)], ["hover", Color(0.3150174, 0.44430792, 1)],
			["pressed", Color(0.2, 0.3, 0.8)], ["disabled", Color(0.24, 0.19, 0.5, 0.45)]]:
		var fundo := StyleBoxFlat.new()
		fundo.bg_color = estado[1]
		fundo.set_corner_radius_all(8)
		fundo.content_margin_top = 6
		fundo.content_margin_bottom = 4
		botao.add_theme_stylebox_override(estado[0], fundo)
	if not Jogo.tem(item.id):
		botao.text = "COMPRAR"
		botao.disabled = preco > Jogo.centavos
		botao.tooltip_text = "Falta %s" % Jogo.reais(preco - Jogo.centavos) if botao.disabled else "Comprar e usar"
	elif Jogo.equipado(item.id):
		botao.text = "EM USO" if item.tipo == "skin" else "GUARDAR"
		botao.disabled = item.tipo == "skin"
	else:
		botao.text = "USAR"
	botao.pressed.connect(agir.bind(item.id))
	coluna.add_child(botao)
	return cartao


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


func _previa(item: Dictionary) -> Control:
	if item.tipo == "skin":
		var sprite := TextureRect.new()
		sprite.texture = Skins.quadro_de_frente()
		sprite.material = Skins.material(item.id)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.custom_minimum_size = Vector2(96, 96)  # 3x o quadro de 32 px: pixel nítido
		return sprite
	var previa := Control.new()
	previa.custom_minimum_size = Vector2(64, 96)
	previa.draw.connect(_desenhar_previa.bind(previa, item))
	return previa


func _desenhar_previa(previa: Control, item: Dictionary) -> void:
	var cor := Color(item.get("cor", "#b07cff"))
	var caixa := Rect2(4, 20, 56, 56)
	previa.draw_rect(caixa, cor)
	previa.draw_rect(Rect2(caixa.position.x, caixa.end.y - 6, caixa.size.x, 6), cor.darkened(0.3))
	previa.draw_rect(caixa, PixelArt.TINTA, false, 3.0)
