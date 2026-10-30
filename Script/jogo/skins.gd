extends RefCounted
## Skins do protagonista. Não existe sprite por skin: o sprite é sempre o da
## caminhada (Sprites/Personagens/blonde_man.png), em todas as cenas, e a skin
## troca cores dele por um shader de troca de paleta. Assim a roupa comprada
## aparece na casa, nas cinco cenas de caminhada e na prévia da loja.
##
## O retrato dos diálogos (Sprites/Personagens/Player.png) é pintado, com muitos
## tons: lá a jaqueta é marcada por uma máscara (Player_mascara_jaqueta.png) e o
## shader do retrato põe nela o tom da cor "jaqueta" da skin, guardando a luz e
## a sombra da pintura. acompanhar_retratos() veste o retrato sempre que o
## Dialogic o mostra (fluxo.gd chama antes de cada conversa). A máscara e a cor
## média saem de ferramentas/gerar_mascara_do_retrato.py.
##
## Cada skin do catálogo (dados/catalogo.json) diz só as partes que mudam, pelo
## nome: {"jaqueta": "#ff74d7", "jaqueta_sombra": "#c0307f"}. As cores originais
## de cada parte estão em CORES_DO_SPRITE.
##
## Uso: Skins.aplicar(sprite) em qualquer CanvasItem que desenhe esse sprite.

const MASCARA_DO_RETRATO := preload("res://Sprites/Personagens/Player_mascara_jaqueta.png")
## Cor média (h, s, v) da jaqueta do retrato original, medida dentro da máscara.
const JAQUETA_DO_RETRATO := Vector3(0.02, 0.887, 0.569)
## Identificador do protagonista no Dialogic (Timeline/Character/Player.dch).
const PERSONAGEM_DO_RETRATO := "Player"

const Jogo = preload("res://Script/jogo/jogo.gd")
const Catalogo = preload("res://Script/jogo/catalogo.gd")

const SPRITE := preload("res://Sprites/Personagens/blonde_man.png")
## Cores do sprite original, por parte (12 cores ao todo; estas são as trocáveis).
const CORES_DO_SPRITE := {
	"jaqueta": Color("e83b3b"),
	"jaqueta_sombra": Color("ae2334"),
	"camisa": Color("ffffff"),
	"calca": Color("cd683d"),
	"calca_sombra": Color("9e4539"),
	"cabelo": Color("f79617"),
	"cabelo_sombra": Color("fb6b1d"),
	"cabelo_brilho": Color("f9c22b"),
	"pele": Color("fdcbb0"),
	"pele_sombra": Color("fca790"),
}
const MAXIMO := 10
const SHADER := """
shader_type canvas_item;
// Troca de paleta: cada cor 'de[i]' do sprite vira 'para[i]'.
uniform vec4 de[10];
uniform vec4 para[10];
uniform int quantas = 0;
varying vec4 modulacao;

void vertex() {
	modulacao = COLOR;
}

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	for (int i = 0; i < 10; i++) {
		if (i >= quantas) {
			break;
		}
		if (distance(cor.rgb, de[i].rgb) < 0.02) {
			cor.rgb = para[i].rgb;
			break;
		}
	}
	COLOR = cor * modulacao;
}
"""
const SHADER_DO_RETRATO := """
shader_type canvas_item;
// Pinta a região da máscara com o tom da skin, mantendo luz e sombra da pintura.
uniform sampler2D mascara : filter_linear;
uniform vec3 base_hsv;
uniform vec3 alvo_hsv;
uniform bool trocar = false;
varying vec4 modulacao;

vec3 rgb_para_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv_para_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	modulacao = COLOR;
}

void fragment() {
	vec4 cor = texture(TEXTURE, UV);
	float m = trocar ? texture(mascara, UV).r : 0.0;
	if (m > 0.0) {
		vec3 hsv = rgb_para_hsv(cor.rgb);
		vec3 novo = hsv_para_rgb(vec3(alvo_hsv.x, clamp(hsv.y * alvo_hsv.y / base_hsv.y, 0.0, 1.0),
				clamp(hsv.z * alvo_hsv.z / base_hsv.z, 0.0, 1.0)));
		cor.rgb = mix(cor.rgb, novo, m);
	}
	COLOR = cor * modulacao;
}
"""

