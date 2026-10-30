extends RefCounted
## Correção do diagrama: compara o diagrama do jogador com o gabarito, dá a nota
## e explica cada ponto que faltou para 100%.
##
## Quem casa e pontua é correcao_do_diagrama.gd; aqui ficam os pesos, a escolha
## entre as respostas aceitas e o relatório. Formato completo do gabarito em
## fases/COMO_ESCREVER_GABARITOS.md; resumo:
##   "diagrama": {"nome", "entidades", "relacionamentos", "especializacoes", "agregacoes"}
##   "alternativas": [outros diagramas igualmente certos]  (vale a melhor nota)
##   "correcao": {"pesos": {...}, "creditoPorPapel": 0.5, ...}  (troca PESOS_PADRAO/REGRAS_PADRAO)
##
## A nota é pontos obtidos / (pontos possíveis + penalidades). Cada item do
## relatório diz quanto ele tirou da nota, e a soma deles é o que falta para 100%.

const Correcao = preload("res://Script/correcao/correcao_do_diagrama.gd")

## Quanto vale cada requisito do gabarito.
const PESOS_PADRAO := {
	"entidade": 2.0,        # entidade com o nome certo
	"atributo": 1.0,        # atributo no dono certo
	"relacionamento": 1.0,  # nome do relacionamento
	"participacao": 1.0,    # cada entidade que o relacionamento liga
	"cardinalidade": 1.0,   # cada ponta do relacionamento
	"marcacao": 1.0,        # chave, derivado, multivalorado, entidade fraca, identificador
	"especializacao": 1.0,  # cada entidade ligada à especialização (e o rótulo, se houver)
	"agregacao": 1.0,       # a agregação e a ligação com o relacionamento que ela envolve
	"extra": 1.0,           # penalidade por bloco ou ligação além do modelo
	"notacao": 1.0,         # penalidade por ligação que a notação não permite
}
const REGRAS_PADRAO := {
	"limiarPapel": 0.5,         # fração de atributos/ligações iguais para casar uma entidade pelo papel
	"creditoPorPapel": 0.5,     # quanto vale a entidade certa com o nome errado
	"creditoForaDoLugar": 0.5,  # quanto vale o atributo certo ligado ao bloco errado
	"atributosExtras": "avisar",  # atributo a mais: "avisar" (não desconta) ou "penalizar"
}
## Ordem das partes no relatório.
const CATEGORIAS := ["Entidades", "Atributos", "Relacionamentos", "Cardinalidades", "Marcações",
		"Especializações", "Agregações", "Itens a mais", "Notação"]
const SEPARADOR := "---------------------------------------------"
const CORES := {"bom": "#7bd88f", "medio": "#ffd866", "ruim": "#ff8a7a", "apagado": "#a0a0a0"}


## Relatório em texto puro (compatível com a versão antiga).
static func verificar(diagrama: Dictionary, caminho_gabarito: String) -> String:
	return relatorio(avaliar_arquivo(diagrama, caminho_gabarito))


static func avaliar_arquivo(diagrama: Dictionary, caminho_gabarito: String) -> Dictionary:
	if not FileAccess.file_exists(caminho_gabarito):
		return {"erro": "Arquivo de gabarito não encontrado: " + caminho_gabarito}
	var gabarito = JSON.parse_string(FileAccess.get_file_as_string(caminho_gabarito))
	if not gabarito is Dictionary:
		return {"erro": "O gabarito não é um JSON válido: " + caminho_gabarito}
	return avaliar(diagrama, gabarito)


## `diagrama` tem o formato do save (ver quadro.gd, estado_do_diagrama()).
## Devolve {"porcentagem", "obtido", "total", "penalidade", "categorias",
## "perdas", "avisos", "modelo", "alternativa"} ou {"erro"}.
static func avaliar(diagrama: Dictionary, gabarito: Dictionary) -> Dictionary:
	var modelos := []
	if gabarito.get("diagrama") is Dictionary:
		modelos.append(gabarito.diagrama)
	var alternativas = gabarito.get("alternativas", [])
	for alternativa in (alternativas if alternativas is Array else []):
		if alternativa is Dictionary:
			modelos.append(alternativa.diagrama if alternativa.get("diagrama") is Dictionary else alternativa)
	if modelos.is_empty():
		return {"erro": "O gabarito não possui a chave raiz 'diagrama'."}

	var pesos := PESOS_PADRAO.duplicate()
	var regras := REGRAS_PADRAO.duplicate()
	var ajustes = gabarito.get("correcao", {})
	if ajustes is Dictionary:
		for chave in ajustes:
			if chave == "pesos" and ajustes.pesos is Dictionary:
				pesos.merge(ajustes.pesos, true)
			elif regras.has(chave):
				regras[chave] = ajustes[chave]

	var melhor := {}
	for i in modelos.size():
		var resultado: Dictionary = Correcao.new(pesos, regras).corrigir(diagrama, modelos[i])
		resultado["modelo"] = str(modelos[i].get("nome", "alternativa %d" % i))
		resultado["alternativa"] = i
		if melhor.is_empty() or resultado.porcentagem > melhor.porcentagem + 0.001:
			melhor = resultado
	return melhor


