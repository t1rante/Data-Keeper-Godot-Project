extends Node2D

var entidade = preload("res://Cenas/entidade.tscn")
var relacionamento = preload("res://Cenas/relacionamento.tscn")
var atributos = preload("res://Cenas/atributo.tscn")
var linha_cena = preload("res://Cenas/linha.tscn")
var conexoes = []
var contador_entidades = 0
var contador_relacionamentos = 0
var contador_atributos = 0
var objeto_focado: Node2D = null 
var primeiro_selecionado: Node2D = null

@export var obj_enti: Area2D
@export var obj_rela: Area2D
@export var obj_atri: Area2D
@export var enti: Sprite2D
@export var rela: Sprite2D

func _ready():
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"entidades": {}, "relacionamentos": {}, "conexoes": []}))
	file.close()
	if obj_enti:
		obj_enti.connect("input_event", _on_entidade)
	if obj_rela:
		obj_rela.connect("input_event", _on_relacionamento)
	if obj_atri:
		obj_atri.connect("input_event", _on_atributo)

func _on_entidade(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		contador_entidades += 1
		var instancia = entidade.instantiate()

		instancia.id_objeto = "Entidade_" + str(contador_entidades)
		instancia.tipo_objeto = "entidades"
		
		instancia.selecionado.connect(on_no_selecionado)
		
		get_parent().add_child(instancia)

func _on_atributo(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		contador_atributos += 1
		var instancia = atributos.instantiate()
		
		instancia.id_objeto = "Atributo_" + str(contador_atributos)
		instancia.tipo_objeto = "atributos"
		
		instancia.selecionado.connect(on_no_selecionado)
		
		get_parent().add_child(instancia)

func _on_relacionamento(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		contador_relacionamentos += 1
		var instancia = relacionamento.instantiate()
		
		instancia.id_objeto = "Relacionamento_" + str(contador_relacionamentos)
		instancia.tipo_objeto = "relacionamentos"
		
		instancia.selecionado.connect(on_no_selecionado)
		
		get_parent().add_child(instancia)

func on_no_selecionado(no: Node2D):
	objeto_focado = no
	print("Objeto focado para Delete: ", objeto_focado.name)
	
	if primeiro_selecionado == null:
		primeiro_selecionado = no
		print("Primeiro selecionado para linha: ", no.name)
	else:
		if primeiro_selecionado == no:
			primeiro_selecionado = null
			print("Seleção de linha cancelada.")
			return
			
		var nova_linha = linha_cena.instantiate()
		get_parent().add_child(nova_linha)
		get_parent().move_child(nova_linha, 0)
		nova_linha.definir_alvos(primeiro_selecionado, no)
		
		if nova_linha.has_method("salvar_conexao"):
			nova_linha.salvar_conexao()
			
		conexoes.append({
			"de": primeiro_selecionado,
			"para": no,
			"linha": nova_linha,
		}) 
		primeiro_selecionado = null

func limpar_outras_pks(atributo_pk_id: String):
	if not FileAccess.file_exists("user://savegame.json"):
		return
		
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	var dados = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not dados or not dados.has("conexoes") or not dados.has("atributos"):
		return

	var entidade_pai_id = ""
	for con in dados["conexoes"]:
		if con["de"] == atributo_pk_id and con["para"].begins_with("Entidade_"):
			entidade_pai_id = con["para"]
			break
		elif con["para"] == atributo_pk_id and con["de"].begins_with("Entidade_"):
			entidade_pai_id = con["de"]
			break

	if entidade_pai_id == "":
		return 

	var atributos_irmaos = []
	for con in dados["conexoes"]:
		if con["de"] == entidade_pai_id and con["para"] != atributo_pk_id:
			if dados["atributos"].has(con["para"]):
				atributos_irmaos.append(con["para"])
		elif con["para"] == entidade_pai_id and con["de"] != atributo_pk_id:
			if dados["atributos"].has(con["de"]):
				atributos_irmaos.append(con["de"])

	for atr_id in atributos_irmaos:
		if dados["atributos"].has(atr_id):
			dados["atributos"][atr_id]["cp"] = false

	var file_w = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file_w.store_string(JSON.stringify(dados, "\t"))
	file_w.close()

	for node in get_parent().get_children():
		if node.get("id_objeto") in atributos_irmaos:
			node.chave_primaria = false
			if node.has_method("atualizar_visual_pk"):
				node.atualizar_visual_pk(false)

func verificar_vitoria():
	var arquivo_gabarito = FileAccess.open("res://gabaritos/gabarito1.json", FileAccess.READ)
	if not arquivo_gabarito:
		print("❌ Erro crítico: Arquivo de gabarito não encontrado!")
		return
	var dados_gabarito_brutos = JSON.parse_string(arquivo_gabarito.get_as_text())
	arquivo_gabarito.close()
	
	if not dados_gabarito_brutos.has("diagrama"):
		print("❌ Erro: O arquivo de gabarito não possui a chave raiz 'diagrama'.")
		return
	var gabarito = dados_gabarito_brutos["diagrama"]
	
	if not FileAccess.file_exists("user://savegame.json"): 
		print("❌ Erro: Salve o jogo antes de verificar!")
		return
		
	var arquivo_player = FileAccess.open("user://savegame.json", FileAccess.READ)
	var dados_player = JSON.parse_string(arquivo_player.get_as_text())
	arquivo_player.close()

	var mapa_nomes = {}
	var nomes_entidades_player = []
	if dados_player.has("entidades"):
		for id in dados_player["entidades"]:
			var n = dados_player["entidades"][id]["nome"].to_lower().strip_edges()
			if n != "":
				nomes_entidades_player.append(n)
				mapa_nomes[id] = n
		
	var nomes_rela_player = []
	if dados_player.has("relacionamentos"):
		for id in dados_player["relacionamentos"]:
			var r = dados_player["relacionamentos"][id]["nome"].to_lower().strip_edges()
			if r != "":
				nomes_rela_player.append(r)
				mapa_nomes[id] = r

	var total_elementos_gabarito = 0
	var total_acertos = 0
	var lista_erros = []

	for entidade_gab in gabarito["entidades"]:
		var nome_certo = entidade_gab["nome"].to_lower().strip_edges()
		total_elementos_gabarito += 1
		
		if nome_certo in nomes_entidades_player:
			total_acertos += 1
		else:
			lista_erros.append("Faltando ou incorreta a entidade: '" + entidade_gab["nome"] + "'")

	for relato_gab in gabarito["relacionamentos"]:
		var nome_relato_certo = relato_gab["nome"].to_lower().strip_edges()
		var orig_certa = relato_gab["entidadeOrigem"]["nome"].to_lower().strip_edges()
		var dest_certa = relato_gab["entidadeDestino"]["nome"].to_lower().strip_edges()
		
		total_elementos_gabarito += 1
		
		if nome_relato_certo in nomes_rela_player:
			total_acertos += 1 
			
			var entidades_conectadas = []
			if dados_player.has("conexoes"):
				for conexao in dados_player["conexoes"]:
					var de_id = conexao["de"]
					var para_id = conexao["para"]
					
					if mapa_nomes.has(de_id) and mapa_nomes.has(para_id):
						var nome_de = mapa_nomes[de_id]
						var nome_para = mapa_nomes[para_id]
						
						if nome_de == nome_relato_certo and nome_para in nomes_entidades_player:
							entidades_conectadas.append(nome_para)
						elif nome_para == nome_relato_certo and nome_de in nomes_entidades_player:
							entidades_conectadas.append(nome_de)
			
			total_elementos_gabarito += 1
			if orig_certa in entidades_conectadas:
				total_acertos += 1
			else:
				lista_erros.append("O relacionamento '" + relato_gab["nome"] + "' deveria estar conectado a '" + relato_gab["entidadeOrigem"]["nome"] + "'.")
				
			total_elementos_gabarito += 1
			if dest_certa in entidades_conectadas:
				total_acertos += 1
			else:
				lista_erros.append("O relacionamento '" + relato_gab["nome"] + "' deveria estar conectado a '" + relato_gab["entidadeDestino"]["nome"] + "'.")
		else:
			lista_erros.append("Faltando ou incorreto o relacionamento: '" + relato_gab["nome"] + "'")

			total_elementos_gabarito += 2

	var porcentagem_acerto: float = 0.0
	if total_elementos_gabarito > 0:
		porcentagem_acerto = (float(total_acertos) / float(total_elementos_gabarito)) * 100.0

	var total_player = nomes_entidades_player.size() + nomes_rela_player.size()
	var total_nomes_gabarito = gabarito["entidades"].size() + gabarito["relacionamentos"].size()
	var itens_extras = max(0, total_player - total_nomes_gabarito)

	print("\n---------------------------------------------")
	print("        PORCENTAGEM DE ACERTOS: " + gabarito["nome"].to_upper())
	print("---------------------------------------------")
	print("Progresso Geral: %.1f%%" % porcentagem_acerto)
	print("Requisitos atendidos: %d de %d" % [total_acertos, total_elementos_gabarito])
	print("---------------------------------------------")

	if porcentagem_acerto >= 100.0:
		if itens_extras > 0:
			print("QUASE PERFEITO! 100%% de acerto, mas remova os %d itens extras da tela." % itens_extras)
		else:
			print("VITÓRIA PERFEITA! O diagrama está perfeito!")
			#if has_node("Prox_fase"):
			#	$Prox_fase.visible = true
	else:
		print("ENCONTRAMOS PROBLEMAS NO SEU MODELO:")
		for erro in lista_erros:
			print("  • " + erro)
			
		if itens_extras > 0:
			print("  • Cuidado: Você possui %d item(s) extra(s) desnecessário(s) na tela." % itens_extras)
	print("---------------------------------------------\n")

func _on_prox_fase_pressed() -> void:
	var fase2 = "res://Cenas/fase2.tscn"
	get_tree().change_scene_to_file(fase2)

func _on_button_pressed() -> void:
	verificar_vitoria();
