extends Node2D
## Quadro do minigame: o jogador monta o diagrama ER sobre a planta azul
## (Cenas/quadro/quadro.tscn). O quadro sempre começa vazio. Na borda direita há três
## menus, cada um com a sua aba [<], uma embaixo da outra: "Blocos" (post-its),
## "Palavras" (banco de palavras: os nomes dos blocos) e "Conversa" (o log da
## conversa com o cliente, para reler o pedido).
##
## A fase (gabarito, banco e conversa) é a do dia (Jogo.fase_atual), ou a de
## `fase`, se preenchida no Inspetor para testar o quadro sozinho (F6).
##
## Os menus laterais (UI/MenusLaterais, ver menu_lateral.gd) e os botões só
## aparecem quando a planta está na tela, ou seja, fora do diálogo do cliente.
## Falas por cima da planta (o tutorial, por exemplo) ligam `fala_por_cima`.
##
## Controles (também escritos no post-it de dicas, que a tecla H esconde):
##   clique num post-it ............. cria um bloco daquele tipo
##   arrastar um bloco .............. move o bloco
##   palavra do banco até um bloco .. dá o nome ao bloco (ninguém digita)
##   clique no bloco ................ seleciona (borda amarela); selecionar um
##                                    segundo bloco liga os dois
##   bloco selecionado + tecla ...... Delete apaga; C, D, M (atributo) e F
##                                    (entidade/relacionamento) mudam o tipo
##   roda do mouse .................. zoom no ponto do mouse (o HUD não muda)
##   arrastar o fundo azul ........... move a vista (botão do meio: em qualquer lugar)
##   tecla 0 ......................... enquadra o diagrama todo
##
## Zoom e arrasto são de uma Camera2D (nó Camera): ela mexe na planta e no
## diagrama; o HUD (UI, um CanvasLayer: menus laterais e botões) fica do mesmo
## tamanho. A planta é desenhada por shader (planta.gdshader) e continua além da
## tela. As posições dos blocos (e do save) são do quadro, não da tela.
##   clique numa linha .............. seleciona; Delete apaga
##   clique direito numa linha ...... cardinalidade 1 -> N -> M
##   Esc ou clique no vazio ......... desfaz a seleção
## Verificar abre a tela de verificação (Cenas/telas/tela_de_verificacao.tscn) por
## cima do quadro. Enquanto ela ou o diálogo do cliente está na tela, o quadro
## não responde. O diagrama fica em Jogo.diagrama a cada mudança: o save feito no
## menu de opções (botão Opções) guarda o quadro no meio da fase, e ao carregar
## esse save o quadro é remontado. ENTREGAR na verificação termina a fase.

## Avisos para quem acompanha o jogador no quadro (o tutorial, por exemplo).
signal bloco_criado(bloco: Node2D)
signal bloco_nomeado(bloco: Node2D)
signal blocos_ligados(a: Node2D, b: Node2D)
signal verificado(resultado: Dictionary)

const Verificador = preload("res://Script/correcao/verificador.gd")
const Jogo = preload("res://Script/jogo/jogo.gd")
const Fases = preload("res://Script/jogo/fases.gd")
const Fluxo = preload("res://Script/jogo/fluxo.gd")
const MENU_DE_OPCOES = preload("res://Cenas/ui/menu_de_opcoes.tscn")
const TutorialDoQuadro = preload("res://Script/quadro/tutorial_do_quadro.gd")
const Musica = preload("res://Script/jogo/musica.gd")

const CENAS_DOS_BLOCOS := {
	"entidades": preload("res://Cenas/quadro/blocos/entidade.tscn"),
	"relacionamentos": preload("res://Cenas/quadro/blocos/relacionamento.tscn"),
	"atributos": preload("res://Cenas/quadro/blocos/atributo.tscn"),
	"especializacoes": preload("res://Cenas/quadro/blocos/especializacao.tscn"),
	"agregacoes": preload("res://Cenas/quadro/blocos/agregacao.tscn"),
}
const PREFIXOS_DOS_IDS := {
	"entidades": "Entidade_",
	"relacionamentos": "Relacionamento_",
	"atributos": "Atributo_",
	"especializacoes": "Especializacao_",
	"agregacoes": "Agregacao_",
}
const CENA_LINHA = preload("res://Cenas/quadro/linha.tscn")
const TELA_DE_VERIFICACAO = preload("res://Cenas/telas/tela_de_verificacao.tscn")

