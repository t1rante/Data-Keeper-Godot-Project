extends CanvasLayer
## Tela de configurações (Cenas/telas/configuracoes.tscn): volume do jogo, volume
## da música, dificuldade e salvamento automático. Abre por cima de quem a chama:
## o OPÇÕES da tela de título e o CONFIGURACOES do menu de pausa. Cada mudança já
## vale e já fica gravada (Script/jogo/configuracoes.gd); VOLTAR ou Esc fecham.
##
## Ao soltar um volume, toca um bipe curto na barra dele (Efeitos para o volume do
## jogo, Musica para o da música), para conferir. Com música tocando (no menu
## principal), o volume da música dispensa o bipe: a própria música mostra.

signal fechou

const Configuracoes = preload("res://Script/jogo/configuracoes.gd")
const Musica = preload("res://Script/jogo/musica.gd")
const Sons = preload("res://Script/jogo/sons.gd")

const DESCRICAO_DA_DIFICULDADE := {
	Configuracoes.DIDATICO: "Didático: ao verificar, o jogo mostra a nota e explica tudo o que faltou.",
	Configuracoes.DESAFIO: "Desafio: ao verificar, o jogo mostra a nota e as partes do diagrama, mas não diz o que faltou.",
}
const DESCRICAO_DO_SALVAMENTO := {
	true: "O jogo salva sozinho no começo do dia, antes de cada cliente e ao entregar. Dá para salvar no menu quando quiser.",
	false: "O jogo só salva quando você usar SALVAR no menu de opções (Esc).",
}

var _bipe: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona com o jogo pausado (menu de pausa)
	_bipe = AudioStreamPlayer.new()
	add_child(_bipe)
	# Mostra o que está gravado sem disparar os sinais (nada é regravado ao abrir).
	%Volume.set_value_no_signal(Configuracoes.volume_do_jogo())
	%Musica.set_value_no_signal(Configuracoes.volume_da_musica())
	%Didatico.set_pressed_no_signal(not Configuracoes.desafio())
	%Desafio.set_pressed_no_signal(Configuracoes.desafio())
	%Automatico.set_pressed_no_signal(Configuracoes.salvamento_automatico())
	_atualizar_textos()

	%Volume.value_changed.connect(func(valor: float): _mudar("volume_do_jogo", int(valor)))
	%Musica.value_changed.connect(func(valor: float): _mudar("volume_da_musica", int(valor)))
	%Volume.drag_ended.connect(func(mudou: bool): if mudou: tocar_bipe(Configuracoes.BARRA_DOS_EFEITOS))
	%Musica.drag_ended.connect(func(mudou: bool): if mudou: tocar_bipe(Configuracoes.BARRA_DA_MUSICA))
	%Didatico.toggled.connect(func(ligado: bool): if ligado: _mudar("dificuldade", Configuracoes.DIDATICO))
	%Desafio.toggled.connect(func(ligado: bool): if ligado: _mudar("dificuldade", Configuracoes.DESAFIO))
	%Automatico.toggled.connect(func(ligado: bool): _mudar("salvamento_automatico", ligado))
	%Voltar.pressed.connect(fechar)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fechar()


func fechar() -> void:
	fechou.emit()
	queue_free()


## Bipe curto na barra `barra`, para ouvir o volume (o jogo ainda não tem som).
func tocar_bipe(barra: String) -> void:
	if barra == Configuracoes.BARRA_DA_MUSICA and Musica.tocando() != null:
		return
	if barra == Configuracoes.BARRA_DOS_EFEITOS:
		Sons.tocar_clique()  # o volume do jogo mostra um som de verdade do jogo
		return
	_bipe.bus = barra
	_bipe.stream = _som([523.25, 659.25] if barra == Configuracoes.BARRA_DA_MUSICA else [880.0])
	_bipe.play()


func _mudar(chave: String, valor: Variant) -> void:
	Configuracoes.definir(chave, valor)
	_atualizar_textos()


func _atualizar_textos() -> void:
	%Valor.text = "%d%%" % Configuracoes.volume_do_jogo()
	%ValorDaMusica.text = "%d%%" % Configuracoes.volume_da_musica()
	%DescricaoDaDificuldade.text = DESCRICAO_DA_DIFICULDADE[Configuracoes.dificuldade()]
	%Automatico.text = "LIGADO" if Configuracoes.salvamento_automatico() else "DESLIGADO"
	%DescricaoDoSalvamento.text = DESCRICAO_DO_SALVAMENTO[Configuracoes.salvamento_automatico()]


## Notas senoidais curtas, uma depois da outra, com a borda suavizada (sem estalo).
static func _som(frequencias: Array, duracao := 0.14) -> AudioStreamWAV:
	var taxa := 22050
	var por_nota := int(taxa * duracao)
	var suave := taxa * 0.01
	var dados := PackedByteArray()
	dados.resize(por_nota * frequencias.size() * 2)
	var posicao := 0
	for frequencia in frequencias:
		for n in por_nota:
			var envelope := minf(1.0, minf(n, por_nota - n) / suave)
			dados.encode_s16(posicao, int(sin(TAU * frequencia * n / taxa) * 0.3 * envelope * 32767))
			posicao += 2
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = taxa
	som.stereo = false
	som.data = dados
	return som