## Texto do resultado; com `bbcode`, para um RichTextLabel (cores e tabela).
static func relatorio(resultado: Dictionary, bbcode := false) -> String:
	if resultado.has("erro"):
		return "❌ Erro: " + str(resultado.erro)
	var nota: float = resultado.porcentagem
	var base: float = resultado.total + resultado.penalidade
	var linhas := PackedStringArray()

	if not bbcode:
		linhas.append(SEPARADOR)
	linhas.append(_negrito("CORREÇÃO: " + str(resultado.modelo).to_upper(), bbcode))
	if resultado.alternativa > 0:
		linhas.append(_cor("Comparado com uma resposta alternativa que também está certa.", "apagado", bbcode))
	var cor_da_nota := "bom" if nota >= 99.95 else ("medio" if nota >= 60.0 else "ruim")
	linhas.append(_cor(_negrito("Nota: %s%%" % formatar_numero(nota), bbcode), cor_da_nota, bbcode) + "  " + _veredito(nota))
	var pontos := "Pontos: %s de %s" % [formatar_numero(resultado.obtido), formatar_numero(resultado.total)]
	if resultado.penalidade > 0.0:
		pontos += " (mais %s de penalidade: %s de %s)" % [formatar_numero(resultado.penalidade), formatar_numero(resultado.obtido), formatar_numero(base)]
	linhas.append(pontos)

	linhas.append("" if bbcode else SEPARADOR)
	linhas.append(_negrito("Por parte do diagrama:", bbcode))
	linhas.append_array(_tabela_das_partes(resultado.categorias, bbcode))

	if not resultado.perdas.is_empty():
		linhas.append("" if bbcode else SEPARADOR)
		linhas.append(_negrito("Por que não foi 100%:", bbcode))
		for grupo in perdas_por_categoria(resultado):
			linhas.append(_negrito("%s (−%s%%)" % [grupo.categoria, formatar_numero(grupo.impacto)], bbcode))
			for perda in grupo.perdas:
				linhas.append("   " + _cor("−%s%%" % formatar_numero(perda.impacto), "ruim", bbcode)
						+ "  " + _escapar(perda.mensagem, bbcode))

	if not resultado.avisos.is_empty():
		linhas.append("" if bbcode else SEPARADOR)
		linhas.append(_negrito("Observações (não descontam):", bbcode))
		for aviso in resultado.avisos:
			linhas.append("   • " + _cor(_escapar(aviso, bbcode), "apagado", bbcode))
	if not bbcode:
		linhas.append(SEPARADOR)
	return "\n".join(linhas)


static func _tabela_das_partes(categorias: Dictionary, bbcode: bool) -> PackedStringArray:
	var linhas := PackedStringArray()
	if bbcode:
		linhas.append("[table=2]")
	for categoria in CATEGORIAS:
		if not categorias.has(categoria):
			continue
		var placar: Dictionary = categorias[categoria]
		var partes := PackedStringArray()
		if placar.total > 0.0:
			var cor := "bom" if placar.obtido >= placar.total - 0.0001 else ("medio" if placar.obtido > 0.0 else "ruim")
			partes.append(_cor("%s de %s" % [formatar_numero(placar.obtido), formatar_numero(placar.total)], cor, bbcode))
		if placar.penalidade > 0.0:
			partes.append(_cor("−%s de penalidade" % formatar_numero(placar.penalidade), "ruim", bbcode))
		var valor := ", ".join(partes)
		if bbcode:
			linhas.append("[cell]   %s[/cell][cell]  %s[/cell]" % [categoria, valor])
		else:
			linhas.append("   %s %s" % [(categoria + " ").rpad(18, "."), valor])
	if bbcode:
		linhas.append("[/table]")
	return linhas


static func _veredito(nota: float) -> String:
	if nota >= 99.95:
		return "Diagrama perfeito!"
	if nota >= 85.0:
		return "Quase lá!"
	if nota >= 60.0:
		return "Bom caminho, mas ainda tem ajustes."
	return "Ainda falta bastante; comece pelos itens abaixo."


