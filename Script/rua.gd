extends Node

func _ready() -> void:
	$AnimationPlayer.play("Andando3")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Andando3":
		get_tree().change_scene_to_file("res://Assets/Cenas/esccritorio_1.tscn")
