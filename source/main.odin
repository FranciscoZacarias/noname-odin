package odinner

import "base:runtime"

import "core:fmt"
import lm "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

import ai "external/assimp"

Window_Width  : i32 : 1280
Window_Height : i32 : 720

Far_Plane  :: 1000.0
Near_Plane :: 0.1

Color_White : lm.vec4 : {1.0, 1.0, 1.0, 1.0}

Window :: struct {
	window: glfw.WindowHandle,

	time:       f32,
	delta_time: f32,
	last_time:  f32,

	camera:     Camera,
	view:       lm.mat4,
	projection: lm.mat4,
	
	near_plane:    f32,
	far_plane:     f32,

	input_state: Input_State,

	window_width:  i32,
	window_height: i32,
}

MainWindow: Window

main :: proc () {
	MainWindow = window_init()
	renderer_init(MainWindow.window_width, MainWindow.window_height)
	game_state_init()

	red   := renderer_load_color(1.0,   0,   0, 1.0)
	green := renderer_load_color(0,   1.0,   0, 1.0)
	blue  := renderer_load_color(0,     0, 1.0, 1.0)
	yell  := renderer_load_color(1.0, 1.0,   0, 0.7)
	kakashi_eye := renderer_load_texture("resources/kakashi.png")

	suzanne_from_assimp := ai.import_file("resources/suzanne.obj", u32(ai.aiPostProcessSteps.Triangulate | ai.aiPostProcessSteps.FlipUVs))
	if suzanne_from_assimp == nil || suzanne_from_assimp.mRootNode == nil || (suzanne_from_assimp.mFlags & u32(ai.aiSceneFlags.INCOMPLETE)) != 0 {
		fmt.eprintln("Assimp failed to load resources/suzanne.obj")
		assert(false)
	}

	suzanne_mesh := mesh_from_wavefront("resources/suzanne.obj")
	suzanne := game_state_push_entity(suzanne_mesh, yell)

	renderer_push_entity(suzanne)

	// XYZ axis
	renderer_push_line(lm.vec3{-32.0,  0.0,   0.0}, lm.vec3{32.0, 0.0,  0.0}, red)
	renderer_push_line(lm.vec3{ 0.0, -32.0,   0.0}, lm.vec3{0.0,  32.0, 0.0}, green)
	renderer_push_line(lm.vec3{ 0.0,   0.0, -32.0}, lm.vec3{0.0,  0.0,  32.0}, blue)

	// Quad tests
	q0 := Quad{lm.vec3{2.0, 2.0, -2.0}, 1, 1}
	renderer_push_quad(q0, lm.vec4{1.0, 1.0, 1.0, 1.0}, kakashi_eye)
	q1 := Quad{lm.vec3{-2.0, 2.0, -2.0}, 1, 1}
	renderer_push_quad(q1, lm.vec4{1.0, 1.0, 1.0, 1.0}, kakashi_eye)

	for !glfw.WindowShouldClose(MainWindow.window) {
		application_tick()

		renderer_draw(MainWindow.view, MainWindow.projection, MainWindow.window_width, MainWindow.window_height)

		glfw.SwapBuffers(MainWindow.window)
	}
}

window_init :: proc () -> (window: Window) {
	glfw.SetErrorCallback(error_callback)
	if !glfw.Init() {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

	window.window = glfw.CreateWindow(Window_Width, Window_Height, "noname-odin", nil, nil)
	if window.window == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		assert(false)
	}

	window.camera     = camera_init()
	window.projection = lm.identity(lm.mat4)
	window.view       = lm.identity(lm.mat4)
	window.far_plane  = Far_Plane
	window.near_plane = Near_Plane
	window.window_width  = Window_Width
	window.window_height = Window_Height

	window.input_state.mouse_current.coords.x  = Window_Width /2
	window.input_state.mouse_current.coords.y  = Window_Height/2
	window.input_state.mouse_previous.coords.x = Window_Width /2
	window.input_state.mouse_previous.coords.y = Window_Height/2

	glfw.MakeContextCurrent(window.window)
	glfw.SwapInterval(0)
	glfw.SetKeyCallback(window.window, key_callback)
	glfw.SetFramebufferSizeCallback(window.window, size_callback)
	glfw.SetCursorPosCallback(window.window, cursor_callback)
	glfw.SetMouseButtonCallback(window.window, button_callback)
	gl.load_up_to(4, 6, set_proc_address)

	fmt.printfln("[%v]: %v\n", gl.GetString(gl.VENDOR), gl.GetString(gl.RENDERER))

	return window
}

