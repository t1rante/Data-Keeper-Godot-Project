class_name MenuLateral
extends Control
## Menu lateral recolhível do quadro: um painel preso na borda da tela, com uma
## aba pequena ([<]) para mostrar e esconder (Cenas/quadro/menu_lateral.tscn).
##
## Para criar outro menu (por exemplo, o banco de palavras do problema):
##   1. Instancie Cenas/quadro/menu_lateral.tscn dentro de UI/MenusLaterais no quadro.
##   2. No Inspetor escolha o lado, a posição da aba (menus do mesmo lado precisam
##      de alturas diferentes) e o título; o tamanho do nó é o tamanho do painel.
##   3. Ponha o conteúdo como filhos do menu, em coordenadas do painel.
## O quadro (quadro.gd) cuida do resto: esconde os menus enquanto a planta
## não está na tela e põe os blocos novos fora da parte coberta por um menu aberto.
## Só um menu fica aberto por lado: abrir um fecha o outro. As abas dos menus
## fechados acompanham a borda do painel aberto, uma embaixo da outra.

## O menu abriu (true) ou fechou (false).
signal alternado(aberto: bool)

enum Lado { ESQUERDA, DIREITA }

const GRUPO := "menus_laterais"
const DURACAO_DA_ANIMACAO := 0.2

@export var lado := Lado.DIREITA
## Distância do topo do painel até a aba.
@export var posicao_da_aba := 14.0
## Aparece ao passar o mouse na aba.
@export var titulo := ""
@export var aberto_no_inicio := false
## Faz a aba piscar de leve até o jogador abrir o menu pela primeira vez.
@export var chamar_atencao := true

var aberto := false

var _ja_foi_aberto := false
var _animacao: Tween
var _animacao_da_aba: Tween
var _pulso: Tween

@onready var _aba: Button = $Aba


func _ready():
	add_to_group(GRUPO)
	_arredondar_do_lado_do_quadro()
	_aba.pressed.connect(alternar)
	_aba.tooltip_text = titulo
	aberto = aberto_no_inicio
	_ja_foi_aberto = aberto
	position.x = _x_aberto() if aberto else _x_fechado()
	_aba.position = Vector2(_x_da_aba(), posicao_da_aba)
	_mover_aba.call_deferred(false)  # quando os outros menus já estiverem no grupo
	_atualizar_aba()


func abrir():
	definir_aberto(true)


func fechar():
	definir_aberto(false)


func alternar():
	definir_aberto(not aberto)


func definir_aberto(valor: bool):
	if valor == aberto:
		return
	aberto = valor
	if aberto:
		_ja_foi_aberto = true
		for outro in _do_mesmo_lado():
			outro.fechar()

	if _animacao:
		_animacao.kill()
	_animacao = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animacao.tween_property(self, "position:x", _x_aberto() if aberto else _x_fechado(), DURACAO_DA_ANIMACAO)
	_mover_aba()
	for outro in _do_mesmo_lado():
		outro._mover_aba()
	_atualizar_aba()
	alternado.emit(aberto)


## Parte da tela coberta pelo painel aberto, aba incluída (vazia se estiver fechado).
## Usa onde painel e aba vão parar, não onde estão no meio da animação.
func area_ocupada() -> Rect2:
	if not aberto:
		return Rect2()
	var painel := Rect2(Vector2(_x_aberto(), position.y), size)
	return painel.merge(Rect2(painel.position + Vector2(_x_da_aba(), _aba.position.y), _aba.size))


func _x_aberto() -> float:
	return get_viewport_rect().size.x - size.x if lado == Lado.DIREITA else 0.0


func _x_fechado() -> float:
	return get_viewport_rect().size.x if lado == Lado.DIREITA else -size.x


func _do_mesmo_lado() -> Array:
	return get_tree().get_nodes_in_group(GRUPO).filter(func(menu): return menu != self and menu.lado == lado)


## X da aba em relação ao painel. Com outro menu do mesmo lado aberto, a aba de
## um menu fechado fica na borda do painel aberto, e não por cima dele.
func _x_da_aba() -> float:
	var deslocamento := 0.0
	if not aberto:
		for outro in _do_mesmo_lado():
			if outro.aberto:
				deslocamento = outro.size.x
	return -_aba.size.x - deslocamento if lado == Lado.DIREITA else size.x + deslocamento


## Anda junto com o painel (mesma duração), então a aba de um menu que abre ou
## fecha enquanto o vizinho faz o contrário fica parada na tela.
func _mover_aba(animar := true):
	if _animacao_da_aba:
		_animacao_da_aba.kill()
	if not animar:
		_aba.position.x = _x_da_aba()
		return
	_animacao_da_aba = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animacao_da_aba.tween_property(_aba, "position:x", _x_da_aba(), DURACAO_DA_ANIMACAO)


## O painel e a aba ficam arredondados do lado que dá para o quadro.
func _arredondar_do_lado_do_quadro():
	var estilos := [[$Fundo, "panel"], [_aba, "normal"], [_aba, "hover"], [_aba, "pressed"]]
	for par in estilos:
		var estilo: StyleBoxFlat = par[0].get_theme_stylebox(par[1]).duplicate()
		var raio: int = maxi(estilo.corner_radius_top_left, estilo.corner_radius_top_right)
		var esquerda := raio if lado == Lado.DIREITA else 0
		var direita := 0 if lado == Lado.DIREITA else raio
		estilo.corner_radius_top_left = esquerda
		estilo.corner_radius_bottom_left = esquerda
		estilo.corner_radius_top_right = direita
		estilo.corner_radius_bottom_right = direita
		par[0].add_theme_stylebox_override(par[1], estilo)


func _atualizar_aba():
	var seta_para_a_direita := aberto == (lado == Lado.DIREITA)
	_aba.text = ">" if seta_para_a_direita else "<"

	if _pulso:
		_pulso.kill()
		_aba.modulate = Color.WHITE
	if chamar_atencao and not _ja_foi_aberto:
		_pulso = create_tween().set_loops()
		_pulso.tween_property(_aba, "modulate", Color(1.6, 1.6, 1.6), 0.7)
		_pulso.tween_property(_aba, "modulate", Color.WHITE, 0.7)
