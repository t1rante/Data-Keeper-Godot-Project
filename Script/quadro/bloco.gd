extends Node2D
## Bloco do diagrama ER: entidade, relacionamento, atributo, especialização ou
## agregação (cenas em Cenas/). Quem trata o mouse e o teclado é o quadro
## (quadro.gd); o bloco guarda o próprio estado e se desenha. O nome vem
## do banco de palavras: o quadro chama definir_nome() quando o jogador solta
## uma palavra em cima do bloco.
##
## Notação desenhada por cima da forma:
##   selecionado ...................................... borda amarela por fora
##   palavra sendo arrastada por cima ................. borda rosa por fora
##   entidade fraca / relacionamento identificador ... contorno duplo
##   atributo multivalorado ........................... contorno duplo
##   atributo derivado ................................ contorno tracejado
##   atributo chave primária .......................... nome sublinhado

## O nome mudou (o quadro grava o save).
signal alterado

enum Formato { RETANGULO, LOSANGO, ELIPSE, TRIANGULO }

const COR_SELECAO := Color(1.0, 0.84, 0.0)
const COR_ALVO := Color(1.0, 0.45, 0.84)  # rosa dos post-its
const COR_TRACO := Color(0.08, 0.08, 0.1)
const COR_SEM_NOME := Color(0, 0, 0, 0.35)
const SEM_NOME := "nome"
const FOLGA_DO_CLIQUE := 6.0  # a borda aceita cliques um pouco para fora do desenho
const TAMANHO_DA_FONTE := 14
## Nome longo diminui a letra até este tamanho; se ainda não couber, quebra a linha.
const TAMANHO_MINIMO_DA_FONTE := 10
## Recuo do contorno duplo: as texturas de entidade e relacionamento têm borda grossa.
const RECUO_DA_BORDA_DUPLA := {Formato.RETANGULO: 12.0, Formato.LOSANGO: 12.0, Formato.ELIPSE: 6.0, Formato.TRIANGULO: 8.0}

## Marcas que cada tipo de bloco aceita: nome curto (usado pelo quadro) -> propriedade.
const MARCAS_POR_TIPO := {
	"atributos": {"chave": "chave_primaria", "derivado": "derivado", "multivalorado": "multivalorado"},
	"entidades": {"fraca": "entidade_fraca"},
	"relacionamentos": {"fraca": "relacionamento_identificador"},
}

@export var tipo_objeto := "entidades"
@export var formato := Formato.RETANGULO
## Tamanho da forma na tela; a textura de Forma é esticada para ele.
@export var tamanho := Vector2(150, 80)
## Caixa onde o nome aparece.
@export var tamanho_nome := Vector2(110, 28)
@export var centro_nome := Vector2.ZERO
## Desenha a forma de cabeça para baixo (a especialização é um triângulo invertido).
@export var virar_forma := false

var id_objeto := ""
var nome := ""
var chave_primaria := false
var derivado := false
var multivalorado := false
var entidade_fraca := false
var relacionamento_identificador := false
var selecionado := false:
	set(valor):
		selecionado = valor
		_atualizar_visual()
## Uma palavra do banco está sendo arrastada por cima do bloco.
var alvo := false:
	set(valor):
		alvo = valor
		_atualizar_visual()

var _contorno: PackedVector2Array
var _area_de_clique: PackedVector2Array
var _rotulo: Label
var _destaque: Line2D
var _dupla: Line2D
var _cobertura: Line2D
var _tracejado: Line2D
var _sublinhado: Line2D


