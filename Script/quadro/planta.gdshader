// Planta azul do quadro, desenhada aqui em vez de ser uma imagem: assim ela continua
// quando o jogador tira o zoom ou arrasta o fundo (quadro.gd). As cores e a grade
// são as da imagem antiga (assets/azul2.png): uma linha clara a cada 42,5 px do
// quadro, centro mais claro e cantos mais escuros. A grade é do quadro (acompanha
// zoom e arrasto); o clareado do centro é da tela (fica igual em qualquer zoom).
shader_type canvas_item;

uniform vec4 cor_do_centro : source_color = vec4(0.114, 0.588, 0.996, 1.0);
uniform vec4 cor_da_borda : source_color = vec4(0.031, 0.424, 0.906, 1.0);
uniform vec4 cor_da_linha : source_color = vec4(0.769, 0.894, 0.996, 0.92);
uniform float espaco = 42.5;     // entre as linhas, em pixels do quadro
uniform float espessura = 2.3;   // largura da linha, em pixels do quadro

varying vec2 no_quadro;

void vertex() {
	no_quadro = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 celula = mod(no_quadro, espaco);
	vec2 ate_a_linha = min(celula, espaco - celula);
	// Tamanho de um pixel da tela, em pixels do quadro: a linha nunca fica mais fina que ~1 pixel.
	float pixel = max(fwidth(no_quadro.x), 0.0001);
	float meia = max(espessura * 0.5, pixel * 0.6);
	float linha = 1.0 - smoothstep(meia - pixel * 0.5, meia + pixel * 0.5, min(ate_a_linha.x, ate_a_linha.y));
	float raio = distance(SCREEN_UV, vec2(0.5)) / 0.7071;
	vec4 fundo = mix(cor_do_centro, cor_da_borda, smoothstep(0.0, 1.0, raio));
	COLOR = vec4(mix(fundo.rgb, cor_da_linha.rgb, linha * cor_da_linha.a), 1.0);
}
