extends CanvasLayer
## Menu de opções (Cenas/ui/menu_de_opcoes.tscn): pausa o jogo e oferece
## CONTINUAR, SALVAR, CONFIGURACOES e SAIR PARA O MENU. Quem abre diz onde o save
## retoma (lugar_do_save: "home" ou "quadro"); o save é o savepoint manual
## (saves.gd), que funciona mesmo com o salvamento automático desligado.
## Esc fecha (com as configurações abertas, fecha só elas).

const Fluxo = preload("res://Script/jogo/fluxo.gd")
const Jogo = preload("res://Script/jogo/jogo.gd")
const CONFIGURACOES = preload("res://Cenas/telas/configuracoes.tscn")

var lugar_do_save := "home"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	%Continuar.pressed.connect(fechar)
	%Salvar.pressed.connect(_salvar)
	%Configuracoes.pressed.connect(abrir_configuracoes)
	%Sair.pressed.connect(_sair)
	%Aviso.text = "Arquivo %d · Dia %d · %s" % [Jogo.slot, Jogo.dia, Jogo.reais(Jogo.centavos)] if Jogo.slot > 0 \
			else "Sem arquivo de save (jogo aberto direto no editor)."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fechar()


func fechar() -> void:
	get_tree().paused = false
	queue_free()


func abrir_configuracoes() -> void:
	add_child(CONFIGURACOES.instantiate())


func _salvar() -> void:
	if Fluxo.salvar_pelo_menu(lugar_do_save):
		%Aviso.text = "Jogo salvo no arquivo %d." % Jogo.slot
	else:
		%Aviso.text = "Não deu para salvar: nenhum arquivo de save em uso."


func _sair() -> void:
	get_tree().paused = false
	Fluxo.sair_para_o_titulo()
