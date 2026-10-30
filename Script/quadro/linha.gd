extends Line2D
## Ligação entre dois blocos, com a cardinalidade escrita perto de uma das pontas.
## O quadro (quadro.gd) cuida dos cliques; a linha só se desenha.
## Ligações com atributo ou especialização não têm cardinalidade na notação ER,
## então nelas o número não aparece nem muda.

const COR_NORMAL := Color.WHITE
const COR_SELECIONADA := Color(1.0, 0.84, 0.0)
const DISTANCIA_DO_CLIQUE := 10.0
const PROXIMA_CARDINALIDADE := {"1": "N", "N": "M", "M": "1"}
const TIPOS_SEM_CARDINALIDADE := ["atributos", "especializacoes"]

var target1: Node2D = null
var target2: Node2D = null
var cardinalidade := "1"
var selecionada := false:
	set(valor):
		selecionada = valor
		default_color = COR_SELECIONADA if valor else COR_NORMAL

var _rotulo: Label


func _ready():
	width = 3.0
	default_color = COR_NORMAL
	antialiased = true

	_rotulo = Label.new()
	_rotulo.name = "LabelCardinalidade"
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.add_theme_font_size_override("font_size", 18)
	_rotulo.add_theme_color_override("font_color", Color.WHITE)
	_rotulo.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.35))
	_rotulo.add_theme_constant_override("outline_size", 6)
	add_child(_rotulo)


func definir_alvos(a: Node2D, b: Node2D):
	target1 = a
	target2 = b
	_atualizar()


func _process(_delta):
	if is_instance_valid(target1) and is_instance_valid(target2):
		_atualizar()
	else:
		queue_free()  # um dos blocos foi apagado


## Liga exatamente estes dois blocos (em qualquer ordem)?
func liga(a: Node2D, b: Node2D) -> bool:
	return (target1 == a and target2 == b) or (target1 == b and target2 == a)


## O ponto (global) está em cima da linha?
func perto(ponto: Vector2) -> bool:
	if points.size() < 2:
		return false
	var local := to_local(ponto)
	return local.distance_to(Geometry2D.get_closest_point_to_segment(local, points[0], points[1])) < DISTANCIA_DO_CLIQUE


func tem_cardinalidade() -> bool:
	return target1.tipo_objeto not in TIPOS_SEM_CARDINALIDADE \
			and target2.tipo_objeto not in TIPOS_SEM_CARDINALIDADE


## Troca 1 -> N -> M -> 1. Devolve false se a ligação não tem cardinalidade.
func alternar_cardinalidade() -> bool:
	if not tem_cardinalidade():
		return false
	cardinalidade = PROXIMA_CARDINALIDADE.get(cardinalidade, "1")
	_atualizar()
	return true


func dados() -> Dictionary:
	return {"de": target1.id_objeto, "para": target2.id_objeto, "cardinalidade": cardinalidade}


## Liga as bordas dos dois blocos e põe a cardinalidade perto da ponta que toca
## a entidade (ou da segunda ponta, se nenhuma ou as duas forem entidades).
func _atualizar():
	if not (is_instance_valid(target1) and is_instance_valid(target2)):
		return
	var a := to_local(target1.ponto_da_borda(target2.global_position))
	var b := to_local(target2.ponto_da_borda(target1.global_position))
	points = PackedVector2Array([a, b])

	var perto_de_a: bool = target1.tipo_objeto == "entidades" and target2.tipo_objeto != "entidades"
	var ponta := a if perto_de_a else b
	var outra := b if perto_de_a else a
	var direcao := (outra - ponta).normalized() if ponta != outra else Vector2.RIGHT
	var lado := Vector2(-direcao.y, direcao.x)

	_rotulo.visible = tem_cardinalidade()
	_rotulo.text = cardinalidade
	_rotulo.reset_size()
	_rotulo.position = ponta + direcao * 18.0 + lado * 13.0 - _rotulo.size / 2
