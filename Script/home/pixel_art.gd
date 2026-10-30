extends RefCounted
## Pixel art provisória, desenhada em código enquanto a arte da casa não fica
## pronta: o coração do carinho e o computador. (O protagonista é o sprite da
## caminhada, com a skin por shader, e a Isha tem sprite próprio.) Cada desenho
## é uma lista de linhas; cada letra é a cor de um pixel e "." é transparente.

const TINTA := Color("1a1030")  # contorno

const CORACAO := [
	".11.11.",
	"1221221",
	"1222221",
	".12221.",
	"..121..",
	"...1...",
]
const PALETA_DO_CORACAO := {"1": Color("c0307f"), "2": Color("ff74d7")}


## Desenha `linhas` em `alvo` (um CanvasItem, dentro do _draw dele) a partir de
## `origem`, cada pixel com `escala` x `escala`.
static func desenhar(alvo: CanvasItem, linhas: Array, paleta: Dictionary, origem: Vector2, escala: float) -> void:
	for y in linhas.size():
		var linha: String = linhas[y]
		for x in linha.length():
			var cor = paleta.get(linha[x])
			if cor != null:
				alvo.draw_rect(Rect2(origem + Vector2(x, y) * escala, Vector2(escala, escala)), cor)


static func tamanho(linhas: Array, escala: float) -> Vector2:
	return Vector2(linhas[0].length(), linhas.size()) * escala


## Computador provisório: monitor com a tela ciana, teclado e o pé.
static func desenhar_computador(alvo: CanvasItem, retangulo: Rect2, ligado: bool) -> void:
	var p := retangulo.position
	var s := retangulo.size
	var monitor := Rect2(p, Vector2(s.x, s.y * 0.72))
	alvo.draw_rect(monitor, TINTA)
	var tela := monitor.grow(-6)
	alvo.draw_rect(tela, Color("5cfff1") if ligado else Color("2a6f8f"))
	for y in range(int(tela.position.y) + 3, int(tela.end.y), 6):  # linhas de varredura
		alvo.draw_rect(Rect2(tela.position.x, y, tela.size.x, 2), Color(1, 1, 1, 0.18))
	alvo.draw_rect(Rect2(p.x + s.x * 0.4, monitor.end.y, s.x * 0.2, s.y * 0.1), TINTA)
	alvo.draw_rect(Rect2(p.x + s.x * 0.1, monitor.end.y + s.y * 0.1, s.x * 0.8, s.y * 0.18), Color("3a3060"))
	alvo.draw_rect(Rect2(p.x + s.x * 0.1, monitor.end.y + s.y * 0.1, s.x * 0.8, 3), TINTA)
