extends RefCounted
## Correção do diagrama do jogador contra UM modelo do gabarito. O verificador
## (verificador.gd) corrige contra o modelo principal e contra cada alternativa,
## e fica com a melhor nota.
##
## 1. Casar: decide qual bloco do jogador corresponde a cada item do modelo.
##    - Entidades casam pelo nome. O nome vem arrastado do banco de palavras,
##      então a comparação é exata: vale o nome do gabarito ou um dos sinônimos
##      dele, com as mesmas letras, acentos e maiúsculas. As que sobram casam
##      pelo papel no diagrama: mesmos atributos e ligações com as entidades já
##      casadas (a palavra "vendedor" no lugar de "cliente").
##    - Relacionamentos casam pelas entidades que ligam; o nome só desempata.
##      Assim três "possui" no mesmo modelo não se confundem.
##    - Agregações casam pelo relacionamento que envolvem; especializações,
##      pelas entidades que ligam.
##    - Atributos casam pelo nome dentro do dono certo; os que sobram, pelo nome
##      em qualquer lugar do quadro (para dizer que estão no lugar errado).
## 2. Pontuar: cada requisito do modelo vale pontos (pesos em verificador.gd);
##    acerto parcial vale parte deles.
## 3. Sobras: blocos além do modelo e ligações que a notação não permite viram
##    penalidade, somada ao total de pontos possíveis.
## Cada ponto perdido e cada penalidade vira uma linha em `perdas` com o motivo;
## a soma dessas linhas é exatamente o que falta para 100%.

const TIPOS := ["entidades", "relacionamentos", "atributos", "especializacoes", "agregacoes"]
const NOME_DO_TIPO := {
	"entidades": "entidade", "relacionamentos": "relacionamento", "atributos": "atributo",
	"especializacoes": "especialização", "agregacoes": "agregação",
}
const FORMA_DO_TIPO := {
	"entidades": "retângulo", "relacionamentos": "losango", "atributos": "elipse",
	"especializacoes": "triângulo", "agregacoes": "caixa de agregação",
}
const TIPOS_FEMININOS := ["entidades", "especializacoes", "agregacoes"]
## Marcações de atributo: campo no gabarito -> [campo no save, nome, como marcar no jogo].
const MARCAS_DE_ATRIBUTO := {
	"chavePrimaria": ["cp", "chave", "nome sublinhado: selecione e tecle C"],
	"derivado": ["derivado", "derivado", "contorno tracejado: selecione e tecle D"],
	"multivalorado": ["multivalorado", "multivalorado", "contorno duplo: selecione e tecle M"],
}
## Blocos que podem ser donos de atributo (além de outro atributo, no composto).
const DONOS_DE_ATRIBUTO := ["entidades", "relacionamentos", "agregacoes"]

var pesos: Dictionary
var regras: Dictionary

# Modelo do gabarito, organizado por _ler_modelo(). Cada item é um Dictionary
# com "chave", "tipo", "nome", "aceitos" (nome + sinônimos) e "dados" (o JSON).
var itens := {}  # chave -> item
var entidades := []
var relacionamentos := []
var especializacoes := []
var agregacoes := []
var atributos := []  # todos, inclusive os de relacionamento e os componentes

# Diagrama do jogador.
var blocos := {}    # id -> {"id", "tipo", "nome", "dados"}
var vizinhos := {}  # id -> {id do vizinho: cardinalidade da ligação}
var ids := []       # em ordem natural, para a correção ser sempre a mesma

# Correspondência entre os dois.
var par := {}         # chave do item -> id do bloco
var como_casou := {}  # chave do item -> "nome", "papel", "ligacoes" ou "fora_do_lugar"
var usado := {}       # id do bloco -> chave do item, ou "explicado" (citado numa mensagem)
var ligacao_explicada := {}  # chave da ligação -> true: já pontuada ou citada

# Resultado.
var categorias := {}  # categoria -> {"total", "obtido", "penalidade"}
var perdas := []      # {"categoria", "pontos", "mensagem"}
var avisos := []      # observações que não descontam


func _init(pesos_da_correcao: Dictionary, regras_da_correcao: Dictionary):
	pesos = pesos_da_correcao
	regras = regras_da_correcao


func corrigir(diagrama: Dictionary, modelo: Dictionary) -> Dictionary:
	_ler_jogador(diagrama)
	_ler_modelo(modelo)

	# Relacionamentos que ligam uma agregação casam depois dela.
	var com_agregacao := relacionamentos.filter(func(r): return _liga_agregacao(r))
	_casar_entidades()
	_casar_relacionamentos(relacionamentos.filter(func(r): return r not in com_agregacao))
	_casar_agregacoes()
	_casar_relacionamentos(com_agregacao)
	_casar_especializacoes()
	_casar_atributos()

	_pontuar_entidades()
	_pontuar_agregacoes()  # antes dos relacionamentos: explica a ligação com o envolvido
	_pontuar_relacionamentos()
	_pontuar_atributos()
	_pontuar_especializacoes()
	_pontuar_sobras()
	_pontuar_notacao()
	_avisar_chaves()
	return _resultado()


# --- Leitura ------------------------------------------------------------------

func _ler_jogador(diagrama: Dictionary) -> void:
	for tipo in TIPOS:
		var grupo = diagrama.get(tipo, {})
		if not grupo is Dictionary:
			continue
		for id in grupo:
			var dados: Dictionary = grupo[id] if grupo[id] is Dictionary else {}
			var nome := str(dados.get("nome", "")).strip_edges()
			if tipo == "agregacoes" and nome == "Agregação":
				nome = ""  # nome que o bloco recebe quando o jogador não escreve nada
			blocos[str(id)] = {"id": str(id), "tipo": tipo, "nome": nome, "dados": dados}
			vizinhos[str(id)] = {}
	var conexoes = diagrama.get("conexoes", [])
	for conexao in (conexoes if conexoes is Array else []):
		if not conexao is Dictionary:
			continue
		var de := str(conexao.get("de", ""))
		var para := str(conexao.get("para", ""))
		if de != para and blocos.has(de) and blocos.has(para):
			var cardinalidade := str(conexao.get("cardinalidade", ""))
			vizinhos[de][para] = cardinalidade
			vizinhos[para][de] = cardinalidade
	ids = blocos.keys()
	ids.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)


