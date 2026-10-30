extends Control
## Menu de pausa (resto/control.tscn): Esc pausa e despausa.
## Ainda não foi colocado em nenhuma cena do jogo.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func resume():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")


func pause():
	get_tree().paused = true
	$AnimationPlayer.play("blur")


func _on_continuabtn_pressed() -> void:
	resume()


func _on_iniciobtn_pressed() -> void:
	get_tree().reload_current_scene()


func _on_sairbtn_pressed() -> void:
	get_tree().quit()