## Parte da tela onde os blocos novos aparecem, com todos os menus fechados (a
## faixa da direita fica livre para as abas). Menus abertos tiram a parte deles.
const AREA_DA_PLANTA := Rect2(16, 16, 1100, 616)
## Até onde o quadro vai (posições do quadro): os blocos e a vista ficam aqui dentro.
const LIMITES_DO_QUADRO := Rect2(-1624, -976, 4400, 2600)
const ZOOM_MINIMO := 0.35
const ZOOM_MAXIMO := 2.0
## Cada passo da roda do mouse multiplica (ou divide) o zoom por isto.
const PASSO_DO_ZOOM := 1.12
## Distância mínima entre um bloco e um menu lateral aberto.
const FOLGA_DOS_MENUS := 16.0
## Blocos novos vão para o primeiro espaço livre da planta, procurando a partir
## do canto de cima à direita, em colunas desta largura e altura.
const GRADE_DE_CRIACAO := Vector2(180, 110)
## Quanto o mouse precisa andar, com o botão apertado, para virar arrasto.
const LIMIAR_DE_ARRASTO := 5.0

## Tecla -> marca que ela liga/desliga no bloco selecionado (ver bloco.gd).
const TECLAS_DAS_MARCAS := {KEY_C: "chave", KEY_D: "derivado", KEY_M: "multivalorado", KEY_F: "fraca"}

## Fase deste quadro (pasta em fases/); vazio = a do dia (Jogo.fase_atual).
@export var fase := ""
## Força o tutorial da fase ao abrir o quadro (para testar no editor). No jogo, o
## tutorial começa sozinho no dia em que a fase tem tutorial.dtl (Jogo.tutorial_pendente).
@export var com_tutorial := false

## Uma fala está na tela, mas a planta continua à mostra (menus visíveis).
var fala_por_cima := false

var _arquivos: Dictionary  # a fase: nome, conversa, gabarito, palavras (fases.gd)
var _ultimo_resultado := {}
var _pecas: Node2D
var _linhas: Node2D
var _interface: CanvasLayer
var _menus: Control
var _dicas_abertas: Control
var _dicas_fechadas: Control
var _banco: Control
var _tela_de_verificacao: CanvasLayer = null
var _bloco_sob_a_palavra: Node2D = null

var contadores := {}  # tipo -> último número usado nos ids
var selecionado: Node2D = null
var linha_selecionada: Line2D = null

# Clique em andamento sobre um bloco.
var _alvo_do_clique: Node2D = null
var _inicio_do_clique := Vector2.ZERO
var _deslocamento := Vector2.ZERO
var _arrastando := false

# Vista: câmera e arrasto do fundo em andamento.
var _camera: Camera2D
var _movendo_vista := false
var _vista_no_inicio := Vector2.ZERO   # posição da câmera quando o arrasto começou
var _tela_no_inicio := Vector2.ZERO    # posição do mouse (tela) quando o arrasto começou