func _ler_modelo(modelo: Dictionary) -> void:
	for dados in _dicionarios(modelo, "entidades"):
		_nova_entidade(dados)
	for dados in _dicionarios(modelo, "agregacoes"):
		var item := _novo_item("agregacoes", dados, agregacoes)
		item["relacionamento"] = _nome_de(dados.get("relacionamento"))
	for dados in _dicionarios(modelo, "relacionamentos"):
		var item := _novo_item("relacionamentos", dados, relacionamentos)
		item["nome_livre"] = dados.get("nomeLivre", false) == true
		item["identificador"] = dados.get("identificador", false) == true
		item["participantes"] = _participantes(dados)
		item["atributos"] = _ler_atributos(item, dados.get("atributosRelacionamento", dados.get("atributos", [])))
		item["completos"] = _atributos_completos(dados)
	for dados in _dicionarios(modelo, "especializacoes"):
		var item := _novo_item("especializacoes", dados, especializacoes)
		item["pai"] = _nome_de(dados.get("entidadePai"))
		item["filhas"] = _dicionarios(dados, "entidadesFilhas").map(func(f): return _nome_de(f)) \
				.filter(func(nome): return nome != "")

	# Entidade citada num relacionamento ou numa especialização é entidade do
	# modelo, mesmo que o gabarito não a declare.
	for item in relacionamentos:
		for ponta in item.participantes:
			_garantir_entidade(ponta.nome)
	for item in especializacoes:
		for nome in [item.pai] + item.filhas:
			_garantir_entidade(nome)


func _novo_item(tipo: String, dados: Dictionary, lista: Array) -> Dictionary:
	var nome := str(dados.get("nome", "")).strip_edges()
	var aceitos := [nome]
	var sinonimos = dados.get("sinonimos", [])
	for sinonimo in (sinonimos if sinonimos is Array else []):
		aceitos.append(str(sinonimo).strip_edges())
	var item := {"chave": "%s%d" % [tipo, itens.size()], "tipo": tipo, "nome": nome, "aceitos": aceitos, "dados": dados}
	itens[item.chave] = item
	lista.append(item)
	return item


func _nova_entidade(dados: Dictionary) -> Dictionary:
	var item := _novo_item("entidades", dados, entidades)
	item["fraca"] = dados.get("fraca", false) == true
	item["atributos"] = _ler_atributos(item, dados.get("atributos", []))
	item["completos"] = _atributos_completos(dados)
	return item


func _garantir_entidade(nome: String) -> void:
	if nome != "" and _item_pelo_nome(nome, entidades + agregacoes).is_empty():
		_nova_entidade({"nome": nome})


## Atributos de um dono; os componentes de um atributo composto ficam em
## "atributos" do próprio atributo. `atributos` recebe cada um antes dos componentes.
func _ler_atributos(dono: Dictionary, lista) -> Array:
	var lidos := []
	for dados in (lista if lista is Array else []):
		if not dados is Dictionary:
			continue
		var item := _novo_item("atributos", dados, atributos)
		item["dono"] = dono.chave
		item["opcional"] = dados.get("opcional", false) == true
		var marcas := {}
		for marca in MARCAS_DE_ATRIBUTO:
			var valor = dados.get(marca, false)
			# true = exigida; false = proibida; "opcional" = tanto faz
			marcas[marca] = "opcional" if str(valor) == "opcional" else valor == true
		item["marcas"] = marcas
		item["atributos"] = _ler_atributos(item, dados.get("componentes", []))
		lidos.append(item)
	return lidos


func _atributos_completos(dados: Dictionary) -> bool:
	return dados.get("atributosCompletos", regras.atributosExtras == "penalizar") == true


func _participantes(dados: Dictionary) -> Array:
	var fonte = dados.get("participantes")
	if not fonte is Array:
		fonte = [dados.get("entidadeOrigem"), dados.get("entidadeDestino")]
	var lista := []
	for ponta in fonte:
		var nome := _nome_de(ponta)
		if nome != "":
			var cardinalidade := str(ponta.get("cardinalidade", "")) if ponta is Dictionary else ""
			lista.append({"nome": nome, "cardinalidade": cardinalidade})
	return lista


func _liga_agregacao(relacionamento: Dictionary) -> bool:
	return relacionamento.participantes.any(func(p): return not _item_pelo_nome(p.nome, agregacoes).is_empty())


static func _dicionarios(dados: Dictionary, chave: String) -> Array:
	var lista = dados.get(chave, [])
	return lista.filter(func(x): return x is Dictionary) if lista is Array else []


static func _nome_de(referencia) -> String:
	if referencia is Dictionary:
		return str(referencia.get("nome", "")).strip_edges()
	if referencia is String:
		return referencia.strip_edges()
	return ""


# --- Consultas --------------------------------------------------------------------

## Item de `lista` com esse nome (ou sinônimo, ou "id" do gabarito).
func _item_pelo_nome(nome: String, lista: Array) -> Dictionary:
	if nome == "":
		return {}
	for item in lista:
		if str(item.dados.get("id", "")) == nome or nome in item.aceitos:
			return item
	return {}


## Bloco do jogador que corresponde à entidade (ou agregação) do modelo com esse nome.
func _bloco_de(nome: String) -> String:
	var item := _item_pelo_nome(nome, entidades + agregacoes)
	return par.get(item.chave, "") if not item.is_empty() else ""


