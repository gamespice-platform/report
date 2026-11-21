@tool
extends EditorPlugin

## Editor entry point for GameSpice Report. No autoloads: a game owns its report node.


func _enter_tree() -> void:
	add_custom_type("GSReport", "Node", load("res://addons/gs_report/runtime/gs_report.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("GSReport")
