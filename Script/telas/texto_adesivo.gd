@tool
extends Control
## Texto no estilo do logo da tela de título (assets/logo_data_keepers.png, que copia o
## estilo do logo antigo "BANCO de DADOS", assets/Jogo de Banco de Dados.png):

const FONTE := preload("res://assets/04b_19/04B_19__.TTF")
const DEGRADE := """
shader_type canvas_item;
uniform vec4 cor_de_cima : source_color;
uniform vec4 cor_de_baixo : source_color;
uniform float topo;
uniform float altura;
varying float y;

void vertex() {
	y = VERTEX.y;
}

void fragment() {
	// O contorno é preto, então só as letras (brancas) recebem o degradê.
	COLOR.rgb *= mix(cor_de_cima.rgb, cor_de_baixo.rgb, clamp((y - topo) / altura, 0.0, 1.0));
}
"""
const CONTORNO := 6

@export var texto := "TEXTO":
	set(valor):
		texto = valor
		_montar()
@export var tamanho_da_fonte := 48:
	set(valor):
		tamanho_da_fonte = valor
		_montar()
@export var cor_de_cima := Color(0.68, 0.95, 0.95):
	set(valor):
		cor_de_cima = valor
		_montar()
@export var cor_de_baixo := Color(0.65, 0.4, 0.73):
	set(valor):
		cor_de_baixo = valor
		_montar()
## Deslocamento da sombra preta.
@export var sombra := Vector2(4, 6):
	set(valor):
		sombra = valor
		_montar()
## Largura da borda branca do adesivo.
@export var borda := 8:
	set(valor):
		borda = valor
		_montar()

var _degrade: ShaderMaterial


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_montar()


func _montar():
	if not is_node_ready():
		return
	for filho in get_children():
		filho.queue_free()
	if _degrade == null:
		var shader := Shader.new()
		shader.code = DEGRADE
		_degrade = ShaderMaterial.new()
		_degrade.shader = shader
	var altura := FONTE.get_height(tamanho_da_fonte)
	_degrade.set_shader_parameter("cor_de_cima", cor_de_cima)
	_degrade.set_shader_parameter("cor_de_baixo", cor_de_baixo)
	_degrade.set_shader_parameter("topo", altura * 0.15)
	_degrade.set_shader_parameter("altura", altura * 0.7)

	var inicio := Vector2(borda, borda)
	_camada(inicio + sombra, Color.BLACK, Color.WHITE, CONTORNO + 2 * borda)
	_camada(inicio, Color.BLACK, Color.WHITE, CONTORNO + 2 * borda)
	_camada(inicio + sombra, Color.BLACK, Color.BLACK, CONTORNO)
	_camada(inicio, Color.WHITE, Color.BLACK, CONTORNO).material = _degrade
	var tamanho := FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_da_fonte)
	custom_minimum_size = Vector2(tamanho.x, altura) + inicio * 2 + sombra
	size = custom_minimum_size


func _camada(posicao: Vector2, cor: Color, cor_do_contorno: Color, contorno: int) -> Label:
	var camada := Label.new()
	camada.text = texto
	camada.position = posicao
	camada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_theme_font_override("font", FONTE)
	camada.add_theme_font_size_override("font_size", tamanho_da_fonte)
	camada.add_theme_color_override("font_color", cor)
	camada.add_theme_color_override("font_outline_color", cor_do_contorno)
	camada.add_theme_constant_override("outline_size", contorno)
	add_child(camada)
	return camada
