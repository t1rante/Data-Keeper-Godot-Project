extends Control
## Tela Home (Cenas/home/home.tscn): o protagonista em casa. É onde o dia
## começa e termina.
##   computador ... loja de móveis, decoração e skins (loja_do_computador.gd)
##   Isha ......... a gatinha: carinho
##   porta ........ IR TRABALHAR (manhã): caminhada -> cliente -> quadro
##   cama ......... dormir (noite, ou quando não há mais clientes)
##   MENU / Esc ... menu de opções (salvar, sair)
##
## A arte da casa ainda não está pronta: o quarto é Sprites/Fundo/Casa_dentro.png
## (da caminhada), o protagonista é o sprite da caminhada vestido com a skin
## (skins.gd), a Isha tem sprite provisório (Sprites/Personagens/isha.png) e o
## computador e os itens comprados são desenhados em código (pixel_art.gd).

const Jogo = preload("res://Script/jogo/jogo.gd")
const Fases = preload("res://Script/jogo/fases.gd")
const Fluxo = preload("res://Script/jogo/fluxo.gd")
const Catalogo = preload("res://Script/jogo/catalogo.gd")
const PixelArt = preload("res://Script/home/pixel_art.gd")
const Skins = preload("res://Script/jogo/skins.gd")
const Sons = preload("res://Script/jogo/sons.gd")
const LOJA = preload("res://Cenas/home/loja_do_computador.tscn")
const MENU_DE_OPCOES = preload("res://Cenas/ui/menu_de_opcoes.tscn")

const COR_DO_DESTAQUE := Color(1.0, 0.84, 0.0)
## Onde fica cada coisa no quarto (coordenadas da tela, sobre Casa_dentro.png x3).
const LUGARES := {
	"parede": Rect2(655, 105, 80, 100),
	"canto": Rect2(650, 292, 56, 96),
	"estante": Rect2(28, 396, 112, 150),
	"sala": Rect2(170, 492, 220, 72),
	"centro": Rect2(420, 404, 104, 44),
	"chao": Rect2(215, 345, 400, 135),
	"gato": Rect2(262, 450, 136, 26),
}
const RETANGULO_DO_COMPUTADOR := Rect2(132, 172, 104, 90)
const DURACAO_DA_DICA := 4.0
## Quanto tempo a Isha fica de olhos fechados depois do carinho.
const DURACAO_DO_RONRONAR := 1.6

var _destaque := Rect2()
var _coracoes := []  # {"posicao", "vida"}
var _tempo_da_dica := 0.0
var _tempo_do_ronronar := 0.0


func _ready() -> void:
	%Desenhos.draw.connect(_desenhar)
	%Efeitos.draw.connect(_desenhar_efeitos)
	for par in [[%Computador, "Computador: comprar móveis, decoração e skins"],
			[%Gato, "Isha, a gatinha: clique para fazer carinho"],
			[%Cama, "Cama: dormir até o dia seguinte"]]:
		par[0].mouse_entered.connect(_ao_passar.bind(par[0], par[1]))
		par[0].mouse_exited.connect(_ao_sair.bind(par[0]))
	%Computador.pressed.connect(abrir_loja)
	%Gato.pressed.connect(fazer_carinho)
	%Cama.pressed.connect(dormir)
	%Porta.pressed.connect(ir_trabalhar)
	%Menu.pressed.connect(abrir_opcoes)
	atualizar()
	_mostrar_o_dia()


func _process(delta: float) -> void:
	if not _coracoes.is_empty():
		for coracao in _coracoes:
			coracao.posicao.y -= 40.0 * delta
			coracao.vida -= delta
		_coracoes = _coracoes.filter(func(c): return c.vida > 0.0)
		%Efeitos.queue_redraw()
	if _tempo_do_ronronar > 0.0:
		_tempo_do_ronronar -= delta
		%Isha.frame = 1 if _tempo_do_ronronar > 0.0 else 0  # olhos fechados
	if _tempo_da_dica > 0.0:
		_tempo_da_dica -= delta
		if _tempo_da_dica <= 0.0:
			%Dica.text = _dica_do_momento()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		abrir_opcoes()


## Redesenha o quarto e o topo com o estado do jogo (depois de comprar, por exemplo).
func atualizar() -> void:
	%Dia.text = "DIA %d" % Jogo.dia
	%Momento.text = "MANHÃ" if Jogo.momento == Jogo.MANHA else "NOITE"
	%Dinheiro.text = Jogo.reais(Jogo.centavos)
	Skins.aplicar(%Protagonista)
	%Noite.visible = Jogo.momento == Jogo.NOITE
	%Porta.disabled = not Jogo.pode_trabalhar()
	%Porta.tooltip_text = "Ir trabalhar: o cliente do dia espera" if Jogo.pode_trabalhar() else _dica_do_momento()
	if _tempo_da_dica <= 0.0:
		%Dica.text = _dica_do_momento()
	%Desenhos.queue_redraw()
	%Efeitos.queue_redraw()


func _dica_do_momento() -> String:
	var fase := Jogo.fase_do_dia()
	if Jogo.momento == Jogo.NOITE:
		var hoje := ""
		for id in Jogo.fases_feitas:
			if int(Jogo.fases_feitas[id].get("dia", 0)) == Jogo.dia:
				hoje = " Hoje você recebeu %s." % Jogo.reais(int(Jogo.fases_feitas[id].pago))
		return "Dia de trabalho concluído.%s Hora de descansar: clique na cama." % hoje
	if fase == "":
		return "Nenhum cliente novo por enquanto. Aproveite a casa ou durma até amanhã."
	return "Hoje %s precisa de um banco de dados. Vá trabalhar pela porta." % Fases.dados(fase).cliente


