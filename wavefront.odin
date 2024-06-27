package odinner

import "core:os"
import "core:strings"
import "core:strconv"
import "core:time"
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
	stopwatch: time.Stopwatch
	time.stopwatch_start(&stopwatch)

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

			case "v", "vn", "vt": {
				v: lm.vec3
				v_index: u32 = 0
				for i in 1..<len(elems) {
					elem := elems[i]
					v[v_index], ok = strconv.parse_f32(elem)
					v_index += 1
					if !ok {
						fmt.printfln("[Wavefront] Unable to  convert v value: '%v' to an f32.", elem)
						assert(false)
					}
				}

				switch elems[0] {
					case "v":  append(&obj.vertex, v)
					case "vn": append(&obj.vertex_normal, v)
					case "vt": append(&obj.vertex_texture, v)
				}
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
				}

				face_indices: [4][3]u64
				vertex_index := 0
				
				for elem, i in elems {
					if i == 0 || len(elem) == 0 {
						continue
					}
					if i > 4 {
						fmt.printfln("[Wavefront] Model %v will be broken. More than 4 index sets in a face L:%v\n Skipping.", obj_path, line_nr)
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
						face_indices[vertex_index] = v_vt_vn
						vertex_index += 1
					} else {
						v_vt_vn[0], ok = strconv.parse_u64(elem)
						face_indices[vertex_index] = v_vt_vn
						vertex_index += 1
					}
				}

				append(&obj.face, face_indices)
			}
			case: {
				fmt.printfln("[Wavefront] Unhandled prefix '%v' in '%v'\n %v: '%v'\n", elems[0], obj_path, line_nr, line)
			}
		}
	}

	time.stopwatch_stop(&stopwatch)
	duration := time.stopwatch_duration(stopwatch)
	fmt.printfln("[parse_wavefront] Parsed %v\n Time: %.4fms.\n", obj_path, time.duration_milliseconds(duration))
	return obj
}
