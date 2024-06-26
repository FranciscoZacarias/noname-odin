package odinner

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"
import lm "core:math/linalg/glsl"

Face_Type :: enum {
	Type_Empty = 0,
	Type_Triangle,
	Type_Quad
}

Wavefront_Object :: struct {
	name: string,

  vertex:         [dynamic]lm.vec3, // Geometric Vertices
  vertex_texture: [dynamic]lm.vec3, // Texture coordinates
  vertex_normal:  [dynamic]lm.vec3, // Vertex normals

	face_type: Face_Type,
	// These START AT 1!
	// vertex_index/vertex_texture_index/vertex_normal_index
	face_triangles: [dynamic][3][3]u64,
	face_quads:     [dynamic][4][3]u64,
}

parse_wavefront :: proc (obj_path: string) -> (obj: Wavefront_Object){
	obj_source, ok := os.read_entire_file(obj_path)
	if !ok {
		fmt.println("Unable to load wavefront file: %v", obj_path)
		assert(false)
	}
	defer delete(obj_source)

	obj.vertex         = make([dynamic]lm.vec3, 0)
	obj.vertex_texture = make([dynamic]lm.vec3, 0)
	obj.vertex_normal	 = make([dynamic]lm.vec3, 0)

	it := string(obj_source)
	obj_src_lines := 0
	for _ in strings.split_lines_iterator(&it) { obj_src_lines += 1 }
	
	it = string(obj_source)
	for line in strings.split_lines_iterator(&it) {
		if len(line) == 0 {
			continue
		}
		
		elems := strings.split(line, " ")
		switch elems[0] {
			case "g": {
				assert(len(elems) == 2, "[Wavefront] The 'g' value had more than 1 value.")
				assert(obj.name == "",  "[Wavefront] Tried to set 'g' value twice.")
				obj.name = elems[1]
			}

			case "v": {
				v: lm.vec3
				v_index: u32 = 0
				for elem, index in elems {
					if index == 0 || len(elem) == 0 {
						continue
					} 
					v[v_index], ok = strconv.parse_f32(elem)
					if !ok {
						fmt.printf("[Wavefront] Unable to  convert v value: '%v' to an f32.", elem)
						assert(false)
					}
					v_index += 1
				}
				append(&obj.vertex, v)
			}

			case "vn": {
				vn: lm.vec3
				vn_index: u32 = 0
				for elem, index in elems {
					if index == 0 || len(elem) == 0 {
						continue
					} 
					vn[vn_index], ok = strconv.parse_f32(elem)
					if !ok {
						fmt.printf("[Wavefront] Unable to convert vn value: '%v' to an f32.", elem)
						assert(false)
					}
					vn_index += 1
				}
				append(&obj.vertex_normal, vn)
			}

			case "vt": {
				vt: lm.vec3
				vt_index: u32 = 0
				for elem, index in elems {
					if index == 0 || len(elem) == 0 {
						continue
					} 
					vt[vt_index], ok = strconv.parse_f32(elem)
					if !ok {
						fmt.printf("[Wavefront] Unable to convert vt value: '%v' to an f32.", elem)
						assert(false)
					}
					vt_index += 1
				}
				append(&obj.vertex_texture, vt)
			}

			case "f": {
				if obj.face_type == .Type_Empty {
					if len(elems) == 4 {
						obj.face_type = .Type_Triangle
						obj.face_triangles = make([dynamic][3][3]u64, 0)
						reserve(&obj.face_triangles, int(f32(obj_src_lines)*0.4))
					} else if len(elems) == 5 {
						obj.face_type = .Type_Quad
						obj.face_quads = make([dynamic][4][3]u64, 0)
						reserve(&obj.face_quads, int(f32(obj_src_lines)*0.4))
					} else {
						assert(false, "[Wavefront] Unexpected number of vertices specified in 'f' value of Wavefront object")
					}
				}

				switch obj.face_type {
					case .Type_Empty: {
						fmt.printf("[Wavefront] Face type was empty and should've already been set.")
						assert(false)
					}

					case .Type_Triangle: {
						data: [3][3]u64

						triangles_index := 0
						for elem, i in elems {
							if i == 0 || len(elem) == 0 {
								continue
							}

							face_triangle_indices: [3]u64
							indices := strings.split(elem, "/")
							for index, j in indices {
								face_triangle_indices[j], ok = strconv.parse_u64(index)
								if !ok {
									fmt.printf("[Wavefront] Unable to convert f value: '%v' to u64.", index)
									assert(false)
								}
							}
							data[triangles_index] = face_triangle_indices
							triangles_index += 1
						}

						append(&obj.face_triangles, data)
					}

					case .Type_Quad: {
						data: [4][3]u64

						quads_index := 0
						for elem, i in elems {
							if i == 0 || len(elem) == 0 {
								continue
							}

							face_quads_indices: [3]u64
							indices := strings.split(elem, "/")
							for index, j in indices {
								face_quads_indices[j], ok = strconv.parse_u64(index)
								if !ok {
									fmt.printf("[Wavefront] Unable to convert f value: '%v' to u64.", index)
									assert(false)
								}
							}
							data[quads_index] = face_quads_indices
							quads_index += 1
						}

						append(&obj.face_quads, data)
					}
				}
			}
			case: {
				fmt.printf("[Wavefront] Unhandled prefix '%v' in '%v'\n", elems[0], obj_path)
			}
		}
	}

	print_wavefront_obj(obj)
	return obj
}

@(private="file")
print_wavefront_obj :: proc (obj: Wavefront_Object) {
	fmt.printf("%v.obj\n", obj.name)
	fmt.printf(" Geometric Vertices:\n")
	for v in obj.vertex {
		fmt.printf("  v %v\n", v)
	}
	fmt.printf(" Texture Coordinates:\n")
	for vt in obj.vertex_texture {
		fmt.printf("  vt %v\n", vt)
	}
	fmt.printf(" Vertex normals:\n")
	for vn in obj.vertex_normal {
		fmt.printf("  vn %v\n", vn)
	}
	fmt.printf(" Face_Type: %v\n", obj.face_type)
	if obj.face_type == .Type_Triangle {
		for f in obj.face_triangles {
			fmt.printf("  f %v\n", f)
		}
	} else if obj.face_type == .Type_Quad {
		for f in obj.face_quads {
			fmt.printf("  f %v\n", f)
		}
	}
}
