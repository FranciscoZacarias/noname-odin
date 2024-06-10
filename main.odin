package odinner

import "base:runtime"

import "core:fmt"
import "core:math"
import "core:c"

import "vendor:glfw"
import gl "vendor:OpenGL"


WindowWidth  : i32 : 800
WindowHeight : i32 : 600

Time: f32

main :: proc() {
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
  glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
  glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

  window := glfw.CreateWindow(WindowWidth, WindowHeight, "Odinner", nil, nil)
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
    gl.Viewport(0, 0, width, height)
  }
  glfw.SetFramebufferSizeCallback(window, size_callback)

  set_proc_address :: proc(p: rawptr, name: cstring) { 
    (cast(^rawptr)p)^ = rawptr(glfw.GetProcAddress(name))
  }
  gl.load_up_to(3, 3, set_proc_address) 

  renderer_init()

  q0 := quad(v3(-0.2, -0.2, 0.0), 0.3, 0.3)
  renderer_push_quad(q0, Color_Red)
  
  for !glfw.WindowShouldClose(window) {
    Time = f32(glfw.GetTime())
    
    renderer_begin_frame()
    
    renderer_end_frame()

    glfw.SwapBuffers(window)
    glfw.PollEvents()
  }
}