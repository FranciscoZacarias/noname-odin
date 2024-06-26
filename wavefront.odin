package odinner

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"
import lm "core:math/linalg/glsl"

Default_Array_Size :: 1024

Face_Type :: enum {
	Type_Empty = 0,
	Type_Triangle,
	Type_Quad,
}

Wavefront_Object :: struct {
	name: string,

  vertex:         [dynamic]lm.vec3, // Geometric Vertices
  vertex_texture: [dynamic]lm.vec3, // Texture coordinates
  vertex_normal:  [dynamic]lm.vec3, // Vertex normals

	face_type: Face_Type,
	// These START AT 1!
	// vertex_index/vertex_texture_index/vertex_normal_index
	face: [dynamic][4][3]u64,
}

parse_wavefront :: proc (obj_path: string) -> (obj: Wavefront_Object){
	obj_source, ok := os.read_entire_file(obj_path)
	if !ok {
		fmt.printfln("Unable to load wavefront file: %v", obj_path)
		assert(false)
	}
	defer delete(obj_source)

	obj.vertex = make([dynamic]lm.vec3, 0)
	reserve(&obj.vertex, Default_Array_Size)
	obj.vertex_texture = make([dynamic]lm.vec3, 0)
	reserve(&obj.vertex_texture, Default_Array_Size)
	obj.vertex_normal	= make([dynamic]lm.vec3, 0)
	reserve(&obj.vertex_normal, Default_Array_Size)

	it := string(obj_source)
	obj_src_lines := 0
	for _ in strings.split_lines_iterator(&it) { obj_src_lines += 1 }
	
	it = string(obj_source)
	line_nr: u32
	for line in strings.split_lines_iterator(&it) {
		line_nr += 1
		if len(line) == 0 {
			continue
		}
		
		elems := strings.split(line, " ")
		switch elems[0] {
			case "#": {
				// This is a comment, we ignore.
			}

			case "g": {
				if obj.name != "" {
					fmt.println("[Wavefront] The 'g' value was set more than once.")
				}
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
						fmt.printfln("[Wavefront] Unable to  convert v value: '%v' to an f32.", elem)
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
						fmt.printfln("[Wavefront] Unable to convert vn value: '%v' to an f32.", elem)
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
						fmt.printfln("[Wavefront] Unable to convert vt value: '%v' to an f32.", elem)
						assert(false)
					}
					vt_index += 1
				}
				append(&obj.vertex_texture, vt)
			}

			case "f": {
				if obj.face_type == .Type_Empty {
					vertex_count := 0
					for i in 1..<len(elems) {
						if len(elems[i]) == 0 {
							continue
						}
						vertex_count += 1
					}

					if vertex_count == 3 {
						obj.face_type = .Type_Triangle
					} else if vertex_count == 4 {
						obj.face_type = .Type_Quad
					} else {
						fmt.printfln("[Wavefront] Unexpected number of vertices '%v' specified in 'f' value of Wavefront object. L:%v", len(elems), line_nr)
						assert(false)
					}
					obj.face = make([dynamic][4][3]u64, 0)
					reserve(&obj.face, int(f32(obj_src_lines)*0.4))
				}

				data: [4][3]u64
				vertex_index := 0
				
				for elem, i in elems {
					if i == 0 || len(elem) == 0 {
						continue
					}

					v_vt_vn: [3]u64
					if strings.contains(elem, "/") {
						indices := strings.split(elem, "/")
						for index, j in indices {
							v_vt_vn[j], ok = strconv.parse_u64(index)
							if !ok {
								v_vt_vn[j] = 0
							}
						}
						data[vertex_index] = v_vt_vn
						vertex_index += 1
					} else {
						v_vt_vn[0], ok = strconv.parse_u64(elem)
						data[vertex_index] = v_vt_vn
						vertex_index += 1
					}
				}

				append(&obj.face, data)
			}
			case: {
				fmt.printfln("[Wavefront] Unhandled prefix '%v' in '%v'", elems[0], obj_path)
			}
		}
	}

	print_wavefront_obj(obj)
	assert(false)
	return obj
}

@(private="file")
print_wavefront_obj :: proc (obj: Wavefront_Object) {
	fmt.printfln("%v.obj", obj.name)
	fmt.printfln(" Geometric Vertices:")
	for v in obj.vertex {
		fmt.printfln("  v %v", v)
	}
	fmt.printfln(" Texture Coordinates:")
	for vt in obj.vertex_texture {
		fmt.printfln("  vt %v", vt)
	}
	fmt.printfln(" Vertex normals:")
	for vn in obj.vertex_normal {
		fmt.printfln("  vn %v", vn)
	}
	fmt.printfln(" %v Vertices:", obj.face_type)
	for f in obj.face {
		fmt.printfln("  f %v", f)
	}
}
