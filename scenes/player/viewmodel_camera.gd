class_name ViewmodelCamera
extends Camera3D

## Project: Lockdown - Viewmodel Camera
## Synchronizes with the player's main camera to render weapon visuals on Layer 2
## via a SubViewport overlay, preventing viewmodel clipping into world geometry.
## Uses a dedicated fixed viewmodel FOV of 65 and a near plane of 0.01.
## Dedicated Environment supplies ambient light matching the world (no sky, no shadows).

const VIEWMODEL_FOV: float = 65.0

@export var main_camera: Camera3D

@onready var sub_viewport: SubViewport = get_parent() as SubViewport

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cull_mask = 2 # Only render visual layer 2 (viewmodels)
	fov = VIEWMODEL_FOV
	near = 0.01
	keep_aspect = Camera3D.KEEP_HEIGHT
	
	if sub_viewport:
		sub_viewport.own_world_3d = false
		sub_viewport.transparent_bg = true
		sub_viewport.positional_shadow_atlas_size = 0
		sub_viewport.positional_shadow_atlas_16_bits = false
		sub_viewport.positional_shadow_atlas_quad_0 = SubViewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
		sub_viewport.positional_shadow_atlas_quad_1 = SubViewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
		sub_viewport.positional_shadow_atlas_quad_2 = SubViewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
		sub_viewport.positional_shadow_atlas_quad_3 = SubViewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
	
	# Dedicated viewmodel Environment providing ambient light matching world ambient
	# without rendering sky or calculating shadows
	var env = Environment.new()
	env.background_mode = Environment.BG_KEEP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.38, 1.0)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment = env
	
	_sync_viewport_size()

func _sync_viewport_size() -> void:
	if sub_viewport:
		var root_vp = get_viewport()
		if root_vp:
			var vp_size = root_vp.size
			if vp_size.x > 0 and vp_size.y > 0 and sub_viewport.size != vp_size:
				sub_viewport.size = vp_size

func _process(_delta: float) -> void:
	if not main_camera:
		var player: Node = get_tree().get_first_node_in_group("player")
		if player and player.has_node("CameraPivot/Camera3D"):
			main_camera = player.get_node("CameraPivot/Camera3D")
	
	if main_camera:
		global_transform = main_camera.global_transform
	
	fov = VIEWMODEL_FOV
	_sync_viewport_size()
