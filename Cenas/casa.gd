extends Node

func _ready() -> void:
	$AnimationPlayer.play("Andando1")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Andando1":
		get_tree().change_scene_to_file("res://Assets/Cenas/quintal.tscn")