static var _shader: Shader
static var _shader_do_retrato: Shader
static var _acompanhando := false


## Material com as cores da skin `id` (vazio = a skin em uso no jogo).
static func material(id := "") -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var skin := Catalogo.item(id if id != "" else str(Jogo.equipados.get("skin", "skin_padrao")))
	var de := PackedColorArray()
	var para := PackedColorArray()
	var cores = skin.get("cores", {})
	for parte in (cores if cores is Dictionary else {}):
		if CORES_DO_SPRITE.has(parte) and de.size() < MAXIMO:
			de.append(CORES_DO_SPRITE[parte])
			para.append(Color(cores[parte]))
	var quantas := de.size()
	while de.size() < MAXIMO:  # o shader espera as listas cheias
		de.append(Color.BLACK)
		para.append(Color.BLACK)
	var resultado := ShaderMaterial.new()
	resultado.shader = _shader
	resultado.set_shader_parameter("de", de)
	resultado.set_shader_parameter("para", para)
	resultado.set_shader_parameter("quantas", quantas)
	return resultado


## Veste o protagonista desenhado por `alvo` com a skin `id` (vazio = a em uso).
static func aplicar(alvo: CanvasItem, id := "") -> void:
	alvo.material = material(id)


## Material do retrato dos diálogos com a skin `id` (vazio = a em uso). A skin
## sem cor de "jaqueta" (a padrão) deixa o retrato como foi pintado.
static func material_do_retrato(id := "") -> ShaderMaterial:
	if _shader_do_retrato == null:
		_shader_do_retrato = Shader.new()
		_shader_do_retrato.code = SHADER_DO_RETRATO
	var skin := Catalogo.item(id if id != "" else str(Jogo.equipados.get("skin", "skin_padrao")))
	var cores = skin.get("cores", {})
	var jaqueta = cores.get("jaqueta") if cores is Dictionary else null
	var resultado := ShaderMaterial.new()
	resultado.shader = _shader_do_retrato
	resultado.set_shader_parameter("mascara", MASCARA_DO_RETRATO)
	resultado.set_shader_parameter("base_hsv", JAQUETA_DO_RETRATO)
	resultado.set_shader_parameter("trocar", jaqueta != null)
	if jaqueta != null:
		var alvo := Color(jaqueta)
		resultado.set_shader_parameter("alvo_hsv", Vector3(alvo.h, alvo.s, alvo.v))
	return resultado


## Passa a vestir o retrato do protagonista sempre que o Dialogic o mostrar
## (entrar na conversa ou trocar de retrato). Pode chamar quantas vezes quiser.
static func acompanhar_retratos() -> void:
	# Pela árvore, e não pelo nome do autoload: assim este script compila em
	# qualquer contexto (os testes o carregam antes dos autoloads existirem).
	var dialogic = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Dialogic")
	if _acompanhando or dialogic == null:
		return
	_acompanhando = true
	dialogic.Portraits.character_joined.connect(func(info): vestir_retrato(info))
	dialogic.Portraits.character_portrait_changed.connect(func(info): vestir_retrato(info))


## `info` dos sinais de retrato do Dialogic: se for o protagonista, aplica a skin.
static func vestir_retrato(info: Dictionary) -> void:
	var personagem = info.get("character")
	var no = info.get("node")
	if personagem == null or personagem.get_identifier() != PERSONAGEM_DO_RETRATO or not is_instance_valid(no):
		return
	if no.get_child_count() == 0:
		return
	var imagem = no.get_child(-1).get_node_or_null("Portrait")
	if imagem is CanvasItem:
		imagem.material = material_do_retrato()


## Quadro parado de frente do sprite (para a prévia da loja).
static func quadro_de_frente() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SPRITE
	atlas.region = Rect2(0, 0, 32, 32)
	return atlas
