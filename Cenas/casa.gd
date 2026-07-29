extends Node2D

func _ready():
	$AnimationPlayer.play("Andando1")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName):
	if anim_name == "Andando1":
		get_tree().change_scene_to_file("res://Cenas/quintal.tscn")
