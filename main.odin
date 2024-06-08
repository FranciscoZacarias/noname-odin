package odinner

import "base:runtime"

import "core:fmt"
import "core:math"
import "core:c"

import "vendor:glfw"
import gl "vendor:OpenGL"

Time: f32;

main :: proc() {
  glfw.SetErrorCallback(error_callback);

  if !glfw.Init() {
    fmt.eprintln("GLFW has failed to load.")
    return
  }
  defer glfw.Terminate()

  glfw.WindowHint(glfw.RESIZABLE, 1)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
  glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

  window := glfw.CreateWindow(1280, 720, "Cube", nil, nil)
  if window == nil {
    fmt.eprintln("GLFW has failed to load the window.")
    return
  }
  defer glfw.DestroyWindow(window)

  glfw.MakeContextCurrent(window)
  glfw.SwapInterval(1)
  glfw.SetKeyCallback(window, key_callback)
  glfw.SetFramebufferSizeCallback(window, size_callback)
  gl.load_up_to(3, 3, glfw.gl_set_proc_address) 

  renderer_init()

  renderer_push_triangle(v3f32(-0.5, -0.5, 0.0), Color_Red, v3f32(0.5, -0.5, 0.0), Color_Green, v3f32(0.0, 0.5, 0.0), Color_Blue)

  for !glfw.WindowShouldClose(window) {
    Time = f32(glfw.GetTime());

    renderer_begin_frame()

    renderer_end_frame()

    glfw.SwapBuffers(window)
    glfw.PollEvents()
  }
}

error_callback :: proc "c" (code: i32, desc: cstring) {
  context = runtime.default_context()
  fmt.println(desc, code)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
  if key == glfw.KEY_ESCAPE {
    glfw.SetWindowShouldClose(window, true)
  }
}

size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
  gl.Viewport(0, 0, width, height)
}
