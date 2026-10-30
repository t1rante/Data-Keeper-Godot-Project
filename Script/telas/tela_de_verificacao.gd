extends CanvasLayer
## Tela de verificação (Cenas/telas/tela_de_verificacao.tscn): cobre o quadro quando
## o jogador aperta Verificar e mostra a nota, cada parte do diagrama e por que
## não foi 100%. O quadro continua embaixo, intacto, para quando ele voltar.
##
## Visual do menu inicial (Cenas/telas/title_screen.tscn): fundo azul, botões
## azul-marinho com a fonte 04B_19, títulos no estilo do logo (texto_adesivo.gd)
## e as cores dos post-its. A fonte 04B_19 não tem acentos e a Pixeled não tem
## todos; o texto corrido usa a fonte padrão.
##
## Uso (quadro.gd): instanciar, add_child e chamar mostrar() com o
## resultado de verificador.gd e o pagamento que o cliente faria por ele.
## ENTREGAR termina a fase (o cliente paga pela nota); VOLTAR AO QUADRO deixa
## o jogador melhorar o diagrama antes.
##
## Na dificuldade desafio (configurações), a tela mostra a nota, as partes do
## diagrama e o pagamento, mas não a lista do que faltou nem as observações.

signal voltar
signal entregar

const Verificador = preload("res://Script/correcao/verificador.gd")
const Configuracoes = preload("res://Script/jogo/configuracoes.gd")

const AZUL_DO_FUNDO := Color("7c9bff")
const AZUL_DA_FAIXA := Color("6c8cf6")
const MARINHO := Color("110730")
const CIANO := Color("5cfff1")
const ROSA := Color("ff74d7")
const AMARELO := Color("ffd84d")
const TEXTO_CLARO := Color("e9edff")
const DURACAO_DA_NOTA := 0.9
## Partes que só têm penalidade (não têm pontos a ganhar).
const SO_PENALIDADE := ["Itens a mais", "Notação"]

var _barras := []


func _ready():
	%Fundo.draw.connect(_desenhar_faixas)
	%Voltar.pressed.connect(voltar.emit)
	%Entregar.pressed.connect(entregar.emit)


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		voltar.emit()


func mostrar(resultado: Dictionary, pagamento := "") -> void:
	%Pagamento.text = ("Entregando agora, você recebe %s" % pagamento) if pagamento != "" else ""
	if resultado.has("erro"):
		%Problema.text = "Não deu para corrigir"
		%Veredito.text = ""
		%Pontos.text = ""
		%Cabecalho.text = "ERRO NO GABARITO"
		%Explicacao.text = _escapar(str(resultado.erro))
		%Nota.texto = "?"
		return

	var nota: float = resultado.porcentagem
	%Problema.text = _nome_do_problema(str(resultado.modelo))
	if resultado.alternativa > 0:
		%Problema.text += "  (resposta alternativa)"
	%Veredito.text = _veredito(nota)
	%Pontos.text = "%s de %s pontos" % [Verificador.formatar_numero(resultado.obtido), Verificador.formatar_numero(resultado.total)]
	if resultado.penalidade > 0.0:
		%Pontos.text += "  ·  %s de penalidade" % Verificador.formatar_numero(resultado.penalidade)
	_montar_partes(resultado.categorias)
	_montar_explicacao(resultado, nota)
	if nota >= 99.95:
		%Entregar.add_theme_stylebox_override("normal", %Entregar.get_theme_stylebox("hover"))
		%Entregar.add_theme_color_override("font_color", Color.WHITE)

	# A nota sobe de 0 até o valor; as barras enchem uma depois da outra.
	var animacao := create_tween()
	animacao.tween_method(func(valor: float): %Nota.texto = Verificador.formatar_numero(valor) + "%",
			0.0, nota, DURACAO_DA_NOTA).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var atraso := 0.15
	for barra in _barras:
		barra.encher(atraso)
		atraso += 0.08


## "Modelo Entidade-Relacionamento - Loja de Roupas" -> "Loja de Roupas".
static func _nome_do_problema(modelo: String) -> String:
	var partes := modelo.split(" - ", false, 1)
	return partes[1] if partes.size() > 1 else modelo


static func _veredito(nota: float) -> String:
	if nota >= 99.95:
		return "DIAGRAMA PERFEITO!"
	if nota >= 85.0:
		return "QUASE LÁ!"
	if nota >= 60.0:
		return "BOM CAMINHO, FALTAM AJUSTES"
	return "AINDA FALTA BASTANTE"


func _montar_partes(categorias: Dictionary) -> void:
	for filho in %Partes.get_children():
		filho.queue_free()
	_barras.clear()
	for categoria in Verificador.CATEGORIAS:
		if not categorias.has(categoria):
			continue
		var placar: Dictionary = categorias[categoria]
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)

		var nome := Label.new()
		nome.text = categoria
		nome.custom_minimum_size.x = 140
		nome.add_theme_color_override("font_color", MARINHO)
		nome.add_theme_font_size_override("font_size", 15)
		linha.add_child(nome)

		var barra := Barra.new()
		_barras.append(barra)
		var valor := Label.new()
		valor.add_theme_font_size_override("font_size", 15)
		valor.add_theme_color_override("font_color", MARINHO)
		if categoria in SO_PENALIDADE or placar.total <= 0.0:
			barra.penalidade = placar.penalidade
			valor.text = "−%s" % Verificador.formatar_numero(placar.penalidade)
		else:
			barra.fracao = placar.obtido / placar.total
			valor.text = "%s de %s" % [Verificador.formatar_numero(placar.obtido), Verificador.formatar_numero(placar.total)]
			if placar.penalidade > 0.0:
				valor.text += "  −%s" % Verificador.formatar_numero(placar.penalidade)
		linha.add_child(barra)
		linha.add_child(valor)
		%Partes.add_child(linha)