func _dizer(texto: String) -> void:
	%Dica.text = texto
	_tempo_da_dica = DURACAO_DA_DICA


# --- Ações --------------------------------------------------------------------

func abrir_loja() -> void:
	if has_node("Loja"):
		return
	var loja := LOJA.instantiate()
	loja.name = "Loja"
	loja.fechou.connect(atualizar)
	add_child(loja)


## Carinho na Isha: ela mia (um miado sorteado; o botão dela não faz o tlin, tem
## metadata sem_som na cena), fecha os olhos e sobem corações.
func fazer_carinho() -> void:
	var primeiro := Jogo.fazer_carinho()
	Sons.tocar_miado()
	_tempo_do_ronronar = DURACAO_DO_RONRONAR
	var cabeca: Vector2 = %Isha.position + Vector2(32, -42)
	for i in 3:
		_coracoes.append({"posicao": cabeca + Vector2(randf_range(-26, 18), randf_range(-6, 6)), "vida": 1.2 + i * 0.25})
	_dizer("Rrrrr... a Isha ficou feliz!" if primeiro else "A Isha adora carinho. (%d carinhos até hoje)" % Jogo.carinhos)


func dormir() -> void:
	if not Jogo.pode_dormir():
		_dizer("Ainda é de manhã: o cliente de hoje está esperando. Vá trabalhar pela porta.")
		return
	%Cama.disabled = true
	var cortina := create_tween()
	cortina.tween_property(%Cortina, "color:a", 1.0, 0.7)
	cortina.tween_callback(func(): Fluxo.dormir())


func ir_trabalhar() -> void:
	if Jogo.pode_trabalhar():
		Fluxo.ir_trabalhar()


func abrir_opcoes() -> void:
	if has_node("Loja") or has_node("MenuDeOpcoes"):
		return
	var menu := MENU_DE_OPCOES.instantiate()
	menu.name = "MenuDeOpcoes"
	menu.lugar_do_save = "home"
	add_child(menu)


## Onde o save do menu de opções retoma o jogo.
func lugar_do_save() -> String:
	return "home"


func _mostrar_o_dia() -> void:
	%Anuncio.texto = "DIA %d" % Jogo.dia
	%Anuncio.position = (size - %Anuncio.size) / 2  # o tamanho vem do texto
	%Anuncio.visible = Jogo.momento == Jogo.MANHA
	%Cortina.color.a = 1.0
	var entrada := create_tween()
	entrada.tween_property(%Cortina, "color:a", 0.0, 0.6)
	if %Anuncio.visible:
		entrada.tween_interval(0.9)
		entrada.tween_property(%Anuncio, "modulate:a", 0.0, 0.5)
		entrada.tween_callback(func(): %Anuncio.visible = false)


func _ao_passar(alvo: Control, dica: String) -> void:
	_destaque = Rect2(alvo.position, alvo.size)
	%Efeitos.queue_redraw()
	if _tempo_da_dica <= 0.0:
		%Dica.text = dica


func _ao_sair(alvo: Control) -> void:
	if _destaque == Rect2(alvo.position, alvo.size):
		_destaque = Rect2()
		%Efeitos.queue_redraw()
	if _tempo_da_dica <= 0.0:
		%Dica.text = _dica_do_momento()


# --- Desenho provisório -------------------------------------------------------

func _desenhar() -> void:
	var tela: Control = %Desenhos
	# Itens comprados, cada um no seu lugar (o tapete por baixo de tudo).
	for lugar in ["chao", "parede", "canto", "estante", "sala", "centro", "gato"]:
		var id: String = Jogo.equipados.get(lugar, "")
		if id != "" and not Catalogo.item(id).is_empty():
			_desenhar_item(tela, Catalogo.item(id), LUGARES[lugar])
	PixelArt.desenhar_computador(tela, RETANGULO_DO_COMPUTADOR, true)


## Por cima da noite: corações do carinho e o destaque do que está sob o mouse.
func _desenhar_efeitos() -> void:
	var tela: Control = %Efeitos
	for coracao in _coracoes:
		var transparencia := clampf(coracao.vida, 0.0, 1.0)
		var paleta := {}
		for letra in PixelArt.PALETA_DO_CORACAO:
			paleta[letra] = Color(PixelArt.PALETA_DO_CORACAO[letra], transparencia)
		PixelArt.desenhar(tela, PixelArt.CORACAO, paleta, coracao.posicao, 4.0)
	if _destaque.has_area():
		tela.draw_rect(_destaque.grow(4), COR_DO_DESTAQUE, false, 3.0)


## Item comprado sem arte ainda: caixa na cor dele com o nome escrito.
func _desenhar_item(tela: Control, item: Dictionary, onde: Rect2) -> void:
	var cor := Color(item.get("cor", "#b07cff"))
	if item.lugar == "chao":
		# Tapete xadrez por cima do tapete do quarto.
		var lado := 15.0
		for y in int(onde.size.y / lado):
			for x in int(onde.size.x / lado):
				if (x + y) % 2 == 0:
					tela.draw_rect(Rect2(onde.position + Vector2(x, y) * lado, Vector2(lado, lado)), Color(cor, 0.55))
		return
	tela.draw_rect(onde, cor)
	tela.draw_rect(Rect2(onde.position.x, onde.end.y - 6, onde.size.x, 6), cor.darkened(0.3))
	tela.draw_rect(onde, PixelArt.TINTA, false, 3.0)
	var fonte := ThemeDB.fallback_font
	tela.draw_multiline_string(fonte, onde.position + Vector2(4, 15), item.nome, HORIZONTAL_ALIGNMENT_CENTER,
			onde.size.x - 8, 11, -1, PixelArt.TINTA)
