extends Node

func _ready() -> void:
	$AnimationPlayer.play("Andando4")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Andando4":
		get_tree().change_scene_to_file("res://Assets/Cenas/escritorio_2.tscn")