## Perdas agrupadas por parte do diagrama, na ordem de CATEGORIAS, cada grupo com
## as maiores perdas primeiro. `impacto` é quanto tirou da nota, em pontos percentuais:
## [{"categoria", "impacto", "perdas": [{"impacto", "mensagem"}]}]
static func perdas_por_categoria(resultado: Dictionary) -> Array:
	var base: float = resultado.total + resultado.penalidade
	var grupos := []
	for categoria in CATEGORIAS:
		var da_parte := []
		for i in resultado.perdas.size():
			var perda: Dictionary = resultado.perdas[i]
			if perda.categoria == categoria:
				da_parte.append({"impacto": 100.0 * perda.pontos / base, "mensagem": perda.mensagem, "ordem": i})
		if da_parte.is_empty():
			continue
		# Empate fica na ordem em que as perdas foram achadas.
		da_parte.sort_custom(func(a, b): return a.impacto > b.impacto or (a.impacto == b.impacto and a.ordem < b.ordem))
		var soma := 0.0
		for perda in da_parte:
			soma += perda.impacto
		grupos.append({"categoria": categoria, "impacto": soma, "perdas": da_parte})
	return grupos


## Nomes que o jogador precisa usar para resolver o modelo principal do
## gabarito: entidades (inclusive as só citadas em relacionamentos), atributos
## não opcionais, relacionamentos sem "nomeLivre" e rótulos de especialização.
## [{"tipo", "nome", "aceitos"}], sem repetir nome.
static func nomes_exigidos(gabarito: Dictionary) -> Array:
	var modelo = gabarito.get("diagrama", {})
	if not modelo is Dictionary:
		return []
	var nomes := []
	var vistos := {}
	var anotar := func(tipo: String, dados):
		var nome := str(dados.get("nome", "")).strip_edges() if dados is Dictionary else str(dados).strip_edges()
		if nome == "" or vistos.has(nome):
			return
		vistos[nome] = true
		var aceitos := [nome]
		if dados is Dictionary and dados.get("sinonimos") is Array:
			aceitos.append_array(dados.sinonimos.map(func(s): return str(s).strip_edges()))
		nomes.append({"tipo": tipo, "nome": nome, "aceitos": aceitos})
	var anotar_atributos := func(lista, proprio: Callable):
		for atributo in (lista if lista is Array else []):
			if atributo is Dictionary and atributo.get("opcional", false) != true:
				anotar.call("atributos", atributo)
				proprio.call(atributo.get("componentes", []), proprio)

	for entidade in modelo.get("entidades", []):
		if entidade is Dictionary:
			anotar.call("entidades", entidade)
			anotar_atributos.call(entidade.get("atributos", []), anotar_atributos)
	for relacionamento in modelo.get("relacionamentos", []):
		if not relacionamento is Dictionary:
			continue
		var pontas = relacionamento.get("participantes", [relacionamento.get("entidadeOrigem"), relacionamento.get("entidadeDestino")])
		for ponta in pontas:
			if ponta is Dictionary or ponta is String:
				anotar.call("entidades", ponta)
		if relacionamento.get("nomeLivre", false) != true:
			anotar.call("relacionamentos", relacionamento)
		anotar_atributos.call(relacionamento.get("atributosRelacionamento", relacionamento.get("atributos", [])), anotar_atributos)
	for especializacao in modelo.get("especializacoes", []):
		if especializacao is Dictionary:
			anotar.call("entidades", especializacao.get("entidadePai", ""))
			for filha in especializacao.get("entidadesFilhas", []):
				anotar.call("entidades", filha)
			if str(especializacao.get("nome", "")) != "":
				anotar.call("especializacoes", especializacao)
	# Agregações e participantes que são agregação não precisam de nome.
	var agregacoes := []
	for agregacao in modelo.get("agregacoes", []):
		if agregacao is Dictionary:
			agregacoes.append(str(agregacao.get("nome", "")).strip_edges())
	return nomes.filter(func(n): return n.tipo != "entidades" or n.nome not in agregacoes)


## 12.5 -> "12,5"; 12.0 -> "12".
static func formatar_numero(valor: float) -> String:
	var arredondado := snappedf(valor, 0.1)
	if is_equal_approx(arredondado, roundf(arredondado)):
		return str(int(roundf(arredondado)))
	return ("%.1f" % arredondado).replace(".", ",")


static func _cor(texto: String, cor: String, bbcode: bool) -> String:
	return "[color=%s]%s[/color]" % [CORES[cor], texto] if bbcode else texto


static func _negrito(texto: String, bbcode: bool) -> String:
	return "[b]%s[/b]" % texto if bbcode else texto


## Nomes do quadro e do gabarito não podem virar tags de BBCode.
static func _escapar(texto: String, bbcode: bool) -> String:
	return texto.replace("[", "[lb]") if bbcode else texto
