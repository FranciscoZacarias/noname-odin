package odinner

import "base:runtime"

import "core:time"
import "core:fmt"
import lm "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

Window_Width  : i32 : 1280
Window_Height : i32 : 720

Far_Plane  :: 1000.0
Near_Plane :: 0.1

Color_White : lm.vec4 : {1.0, 1.0, 1.0, 1.0}

Application_State :: struct {
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

AppState: Application_State

main :: proc () {
	glfw.SetErrorCallback(error_callback)

	if !glfw.Init() {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	AppState = application_init()

	glfw.MakeContextCurrent(AppState.window)
	glfw.SwapInterval(0)
	glfw.SetKeyCallback(AppState.window, key_callback)
	glfw.SetFramebufferSizeCallback(AppState.window, size_callback)
	glfw.SetCursorPosCallback(AppState.window, cursor_callback)
	glfw.SetMouseButtonCallback(AppState.window, button_callback)
	gl.load_up_to(4, 6, set_proc_address) 

	renderer_init(AppState.window_width, AppState.window_height)
	game_state_init()

	red   := renderer_load_color(1.0,   0,   0, 1.0)
	green := renderer_load_color(0,   1.0,   0, 1.0)
	blue  := renderer_load_color(0,     0, 1.0, 1.0)
	yell  := renderer_load_color(1.0, 1.0,   0, 0.7)
	kakashi_eye := renderer_load_texture("res/kakashi.png")

	suzanne_mesh := mesh_from_wavefront("res/suzanne.obj")
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

	for !glfw.WindowShouldClose(AppState.window) {
		application_tick()

		renderer_draw(AppState.view, AppState.projection, AppState.window_width, AppState.window_height)

		glfw.SwapBuffers(AppState.window)
	}
}

application_init :: proc () -> (app: Application_State) {
	app.window = glfw.CreateWindow(Window_Width, Window_Height, "noname-odin", nil, nil)
	if app.window == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		assert(false)
	}

	app.camera     = camera_init()
	app.projection = lm.identity(lm.mat4)
	app.view       = lm.identity(lm.mat4)
	app.far_plane  = Far_Plane
	app.near_plane = Near_Plane
	app.window_width  = Window_Width
	app.window_height = Window_Height

	app.input_state.mouse_current.coords.x  = Window_Width /2
	app.input_state.mouse_current.coords.y  = Window_Height/2
	app.input_state.mouse_previous.coords.x = Window_Width /2
	app.input_state.mouse_previous.coords.y = Window_Height/2

	return app
}

application_tick :: proc () {
	// Input and glfw events
	AppState.input_state.keyboard_previous = AppState.input_state.keyboard_current
	AppState.input_state.mouse_previous    = AppState.input_state.mouse_current
	glfw.PollEvents()

	// Perspective
	AppState.projection = lm.mat4Perspective(lm.radians(f32(45)), f32(AppState.window_width) / f32(AppState.window_height), AppState.near_plane, AppState.far_plane)
	AppState.view       = lm.mat4LookAt(AppState.camera.position, AppState.camera.position + AppState.camera.front, AppState.camera.up)

	// Time 
	AppState.time       = f32(glfw.GetTime())
  AppState.delta_time = AppState.time - AppState.last_time
  AppState.last_time  = AppState.time

	// Camera
	if is_button_down(AppState.input_state, .Button_RIGHT) {
		if is_button_released(AppState.input_state, .Button_RIGHT) {
			AppState.input_state.mouse_previous.coords = AppState.input_state.mouse_current.coords
		}

		AppState.camera.mode = .Mode_Fly
		camera_speed: f32 = Camera_Speed * AppState.delta_time
		if is_key_down(AppState.input_state, .Key_W) {
			delta: lm.vec3 = AppState.camera.front * camera_speed
			AppState.camera.position = AppState.camera.position + delta
		}
		if is_key_down(AppState.input_state, .Key_S) {
			delta: lm.vec3 = AppState.camera.front * camera_speed
			AppState.camera.position = AppState.camera.position - delta
		}
		if is_key_down(AppState.input_state, .Key_D) {
			cross: lm.vec3 = lm.cross_vec3(AppState.camera.front, AppState.camera.up)
			delta: lm.vec3 = cross * camera_speed
			AppState.camera.position = AppState.camera.position + delta
		}
		if is_key_down(AppState.input_state, .Key_A) {
			cross: lm.vec3 = lm.cross_vec3(AppState.camera.front, AppState.camera.up)
			delta: lm.vec3 = cross * camera_speed
			AppState.camera.position = AppState.camera.position - delta
		}
		if is_key_down(AppState.input_state, .Key_Q) {
			AppState.camera.position.y -= camera_speed
		}
		if is_key_down(AppState.input_state, .Key_E) {
			AppState.camera.position.y += camera_speed
		}

		x_offset := AppState.input_state.mouse_current.coords.x - AppState.input_state.mouse_previous.coords.x
		y_offset := AppState.input_state.mouse_previous.coords.y - AppState.input_state.mouse_current.coords.y

		AppState.camera.yaw   += f32(x_offset) * Camera_Sensitivity
		pitch := f32(y_offset) * Camera_Sensitivity
		AppState.camera.pitch += clamp(pitch, -89.0, 89.0)

		camera_update(&AppState.camera)
	} else {
		AppState.camera.mode = .Mode_Select
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
		if AppState.input_state.keyboard_current.keys[key] != is_key_pressed {
			AppState.input_state.keyboard_current.keys[key] = is_key_pressed
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

		if AppState.input_state.mouse_current.buttons[button] != is_button_pressed {
			AppState.input_state.mouse_current.buttons[button] = is_button_pressed
		}
	}
}

cursor_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	AppState.input_state.mouse_current.coords.x = i32(xpos)
	AppState.input_state.mouse_current.coords.y = i32(ypos)
}

size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	context = runtime.default_context()
	gl.Viewport(0, 0, width, height)
	AppState.window_width  = width
	AppState.window_height = height
	renderer_on_resize(AppState.window_width, AppState.window_height)
}

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()
	fmt.println(desc, code)
}

set_proc_address :: proc (p: rawptr, name: cstring) { 
	(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name))
}