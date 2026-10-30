extends RefCounted
## Efeitos sonoros: o "tlin" dos botões, o tique ao passar o mouse, os passos
## das cenas de caminhada e os miados da Isha. Tocam na barra "Efeitos" (o volume do jogo, nas
## configurações, vale para eles) e são baixos de propósito: fazem parte do
## cenário, não passam por cima dele. Ajuste em VOLUMES (dB) se precisar.
##
## Sons do Kenney (kenney.nl), licença CC0 (domínio público): assets/sons/,
## "Interface Sounds" e "Impact Sounds"; as licenças estão junto dos arquivos.
## Os miados são da Isha de verdade, gravados pelo Nikolas (assets/sons/isha/,
## cortados por ferramentas/cortar_miados.py).
##
## Uso: Sons.instalar() uma vez (a tela de título chama): todo botão que entrar
## na árvore ganha o tlin ao apertar, e todo Button o tique ao passar o mouse.
## Botão que não deve fazer som: botao.set_meta("sem_som", true).
## Passos: Sons.tocar_passo("madeira") (cena_caminhada.gd faz isso).
## Miado: Sons.tocar_miado() (o carinho na casa faz isso).

const CLIQUE := preload("res://assets/sons/interface/glass_002.ogg")
const PASSAR := preload("res://assets/sons/interface/tick_002.ogg")
const PASSOS := {
	"madeira": [
		preload("res://assets/sons/passos/footstep_wood_000.ogg"), preload("res://assets/sons/passos/footstep_wood_001.ogg"),
		preload("res://assets/sons/passos/footstep_wood_002.ogg"), preload("res://assets/sons/passos/footstep_wood_003.ogg"),
		preload("res://assets/sons/passos/footstep_wood_004.ogg"),
	],
	"grama": [
		preload("res://assets/sons/passos/footstep_grass_000.ogg"), preload("res://assets/sons/passos/footstep_grass_001.ogg"),
		preload("res://assets/sons/passos/footstep_grass_002.ogg"), preload("res://assets/sons/passos/footstep_grass_003.ogg"),
		preload("res://assets/sons/passos/footstep_grass_004.ogg"),
	],
	"pedra": [
		preload("res://assets/sons/passos/footstep_concrete_000.ogg"), preload("res://assets/sons/passos/footstep_concrete_001.ogg"),
		preload("res://assets/sons/passos/footstep_concrete_002.ogg"), preload("res://assets/sons/passos/footstep_concrete_003.ogg"),
		preload("res://assets/sons/passos/footstep_concrete_004.ogg"),
	],
	"carpete": [
		preload("res://assets/sons/passos/footstep_carpet_000.ogg"), preload("res://assets/sons/passos/footstep_carpet_001.ogg"),
		preload("res://assets/sons/passos/footstep_carpet_002.ogg"), preload("res://assets/sons/passos/footstep_carpet_003.ogg"),
		preload("res://assets/sons/passos/footstep_carpet_004.ogg"),
	],
}
## Um por trecho do arquivo de miados (ferramentas/cortar_miados.py): todos com o
## mesmo volume; o carinho sorteia um.
const MIADOS := [
	preload("res://assets/sons/isha/miado_1.ogg"), preload("res://assets/sons/isha/miado_2.ogg"),
	preload("res://assets/sons/isha/miado_3.ogg"), preload("res://assets/sons/isha/miado_4.ogg"),
	preload("res://assets/sons/isha/miado_5.ogg"), preload("res://assets/sons/isha/miado_6.ogg"),
	preload("res://assets/sons/isha/miado_7.ogg"),
]
## Volume de cada som (dB, além da barra Efeitos). Medidos para os passos ficarem
## por volta de -36 dB, o tlin por volta de -32 dB e o tique bem abaixo; o miado
## fica no nível do tlin e dos passos.
const VOLUMES := {
	"clique": -13.0, "passar": -20.0,
	"madeira": -19.0, "grama": -14.0, "pedra": -14.0, "carpete": -15.0,
	"miado": -14.0,
}
const BARRA := "Efeitos"
const TOCADORES := 6  # sons ao mesmo tempo (os passos da grama são longos e se sobrepõem)

