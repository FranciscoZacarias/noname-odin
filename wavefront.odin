package odinner

import lm "core:math/linalg/glsl"

Wavefront_Object :: struct {
  vertex:         [dynamic]lm.vec3, // Geometric Vertices
  vertex_texture: [dynamic]lm.vec3, // Texture coordinates
  vertex_normal:  [dynamic]lm.vec3, // Vertex normals
  face:           [dynamic]lm.vec3, // Can be defined as a triangle or quad
}

parse_wavefront :: proc(obj_path: string) {
	// obj, ok := os.read_entire_file(obj_path)
	// if !ok {
	//	fmt.println("Unable to load wavefront file: %v", obj_path)
	//	assert(false)
	// }
 
}