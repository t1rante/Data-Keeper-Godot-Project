extends Control
## Banco de palavras do problema (menu lateral "Palavras" do quadro). O jogador
## não digita nomes: arrasta uma destas palavras até um bloco.
##
## As palavras vêm de fases/<fase>/palavras.json (formato e dicas em
## fases/COMO_CRIAR_BANCOS_DE_PALAVRAS.md). Sem esse arquivo, o banco usa os
## nomes que o gabarito exige, sem distratores, e avisa no console.
##
## O banco cuida só das fichas e do arrasto. Quem acha o bloco embaixo do mouse
## e dá o nome é o quadro (quadro.gd), pelos sinais abaixo; as posições
## são da tela (as mesmas dos eventos de mouse).

## Uma palavra está sendo arrastada.
signal palavra_arrastada(palavra: String, posicao: Vector2)
## O jogador soltou a palavra.
signal palavra_solta(palavra: String, posicao: Vector2)

const Verificador = preload("res://Script/correcao/verificador.gd")

## Quanto o mouse precisa andar, com o botão apertado, para virar arrasto.
const LIMIAR_DE_ARRASTO := 4.0
const COR_DO_PAPEL := Color(1.0, 0.973, 0.855)
const COR_DO_PAPEL_EM_CIMA := Color(1.0, 1.0, 0.95)
const COR_DA_DOBRA := Color(0.839, 0.776, 0.588)
const COR_DO_TEXTO := Color(0.16, 0.14, 0.1)
const COR_DE_USADA := Color(0.36, 1.0, 0.945)  # ciano do post-it de entidade
const TAMANHO_DA_FONTE := 14

## [{"texto", "usos"}]; usos 0 = sem limite.
var palavras := []

var _fantasma: PanelContainer


## Listas do arquivo que viram fichas (no jogo elas aparecem misturadas).
const LISTAS := ["palavras", "extras", "distratores"]


## Lê um banco de palavras. Devolve {"palavras": [{"texto", "usos"}]} ou {"erro"}.
## As listas do arquivo vêm juntas, na ordem pedida em "ordem".
static func ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {"erro": "Banco de palavras não encontrado: " + caminho}
	var banco = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not banco is Dictionary:
		return {"erro": "O banco de palavras não é um JSON válido: " + caminho}
	var lidas := []
	var vistas := {}
	for lista in LISTAS:
		var entradas = banco.get(lista, [])
		for entrada in (entradas if entradas is Array else []):
			var texto := str(entrada.get("texto", "") if entrada is Dictionary else entrada).strip_edges()
			if texto == "" or vistas.has(texto):
				continue
			vistas[texto] = true
			lidas.append({"texto": texto, "usos": int(entrada.get("usos", 0)) if entrada is Dictionary else 0})
	if lidas.is_empty():
		return {"erro": "O banco de palavras não tem nenhuma palavra: " + caminho}
	match str(banco.get("ordem", "alfabetica")):
		"arquivo":
			pass
		"embaralhada":
			lidas.shuffle()
		_:
			lidas.sort_custom(_em_ordem_alfabetica)
	return {"palavras": lidas}


## Ordem do dicionário: "área" fica junto do "a", não depois do "z".
static func _em_ordem_alfabetica(a: Dictionary, b: Dictionary) -> bool:
	return _sem_acento(a.texto) < _sem_acento(b.texto)


static func _sem_acento(texto: String) -> String:
	var resultado := texto.to_lower()
	for trocas in [["áàâãä", "a"], ["éèêë", "e"], ["íìîï", "i"], ["óòôõö", "o"], ["úùûü", "u"], ["ç", "c"]]:
		for letra in trocas[0]:
			resultado = resultado.replace(letra, trocas[1])
	return resultado


## Carrega o banco do problema e monta as fichas.
func carregar(caminho_do_banco: String, caminho_do_gabarito: String) -> void:
	var banco := ler(caminho_do_banco)
	if banco.has("erro"):
		push_warning(banco.erro + " Usando os nomes do gabarito, sem distratores.")
		var gabarito = JSON.parse_string(FileAccess.get_file_as_string(caminho_do_gabarito)) \
				if FileAccess.file_exists(caminho_do_gabarito) else null
		var nomes := Verificador.nomes_exigidos(gabarito if gabarito is Dictionary else {})
		banco = {"palavras": nomes.map(func(n): return {"texto": n.nome, "usos": 0})}
		banco.palavras.sort_custom(_em_ordem_alfabetica)
	palavras = banco.palavras
	_montar_fichas()


## Marca as palavras já usadas no quadro (`nomes`: o nome de cada bloco). Palavra
## com limite de usos esgotado fica apagada e não arrasta.
func atualizar_usos(nomes: Array) -> void:
	for ficha in %Fichas.get_children():
		ficha.usos = nomes.count(ficha.texto)