application_tick :: proc () {
	// Input and glfw events
	MainWindow.input_state.keyboard_previous = MainWindow.input_state.keyboard_current
	MainWindow.input_state.mouse_previous    = MainWindow.input_state.mouse_current
	glfw.PollEvents()

	// Perspective
	MainWindow.projection = lm.mat4Perspective(lm.radians(f32(45)), f32(MainWindow.window_width) / f32(MainWindow.window_height), MainWindow.near_plane, MainWindow.far_plane)
	MainWindow.view       = lm.mat4LookAt(MainWindow.camera.position, MainWindow.camera.position + MainWindow.camera.front, MainWindow.camera.up)

	// Time 
	MainWindow.time       = f32(glfw.GetTime())
  MainWindow.delta_time = MainWindow.time - MainWindow.last_time
  MainWindow.last_time  = MainWindow.time

	// Camera
	if is_button_down(MainWindow.input_state, .Button_RIGHT) {
		if is_button_released(MainWindow.input_state, .Button_RIGHT) {
			MainWindow.input_state.mouse_previous.coords = MainWindow.input_state.mouse_current.coords
		}

		MainWindow.camera.mode = .Mode_Fly
		camera_speed: f32 = Camera_Speed * MainWindow.delta_time
		if is_key_down(MainWindow.input_state, .Key_W) {
			delta: lm.vec3 = MainWindow.camera.front * camera_speed
			MainWindow.camera.position = MainWindow.camera.position + delta
		}
		if is_key_down(MainWindow.input_state, .Key_S) {
			delta: lm.vec3 = MainWindow.camera.front * camera_speed
			MainWindow.camera.position = MainWindow.camera.position - delta
		}
		if is_key_down(MainWindow.input_state, .Key_D) {
			cross: lm.vec3 = lm.cross_vec3(MainWindow.camera.front, MainWindow.camera.up)
			delta: lm.vec3 = cross * camera_speed
			MainWindow.camera.position = MainWindow.camera.position + delta
		}
		if is_key_down(MainWindow.input_state, .Key_A) {
			cross: lm.vec3 = lm.cross_vec3(MainWindow.camera.front, MainWindow.camera.up)
			delta: lm.vec3 = cross * camera_speed
			MainWindow.camera.position = MainWindow.camera.position - delta
		}
		if is_key_down(MainWindow.input_state, .Key_Q) {
			MainWindow.camera.position.y -= camera_speed
		}
		if is_key_down(MainWindow.input_state, .Key_E) {
			MainWindow.camera.position.y += camera_speed
		}

		x_offset := MainWindow.input_state.mouse_current.coords.x - MainWindow.input_state.mouse_previous.coords.x
		y_offset := MainWindow.input_state.mouse_previous.coords.y - MainWindow.input_state.mouse_current.coords.y

		MainWindow.camera.yaw   += f32(x_offset) * Camera_Sensitivity
		pitch := f32(y_offset) * Camera_Sensitivity
		MainWindow.camera.pitch += clamp(pitch, -89.0, 89.0)

		camera_update(&MainWindow.camera)
	} else {
		MainWindow.camera.mode = .Mode_Select
	}
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()

	if key == glfw.KEY_ESCAPE {
		fmt.print("Program exited from pressing Escape!\n")
		glfw.SetWindowShouldClose(window, true)
	}

	if key >= 32 && key <= 248 {
		is_key_pressed: bool = (action != glfw.RELEASE)
		if MainWindow.input_state.keyboard_current.keys[key] != is_key_pressed {
			MainWindow.input_state.keyboard_current.keys[key] = is_key_pressed
		}
	}
}

button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	if button >= 0 && button <= 3 {
		is_button_pressed: bool = (action != glfw.RELEASE)

		if is_button_pressed && button == i32(Mouse_Button.Button_RIGHT) {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		} else {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		}

		if MainWindow.input_state.mouse_current.buttons[button] != is_button_pressed {
			MainWindow.input_state.mouse_current.buttons[button] = is_button_pressed
		}
	}
}

cursor_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	MainWindow.input_state.mouse_current.coords.x = i32(xpos)
	MainWindow.input_state.mouse_current.coords.y = i32(ypos)
}

size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	context = runtime.default_context()
	gl.Viewport(0, 0, width, height)
	MainWindow.window_width  = width
	MainWindow.window_height = height
	renderer_on_resize(MainWindow.window_width, MainWindow.window_height)
}

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

set_proc_address :: proc (p: rawptr, name: cstring) { 
	(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name))
}