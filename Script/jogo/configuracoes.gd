extends RefCounted
## Configurações do jogo (tela em Cenas/telas/configuracoes.tscn). Valem para o
## jogo todo, não para um save: ficam em user://configuracoes.cfg.
##
##   volume_do_jogo ......... 0 a 100: volume geral (barra de áudio "Master")
##   volume_da_musica ....... 0 a 100: barra "Musica" (passa pela Master)
##   dificuldade ............ "didatico": a verificação explica tudo o que faltou
##                            "desafio": mostra a nota e as partes, sem dizer o quê
##   salvamento_automatico .. true: o jogo salva sozinho nos savepoints (fluxo.gd);
##                            false: só quando o jogador usa SALVAR no menu
##
## Áudio: as barras Master, Musica e Efeitos estão em default_bus_layout.tres
## (aba Áudio do editor). Toque a música num AudioStreamPlayer com bus = "Musica"
## e os sons com bus = "Efeitos": os dois volumes já valem para eles.
##
## Como os outros scripts de jogo/, é só estático: Configuracoes.desafio(),
## Configuracoes.definir("volume_da_musica", 50). Lê o arquivo na primeira consulta.

const ARQUIVO := "user://configuracoes.cfg"
const SECAO := "jogo"
const DIDATICO := "didatico"
const DESAFIO := "desafio"
const DIFICULDADES := [DIDATICO, DESAFIO]
const BARRA_DO_JOGO := "Master"
const BARRA_DA_MUSICA := "Musica"
const BARRA_DOS_EFEITOS := "Efeitos"
const PADRAO := {
	"volume_do_jogo": 80,
	"volume_da_musica": 70,
	"dificuldade": DIDATICO,
	"salvamento_automatico": true,
}

static var _valores := {}


static func volume_do_jogo() -> int:
	return int(valor("volume_do_jogo"))


static func volume_da_musica() -> int:
	return int(valor("volume_da_musica"))


static func dificuldade() -> String:
	return str(valor("dificuldade"))


static func desafio() -> bool:
	return dificuldade() == DESAFIO


static func salvamento_automatico() -> bool:
	return valor("salvamento_automatico") == true


static func valor(chave: String) -> Variant:
	if _valores.is_empty():
		carregar()
	return _valores.get(chave, PADRAO.get(chave))


## Troca uma configuração, aplica (volumes) e grava no arquivo. Valor fora do
## permitido é ajustado (volume) ou ignorado (dificuldade desconhecida).
## `gravar` = false só muda na memória (os testes usam, para não mexer no arquivo).
static func definir(chave: String, novo: Variant, gravar := true) -> void:
	if not PADRAO.has(chave):
		push_warning("Configuração desconhecida: " + chave)
		return
	if _valores.is_empty():
		carregar()
	_valores[chave] = _validar(chave, novo)
	aplicar()
	if gravar:
		salvar()


## Lê o arquivo (o que falta ou não vale fica com o padrão) e aplica.
static func carregar() -> void:
	_valores = PADRAO.duplicate()
	var arquivo := ConfigFile.new()
	if arquivo.load(ARQUIVO) == OK:
		for chave in PADRAO:
			if arquivo.has_section_key(SECAO, chave):
				_valores[chave] = _validar(chave, arquivo.get_value(SECAO, chave))
	aplicar()


static func salvar() -> bool:
	var arquivo := ConfigFile.new()
	for chave in PADRAO:
		arquivo.set_value(SECAO, chave, valor(chave))
	return arquivo.save(ARQUIVO) == OK


## Volta tudo ao padrão (e apaga o arquivo, se `apagar_arquivo`).
static func restaurar_padrao(apagar_arquivo := true) -> void:
	if apagar_arquivo and FileAccess.file_exists(ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	_valores = PADRAO.duplicate()
	aplicar()


## Põe os volumes nas barras de áudio. 0 deixa a barra muda.
static func aplicar() -> void:
	garantir_barras()
	_volume_na_barra(BARRA_DO_JOGO, volume_do_jogo())
	_volume_na_barra(BARRA_DA_MUSICA, volume_da_musica())


## As barras Musica e Efeitos vêm de default_bus_layout.tres; se faltarem (o
## arquivo foi apagado, por exemplo), são criadas aqui, ligadas à Master.
static func garantir_barras() -> void:
	for nome in [BARRA_DA_MUSICA, BARRA_DOS_EFEITOS]:
		if AudioServer.get_bus_index(nome) == -1:
			AudioServer.add_bus()
			var indice := AudioServer.bus_count - 1
			AudioServer.set_bus_name(indice, nome)
			AudioServer.set_bus_send(indice, BARRA_DO_JOGO)


## Volume em decibéis que a barra recebe para `porcentagem` (0 a 100).
static func decibeis(porcentagem: int) -> float:
	return linear_to_db(clampi(porcentagem, 0, 100) / 100.0) if porcentagem > 0 else -80.0


static func _volume_na_barra(nome: String, porcentagem: int) -> void:
	var indice := AudioServer.get_bus_index(nome)
	if indice == -1:
		return
	AudioServer.set_bus_volume_db(indice, decibeis(porcentagem))
	AudioServer.set_bus_mute(indice, porcentagem <= 0)


static func _validar(chave: String, novo: Variant) -> Variant:
	match chave:
		"volume_do_jogo", "volume_da_musica":
			if novo is int or novo is float or (novo is String and novo.is_valid_float()):
				return clampi(int(round(float(novo))), 0, 100)
		"dificuldade":
			if str(novo) in DIFICULDADES:
				return str(novo)
		"salvamento_automatico":
			if novo is bool:
				return novo
	# Valor que não serve: fica o que já estava (ou o padrão).
	return _valores.get(chave, PADRAO[chave])
