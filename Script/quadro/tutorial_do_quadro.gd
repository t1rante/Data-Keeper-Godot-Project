extends Node
## Tutorial no quadro: a Ana explica a parte técnica (entidade, atributo,
## relacionamento…) enquanto o jogador monta o diagrama.
##
## As falas ficam em fases/<id>/tutorial.dtl, no formato do Dialogic, divididas
## em passos por linhas de comentário "# espera:". Em cada passo, as falas
## aparecem com a planta à mostra e o tutorial espera o jogador fazer algo no
## quadro, pelos sinais de quadro.gd:
##
##   # espera: bloco_criado atributo     (criou um bloco desse tipo)
##   # espera: bloco_nomeado entidade    (deu nome a um bloco desse tipo)
##   # espera: blocos_ligados atributo   (ligou dois blocos, um deles desse tipo)
##   # espera: verificado                (apertou Verificar)
##
## O tipo é opcional: entidade, relacionamento, atributo, especializacao ou
## agregacao. Depois do último "# espera:", as falas que sobram encerram o
## tutorial. Enquanto uma fala está na tela, o quadro não responde; entre as
## falas, sim. As falas podem usar {nome} (dialogos.gd).
##
## Cada passo vira uma timeline (DialogicTimeline.from_text). No fim dela,
## [signal] avisa que acabou e o tutorial encerra a timeline sem a animação de
## saída do Dialogic (que deixaria o quadro travado por uns 2 s).
##
## O quadro começa o tutorial sozinho no dia em que a fase tem tutorial.dtl, ou
## com `com_tutorial` ligado (quadro.comecar_tutorial()).

signal terminou
# Os awaits esperam sinais do próprio tutorial, ligados aos do Dialogic: se o
# quadro (e o tutorial junto) sair no meio de uma fala, a ligação some com ele
# e nada tenta continuar uma função de um objeto que já não existe.
signal _conversa_acabou
signal _falas_acabaram
signal _passou_um_quadro

const Dialogos = preload("res://Script/jogo/dialogos.gd")

const FIM_DAS_FALAS := "fim_das_falas_do_tutorial"
## Pausa entre o fim da conversa com o cliente e a primeira fala: o jogador vê a
## planta, e os Enter que sobraram da conversa não pulam as falas da Ana.
const PAUSA_DEPOIS_DA_CONVERSA := 0.6
const MARCA_DE_ESPERA := "# espera:"
const SINAIS := ["bloco_criado", "bloco_nomeado", "blocos_ligados", "verificado"]
const TIPOS := {
	"entidade": "entidades", "relacionamento": "relacionamentos", "atributo": "atributos",
	"especializacao": "especializacoes", "agregacao": "agregacoes",
}

var quadro: Node2D
var passo := -1


## Passos do arquivo: [{"falas": texto do Dialogic, "espera": sinal ou "", "tipo": tipo_objeto ou ""}].
static func ler(caminho: String) -> Array:
	var passos := []
	var falas := PackedStringArray()
	for linha in FileAccess.get_file_as_string(caminho).split("\n"):
		var limpa := linha.strip_edges()
		if limpa.begins_with(MARCA_DE_ESPERA):
			var partes := limpa.trim_prefix(MARCA_DE_ESPERA).strip_edges().split(" ", false)
			var sinal := partes[0] if partes.size() > 0 else ""
			var tipo := partes[1] if partes.size() > 1 else ""
			passos.append({"falas": "\n".join(falas), "espera": sinal, "tipo": TIPOS.get(tipo, tipo)})
			falas = PackedStringArray()
		else:
			falas.append(linha)
	if "\n".join(falas).strip_edges() != "":
		passos.append({"falas": "\n".join(falas), "espera": "", "tipo": ""})
	return passos


func comecar(o_quadro: Node2D, caminho: String) -> void:
	quadro = o_quadro
	if Dialogic.current_timeline != null:  # a conversa com o cliente termina antes
		Dialogic.timeline_ended.connect(_ao_terminar_conversa, CONNECT_ONE_SHOT)
		await _conversa_acabou
		# O Dialogic avisa o fim antes de apagar a caixa de texto da conversa: uma
		# timeline começada agora iria junto com ela.
		get_tree().create_timer(PAUSA_DEPOIS_DA_CONVERSA).timeout.connect(_ao_passar_um_quadro, CONNECT_ONE_SHOT)
		await _passou_um_quadro
	var passos := ler(caminho)
	for i in passos.size():
		passo = i
		if _tem_fala(passos[i].falas):
			await _falar(passos[i].falas)
		if passos[i].espera in SINAIS:
			await _esperar(passos[i].espera, passos[i].tipo)
	terminou.emit()
	queue_free()


## Espera o sinal do quadro; com `tipo`, só vale se envolver um bloco desse tipo.
func _esperar(sinal: String, tipo: String) -> void:
	while true:
		var recebido = await Signal(quadro, sinal)
		var argumentos: Array = recebido if recebido is Array else [recebido]
		if tipo == "" or argumentos.any(func(a): return a is Node and a.get("tipo_objeto") == tipo):
			return


func _tem_fala(texto: String) -> bool:
	for linha in texto.split("\n"):
		var limpa := linha.strip_edges()
		if limpa != "" and not limpa.begins_with("#"):
			return true
	return false


func _falar(texto: String) -> void:
	var timeline := DialogicTimeline.new()
	timeline.from_text(texto + "\n[signal arg=\"%s\"]" % FIM_DAS_FALAS)
	Dialogos.preparar()
	quadro.fala_por_cima = true
	Dialogic.signal_event.connect(_ao_sinal)
	Dialogic.start(timeline)
	await _falas_acabaram
	Dialogic.signal_event.disconnect(_ao_sinal)
	await _esperar_um_quadro()  # deixa o evento de sinal terminar
	Dialogic.end_timeline(true)
	await _esperar_um_quadro()  # a caixa de texto some antes da próxima fala
	quadro.fala_por_cima = false


func _esperar_um_quadro() -> void:
	get_tree().process_frame.connect(_ao_passar_um_quadro, CONNECT_ONE_SHOT)
	await _passou_um_quadro


func _ao_passar_um_quadro() -> void:
	_passou_um_quadro.emit()


func _ao_terminar_conversa() -> void:
	_conversa_acabou.emit()


func _ao_sinal(argumento) -> void:
	if str(argumento) == FIM_DAS_FALAS:
		_falas_acabaram.emit()