func _ready():
	if not has_node("Diagrama"):
		# Este script só funciona como raiz de Cenas/quadro/quadro.tscn. Se ele for
		# carregado em outro lugar (como o antigo autoload "GameManager"), fica
		# parado em vez de quebrar o jogo.
		push_warning("quadro.gd é o script do quadro (Cenas/quadro/quadro.tscn); remova o autoload GameManager em Projeto > Configurações do Projeto > Globais > Autoload.")
		set_process(false)
		set_process_unhandled_input(false)
		return

	_pecas = $Diagrama/Pecas
	_linhas = $Diagrama/Linhas
	_interface = $UI
	_menus = %MenusLaterais
	_dicas_abertas = %DicasAbertas
	_dicas_fechadas = %DicasFechadas
	_banco = %BancoDePalavras
	_camera = $Camera
	vista_padrao()
	if fase != "":
		Jogo.fase_atual = fase
	elif Jogo.fase_atual == "":
		Jogo.fase_atual = Jogo.fase_do_dia()
	_arquivos = Fases.dados(Jogo.fase_atual)
	_banco.carregar(_arquivos.palavras, _arquivos.gabarito)
	%LogDaConversa.carregar(_arquivos.conversa)
	Dialogic.timeline_ended.connect(_ao_terminar_conversa)
	_banco.palavra_arrastada.connect(_ao_arrastar_palavra)
	_banco.palavra_solta.connect(_ao_soltar_palavra)

	# O quadro começa vazio, mesmo que alguém deixe blocos na cena pelo editor, ou
	# com o diagrama do save feito no meio desta fase.
	for filho in _pecas.get_children() + _linhas.get_children():
		filho.free()
	if not Jogo.diagrama.is_empty():
		carregar_diagrama(Jogo.diagrama)
	_diagrama_mudou()

	for post_it in %PostIts.get_children():
		post_it.pivot_offset = post_it.size / 2
		post_it.mouse_entered.connect(func(): post_it.scale = Vector2(1.05, 1.05))
		post_it.mouse_exited.connect(func(): post_it.scale = Vector2.ONE)
	_atualizar_interface()
	if com_tutorial or Jogo.tutorial_pendente:
		Jogo.tutorial_pendente = false
		comecar_tutorial()
	if not _dialogo_ativo():
		Musica.tocar(Musica.MENU)  # por enquanto, a mesma música do menu enquanto monta o MER


func _process(_delta):
	_atualizar_interface()


func _exit_tree():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# --- Post-its e botões (sinais ligados na cena) -----------------------------------

func criar_bloco(tipo: String):
	if _bloqueado():
		return
	var bloco = CENAS_DOS_BLOCOS[tipo].instantiate()
	bloco.id_objeto = _novo_id(tipo)
	var lugar := _lugar_livre(bloco.tamanho)
	_pecas.add_child(bloco)
	bloco.global_position = lugar
	bloco.alterado.connect(_diagrama_mudou)
	_diagrama_mudou()
	bloco_criado.emit(bloco)