func _montar_fichas() -> void:
	for ficha in %Fichas.get_children():
		ficha.queue_free()
	for palavra in palavras:
		var ficha := Ficha.new(palavra.texto, palavra.usos)
		ficha.arrastando.connect(_ao_arrastar)
		ficha.solta.connect(_ao_soltar)
		%Fichas.add_child(ficha)


func _ao_arrastar(ficha: Ficha, posicao: Vector2) -> void:
	if _fantasma == null:
		_fantasma = Ficha.visual(ficha.texto, COR_DO_PAPEL_EM_CIMA)
		_fantasma.top_level = true  # posição na tela, fora do painel
		_fantasma.z_index = 100
		_fantasma.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fantasma.rotation_degrees = -4.0
		add_child(_fantasma)
	_fantasma.reset_size()
	_fantasma.global_position = posicao - Vector2(_fantasma.size.x / 2, _fantasma.size.y + 6)
	palavra_arrastada.emit(ficha.texto, posicao)


func _ao_soltar(ficha: Ficha, posicao: Vector2) -> void:
	if _fantasma:
		_fantasma.queue_free()
		_fantasma = null
	palavra_solta.emit(ficha.texto, posicao)


## Uma palavra do banco: papel pequeno que o jogador arrasta.
class Ficha extends PanelContainer:
	signal arrastando(ficha: Ficha, posicao: Vector2)
	signal solta(ficha: Ficha, posicao: Vector2)

	var texto := ""
	var limite := 0
	var usos := 0:
		set(valor):
			usos = valor
			_atualizar()

	var _apertada := false
	var _arrastando := false
	var _inicio := Vector2.ZERO
	var _mouse_em_cima := false

	func _init(palavra: String, limite_de_usos: int):
		texto = palavra
		limite = limite_de_usos
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		tooltip_text = "Arraste até um bloco do quadro"
		add_child(_rotulo(palavra))
		mouse_entered.connect(_ao_entrar_o_mouse.bind(true))
		mouse_exited.connect(_ao_entrar_o_mouse.bind(false))
		_atualizar()

	## Papel com a palavra (também usado na ficha que segue o mouse).
	static func visual(palavra: String, cor: Color) -> PanelContainer:
		var papel := PanelContainer.new()
		papel.add_theme_stylebox_override("panel", _estilo(cor, false))
		papel.add_child(_rotulo(palavra))
		return papel

	static func _rotulo(palavra: String) -> Label:
		var rotulo := Label.new()
		rotulo.text = palavra
		rotulo.add_theme_color_override("font_color", COR_DO_TEXTO)
		rotulo.add_theme_font_size_override("font_size", TAMANHO_DA_FONTE)
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rotulo

	## Papel de canto reto (pixel art) com a dobra embaixo. Palavra já usada no
	## quadro ganha a dobra e uma faixa à esquerda em ciano.
	static func _estilo(cor: Color, usada: bool) -> StyleBoxFlat:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = cor
		estilo.border_color = COR_DE_USADA if usada else COR_DA_DOBRA
		estilo.border_width_bottom = 3
		estilo.border_width_left = 4 if usada else 0
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 3
		estilo.content_margin_bottom = 4
		return estilo

	func esgotada() -> bool:
		return limite > 0 and usos >= limite

	func _ao_entrar_o_mouse(dentro: bool) -> void:
		_mouse_em_cima = dentro
		_atualizar()

	func _atualizar() -> void:
		var cor := COR_DO_PAPEL_EM_CIMA if _mouse_em_cima and not esgotada() else COR_DO_PAPEL
		add_theme_stylebox_override("panel", _estilo(cor, usos > 0))
		modulate.a = 0.4 if esgotada() else 1.0
		mouse_default_cursor_shape = Control.CURSOR_ARROW if esgotada() else Control.CURSOR_DRAG
		if usos > 0:
			tooltip_text = "No quadro %d vez(es). Arraste até um bloco do quadro" % usos
		else:
			tooltip_text = "Arraste até um bloco do quadro"

	func _gui_input(event: InputEvent) -> void:
		# Depois de apertar, o Godot manda o mouse para esta ficha até soltar,
		# mesmo fora dela: dá para seguir o arrasto pelo quadro inteiro.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not esgotada():
				_apertada = true
				_arrastando = false
				_inicio = event.global_position
				accept_event()
			elif not event.pressed and _apertada:
				_apertada = false
				if _arrastando:
					_arrastando = false
					solta.emit(self, event.global_position)
				accept_event()
		elif event is InputEventMouseMotion and _apertada:
			if not _arrastando and event.global_position.distance_to(_inicio) > LIMIAR_DE_ARRASTO:
				_arrastando = true
			if _arrastando:
				arrastando.emit(self, event.global_position)
			accept_event()
