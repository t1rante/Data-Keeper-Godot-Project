extends RefCounted
## Música de fundo. Um AudioStreamPlayer só, preso na raiz da árvore (e não numa
## cena), para a música continuar quando a cena troca: a do menu principal toca
## na tela de título e segue, sem recomeçar, na escolha de arquivo; quando o jogo
## começa (fluxo.gd), ela some aos poucos.
##
## Toca na barra de áudio "Musica": o volume da música das configurações vale
## para ela. O loop é da importação (aba Importar do editor, "Loop" ligado).
##
## Uso: Musica.tocar(Musica.MENU), Musica.parar(). Música nova: ponha o arquivo em
## assets/musica/, ligue o loop na importação e chame Musica.tocar(load(...)).

const MENU := preload("res://assets/musica/menu_principal.ogg")
const BARRA := "Musica"
const NOME_DO_NO := "MusicaDeFundo"
## Segundos para sumir em parar().
const SUMIR_EM := 0.8

static var _tocador: AudioStreamPlayer
static var _sumindo: Tween


## Toca `musica`. Se ela já está tocando, continua de onde está.
static func tocar(musica: AudioStream) -> void:
	var tocador := _o_tocador()
	if _sumindo and _sumindo.is_valid():
		_sumindo.kill()
		tocador.volume_db = 0.0
	if tocador.stream == musica and (tocador.playing or not tocador.is_inside_tree()):
		return
	tocador.stream = musica
	tocador.volume_db = 0.0
	if tocador.is_inside_tree():
		tocador.play()
	else:
		tocador.play.call_deferred()  # entra na árvore no fim do quadro (ver _o_tocador)


## Para a música; com `suave`, ela some em SUMIR_EM segundos.
static func parar(suave := true) -> void:
	if not is_instance_valid(_tocador) or not _tocador.playing:
		return
	if not suave or not _tocador.is_inside_tree():
		_tocador.stop()
		return
	if _sumindo and _sumindo.is_valid():
		return
	_sumindo = _tocador.create_tween()
	_sumindo.tween_property(_tocador, "volume_db", -40.0, SUMIR_EM)
	_sumindo.tween_callback(_tocador.stop)
	_sumindo.tween_callback(func(): _tocador.volume_db = 0.0)


## A música tocando agora (null se nenhuma).
static func tocando() -> AudioStream:
	if is_instance_valid(_tocador) and _tocador.playing:
		return _tocador.stream
	return null


static func _o_tocador() -> AudioStreamPlayer:
	if is_instance_valid(_tocador):
		return _tocador
	_tocador = AudioStreamPlayer.new()
	_tocador.name = NOME_DO_NO
	_tocador.bus = BARRA
	_tocador.process_mode = Node.PROCESS_MODE_ALWAYS  # não para com o jogo pausado
	# A raiz pode estar no meio de montar a cena nova (é quando as telas chamam
	# tocar(), no _ready): o tocador entra na árvore no fim do quadro.
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_tocador)
	return _tocador
