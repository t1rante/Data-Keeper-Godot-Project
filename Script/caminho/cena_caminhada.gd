extends Node
## Cena da caminhada até o trabalho (Cenas/caminho/: casa, quintal, rua,
## escritorio_1, escritorio_2): toca a animação e, quando ela termina, vai para a
## próxima cena. A última (vai_para_o_cliente) chega ao escritório: aí o fluxo
## salva o savepoint "antes do cliente", começa a conversa do cliente do dia e
## abre o quadro (fluxo.gd). Enter, Esc ou um clique pulam a caminhada inteira.
## O protagonista (nó Player) anda com a skin em uso (skins.gd) e faz o som dos
## passos no chão da cena (`piso`), nos quadros em que o pé toca o chão.

const Fluxo = preload("res://Script/jogo/fluxo.gd")
const Skins = preload("res://Script/jogo/skins.gd")
const Sons = preload("res://Script/jogo/sons.gd")

@export var animacao: StringName
@export_file("*.tscn") var proxima_cena: String
## Última cena da caminhada: em vez de proxima_cena, vai para o cliente do dia.
@export var vai_para_o_cliente := false
## Chão desta cena: o som dos passos (sons.gd).
@export_enum("madeira", "grama", "pedra", "carpete") var piso := "pedra"

var _saindo := false
var _ultimo_quadro := -1
var _ultima_posicao := Vector2.ZERO


func _ready() -> void:
	if has_node("Player"):
		Skins.aplicar($Player)
	$AnimationPlayer.play(animacao)
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)


## Passo nos quadros ímpares da caminhada (17, 19, 21, 23: o pé no chão), só
## quando o protagonista está andando (parado, o quadro 0 não faz som).
func _process(_delta: float) -> void:
	if not has_node("Player"):
		return
	var jogador: Sprite2D = $Player
	if jogador.frame == _ultimo_quadro:
		return
	var andou := jogador.position.distance_to(_ultima_posicao) > 0.5
	_ultimo_quadro = jogador.frame
	_ultima_posicao = jogador.position
	if andou and jogador.frame % 2 == 1:
		Sons.tocar_passo(piso)


func _unhandled_input(event: InputEvent) -> void:
	var pular: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventMouseButton and event.pressed)
	if pular:
		get_viewport().set_input_as_handled()
		_chegar_ao_cliente()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != animacao:
		return
	if vai_para_o_cliente or proxima_cena == "":
		_chegar_ao_cliente()
	else:
		get_tree().change_scene_to_file(proxima_cena)


func _chegar_ao_cliente() -> void:
	if _saindo:
		return
	_saindo = true
	Fluxo.ir_para_o_cliente()
