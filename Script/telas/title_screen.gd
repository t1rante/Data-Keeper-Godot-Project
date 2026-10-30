extends Control
## Tela de título (Cenas/telas/title_screen.tscn, a cena principal do projeto).

## START abre a escolha de arquivo (novo jogo ou continuar um save); OPCOES e
## CREDITOS abrem as configurações e os créditos por cima do título.
const PRIMEIRA_CENA := "res://Cenas/telas/escolha_de_arquivo.tscn"
const CONFIGURACOES = preload("res://Cenas/telas/configuracoes.tscn")
const CREDITOS = preload("res://Cenas/telas/creditos.tscn")
const Configuracoes = preload("res://Script/jogo/configuracoes.gd")
const Musica = preload("res://Script/jogo/musica.gd")
const Sons = preload("res://Script/jogo/sons.gd")


func _ready() -> void:
	Configuracoes.carregar()  # volumes gravados valem desde a abertura do jogo
	Musica.tocar(Musica.MENU)
	Sons.instalar()  # tlin nos botões do jogo todo


func _on_startbtn_pressed() -> void:
	get_tree().change_scene_to_file(PRIMEIRA_CENA)


func _on_opcoesbtn_pressed() -> void:
	if not has_node("Configuracoes"):
		add_child(CONFIGURACOES.instantiate())


func _on_creditosbtn_pressed() -> void:
	if not has_node("Creditos"):
		add_child(CREDITOS.instantiate())


func _on_sairbtn_pressed() -> void:
	get_tree().quit()
