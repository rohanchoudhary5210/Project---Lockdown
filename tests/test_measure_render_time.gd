extends SceneTree

func _init() -> void:
	var vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("Method exists: viewport_set_measure_render_time")
	print("CPU: ", RenderingServer.viewport_get_measured_render_time_cpu(vp))
	print("GPU: ", RenderingServer.viewport_get_measured_render_time_gpu(vp))
	quit(0)