func _ready():
	_ajustar_forma()
	_contorno = _poligono(0.0)
	_area_de_clique = _poligono(FOLGA_DO_CLIQUE)

	_cobertura = _nova_linha(_poligono(-1.0), Color.WHITE, 5.0)
	_tracejado = _nova_linha(_poligono(-1.0), COR_TRACO, 2.5)
	_tracejar(_tracejado)
	_dupla = _nova_linha(_poligono(-RECUO_DA_BORDA_DUPLA[formato]), COR_TRACO, 2.0)
	_destaque = _nova_linha(_poligono(5.0), COR_SELECAO, 3.0)
	_rotulo = _novo_rotulo()
	_sublinhado = _nova_linha(PackedVector2Array(), COR_TRACO, 2.0)
	_sublinhado.closed = false
	_atualizar_rotulo()
	_atualizar_visual()


# --- Perguntas do quadro --------------------------------------------------------

## O ponto (em coordenadas globais) cai sobre o bloco, borda incluída?
func contem(ponto: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(ponto), _area_de_clique)


## Onde a reta do centro do bloco até `alvo` cruza a borda (para as linhas
## começarem na borda, e não no meio do bloco).
func ponto_da_borda(alvo: Vector2) -> Vector2:
	var destino := to_local(alvo)
	var melhor := Vector2.ZERO
	var menor := INF
	for i in _contorno.size():
		var cruzamento = Geometry2D.segment_intersects_segment(
				Vector2.ZERO, destino, _contorno[i], _contorno[(i + 1) % _contorno.size()])
		if cruzamento != null and cruzamento.length() < menor:
			melhor = cruzamento
			menor = cruzamento.length()
	return to_global(melhor)


## Dados gravados no save (mesmo formato que o verificador lê).
func dados() -> Dictionary:
	var d := {"nome": nome, "posicao": {"x": global_position.x, "y": global_position.y}}
	match tipo_objeto:
		"entidades":
			d["cp"] = chave_primaria
			d["fraca"] = entidade_fraca
		"atributos":
			d["cp"] = chave_primaria
			d["derivado"] = derivado
			d["multivalorado"] = multivalorado
		"relacionamentos":
			d["identificador"] = relacionamento_identificador
		"agregacoes":
			d["nome"] = nome if nome != "" else "Agregação"
			d["relacionamento_envolvido"] = ""
	return d


# --- Marcas (teclas C, D, M e F no quadro) ---------------------------------------

## Liga/desliga uma marca ("chave", "derivado", "multivalorado" ou "fraca").
## Devolve false se este tipo de bloco não tem essa marca.
func alternar_marca(marca: String) -> bool:
	var propriedade = MARCAS_POR_TIPO.get(tipo_objeto, {}).get(marca)
	if propriedade == null:
		return false
	set(propriedade, not get(propriedade))
	_atualizar_visual()
	return true


# --- Nome (vem do banco de palavras) ----------------------------------------------

## Volta ao estado de um save (bloco.dados()), sem avisar o quadro.
func restaurar(dados: Dictionary):
	nome = str(dados.get("nome", ""))
	if tipo_objeto == "agregacoes" and nome == "Agregação":
		nome = ""  # nome que dados() põe quando o jogador não deu nenhum
	match tipo_objeto:
		"entidades":
			entidade_fraca = dados.get("fraca", false) == true
		"atributos":
			chave_primaria = dados.get("cp", false) == true
			derivado = dados.get("derivado", false) == true
			multivalorado = dados.get("multivalorado", false) == true
		"relacionamentos":
			relacionamento_identificador = dados.get("identificador", false) == true
	if is_node_ready():
		_atualizar_rotulo()
		_atualizar_visual()


func definir_nome(texto: String):
	if texto == nome:
		return
	nome = texto
	_atualizar_rotulo()
	alterado.emit()


# --- Desenho -------------------------------------------------------------------

func _atualizar_visual():
	if _destaque == null:
		return  # ainda não entrou na árvore
	_destaque.visible = selecionado or alvo
	_destaque.default_color = COR_ALVO if alvo else COR_SELECAO
	_dupla.visible = entidade_fraca or relacionamento_identificador or multivalorado
	_cobertura.visible = derivado
	_tracejado.visible = derivado
	_sublinhado.visible = chave_primaria


