extends Node

func _ready() -> void:
	$AnimationPlayer.play("Andando5")
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Andando5":
		Dialogic.start('Loja_de_roupa')
