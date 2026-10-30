extends RefCounted
## Leitura e escrita dos arquivos JSON do jogo.
##
## CAMINHO_SAVE guarda o diagrama que está no quadro (blocos e ligações). Fica em
## user:// porque res:// não pode ser escrito num jogo exportado.

const CAMINHO_SAVE := "user://savegame.json"


static func existe(caminho: String) -> bool:
	return FileAccess.file_exists(caminho)


static func ler_texto(caminho: String) -> String:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	var texto := arquivo.get_as_text()
	arquivo.close()
	return texto


## Devolve o conteúdo do arquivo já convertido de JSON (null se o JSON for inválido).
static func ler(caminho: String) -> Variant:
	return JSON.parse_string(ler_texto(caminho))


## Grava `dados` como JSON. Devolve false se o arquivo não pôde ser aberto.
static func gravar(caminho: String, dados: Variant, indentacao := "\t") -> bool:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if not arquivo:
		return false
	arquivo.store_string(JSON.stringify(dados, indentacao))
	arquivo.close()
	return true