## O bloco tem o nome do item (ou um dos sinônimos), exatamente?
func _mesmo_nome(id: String, item: Dictionary) -> bool:
	return blocos[id].nome != "" and blocos[id].nome in item.aceitos


func _livres(tipo: String) -> Array:
	return ids.filter(func(id): return blocos[id].tipo == tipo and not usado.has(id))


func _vizinhos_do_tipo(id: String, tipos: Array) -> Array:
	return ids.filter(func(v): return vizinhos[id].has(v) and blocos[v].tipo in tipos)


## Os dois blocos estão ligados, direto ou por um relacionamento/especialização?
func _ligados(a: String, b: String) -> bool:
	if vizinhos[a].has(b):
		return true
	for meio in vizinhos[a]:
		if blocos[meio].tipo in ["relacionamentos", "especializacoes"] and vizinhos[meio].has(b):
			return true
	return false


## Entidades (e agregações) que aparecem junto com `item` em algum
## relacionamento ou especialização do modelo.
func _vizinhas_no_modelo(item: Dictionary) -> Array:
	var grupos := []
	for relacionamento in relacionamentos:
		grupos.append(relacionamento.participantes.map(func(p): return p.nome))
	for especializacao in especializacoes:
		grupos.append([especializacao.pai] + especializacao.filhas)
	var vizinhas := {}
	for grupo in grupos:
		var membros: Array = grupo.map(func(nome): return _item_pelo_nome(nome, entidades + agregacoes)) \
				.filter(func(m): return not m.is_empty())
		if membros.any(func(m): return m.chave == item.chave):
			for membro in membros:
				if membro.chave != item.chave:
					vizinhas[membro.chave] = membro
	return vizinhas.values()


