package odinner

import "base:runtime"

import "core:fmt"
import lm "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

WindowWidth  : i32 : 400
WindowHeight : i32 : 400

Application_State :: struct {
	time:       f32,
	delta_time: f32,
	last_time:  f32,

	view:       lm.mat4,
	projection: lm.mat4,

	window_width:  i32,
	window_height: i32,
	window_dimensions_dirty_this_frame: bool
}

AppState: Application_State

main :: proc () {
	error_callback :: proc "c" (code: i32, desc: cstring) {
		context = runtime.default_context()
		fmt.println(desc, code)
	}  
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

	window := glfw.CreateWindow(WindowWidth, WindowHeight, "noname-odin", nil, nil)
	if window == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)

	key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
		if key == glfw.KEY_ESCAPE {
			glfw.SetWindowShouldClose(window, true)
		}
	}
	glfw.SetKeyCallback(window, key_callback)

	size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
		context = runtime.default_context()
		gl.Viewport(0, 0, width, height)
		AppState.window_width  = width
		AppState.window_height = height
		renderer_on_resize(width, height)
	}
	glfw.SetFramebufferSizeCallback(window, size_callback)

	set_proc_address :: proc (p: rawptr, name: cstring) { 
		(cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name))
	}
	gl.load_up_to(3, 3, set_proc_address) 

	AppState = {
		time       = 0,
		projection = lm.mat4Perspective(lm.radians(f32(45)), f32(WindowWidth / WindowHeight), 0.1, 100.0),
		view       = lm.mat4LookAt(lm.vec3{0.0, 0.0, 3.0}, lm.vec3{0.0, 0.0, 3.0} + lm.vec3{0.0, 0.0, -1.0}, lm.vec3{0.0, 1.0, 0.0}),
		window_width  = WindowWidth,
		window_height = WindowHeight
	}

	renderer_init(AppState.window_width, AppState.window_height)
	texture: u32 = renderer_texture_load("res/kakashi.png")
	q0 := Quad{lm.vec3{-0.25, -0.25, 0.0}, 0.5, 0.5}
	renderer_push_quad(q0, lm.vec4{1.0, 1.0, 1.0, 1.0}, texture)

	for !glfw.WindowShouldClose(window) {
		application_tick()

		renderer_begin_frame()

		renderer_end_frame(AppState.view, AppState.projection, AppState.window_width, AppState.window_height)
		
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

application_tick :: proc() {
	AppState.time       = f32(glfw.GetTime())
  AppState.delta_time = AppState.time - AppState.last_time
  AppState.last_time  = AppState.time

	AppState.projection = lm.mat4Perspective(lm.radians(f32(45)), f32(AppState.window_width / AppState.window_height), 0.1, 100.0)
	AppState.view       = lm.mat4LookAt(lm.vec3{0.0, 0.0, 3.0}, lm.vec3{0.0, 0.0, 3.0} + lm.vec3{0.0, 0.0, -1.0}, lm.vec3{0.0, 1.0, 0.0})
}