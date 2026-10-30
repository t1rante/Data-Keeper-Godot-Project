extends RefCounted
## Caminho do jogador entre as cenas, com os savepoints no lugar certo:
##
##   título -> escolha de arquivo -> casa (manhã) ................. início do dia
##   casa -> porta -> caminhada (Cenas/caminho) -> escritório ..... antes do cliente
##   Bruno e Ana -> conversa com o cliente -> quadro (tutorial da
##   Ana, se a fase tiver) -> verificação -> ENTREGAR ................ fim da fase
##   casa (noite) -> cama -> casa (manhã do dia seguinte) ......... início do dia
##   menu de opções > Salvar (em casa ou no quadro) ............... manual
##
## Os savepoints só gravam com o salvamento automático ligado (configurações);
## o SALVAR do menu grava sempre.
##
## As cenas chamam estas funções em vez de trocar de cena sozinhas.

const Jogo = preload("res://Script/jogo/jogo.gd")
const Saves = preload("res://Script/jogo/saves.gd")
const Fases = preload("res://Script/jogo/fases.gd")
const Dialogos = preload("res://Script/jogo/dialogos.gd")
const Configuracoes = preload("res://Script/jogo/configuracoes.gd")
const Musica = preload("res://Script/jogo/musica.gd")

const CENA_TITULO := "res://Cenas/telas/title_screen.tscn"
const CENA_ARQUIVOS := "res://Cenas/telas/escolha_de_arquivo.tscn"
const CENA_HOME := "res://Cenas/home/home.tscn"
const CENA_CAMINHO := "res://Cenas/caminho/casa.tscn"
const CENA_QUADRO := "res://Cenas/quadro/quadro.tscn"


static func novo_jogo(numero: int, nome := "") -> void:
	Musica.parar()  # a música do menu some quando o jogo começa
	Jogo.novo_jogo(numero, nome)
	salvar_no_savepoint("inicio_do_dia", "home")
	_trocar(CENA_HOME)


## Carrega o arquivo e continua de onde ele foi salvo. False se o arquivo não vale.
static func continuar(numero: int) -> bool:
	var dados := Saves.carregar(numero)
	if dados.is_empty():
		return false
	Musica.parar()
	match str(dados.lugar):
		"cliente":
			ir_para_o_cliente()
		"quadro":
			_trocar(CENA_QUADRO)  # o quadro remonta o diagrama salvo (Jogo.diagrama)
		_:
			_trocar(CENA_HOME)
	return true


## Porta de casa: sai para o trabalho (a caminhada termina em ir_para_o_cliente).
static func ir_trabalhar() -> void:
	if not Jogo.pode_trabalhar():
		return
	Jogo.fase_atual = Jogo.fase_do_dia()
	Jogo.diagrama = {}
	Jogo.conversa = []
	_trocar(CENA_CAMINHO)


## Chegou ao escritório (ou carregou esse savepoint): salva, começa a conversa
## do dia (os colegas e depois o cliente, dialogos.gd) e abre o quadro por baixo
## dela. O tutorial da fase, se houver, começa no quadro depois da conversa.
static func ir_para_o_cliente() -> void:
	if Jogo.fase_atual == "":
		Jogo.fase_atual = Jogo.fase_do_dia()
	salvar_no_savepoint("antes_do_cliente", "cliente")
	Jogo.conversa = []
	Jogo.tutorial_pendente = Fases.dados(Jogo.fase_atual).tutorial != ""
	if Dialogic.current_timeline == null:
		Dialogos.comecar_dia(Jogo.fase_atual)
	_trocar(CENA_QUADRO)


## ENTREGAR na tela de verificação: recebe, salva e volta para casa (noite).
static func entregar_fase(porcentagem: float) -> int:
	Musica.parar()  # a música do quadro some na volta para casa
	var pago := Jogo.concluir_fase(porcentagem)
	salvar_no_savepoint("fim_da_fase", "home")
	_trocar(CENA_HOME)
	return pago


## Cama: passa para o dia seguinte e salva o começo dele.
static func dormir() -> void:
	if not Jogo.pode_dormir():
		return
	Jogo.dormir()
	salvar_no_savepoint("inicio_do_dia", "home")
	_trocar(CENA_HOME)


## Menu de opções > Salvar. `lugar`: "home" ou "quadro". Grava mesmo com o
## salvamento automático desligado.
static func salvar_pelo_menu(lugar: String) -> bool:
	return Saves.salvar("manual", lugar)


## Savepoint automático: só grava com o salvamento automático ligado.
static func salvar_no_savepoint(motivo: String, lugar: String) -> bool:
	if not Configuracoes.salvamento_automatico():
		return false
	return Saves.salvar(motivo, lugar)


static func sair_para_o_titulo() -> void:
	var arvore := _arvore()
	arvore.paused = false
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)
	_trocar(CENA_TITULO)


static func _arvore() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _trocar(cena: String) -> void:
	_arvore().change_scene_to_file(cena)