static func _chave_da_ligacao(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


# --- Casamento -----------------------------------------------------------------

func _casar(item: Dictionary, id: String, como: String) -> void:
	par[item.chave] = id
	como_casou[item.chave] = como
	usado[id] = item.chave


## `candidatos`: [nota, item, id]. Casa do mais parecido para o menos parecido;
## cada item e cada bloco ficam com um par só.
func _casar_em_ordem(candidatos: Array, como: String) -> void:
	candidatos.sort_custom(_vem_antes)
	for candidato in candidatos:
		var item: Dictionary = candidato[1]
		var id: String = candidato[2]
		if not par.has(item.chave) and not usado.has(id):
			_casar(item, id, como)


func _vem_antes(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]
	if a[1].chave != b[1].chave:
		return a[1].chave.naturalnocasecmp_to(b[1].chave) < 0
	return a[2].naturalnocasecmp_to(b[2]) < 0


func _casar_entidades() -> void:
	var candidatos := []
	for item in entidades:
		for id in _livres("entidades"):
			if _mesmo_nome(id, item):
				candidatos.append([1.0, item, id])
	_casar_em_ordem(candidatos, "nome")

	# As que sobraram casam pelo papel, uma por vez: cada par novo é pista para os próximos.
	while true:
		var melhor := []
		for item in entidades:
			if par.has(item.chave):
				continue
			for id in _livres("entidades"):
				var papel := _papel(item, id)
				if papel[0] >= 1 and papel[1] >= float(regras.limiarPapel):
					var candidato := [papel[1], item, id]
					if melhor.is_empty() or _vem_antes(candidato, melhor):
						melhor = candidato
		if melhor.is_empty():
			break
		_casar(melhor[1], melhor[2], "papel")


## Quanto o bloco `id` faz o papel da entidade `item`: atributos com os mesmos
## nomes e ligações com as mesmas entidades (só contam as já casadas).
## Devolve [acertos, fração].
func _papel(item: Dictionary, id: String) -> Array:
	var esperados := 0
	var acertos := 0
	var atributos_do_bloco := _vizinhos_do_tipo(id, ["atributos"])
	for atributo in item.atributos:
		esperados += 1
		if atributos_do_bloco.any(func(a): return _mesmo_nome(a, atributo)):
			acertos += 1
	for outra in _vizinhas_no_modelo(item):
		var bloco: String = par.get(outra.chave, "")
		if bloco != "":
			esperados += 1
			if _ligados(id, bloco):
				acertos += 1
	return [acertos, float(acertos) / esperados if esperados > 0 else 0.0]


func _casar_relacionamentos(lista: Array) -> void:
	var candidatos := []
	for item in lista:
		var pontas: Array = item.participantes.map(func(p): return _bloco_de(p.nome))
		for id in _livres("relacionamentos"):
			var ligadas := pontas.filter(func(b): return b != "" and vizinhos[id].has(b)).size()
			var nome := 1.0 if _mesmo_nome(id, item) else 0.0
			if ligadas > 0 or nome > 0.0:
				candidatos.append([float(ligadas) / maxi(pontas.size(), 1) + 0.5 * nome, item, id])
	_casar_em_ordem(candidatos, "ligacoes")


func _casar_agregacoes() -> void:
	var candidatos := []
	for item in agregacoes:
		var interno := _bloco_do_relacionamento(item.relacionamento)
		for id in _livres("agregacoes"):
			var nota := 1.0 if interno != "" and vizinhos[id].has(interno) else 0.0
			if _mesmo_nome(id, item):
				nota += 0.5
			candidatos.append([nota, item, id])
	_casar_em_ordem(candidatos, "ligacoes")


func _bloco_do_relacionamento(referencia: String) -> String:
	var item := _item_pelo_nome(referencia, relacionamentos)
	return par.get(item.chave, "") if not item.is_empty() else ""


func _casar_especializacoes() -> void:
	var candidatos := []
	for item in especializacoes:
		var membros: Array = ([item.pai] + item.filhas).map(func(nome): return _bloco_de(nome))
		for id in _livres("especializacoes"):
			var ligadas := membros.filter(func(b): return b != "" and vizinhos[id].has(b)).size()
			var nota := float(ligadas) / maxi(membros.size(), 1)
			if _mesmo_nome(id, item):
				nota += 0.5
			candidatos.append([nota, item, id])
	_casar_em_ordem(candidatos, "ligacoes")


func _casar_atributos() -> void:
	_casar_atributos_no_dono()
	# Os que não estão no dono certo: pelo nome, em qualquer lugar do quadro.
	var candidatos := []
	for atributo in atributos:
		if par.has(atributo.chave):
			continue
		for id in _livres("atributos"):
			if _mesmo_nome(id, atributo):
				candidatos.append([1.0, atributo, id])
	_casar_em_ordem(candidatos, "fora_do_lugar")
	# Componentes de um atributo composto que estava fora do lugar.
	_casar_atributos_no_dono()


func _casar_atributos_no_dono() -> void:
	# Um atributo composto aparece em `atributos` antes dos componentes, então
	# casa antes de virar dono deles.
	for dono in entidades + relacionamentos + atributos:
		var id_dono: String = par.get(dono.chave, "")
		if id_dono == "":
			continue
		var candidatos := []
		for atributo in dono.atributos:
			if par.has(atributo.chave):
				continue
			for id in _vizinhos_do_tipo(id_dono, ["atributos"]):
				if not usado.has(id) and _mesmo_nome(id, atributo):
					candidatos.append([1.0, atributo, id])
		_casar_em_ordem(candidatos, "nome")


# --- Pontuação ----------------------------------------------------------------

func _peso(nome: String) -> float:
	return float(pesos.get(nome, 0.0))


func _somar(categoria: String, total: float, obtido: float) -> void:
	var placar: Dictionary = categorias.get_or_add(categoria, {"total": 0.0, "obtido": 0.0, "penalidade": 0.0})
	placar.total += total
	placar.obtido += obtido


func _perder(categoria: String, pontos: float, motivo: String) -> void:
	if pontos > 0.000001:
		perdas.append({"categoria": categoria, "pontos": pontos, "mensagem": motivo})


## Requisito que vale `peso`, do qual o jogador cumpriu a `fracao`.
func _requisito(categoria: String, peso: float, fracao: float, motivo: String) -> void:
	_somar(categoria, peso, peso * fracao)
	_perder(categoria, peso * (1.0 - fracao), motivo)


func _penalizar(categoria: String, peso: float, motivo: String) -> void:
	var placar: Dictionary = categorias.get_or_add(categoria, {"total": 0.0, "obtido": 0.0, "penalidade": 0.0})
	placar.penalidade += peso
	_perder(categoria, peso, motivo)


func _pontuar_entidades() -> void:
	var peso := _peso("entidade")
	for item in entidades:
		var id: String = par.get(item.chave, "")
		var nome := _q(item.nome)
		if id == "":
			_somar("Entidades", peso, 0.0)
			var pontos := peso
			var detalhe := ""
			if item.fraca:
				_somar("Marcações", _peso("marcacao"), 0.0)
				pontos += _peso("marcacao")
				detalhe = " (entidade fraca)"
			_perder("Entidades", pontos, "Falta a entidade %s%s.%s" % [nome, detalhe, _confusao(item)])
			continue

		var desenhada: String = blocos[id].nome
		if como_casou[item.chave] == "papel":
			var quem := "Uma entidade sem nome" if desenhada == "" else "A entidade %s" % _q(desenhada)
			var motivo := "%s faz o papel de %s (mesmas ligações e atributos): arraste a palavra %s até ela." % [quem, nome, nome]
			_requisito("Entidades", peso, float(regras.creditoPorPapel), motivo)
		else:
			_requisito("Entidades", peso, 1.0, "")

		var marcada: bool = blocos[id].dados.get("fraca", false) == true
		var rotulo := _q(desenhada if desenhada != "" else item.nome)
		if item.fraca:
			_requisito("Marcações", _peso("marcacao"), 1.0 if marcada else 0.0,
					"A entidade %s é fraca (só existe ligada a outra): selecione e tecle F para o contorno duplo." % rotulo)
		elif marcada:
			_penalizar("Marcações", _peso("marcacao"), "A entidade %s está marcada como fraca, mas não é." % rotulo)


func _pontuar_relacionamentos() -> void:
	for item in relacionamentos:
		var id: String = par.get(item.chave, "")
		var entre := _lista_txt(item.participantes.map(func(p): return p.nome))
		if id == "":
			_pontuar_relacionamento_ausente(item, entre)
			continue
		var rotulo := _rotulo(id, item)

		if not item.nome_livre:
			var desenhado: String = blocos[id].nome
			var certo := _mesmo_nome(id, item)
			var motivo := ""
			if desenhado == "":
				motivo = "O relacionamento entre %s está sem nome; o esperado é %s." % [entre, _q(item.nome)]
			elif not certo:
				motivo = "O relacionamento entre %s se chama %s, mas o esperado é %s." % [entre, _q(desenhado), _q(item.nome)]
			_requisito("Relacionamentos", _peso("relacionamento"), 1.0 if certo else 0.0, motivo)

		_pontuar_pontas(item, id, rotulo)

		var identificador: bool = blocos[id].dados.get("identificador", false) == true
		if item.identificador:
			_requisito("Marcações", _peso("marcacao"), 1.0 if identificador else 0.0,
					"O %s liga uma entidade fraca à dona dela: selecione e tecle F para marcá-lo como identificador (contorno duplo)." % rotulo)
		elif identificador:
			_penalizar("Marcações", _peso("marcacao"), "O %s está marcado como identificador, mas nenhuma entidade fraca depende dele." % rotulo)


func _pontuar_relacionamento_ausente(item: Dictionary, entre: String) -> void:
	var pontos := 0.0
	if not item.nome_livre:
		_somar("Relacionamentos", _peso("relacionamento"), 0.0)
		pontos += _peso("relacionamento")
	for ponta in item.participantes:
		_somar("Relacionamentos", _peso("participacao"), 0.0)
		pontos += _peso("participacao")
		if _classe(ponta.cardinalidade) != "":
			_somar("Cardinalidades", _peso("cardinalidade"), 0.0)
			pontos += _peso("cardinalidade")
	if item.identificador:
		_somar("Marcações", _peso("marcacao"), 0.0)
		pontos += _peso("marcacao")
	var motivo := ("Falta um relacionamento entre %s." % entre) if item.nome_livre \
			else ("Falta o relacionamento %s entre %s." % [_q(item.nome), entre])
	_perder("Relacionamentos", pontos, motivo + _ligacao_direta(item) + _confusao(item))


## Participação de cada entidade no relacionamento e a cardinalidade de cada ponta.
func _pontuar_pontas(item: Dictionary, id: String, rotulo: String) -> void:
	var erradas := []
	for ponta in item.participantes:
		var bloco := _bloco_de(ponta.nome)
		var esperada := _classe(ponta.cardinalidade)
		if bloco == "" or not vizinhos[id].has(bloco):
			var pontos := _peso("participacao")
			_somar("Relacionamentos", _peso("participacao"), 0.0)
			if esperada != "":
				_somar("Cardinalidades", _peso("cardinalidade"), 0.0)
				pontos += _peso("cardinalidade")
			var motivo := "O %s não está ligado a %s" % [rotulo, _q(ponta.nome)]
			_perder("Relacionamentos", pontos, motivo + (" (essa entidade não está no quadro)." if bloco == "" else "."))
			continue

		ligacao_explicada[_chave_da_ligacao(id, bloco)] = true
		_somar("Relacionamentos", _peso("participacao"), _peso("participacao"))
		if esperada != "":
			var desenhada: String = vizinhos[id][bloco]
			var certa := _classe(desenhada) == esperada
			_somar("Cardinalidades", _peso("cardinalidade"), _peso("cardinalidade") if certa else 0.0)
			if not certa:
				erradas.append({"ponta": ponta.nome, "desenhada": desenhada, "esperada": esperada})
	_explicar_cardinalidades(rotulo, item.participantes.size(), erradas)

	# Ligação com uma entidade do modelo que não participa deste relacionamento.
	# (Ligação com um bloco a mais não conta aqui: o bloco já é penalizado.)
	for outro in _vizinhos_do_tipo(id, ["entidades", "agregacoes"]):
		var ligacao := _chave_da_ligacao(id, outro)
		if usado.has(outro) and not ligacao_explicada.has(ligacao):
			ligacao_explicada[ligacao] = true
			_penalizar("Itens a mais", _peso("extra"), "O %s também está ligado a %s, que não participa dele." % [rotulo, _q(blocos[outro].nome)])


func _explicar_cardinalidades(rotulo: String, quantas_pontas: int, erradas: Array) -> void:
	var peso := _peso("cardinalidade")
	if quantas_pontas == 2 and erradas.size() == 2 \
			and _classe(erradas[0].desenhada) == erradas[1].esperada \
			and _classe(erradas[1].desenhada) == erradas[0].esperada:
		_perder("Cardinalidades", 2 * peso, ("As cardinalidades do %s estão invertidas: do lado de %s vai %s e do lado de %s vai %s. "
				+ "Lembre: o número perto de cada entidade diz quantas dela se ligam a uma da outra ponta.")
				% [rotulo, _q(erradas[0].ponta), _mostrar(erradas[0].esperada), _q(erradas[1].ponta), _mostrar(erradas[1].esperada)])
		return
	for errada in erradas:
		var desenhada: String = errada.desenhada if errada.desenhada != "" else "sem número"
		_perder("Cardinalidades", peso, "No %s, do lado de %s a cardinalidade está %s, mas deveria ser %s."
				% [rotulo, _q(errada.ponta), desenhada, _mostrar(errada.esperada)])


## Você ligou as entidades direto, sem o losango? (só para explicar a falta)
func _ligacao_direta(item: Dictionary) -> String:
	var pontas: Array = item.participantes.map(func(p): return _bloco_de(p.nome))
	for i in pontas.size():
		for j in range(i + 1, pontas.size()):
			var a: String = pontas[i]
			var b: String = pontas[j]
			if a != "" and b != "" and vizinhos[a].has(b):
				ligacao_explicada[_chave_da_ligacao(a, b)] = true
				return " Você ligou %s direto em %s: a ligação precisa passar por um relacionamento (losango)." \
						% [_nome_txt(a), _nome_txt(b)]
	return ""


func _pontuar_atributos() -> void:
	var peso := _peso("atributo")
	for atributo in atributos:
		if atributo.opcional:
			continue
		var id: String = par.get(atributo.chave, "")
		var exigidas: Array = MARCAS_DE_ATRIBUTO.keys().filter(func(m): return atributo.marcas[m] is bool and atributo.marcas[m])
		if id == "":
			_somar("Atributos", peso, 0.0)
			for marca in exigidas:
				_somar("Marcações", _peso("marcacao"), 0.0)
			var tipo := " ".join(["atributo"] + exigidas.map(func(m): return MARCAS_DE_ATRIBUTO[m][1]))
			_perder("Atributos", peso + exigidas.size() * _peso("marcacao"),
					"Falta o %s %s %s.%s" % [tipo, _q(atributo.nome), _do_dono(atributo), _confusao(atributo)])
			continue

		if como_casou[atributo.chave] == "fora_do_lugar":
			_requisito("Atributos", peso, float(regras.creditoForaDoLugar), _fora_do_lugar(atributo, id))
		else:
			ligacao_explicada[_chave_da_ligacao(id, par[atributo.dono])] = true
			_requisito("Atributos", peso, 1.0, "")
		_pontuar_marcas(atributo, id)


func _fora_do_lugar(atributo: Dictionary, id: String) -> String:
	var donos := _donos_no_quadro(id)
	for dono in donos:
		ligacao_explicada[_chave_da_ligacao(id, dono)] = true
	var nome := _q(blocos[id].nome)
	if donos.is_empty():
		return "O atributo %s está solto: ligue-o %s." % [nome, _ao_dono(atributo)]
	# Só ligado a outros atributos, mas o gabarito põe o atributo direto numa
	# entidade ou relacionamento: o jogador encadeou atributos, e na notação
	# isso quer dizer atributo composto.
	if blocos[donos[0]].tipo == "atributos" and itens[atributo.dono].tipo != "atributos":
		return ("O atributo %s está ligado ao atributo %s. Ligar um atributo em outro quer dizer que ele é parte "
				+ "de um atributo composto (como 'rua' dentro de 'endereço'); ligue %s direto %s.") \
				% [nome, _nome_txt(_atributo_de_cima(id)), nome, _ao_dono(atributo)]
	return "O atributo %s está ligado a %s, mas é atributo %s." \
			% [nome, _lista_txt(donos.map(func(d): return blocos[d].nome)), _do_dono(atributo)]


## Numa cadeia de atributos, o vizinho de `id` mais perto de uma entidade ou
## relacionamento (o "de cima"). Sem caminho até um deles, o primeiro vizinho.
func _atributo_de_cima(id: String) -> String:
	var candidatos := _vizinhos_do_tipo(id, ["atributos"])
	var melhor: String = candidatos[0]
	var menor := INF
	for vizinho in candidatos:
		var passos := _passos_ate_um_dono(vizinho, id)
		if passos < menor:
			menor = passos
			melhor = vizinho
	return melhor


## Quantos atributos há entre `inicio` e a entidade (ou relacionamento) mais
## próxima, andando só por atributos e sem passar por `evitar`.
func _passos_ate_um_dono(inicio: String, evitar: String) -> float:
	var visitados := {inicio: true, evitar: true}
	var fila := [[inicio, 0]]
	while not fila.is_empty():
		var atual: Array = fila.pop_front()
		if not _vizinhos_do_tipo(atual[0], DONOS_DE_ATRIBUTO).is_empty():
			return atual[1]
		for proximo in _vizinhos_do_tipo(atual[0], ["atributos"]):
			if not visitados.has(proximo):
				visitados[proximo] = true
				fila.append([proximo, atual[1] + 1])
	return INF


func _pontuar_marcas(atributo: Dictionary, id: String) -> void:
	var dados: Dictionary = blocos[id].dados
	var nome := _q(blocos[id].nome)
	for marca in MARCAS_DE_ATRIBUTO:
		var esperada = atributo.marcas[marca]
		if not esperada is bool:
			continue  # "opcional": tanto faz
		var campo: String = MARCAS_DE_ATRIBUTO[marca][0]
		var como: String = MARCAS_DE_ATRIBUTO[marca][1]
		var marcada: bool = dados.get(campo, false) == true
		if esperada:
			_requisito("Marcações", _peso("marcacao"), 1.0 if marcada else 0.0, "O atributo %s %s deveria ser %s (%s)."
					% [nome, _do_dono(atributo), como, MARCAS_DE_ATRIBUTO[marca][2]])
		elif marcada:
			_penalizar("Marcações", _peso("marcacao"), "O atributo %s %s está marcado como %s, mas não é."
					% [nome, _do_dono(atributo), como])


func _pontuar_especializacoes() -> void:
	var peso := _peso("especializacao")
	for item in especializacoes:
		var id: String = par.get(item.chave, "")
		var membros: Array = [item.pai] + item.filhas
		var descricao := "de %s em %s" % [_q(item.pai), _lista_txt(item.filhas)]
		var com_rotulo: bool = item.nome != ""
		if id == "":
			var pontos := peso * (membros.size() + (1 if com_rotulo else 0))
			_somar("Especializações", pontos, 0.0)
			_perder("Especializações", pontos, "Falta a especialização %s: um triângulo ligado a %s.%s"
					% [descricao, _lista_txt(membros), _confusao(item)])
			continue

		for nome in membros:
			var bloco := _bloco_de(nome)
			var ligada: bool = bloco != "" and vizinhos[id].has(bloco)
			if ligada:
				ligacao_explicada[_chave_da_ligacao(id, bloco)] = true
			_requisito("Especializações", peso, 1.0 if ligada else 0.0, "A especialização %s não está ligada a %s%s."
					% [descricao, _q(nome), "" if bloco != "" else " (essa entidade não está no quadro)"])
		if com_rotulo:
			_requisito("Especializações", peso, 1.0 if _mesmo_nome(id, item) else 0.0,
					"A especialização %s deveria ter %s no triângulo." % [descricao, _q(item.nome)])
		for outro in _vizinhos_do_tipo(id, ["entidades"]):
			var ligacao := _chave_da_ligacao(id, outro)
			if usado.has(outro) and not ligacao_explicada.has(ligacao):
				ligacao_explicada[ligacao] = true
				_penalizar("Itens a mais", _peso("extra"), "A especialização %s também está ligada a %s, que não faz parte dela."
						% [descricao, _q(blocos[outro].nome)])


func _pontuar_agregacoes() -> void:
	var peso := _peso("agregacao")
	for item in agregacoes:
		var id: String = par.get(item.chave, "")
		var relacionamento := _item_pelo_nome(item.relacionamento, relacionamentos)
		var envolvido := _q(relacionamento.nome if not relacionamento.is_empty() else item.relacionamento)
		var nome := (" " + _q(item.nome)) if item.nome != "" else ""
		if id == "":
			_somar("Agregações", 2 * peso, 0.0)
			_perder("Agregações", 2 * peso, "Falta a agregação%s envolvendo o relacionamento %s." % [nome, envolvido])
			continue
		_requisito("Agregações", peso, 1.0, "")
		var interno: String = par.get(relacionamento.chave, "") if not relacionamento.is_empty() else ""
		var ligada: bool = interno != "" and vizinhos[id].has(interno)
		if ligada:
			ligacao_explicada[_chave_da_ligacao(id, interno)] = true
		_requisito("Agregações", peso, 1.0 if ligada else 0.0,
				"A agregação%s não está ligada ao relacionamento %s, que ela envolve." % [nome, envolvido])


## Blocos que o jogador desenhou além do modelo.
func _pontuar_sobras() -> void:
	for id in ids:
		if usado.has(id):
			continue
		if blocos[id].tipo == "atributos":
			_sobra_de_atributo(id)
		else:
			_penalizar("Itens a mais", _peso("extra"), _motivo_da_sobra(id))


func _motivo_da_sobra(id: String) -> String:
	var bloco: Dictionary = blocos[id]
	var tipo: String = NOME_DO_TIPO[bloco.tipo]
	var feminino: bool = bloco.tipo in TIPOS_FEMININOS
	var ligado_a := _lista_txt(_vizinhos_do_tipo(id, ["entidades", "agregacoes"]).map(func(v): return blocos[v].nome))
	if bloco.tipo in ["especializacoes", "agregacoes"] and bloco.nome == "":
		return "Há uma %s a mais no quadro%s." % [tipo, (" (ligada a %s)" % ligado_a) if ligado_a != "" else ""]
	if bloco.nome == "":
		return "Há %s %s sem nome sobrando no quadro." % ["uma" if feminino else "um", tipo]
	for item in itens.values():
		if item.tipo == bloco.tipo and par.has(item.chave) and _mesmo_nome(id, item):
			return "%s %s %s aparece repetid%s: apague a cópia." \
					% ["A" if feminino else "O", tipo, _q(bloco.nome), "a" if feminino else "o"]
	var onde := (" (ligado a %s)" % ligado_a) if bloco.tipo == "relacionamentos" and ligado_a != "" else ""
	return "%s %s %s%s não faz parte do modelo esperado." % ["A" if feminino else "O", tipo, _q(bloco.nome), onde]


func _sobra_de_atributo(id: String) -> void:
	var nome := _q(blocos[id].nome)
	var donos := _donos_no_quadro(id)
	if donos.is_empty():
		_penalizar("Notação", _peso("notacao"), "O atributo %s está solto: todo atributo fica ligado a uma entidade, a um relacionamento ou a outro atributo."
				% _nome_txt(id))
		return
	var dono: Dictionary = itens.get(usado.get(donos[0], ""), {})
	if dono.is_empty() or not dono.has("atributos"):
		return  # o dono é um bloco a mais e já foi penalizado
	if blocos[id].nome == "":
		_penalizar("Itens a mais", _peso("extra"), "Há um atributo sem nome %s." % _em(dono))
		return
	for atributo in dono.atributos:
		if par.has(atributo.chave) and _mesmo_nome(id, atributo):
			_penalizar("Itens a mais", _peso("extra"), "O atributo %s aparece repetido %s: apague a cópia." % [nome, _em(dono)])
			return
	if dono.get("completos", false):
		_penalizar("Itens a mais", _peso("extra"), "O atributo %s %s não faz parte do modelo esperado." % [nome, _em(dono)])
	else:
		avisos.append("O atributo %s %s não está no gabarito; não desconta." % [nome, _em(dono)])


## Ligações que a notação do MER não permite (as que ainda não entraram em
## nenhuma mensagem).
func _pontuar_notacao() -> void:
	for id in ids:
		for outro in vizinhos[id]:
			var ligacao := _chave_da_ligacao(id, outro)
			if id > outro or ligacao_explicada.has(ligacao):
				continue
			var problema := _problema_da_ligacao(id, outro)
			if problema != "":
				ligacao_explicada[ligacao] = true
				_penalizar("Notação", _peso("notacao"), problema)
	for id in ids:
		if blocos[id].tipo != "atributos":
			continue
		var donos := _vizinhos_do_tipo(id, DONOS_DE_ATRIBUTO)
		var novas := donos.filter(func(d): return not ligacao_explicada.has(_chave_da_ligacao(id, d)))
		if donos.size() >= 2 and not novas.is_empty():
			for dono in donos:
				ligacao_explicada[_chave_da_ligacao(id, dono)] = true
			_penalizar("Notação", _peso("notacao"), "O atributo %s está ligado a %s: cada atributo pertence a um bloco só."
					% [_nome_txt(id), _lista_txt(donos.map(func(d): return blocos[d].nome))])


func _problema_da_ligacao(a: String, b: String) -> String:
	var tipo_a: String = blocos[a].tipo
	var tipo_b: String = blocos[b].tipo
	if tipo_a == "entidades" and tipo_b == "entidades":
		return "As entidades %s e %s estão ligadas direto: entre duas entidades vai um relacionamento (losango)." % [_nome_txt(a), _nome_txt(b)]
	if tipo_a == "relacionamentos" and tipo_b == "relacionamentos":
		return "Os relacionamentos %s e %s estão ligados direto: relacionamento liga entidades (ou uma agregação)." % [_nome_txt(a), _nome_txt(b)]
	if tipo_a == "agregacoes" and tipo_b == "agregacoes":
		return "As agregações %s e %s estão ligadas direto." % [_nome_txt(a), _nome_txt(b)]
	if "especializacoes" in [tipo_a, tipo_b]:
		var outro := b if tipo_a == "especializacoes" else a
		if blocos[outro].tipo != "entidades":
			return "A especialização só se liga a entidades, mas está ligada ao %s %s." % [NOME_DO_TIPO[blocos[outro].tipo], _nome_txt(outro)]
	return ""


## Entidade com atributos e nenhum marcado como chave. Só avisa, e só quando o
## gabarito não lista os atributos dela: se lista, ele já decide qual é chave
## (e marcar outro desconta em Marcações).
func _avisar_chaves() -> void:
	for id in ids:
		var item: Dictionary = itens.get(usado.get(id, ""), {})
		if blocos[id].tipo != "entidades" or item.is_empty() or not item.atributos.is_empty():
			continue
		var do_bloco := _vizinhos_do_tipo(id, ["atributos"])
		if do_bloco.is_empty() or do_bloco.any(func(a): return blocos[a].dados.get("cp", false) == true):
			continue
		avisos.append("A entidade %s tem atributos, mas nenhum está marcado como chave (selecione o atributo e tecle C)." % _nome_txt(id))


## Procura um bloco de outro tipo com o nome do item que faltou ('cor' desenhado
## como entidade, por exemplo). Devolve a frase que explica, ou "".
func _confusao(item: Dictionary) -> String:
	for id in ids:
		if usado.has(id) or blocos[id].tipo == item.tipo or not _mesmo_nome(id, item):
			continue
		usado[id] = "explicado"
		for outro in vizinhos[id]:
			ligacao_explicada[_chave_da_ligacao(id, outro)] = true
		var tipo: String = blocos[id].tipo
		return " %s foi desenhado como %s (%s), mas é %s (%s)." % [_q(blocos[id].nome),
				NOME_DO_TIPO[tipo], FORMA_DO_TIPO[tipo], NOME_DO_TIPO[item.tipo], FORMA_DO_TIPO[item.tipo]]
	return ""


func _resultado() -> Dictionary:
	var total := 0.0
	var obtido := 0.0
	var penalidade := 0.0
	for placar in categorias.values():
		total += placar.total
		obtido += placar.obtido
		penalidade += placar.penalidade
	var base := total + penalidade
	return {
		"porcentagem": 100.0 * obtido / base if base > 0.0 else 0.0,
		"obtido": obtido,
		"total": total,
		"penalidade": penalidade,
		"categorias": categorias,
		"perdas": perdas,
		"avisos": avisos,
	}


# --- Texto das mensagens -----------------------------------------------------------

static func _q(texto) -> String:
	return "'%s'" % texto


func _nome_txt(id: String) -> String:
	return _q(blocos[id].nome) if blocos[id].nome != "" else "(sem nome)"


## 'a', 'b' e 'c'
static func _lista_txt(nomes: Array) -> String:
	var partes := PackedStringArray()
	for nome in nomes:
		partes.append(_q(nome))
	if partes.size() <= 1:
		return "".join(partes)
	return ", ".join(partes.slice(0, partes.size() - 1)) + " e " + partes[partes.size() - 1]


## Como o relacionamento do jogador aparece nas mensagens: "relacionamento 'faz'".
func _rotulo(id: String, item: Dictionary) -> String:
	var desenhado: String = blocos[id].nome
	if desenhado != "":
		return "relacionamento %s" % _q(desenhado)
	return "relacionamento sem nome (o %s)" % _q(item.nome)


## 'possui', ou 'possui' (entre 'livro' e 'gênero') quando o modelo tem outro 'possui'.
func _nome_do_relacionamento(item: Dictionary) -> String:
	var homonimos := relacionamentos.filter(func(r): return r.nome == item.nome)
	if homonimos.size() < 2:
		return _q(item.nome)
	return "%s (entre %s)" % [_q(item.nome), _lista_txt(item.participantes.map(func(p): return p.nome))]


func _do_dono(atributo: Dictionary) -> String:
	var dono: Dictionary = itens[atributo.dono]
	match dono.tipo:
		"relacionamentos":
			return "do relacionamento %s" % _nome_do_relacionamento(dono)
		"atributos":
			return "do atributo composto %s" % _q(dono.nome)
	return "de %s" % _q(dono.nome)


func _ao_dono(atributo: Dictionary) -> String:
	var dono: Dictionary = itens[atributo.dono]
	match dono.tipo:
		"relacionamentos":
			return "ao relacionamento %s" % _nome_do_relacionamento(dono)
		"atributos":
			return "ao atributo %s" % _q(dono.nome)
	return "à entidade %s" % _q(dono.nome)


func _em(dono: Dictionary) -> String:
	match dono.tipo:
		"relacionamentos":
			return "no relacionamento %s" % _nome_do_relacionamento(dono)
		"atributos":
			return "no atributo %s" % _q(dono.nome)
	return "em %s" % _q(dono.nome)


## Blocos a que o atributo está ligado como dono (o atributo pai, se for componente).
func _donos_no_quadro(id: String) -> Array:
	var donos := _vizinhos_do_tipo(id, DONOS_DE_ATRIBUTO)
	return donos if not donos.is_empty() else _vizinhos_do_tipo(id, ["atributos"])


## "1" ou "N" (muitos); vazio se o gabarito não diz. Aceita também (min,max) e min..max.
static func _classe(cardinalidade) -> String:
	var texto := str(cardinalidade).strip_edges().to_upper().replace(" ", "").trim_prefix("(").trim_suffix(")")
	for separador in [",", ".."]:
		if texto.contains(separador):
			var partes := texto.split(separador)
			texto = partes[partes.size() - 1]
	if texto == "1":
		return "1"
	if texto in ["N", "M", "*", "MUITOS"] or (texto.is_valid_int() and texto.to_int() > 1):
		return "N"
	return ""


static func _mostrar(classe: String) -> String:
	return "N (muitos)" if classe == "N" else classe