func _montar_explicacao(resultado: Dictionary, nota: float) -> void:
	var linhas := PackedStringArray()
	if nota >= 99.95:
		%Cabecalho.text = "TUDO CERTO!"
		%Cabecalho.add_theme_color_override("font_color", CIANO)
		linhas.append("Nenhum ponto perdido: o diagrama bate com o que o cliente pediu.")
	elif Configuracoes.desafio():
		%Cabecalho.text = "MODO DESAFIO"
		%Explicacao.text = ("No desafio, a correção não diz o que faltou: as barras à esquerda mostram em que partes "
				+ "do diagrama você perdeu pontos.\n\nVolte ao quadro, releia a conversa (aba Conversa) e revise.\n\n"
				+ "[color=#%s]Para ver a explicação completa, mude para didático em Opções > Configurações.[/color]") \
				% TEXTO_CLARO.darkened(0.25).to_html(false)
		%Explicacao.scroll_to_line(0)
		return
	else:
		%Cabecalho.text = "POR QUE NÃO FOI NOTA MÁXIMA"
		for grupo in Verificador.perdas_por_categoria(resultado):
			linhas.append("[color=#%s][b]%s  −%s%%[/b][/color]" % [ROSA.to_html(false), grupo.categoria, Verificador.formatar_numero(grupo.impacto)])
			for perda in grupo.perdas:
				linhas.append("[indent][color=#%s]−%s%%[/color]  %s[/indent]"
						% [ROSA.lightened(0.35).to_html(false), Verificador.formatar_numero(perda.impacto), _escapar(perda.mensagem)])
			linhas.append("")
	if not resultado.avisos.is_empty():
		if nota >= 99.95:
			linhas.append("")
		linhas.append("[color=#%s][b]Observações[/b] (não descontam)[/color]" % CIANO.to_html(false))
		for aviso in resultado.avisos:
			linhas.append("[indent]• %s[/indent]" % _escapar(aviso))
	%Explicacao.text = "\n".join(linhas).strip_edges()
	%Explicacao.scroll_to_line(0)


## Nomes do quadro e do gabarito não podem virar tags de BBCode.
static func _escapar(texto: String) -> String:
	return texto.replace("[", "[lb]")


## Faixas xadrez em cima e embaixo, como a dobra pixelada dos post-its.
func _desenhar_faixas() -> void:
	var fundo: ColorRect = %Fundo
	var lado := 8.0
	var colunas := int(ceil(fundo.size.x / lado))
	for linha in 2:
		for coluna in colunas:
			if (coluna + linha) % 2 == 0:
				fundo.draw_rect(Rect2(coluna * lado, linha * lado, lado, lado), AZUL_DA_FAIXA)
				fundo.draw_rect(Rect2(coluna * lado, fundo.size.y - (linha + 1) * lado, lado, lado), AZUL_DA_FAIXA)


## Barra de quadradinhos (pixel art) de uma parte do diagrama. `fracao` enche em
## ciano (tudo certo), amarelo (parte) ou rosa (nada); `penalidade` desenha um
## quadradinho rosa por ponto perdido.
class Barra extends Control:
	const QUADRADOS := 16
	const LADO := 10.0
	const ESPACO := 2.0

	var fracao := 0.0
	var penalidade := 0.0
	var _visivel := 0.0  # quanto da barra já apareceu (animação)

	func _init():
		custom_minimum_size = Vector2(QUADRADOS * (LADO + ESPACO), LADO + 4)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func encher(atraso: float) -> void:
		var animacao := create_tween()
		animacao.tween_interval(atraso)
		animacao.tween_method(_mostrar_ate, 0.0, 1.0, 0.35)

	func _mostrar_ate(valor: float) -> void:
		_visivel = valor
		queue_redraw()

	func _draw() -> void:
		var cheios := 0
		var cor := MARINHO
		if penalidade > 0.0:
			cheios = mini(int(ceil(penalidade)), QUADRADOS)
			cor = ROSA
		else:
			cheios = int(round(fracao * QUADRADOS))
			cor = CIANO if fracao >= 0.999 else (AMARELO if fracao > 0.0 else ROSA)
		var mostrados := int(ceil(_visivel * QUADRADOS))
		for i in QUADRADOS:
			var quadrado := Rect2(i * (LADO + ESPACO), 2, LADO, LADO)
			var vazio := Color(MARINHO, 0.18)
			draw_rect(quadrado, cor if i < cheios and i < mostrados else vazio)
			if i < cheios and i < mostrados:
				# Sombra de 2 px embaixo, como nos post-its.
				draw_rect(Rect2(quadrado.position + Vector2(0, LADO - 2), Vector2(LADO, 2)), cor.darkened(0.25))
