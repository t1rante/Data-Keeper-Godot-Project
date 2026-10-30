extends RefCounted
## Catálogo da loja do computador (dados/catalogo.json): skins, móveis e
## decorações da casa. Cada item: {"id", "tipo", "lugar", "nome", "preco" (R$),
## "descricao", "cor" ou "cores"}. Só um item equipado por lugar (jogo.gd).

const CAMINHO := "res://dados/catalogo.json"
const TIPOS := ["skin", "movel", "decoracao"]
const NOME_DO_TIPO := {"skin": "Skins", "movel": "Móveis", "decoracao": "Decoração"}

static var _itens := []


static func itens() -> Array:
	if _itens.is_empty():
		var dados = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO)) if FileAccess.file_exists(CAMINHO) else null
		for item in (dados.get("itens", []) if dados is Dictionary else []):
			if item is Dictionary and item.get("tipo") in TIPOS:
				item["preco"] = float(item.get("preco", 0))
				item["lugar"] = str(item.get("lugar", item.tipo))
				_itens.append(item)
	return _itens


static func item(id: String) -> Dictionary:
	for candidato in itens():
		if candidato.id == id:
			return candidato
	return {}


static func do_tipo(tipo: String) -> Array:
	return itens().filter(func(i): return i.tipo == tipo)