## Põe o nome na caixa: nome longo diminui a letra e, se ainda não couber,
## quebra em duas linhas. O sublinhado da chave acompanha o texto.
func _atualizar_rotulo():
	var vazio := nome == ""
	var texto := SEM_NOME if vazio else nome
	var fonte := _rotulo.get_theme_font("font")
	var tamanho_da_fonte := TAMANHO_DA_FONTE
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_fonte).x
	while largura > tamanho_nome.x and tamanho_da_fonte > TAMANHO_MINIMO_DA_FONTE:
		tamanho_da_fonte -= 1
		largura = fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_fonte).x
	var linhas := 2 if largura > tamanho_nome.x else 1

	_rotulo.text = texto
	_rotulo.add_theme_font_size_override("font_size", tamanho_da_fonte)
	_rotulo.add_theme_color_override("font_color", COR_SEM_NOME if vazio else COR_TRACO)
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if linhas > 1 else TextServer.AUTOWRAP_OFF
	var altura_do_texto := fonte.get_height(tamanho_da_fonte) * linhas
	_rotulo.size = Vector2(tamanho_nome.x, maxf(tamanho_nome.y, altura_do_texto))
	_rotulo.position = centro_nome - _rotulo.size / 2

	largura = minf(largura, tamanho_nome.x)
	var y := centro_nome.y + altura_do_texto / 2 + 1.0
	_sublinhado.points = PackedVector2Array([Vector2(centro_nome.x - largura / 2, y), Vector2(centro_nome.x + largura / 2, y)])


## Estica a parte desenhada da textura (region_rect) para ocupar `tamanho`.
func _ajustar_forma():
	var forma: Sprite2D = $Forma
	var desenho: Vector2 = forma.region_rect.size if forma.region_enabled else forma.texture.get_size()
	forma.centered = true
	forma.position = Vector2.ZERO
	forma.scale = tamanho / desenho
	forma.flip_v = virar_forma


## Contorno da forma, afastado `margem` pixels para fora (ou para dentro, se negativo).
func _poligono(margem: float) -> PackedVector2Array:
	var m := tamanho / 2
	var base := PackedVector2Array()
	match formato:
		Formato.RETANGULO:
			base = PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
		Formato.LOSANGO:
			base = PackedVector2Array([Vector2(0, -m.y), Vector2(m.x, 0), Vector2(0, m.y), Vector2(-m.x, 0)])
		Formato.TRIANGULO:
			var y := -1.0 if virar_forma else 1.0
			base = PackedVector2Array([Vector2(0, -m.y * y), Vector2(m.x, m.y * y), Vector2(-m.x, m.y * y)])
		Formato.ELIPSE:
			for i in 48:
				var angulo := TAU * i / 48
				base.append(Vector2(cos(angulo) * m.x, sin(angulo) * m.y))
	if margem == 0.0:
		return base
	var juncao := Geometry2D.JOIN_ROUND if formato == Formato.ELIPSE else Geometry2D.JOIN_MITER
	var resultado := Geometry2D.offset_polygon(base, margem, juncao)
	return resultado[0] if not resultado.is_empty() else base


func _nova_linha(pontos: PackedVector2Array, cor: Color, largura: float) -> Line2D:
	var linha := Line2D.new()
	linha.points = pontos
	linha.closed = true
	linha.width = largura
	linha.default_color = cor
	linha.joint_mode = Line2D.LINE_JOINT_ROUND
	linha.antialiased = true
	linha.visible = false
	add_child(linha)
	return linha


func _tracejar(linha: Line2D):
	var img := Image.create(16, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(0, 0, 8, 2), Color.WHITE)
	linha.texture = ImageTexture.create_from_image(img)
	linha.texture_mode = Line2D.LINE_TEXTURE_TILE
	linha.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _novo_rotulo() -> Label:
	var rotulo := Label.new()
	rotulo.name = "Nome"
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotulo)
	return rotulo
