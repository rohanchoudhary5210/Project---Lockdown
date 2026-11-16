extends SceneTree

## Tool script to generate procedural materials for Project: Lockdown.
## Uses FastNoiseLite + NoiseTexture2D with triplanar projection for zero-asset materials.

func _initialize() -> void:
	call_deferred("_run_generation")

func _run_generation() -> void:
	print("--- Generating Procedural Materials ---")
	var dir = "res://game/assets/materials/procedural"
	DirAccess.make_dir_recursive_absolute(dir)
	
	# 1. Base Wall Noise Texture
	var noise_wall = FastNoiseLite.new()
	noise_wall.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_wall.frequency = 0.04
	noise_wall.fractal_octaves = 3
	
	var tex_wall_noise = NoiseTexture2D.new()
	tex_wall_noise.noise = noise_wall
	tex_wall_noise.width = 256
	tex_wall_noise.height = 256
	tex_wall_noise.seamless = true
	tex_wall_noise.generate_mipmaps = true
	
	# 2. Floor Tile Noise Texture (Cellular)
	var noise_floor = FastNoiseLite.new()
	noise_floor.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_floor.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise_floor.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise_floor.frequency = 0.08
	
	var tex_floor_noise = NoiseTexture2D.new()
	tex_floor_noise.noise = noise_floor
	tex_floor_noise.width = 256
	tex_floor_noise.height = 256
	tex_floor_noise.seamless = true
	tex_floor_noise.generate_mipmaps = true
	
	# 3. Metal Noise Texture (Fine scratches)
	var noise_metal = FastNoiseLite.new()
	noise_metal.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_metal.frequency = 0.12
	noise_metal.fractal_octaves = 2
	
	var tex_metal_noise = NoiseTexture2D.new()
	tex_metal_noise.noise = noise_metal
	tex_metal_noise.width = 256
	tex_metal_noise.height = 256
	tex_metal_noise.seamless = true
	tex_metal_noise.generate_mipmaps = true
	
	# 4. Wood Grain Noise Texture (Stretched)
	var noise_wood = FastNoiseLite.new()
	noise_wood.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_wood.frequency = 0.06
	noise_wood.fractal_octaves = 3
	
	var tex_wood_noise = NoiseTexture2D.new()
	tex_wood_noise.noise = noise_wood
	tex_wood_noise.width = 256
	tex_wood_noise.height = 256
	tex_wood_noise.seamless = true
	tex_wood_noise.generate_mipmaps = true
	
	# 5. Ceiling Noise Texture
	var noise_ceiling = FastNoiseLite.new()
	noise_ceiling.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_ceiling.frequency = 0.05
	noise_ceiling.fractal_octaves = 2
	
	var tex_ceiling_noise = NoiseTexture2D.new()
	tex_ceiling_noise.noise = noise_ceiling
	tex_ceiling_noise.width = 256
	tex_ceiling_noise.height = 256
	tex_ceiling_noise.seamless = true
	tex_ceiling_noise.generate_mipmaps = true
	
	# Load wall grime shader
	var grime_shader = load("res://game/assets/shaders/wall_grime.gdshader")
	
	# Material A: Concrete Wall (Corridor, stairwells, utility, meter room)
	var mat_concrete = ShaderMaterial.new()
	mat_concrete.shader = grime_shader
	mat_concrete.set_shader_parameter("base_color", Color(0.32, 0.34, 0.37, 1.0))
	mat_concrete.set_shader_parameter("grime_color", Color(0.10, 0.09, 0.08, 1.0))
	mat_concrete.set_shader_parameter("noise_tex", tex_wall_noise)
	mat_concrete.set_shader_parameter("uv_scale", 0.35)
	mat_concrete.set_shader_parameter("grime_height", 0.9)
	mat_concrete.set_shader_parameter("roughness_base", 0.8)
	var err_conc = ResourceSaver.save(mat_concrete, dir + "/mat_concrete_wall.tres")
	print("Saved mat_concrete_wall.tres: ", err_conc)
	
	# Material B: Plaster Wall (Apartments 101-104, Common Room)
	var mat_plaster = ShaderMaterial.new()
	mat_plaster.shader = grime_shader
	mat_plaster.set_shader_parameter("base_color", Color(0.48, 0.46, 0.42, 1.0))
	mat_plaster.set_shader_parameter("grime_color", Color(0.12, 0.11, 0.09, 1.0))
	mat_plaster.set_shader_parameter("noise_tex", tex_wall_noise)
	mat_plaster.set_shader_parameter("uv_scale", 0.45)
	mat_plaster.set_shader_parameter("grime_height", 0.8)
	mat_plaster.set_shader_parameter("roughness_base", 0.72)
	var err_plas = ResourceSaver.save(mat_plaster, dir + "/mat_plaster_wall.tres")
	print("Saved mat_plaster_wall.tres: ", err_plas)
	
	# Material C: Tiled Floor (StandardMaterial3D)
	var mat_floor = StandardMaterial3D.new()
	mat_floor.albedo_color = Color(0.26, 0.27, 0.29, 1.0)
	mat_floor.albedo_texture = tex_floor_noise
	mat_floor.roughness = 0.45
	mat_floor.uv1_triplanar = true
	mat_floor.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var err_floor = ResourceSaver.save(mat_floor, dir + "/mat_tiled_floor.tres")
	print("Saved mat_tiled_floor.tres: ", err_floor)
	
	# Material D: Ceiling (StandardMaterial3D)
	var mat_ceiling = StandardMaterial3D.new()
	mat_ceiling.albedo_color = Color(0.28, 0.29, 0.31, 1.0)
	mat_ceiling.albedo_texture = tex_ceiling_noise
	mat_ceiling.roughness = 0.85
	mat_ceiling.uv1_triplanar = true
	mat_ceiling.uv1_scale = Vector3(0.4, 0.4, 0.4)
	var err_ceil = ResourceSaver.save(mat_ceiling, dir + "/mat_ceiling.tres")
	print("Saved mat_ceiling.tres: ", err_ceil)
	
	# Material E: Metal (Barricades / Doorways)
	var mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.22, 0.23, 0.26, 1.0)
	mat_metal.albedo_texture = tex_metal_noise
	mat_metal.metallic = 0.85
	mat_metal.roughness = 0.38
	mat_metal.uv1_triplanar = true
	mat_metal.uv1_scale = Vector3(0.6, 0.6, 0.6)
	var err_metal = ResourceSaver.save(mat_metal, dir + "/mat_metal.tres")
	print("Saved mat_metal.tres: ", err_metal)
	
	# Material F: Wood (Cover Boxes)
	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.42, 0.31, 0.20, 1.0)
	mat_wood.albedo_texture = tex_wood_noise
	mat_wood.roughness = 0.72
	mat_wood.metallic = 0.0
	mat_wood.uv1_triplanar = true
	mat_wood.uv1_scale = Vector3(0.3, 1.2, 0.3) # Stretched for grain
	var err_wood = ResourceSaver.save(mat_wood, dir + "/mat_wood.tres")
	print("Saved mat_wood.tres: ", err_wood)
	
	# ----------------------------------------------------
	# LOW QUALITY VARIANTS (Flat color + roughness, no noise textures, no triplanar)
	# ----------------------------------------------------
	print("--- Generating Cheap Non-Triplanar Low Quality Materials ---")
	
	var mat_concrete_low = StandardMaterial3D.new()
	mat_concrete_low.albedo_color = Color(0.32, 0.34, 0.37, 1.0)
	mat_concrete_low.roughness = 0.8
	ResourceSaver.save(mat_concrete_low, dir + "/mat_concrete_wall_low.tres")
	
	var mat_plaster_low = StandardMaterial3D.new()
	mat_plaster_low.albedo_color = Color(0.48, 0.46, 0.42, 1.0)
	mat_plaster_low.roughness = 0.72
	ResourceSaver.save(mat_plaster_low, dir + "/mat_plaster_wall_low.tres")
	
	var mat_floor_low = StandardMaterial3D.new()
	mat_floor_low.albedo_color = Color(0.26, 0.27, 0.29, 1.0)
	mat_floor_low.roughness = 0.45
	ResourceSaver.save(mat_floor_low, dir + "/mat_tiled_floor_low.tres")
	
	var mat_ceiling_low = StandardMaterial3D.new()
	mat_ceiling_low.albedo_color = Color(0.28, 0.29, 0.31, 1.0)
	mat_ceiling_low.roughness = 0.85
	ResourceSaver.save(mat_ceiling_low, dir + "/mat_ceiling_low.tres")
	
	var mat_metal_low = StandardMaterial3D.new()
	mat_metal_low.albedo_color = Color(0.22, 0.23, 0.26, 1.0)
	mat_metal_low.metallic = 0.85
	mat_metal_low.roughness = 0.38
	ResourceSaver.save(mat_metal_low, dir + "/mat_metal_low.tres")
	
	var mat_wood_low = StandardMaterial3D.new()
	mat_wood_low.albedo_color = Color(0.42, 0.31, 0.20, 1.0)
	mat_wood_low.roughness = 0.72
	ResourceSaver.save(mat_wood_low, dir + "/mat_wood_low.tres")
	
	print("--- Procedural Materials Generated Successfully! ---")
	quit(0)
