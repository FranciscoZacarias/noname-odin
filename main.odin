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

	window_width:  i32,
	window_height: i32,
}

AppState: Application_State

Square :: struct {
	quad:    Quad,
	color:   lm.vec4,
	texture: u32
}

Squares: [dynamic]Square;

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
	gl.load_up_to(4, 6, set_proc_address) 

	AppState = {
		camera     = camera_init(),
		projection = lm.identity(lm.mat4),
		view       = lm.identity(lm.mat4),
		near_plane = 0.1,
		far_plane  = 100.0,
		window_width  = Window_Width,
		window_height = Window_Height
	}

	renderer_init(AppState.window_width, AppState.window_height)
	kakashi_eye: u32 = renderer_texture_load("res/kakashi.png")
	
	for !glfw.WindowShouldClose(window) {
		application_tick()

		renderer_begin_frame()

		q0 := Quad{lm.vec3{-0.25, -0.25, 0.0}, 0.5, 0.5}
		renderer_push_quad(q0, lm.vec4{1.0, 1.0, 1.0, 1.0}, kakashi_eye)

		renderer_end_frame(AppState.view, AppState.projection, AppState.window_width, AppState.window_height)
		
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

application_tick :: proc() {
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