## Corrige o diagrama e abre a tela de verificação por cima do quadro.
func verificar_vitoria():
	if _bloqueado():
		return
	_diagrama_mudou()
	var resultado := Verificador.avaliar_arquivo(estado_do_diagrama(), _arquivos.gabarito)
	print(Verificador.relatorio(resultado))
	_selecionar_bloco(null)
	_selecionar_linha(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_tela_de_verificacao = TELA_DE_VERIFICACAO.instantiate()
	add_child(_tela_de_verificacao)
	_tela_de_verificacao.voltar.connect(_fechar_verificacao)
	_tela_de_verificacao.entregar.connect(_entregar)
	_ultimo_resultado = resultado
	var pagamento := Jogo.pagamento(_arquivos.id, resultado.get("porcentagem", 0.0))
	_tela_de_verificacao.mostrar(resultado, Jogo.reais(pagamento))
	verificado.emit(resultado)


func _fechar_verificacao():
	if _tela_de_verificacao:
		_tela_de_verificacao.queue_free()
		_tela_de_verificacao = null


func alternar_dicas():
	_dicas_abertas.visible = not _dicas_abertas.visible
	_dicas_fechadas.visible = not _dicas_abertas.visible


## Começa o tutorial da fase (fases/<id>/tutorial.dtl) depois da conversa com o
## cliente, se ela ainda estiver na tela. Fase sem tutorial usa o do dia 1.
func comecar_tutorial():
	var caminho: String = _arquivos.tutorial if _arquivos.tutorial != "" else Fases.dados(Fases.ORDEM[0]).tutorial
	if caminho == "":
		return
	var tutorial := TutorialDoQuadro.new()
	add_child(tutorial)
	tutorial.comecar(self, caminho)


## A conversa do dia acabou: o log passa a mostrar o que foi dito, e a música
## começa (por enquanto, a mesma do menu) enquanto o jogador monta o MER.
func _ao_terminar_conversa():
	%LogDaConversa.carregar(_arquivos.conversa)
	Musica.tocar(Musica.MENU)


## Menus e botões só aparecem com a planta na tela (o diálogo cobre a planta).
func _atualizar_interface():
	var mostrar := not _dialogo_ativo() or fala_por_cima
	if _interface.visible != mostrar:
		_interface.visible = mostrar


## ENTREGAR na tela de verificação: o cliente paga pela nota e o dia de trabalho acaba.
func _entregar() -> void:
	Fluxo.entregar_fase(_ultimo_resultado.get("porcentagem", 0.0))


## Botão Opções: menu de pausa com Salvar (o save guarda o quadro como está).
func abrir_opcoes() -> void:
	if _bloqueado() or has_node("MenuDeOpcoes"):
		return
	_selecionar_bloco(null)
	_selecionar_linha(null)
	var menu := MENU_DE_OPCOES.instantiate()
	menu.name = "MenuDeOpcoes"
	menu.lugar_do_save = "quadro"
	add_child(menu)


# --- Mouse e teclado no quadro -----------------------------------------------------

func _unhandled_input(event: InputEvent):
	if _bloqueado():
		return
	if event is InputEventMouse:
		var ponto: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if event.pressed:
						_apertar(ponto, event.position)
					else:
						_soltar()
				MOUSE_BUTTON_RIGHT:
					if event.pressed:
						_clique_direito(ponto)
				MOUSE_BUTTON_MIDDLE:
					if event.pressed:
						_comecar_a_mover_a_vista(event.position)
					else:
						_parar_de_mover_a_vista()
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					if event.pressed:
						var passos: float = event.factor if event.factor > 0.0 else 1.0
						var fator := pow(PASSO_DO_ZOOM, passos)
						dar_zoom(fator if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / fator, event.position)
		elif event is InputEventMouseMotion:
			if _movendo_vista:
				_mover_a_vista_ate(event.position)
			else:
				_mover(ponto)
	elif event is InputEventPanGesture:  # touchpad: dois dedos arrastam
		mover_vista(-event.delta * 12.0)
	elif event is InputEventMagnifyGesture:  # touchpad: pinça dá zoom
		dar_zoom(event.factor, event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		_tecla(event.keycode)


func _apertar(ponto: Vector2, na_tela: Vector2):
	var bloco := _bloco_em(ponto)
	if bloco:
		_alvo_do_clique = bloco
		_inicio_do_clique = ponto
		_deslocamento = bloco.global_position - ponto
		_arrastando = false
		return

	var linha := _linha_em(ponto)
	_selecionar_bloco(null)
	_selecionar_linha(linha)  # clique no vazio desmarca tudo
	if linha == null:
		_comecar_a_mover_a_vista(na_tela)  # segurar no fundo azul arrasta a vista


func _mover(ponto: Vector2):
	if _alvo_do_clique == null:
		_atualizar_cursor(ponto)
		return
	if not _arrastando and ponto.distance_to(_inicio_do_clique) > LIMIAR_DE_ARRASTO:
		_arrastando = true
		_alvo_do_clique.move_to_front()
	if _arrastando:
		_alvo_do_clique.global_position = _dentro_da_area(ponto + _deslocamento, _alvo_do_clique)


func _soltar():
	_parar_de_mover_a_vista()
	var bloco := _alvo_do_clique
	if bloco == null:
		return
	_alvo_do_clique = null
	if _arrastando:
		_arrastando = false
		_diagrama_mudou()
	else:
		_clicar_no_bloco(bloco)


## Seleciona o bloco; se já havia outro selecionado, liga os dois.
func _clicar_no_bloco(bloco: Node2D):
	_selecionar_linha(null)
	if selecionado == null:
		_selecionar_bloco(bloco)
	elif selecionado == bloco:
		_selecionar_bloco(null)
	else:
		var primeiro := selecionado
		_selecionar_bloco(null)
		_ligar(primeiro, bloco)


func _clique_direito(ponto: Vector2):
	if _bloco_em(ponto):
		return
	var linha := _linha_em(ponto)
	if linha and linha.alternar_cardinalidade():
		_diagrama_mudou()


func _tecla(tecla: Key):
	match tecla:
		KEY_ESCAPE:
			_selecionar_bloco(null)
			_selecionar_linha(null)
		KEY_H:
			alternar_dicas()
		KEY_0, KEY_KP_0:
			enquadrar()
		KEY_DELETE, KEY_BACKSPACE:
			_apagar_selecao()
		_:
			if tecla in TECLAS_DAS_MARCAS and selecionado and selecionado.alternar_marca(TECLAS_DAS_MARCAS[tecla]):
				_diagrama_mudou()


func _atualizar_cursor(ponto: Vector2):
	var cursor := Input.CURSOR_ARROW
	if _bloco_em(ponto):
		cursor = Input.CURSOR_POINTING_HAND
	elif _linha_em(ponto):
		cursor = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)


# --- Ações ------------------------------------------------------------------------

func _ligar(a: Node2D, b: Node2D):
	for linha in _linhas_vivas():
		if linha.liga(a, b):
			_selecionar_linha(linha)  # já estavam ligados
			return
	var nova_linha = CENA_LINHA.instantiate()
	_linhas.add_child(nova_linha)
	nova_linha.definir_alvos(a, b)
	_diagrama_mudou()
	blocos_ligados.emit(a, b)


func _apagar_selecao():
	if selecionado:
		var bloco := selecionado
		_selecionar_bloco(null)
		for linha in _linhas_vivas():
			if linha.target1 == bloco or linha.target2 == bloco:
				linha.queue_free()
		bloco.queue_free()
		_diagrama_mudou()
	elif linha_selecionada:
		var linha := linha_selecionada
		_selecionar_linha(null)
		linha.queue_free()
		_diagrama_mudou()


func _selecionar_bloco(bloco: Node2D):
	if is_instance_valid(selecionado):
		selecionado.selecionado = false
	selecionado = bloco
	if bloco:
		bloco.selecionado = true


func _selecionar_linha(linha: Line2D):
	if is_instance_valid(linha_selecionada):
		linha_selecionada.selecionada = false
	linha_selecionada = linha
	if linha:
		linha.selecionada = true


# --- Banco de palavras ------------------------------------------------------------

## Destaca (borda rosa) o bloco que vai receber a palavra.
func _ao_arrastar_palavra(_palavra: String, posicao: Vector2):
	_marcar_alvo(_bloco_em(_no_quadro(posicao)))


func _ao_soltar_palavra(palavra: String, posicao: Vector2):
	_marcar_alvo(null)
	var bloco := _bloco_em(_no_quadro(posicao))
	if bloco and not _bloqueado():
		bloco.definir_nome(palavra)  # o bloco avisa (alterado) e o save é gravado
		bloco_nomeado.emit(bloco)


func _marcar_alvo(bloco: Node2D):
	if is_instance_valid(_bloco_sob_a_palavra):
		_bloco_sob_a_palavra.alvo = false
	_bloco_sob_a_palavra = bloco
	if bloco:
		bloco.alvo = true


## Posição na tela (eventos de mouse da interface) -> posição no quadro.
func _no_quadro(posicao_na_tela: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * posicao_na_tela


# --- Consultas ----------------------------------------------------------------------

func _dialogo_ativo() -> bool:
	return Dialogic.current_timeline != null


## O quadro não responde com o diálogo, a tela de verificação ou o menu de opções na frente.
func _bloqueado() -> bool:
	return _dialogo_ativo() or _tela_de_verificacao != null or has_node("MenuDeOpcoes")


func _blocos_vivos() -> Array:
	return _pecas.get_children().filter(func(b): return not b.is_queued_for_deletion())


func _linhas_vivas() -> Array:
	return _linhas.get_children().filter(func(l):
		return not l.is_queued_for_deletion() \
				and is_instance_valid(l.target1) and not l.target1.is_queued_for_deletion() \
				and is_instance_valid(l.target2) and not l.target2.is_queued_for_deletion())


## Bloco mais de cima que contém o ponto.
func _bloco_em(ponto: Vector2) -> Node2D:
	var blocos := _blocos_vivos()
	blocos.reverse()
	for bloco in blocos:
		if bloco.contem(ponto):
			return bloco
	return null


func _linha_em(ponto: Vector2) -> Line2D:
	for linha in _linhas_vivas():
		if linha.perto(ponto):
			return linha
	return null


## Parte do quadro que está à vista e livre para blocos novos (em posições do
## quadro): a área da tela menos os menus abertos, passada pelo zoom e pelo arrasto.
func area_dos_blocos() -> Rect2:
	var na_tela := _area_livre_na_tela()
	var inversa := get_canvas_transform().affine_inverse()
	var inicio: Vector2 = inversa * na_tela.position
	var fim: Vector2 = inversa * na_tela.end
	return Rect2(inicio, fim - inicio)


## A área da tela menos os menus laterais abertos.
func _area_livre_na_tela() -> Rect2:
	var area := AREA_DA_PLANTA
	for menu in _menus.get_children():
		var coberta: Rect2 = menu.area_ocupada()
		if not coberta.has_area():
			continue
		var fim := area.end
		if menu.lado == MenuLateral.Lado.DIREITA:
			fim.x = minf(fim.x, coberta.position.x - FOLGA_DOS_MENUS)
		else:
			area.position.x = maxf(area.position.x, coberta.end.x + FOLGA_DOS_MENUS)
		area.end = fim
	return area


## Posição dentro dos limites do quadro (o bloco pode ir para fora da tela: a
## vista acompanha com zoom e arrasto).
func _dentro_da_area(posicao: Vector2, bloco: Node2D) -> Vector2:
	var metade: Vector2 = bloco.tamanho / 2
	return posicao.clamp(LIMITES_DO_QUADRO.position + metade, LIMITES_DO_QUADRO.end - metade)


# --- Vista: zoom e arrasto ----------------------------------------------------------

## Zoom em volta de `na_tela` (posição do mouse): o que está embaixo dele fica no lugar.
func dar_zoom(fator: float, na_tela: Vector2) -> void:
	var embaixo_do_mouse := _no_quadro(na_tela)
	var zoom := clampf(_camera.zoom.x * fator, ZOOM_MINIMO, ZOOM_MAXIMO)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = embaixo_do_mouse - (na_tela - _centro_da_tela()) / zoom
	_limitar_a_vista()


## Arrasta a vista `na_tela` pixels da tela (o fundo segue o mouse).
func mover_vista(na_tela: Vector2) -> void:
	_camera.position -= na_tela / _camera.zoom.x
	_limitar_a_vista()


## Zoom 1 e a vista no lugar de sempre (como o quadro abre).
func vista_padrao() -> void:
	_camera.zoom = Vector2.ONE
	_camera.position = _centro_da_tela()
	_limitar_a_vista()


## Enquadra todos os blocos (sem passar de zoom 1); sem blocos, a vista de sempre.
func enquadrar() -> void:
	var blocos := _blocos_vivos()
	if blocos.is_empty():
		vista_padrao()
		return
	var caixa := Rect2(blocos[0].global_position, Vector2.ZERO)
	for bloco in blocos:
		caixa = caixa.merge(Rect2(bloco.global_position - bloco.tamanho / 2, bloco.tamanho))
	var livre := _area_livre_na_tela()
	var cabe := minf(livre.size.x / (caixa.size.x + 80.0), livre.size.y / (caixa.size.y + 80.0))
	var zoom := clampf(minf(cabe, 1.0), ZOOM_MINIMO, ZOOM_MAXIMO)
	_camera.zoom = Vector2(zoom, zoom)
	# o centro da caixa vai para o centro da área livre (os menus abertos ficam de fora)
	_camera.position = caixa.get_center() - (livre.get_center() - _centro_da_tela()) / zoom
	_limitar_a_vista()


func zoom_atual() -> float:
	return _camera.zoom.x


func _comecar_a_mover_a_vista(na_tela: Vector2) -> void:
	_movendo_vista = true
	_tela_no_inicio = na_tela
	_vista_no_inicio = _camera.position
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _mover_a_vista_ate(na_tela: Vector2) -> void:
	_camera.position = _vista_no_inicio - (na_tela - _tela_no_inicio) / _camera.zoom.x
	_limitar_a_vista()


func _parar_de_mover_a_vista() -> void:
	if _movendo_vista:
		_movendo_vista = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _limitar_a_vista() -> void:
	_camera.position = _camera.position.clamp(LIMITES_DO_QUADRO.position, LIMITES_DO_QUADRO.end)
	_camera.force_update_scroll()  # as contas de posição (cliques, palavras) já valem neste quadro


func _centro_da_tela() -> Vector2:
	return get_viewport().get_visible_rect().size / 2


## Primeiro lugar da grade de criação onde um bloco desse tamanho não encosta
## em nenhum outro; se a planta estiver cheia, o canto de cima à direita.
func _lugar_livre(tamanho: Vector2) -> Vector2:
	var area := area_dos_blocos()
	var ocupados := _blocos_vivos().map(func(b): return Rect2(b.global_position - b.tamanho / 2, b.tamanho).grow(12))
	var inicio := area.end - tamanho / 2
	var x := inicio.x
	while x >= area.position.x + tamanho.x / 2:
		var y := area.position.y + tamanho.y / 2 + 8
		while y <= area.end.y - tamanho.y / 2:
			var lugar := Rect2(Vector2(x, y) - tamanho / 2, tamanho)
			if not ocupados.any(func(r): return r.intersects(lugar)):
				return Vector2(x, y)
			y += GRADE_DE_CRIACAO.y
		x -= GRADE_DE_CRIACAO.x
	return Vector2(inicio.x, area.position.y + tamanho.y / 2 + 8)


func _novo_id(tipo: String) -> String:
	var usados := _blocos_vivos().map(func(b): return b.id_objeto)
	var numero: int = contadores.get(tipo, 0)
	var id := ""
	while id == "" or id in usados:
		numero += 1
		id = PREFIXOS_DOS_IDS[tipo] + str(numero)
	contadores[tipo] = numero
	return id


# --- Save ---------------------------------------------------------------------------

func estado_do_diagrama() -> Dictionary:
	var estado := {
		"entidades": {},
		"atributos": {},
		"relacionamentos": {},
		"especializacoes": {},
		"agregacoes": {},
		"conexoes": [],
	}
	for bloco in _blocos_vivos():
		estado[bloco.tipo_objeto][bloco.id_objeto] = bloco.dados()
	for linha in _linhas_vivas():
		estado["conexoes"].append(linha.dados())
	return estado


## Remonta um diagrama no formato de estado_do_diagrama() (o do save).
func carregar_diagrama(dados: Dictionary) -> void:
	var por_id := {}
	for tipo in CENAS_DOS_BLOCOS:
		var blocos = dados.get(tipo, {})
		for id in (blocos if blocos is Dictionary else {}):
			var bloco = CENAS_DOS_BLOCOS[tipo].instantiate()
			bloco.id_objeto = str(id)
			_pecas.add_child(bloco)
			var posicao = blocos[id].get("posicao", {})
			bloco.global_position = Vector2(float(posicao.get("x", 0)), float(posicao.get("y", 0)))
			bloco.restaurar(blocos[id])
			bloco.alterado.connect(_diagrama_mudou)
			por_id[str(id)] = bloco
	for conexao in dados.get("conexoes", []):
		var a = por_id.get(str(conexao.get("de", "")))
		var b = por_id.get(str(conexao.get("para", "")))
		if a and b:
			var linha = CENA_LINHA.instantiate()
			_linhas.add_child(linha)
			linha.definir_alvos(a, b)
			linha.cardinalidade = str(conexao.get("cardinalidade", "1"))
	# Diagrama grande (algum bloco fora da vista de sempre): já abre enquadrado.
	var vista := area_dos_blocos()
	if por_id.values().any(func(b): return not vista.encloses(Rect2(b.global_position - b.tamanho / 2, b.tamanho))):
		enquadrar()


## Onde o save do menu de opções retoma o jogo.
func lugar_do_save() -> String:
	return "quadro"


## Toda mudança no quadro passa por aqui: o diagrama fica em Jogo.diagrama (vai
## para o save) e o banco marca as palavras usadas.
func _diagrama_mudou():
	Jogo.diagrama = estado_do_diagrama()
	if _banco:
		_banco.atualizar_usos(_blocos_vivos().map(func(b): return b.nome))