## O último som tocado e o nome dele (para os testes conferirem).
static var ultimo: AudioStream
static var ultimo_nome := ""

static var _instalado := false
static var _tocadores: Array[AudioStreamPlayer] = []
static var _proximo := 0
static var _ultimo_miado := -1
static var _tocador_do_miado: AudioStreamPlayer


## Liga o som de todos os botões, os que já estão na árvore e os que entrarem.
static func instalar() -> void:
	var arvore := Engine.get_main_loop() as SceneTree
	if not _instalado:
		_instalado = true
		arvore.node_added.connect(func(no: Node): _ligar(no))
	for botao in arvore.root.find_children("*", "BaseButton", true, false):
		_ligar(botao)


static func tocar_clique() -> void:
	_tocar(CLIQUE, "clique", randf_range(0.97, 1.03))


static func tocar_passar() -> void:
	_tocar(PASSAR, "passar", randf_range(0.95, 1.05))


## Um passo no piso `piso` ("madeira", "grama", "pedra" ou "carpete"), variado.
static func tocar_passo(piso: String) -> void:
	var lista: Array = PASSOS.get(piso, PASSOS.pedra)
	_tocar(lista.pick_random(), piso if PASSOS.has(piso) else "pedra", randf_range(0.92, 1.08))


## Um miado da Isha sorteado, nunca o mesmo duas vezes seguidas. A Isha tem uma voz
## só: um miado novo corta o que ainda estiver tocando (cliques seguidos não empilham).
static func tocar_miado() -> void:
	var sorteado := randi() % MIADOS.size()
	if _ultimo_miado >= 0:
		sorteado = randi() % (MIADOS.size() - 1)
		if sorteado >= _ultimo_miado:
			sorteado += 1  # pula o último
	_ultimo_miado = sorteado
	# (o tocador é do rodízio: só para se ainda for um miado, não o som de outra coisa)
	if is_instance_valid(_tocador_do_miado) and _tocador_do_miado.stream in MIADOS:
		_tocador_do_miado.stop()
	_tocador_do_miado = _tocar(MIADOS[sorteado], "miado", 1.0)


static func _ligar(no: Node) -> void:
	if not no is BaseButton or no.has_meta("_com_som") or no.get_meta("sem_som", false):
		return
	no.set_meta("_com_som", true)
	no.pressed.connect(func(): tocar_clique())
	if no is Button:
		no.mouse_entered.connect(func(): if not no.disabled: tocar_passar())


static func _tocar(som: AudioStream, nome: String, tom: float) -> AudioStreamPlayer:
	var tocador := _tocador_livre()
	tocador.stream = som
	tocador.volume_db = VOLUMES.get(nome, -14.0)
	tocador.pitch_scale = tom
	ultimo = som
	ultimo_nome = nome
	if tocador.is_inside_tree():
		tocador.play()
	else:
		tocador.play.call_deferred()
	return tocador


## Tocadores presos na raiz (os sons não cortam quando a cena troca), em rodízio.
static func _tocador_livre() -> AudioStreamPlayer:
	if _tocadores.is_empty() or not is_instance_valid(_tocadores[0]):
		_tocadores.clear()
		var raiz := (Engine.get_main_loop() as SceneTree).root
		for i in TOCADORES:
			var tocador := AudioStreamPlayer.new()
			tocador.name = "Som%d" % i
			tocador.bus = BARRA
			tocador.process_mode = Node.PROCESS_MODE_ALWAYS
			raiz.add_child.call_deferred(tocador)  # a raiz pode estar montando a cena nova
			_tocadores.append(tocador)
	_proximo = (_proximo + 1) % _tocadores.size()
	return _tocadores[_proximo]
