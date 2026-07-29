extends Control

func resume():
	get_tree().paused=false
	$AnimationPlayer.play_backwards("blur")
	
func pause():
		get_tree().paused=true
		$AnimationPlayer.play("blur")

func testEsc():
	if Input.is_action_just_pressed("escape") and paused()==false
	resume()
	elif Input.is_action_just_pressed("escape") and paused()==true
	pause()
	

func _on_continuabtn_pressed() -> void:
	resume()
	


func _on_iniciobtn_pressed() -> void:
	get_tree().reload_current_scene()


func _on_sairbtn_pressed() -> void:
	get_tree().quit()
