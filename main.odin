package odinner

import "base:runtime"

import "core:fmt"
import lm "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

Window_Width  : i32 : 400
Window_Height : i32 : 400

Application_State :: struct {
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

Square :: struct {
	quad:    Quad,
	color:   lm.vec4,
	texture: u32
}

main :: proc () {
	glfw.SetErrorCallback(error_callback)

	if !glfw.Init() {
		fmt.eprintln("GLFW has failed to load.")
		return
	}
	defer glfw.Terminate()

	glfw.WindowHint(glfw.RESIZABLE, 1)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(Window_Width, Window_Height, "noname-odin", nil, nil)
	if window == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)
	glfw.SetKeyCallback(window, key_callback)
	glfw.SetFramebufferSizeCallback(window, size_callback)
	glfw.SetCursorPosCallback(window, cursor_callback)
	glfw.SetMouseButtonCallback(window, button_callback)
	gl.load_up_to(4, 6, set_proc_address) 

	AppState = application_init()

	renderer_init(AppState.window_width, AppState.window_height)
	kakashi_eye: u32 = renderer_texture_load("res/kakashi.png")
	
	for !glfw.WindowShouldClose(window) {
		application_tick()

		renderer_begin_frame()

		q0 := Quad{lm.vec3{-0.25, -0.25, 0.0}, 0.5, 0.5}
		renderer_push_quad(q0, lm.vec4{1.0, 1.0, 1.0, 1.0}, kakashi_eye)

		renderer_end_frame(AppState.view, AppState.projection, AppState.window_width, AppState.window_height)
		
		glfw.SwapBuffers(window)
	}
}

application_init :: proc() -> (app: Application_State) {
	app.camera     = camera_init()
	app.projection = lm.identity(lm.mat4)
	app.view       = lm.identity(lm.mat4)
	app.near_plane = 0.1
	app.far_plane  = 100.0
	app.window_width  = Window_Width
	app.window_height = Window_Height

	app.input_state.mouse_current.coords.x  = Window_Width /2
	app.input_state.mouse_current.coords.y  = Window_Height/2
	app.input_state.mouse_previous.coords.x = Window_Width /2
	app.input_state.mouse_previous.coords.y = Window_Height/2

	return app
}

application_tick :: proc() {
	AppState.input_state.keyboard_previous = AppState.input_state.keyboard_current;
	AppState.input_state.mouse_previous    = AppState.input_state.mouse_current;
	glfw.PollEvents()

	AppState.projection = lm.mat4Perspective(lm.radians(f32(45)), f32(AppState.window_width) / f32(AppState.window_height), AppState.near_plane, AppState.far_plane)
	AppState.view       = lm.mat4LookAt(AppState.camera.position, AppState.camera.position + AppState.camera.front, AppState.camera.up)

	camera_update(&AppState.camera, AppState.delta_time)

	AppState.time       = f32(glfw.GetTime())
  AppState.delta_time = AppState.time - AppState.last_time
  AppState.last_time  = AppState.time
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	}

	if key >= 32 && key <= 248 {
		is_key_pressed: bool = (action != glfw.RELEASE)
		if AppState.input_state.keyboard_current.keys[key] != is_key_pressed {
			AppState.input_state.keyboard_current.keys[key] = is_key_pressed

			context = runtime.default_context()
			fmt.printf("[Keyboard]\n%v is %v\n\n", key, is_key_pressed)
		}
	}
}

button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	if button >= 0 && button <= 3 {
		is_button_pressed: bool = (action != glfw.RELEASE)
		if AppState.input_state.mouse_current.buttons[button] != is_button_pressed {
			AppState.input_state.mouse_current.buttons[button] = is_button_pressed

			context = runtime.default_context()
			fmt.printf("[Button]\n%v is %v\n\n", button, is_button_pressed)
		}
	}
}

cursor_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	AppState.input_state.mouse_current.coords.x = i32(xpos)
	AppState.input_state.mouse_current.coords.y = i32(ypos)

	context = runtime.default_context()
	fmt.printf("[Cursor]\n%v, %v\n\n", i32(xpos), i32(ypos))
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