package odinner

import lm "core:math/linalg/glsl"

Mouse_Button :: enum {
  Mouse_Button_LEFT   = 0,
  Mouse_Button_RIGHT  = 1,
  Mouse_Button_MIDDLE = 2,

  Mouse_Button_COUNT
}

// NOTE(fz): These match GLFW. Needs to be re worked if we abstract this input system
Keyboard_Key :: enum {
  Keyboard_Key_SPACE         = 32,
  Keyboard_Key_APOSTROPHE    = 39, /* ' */
  Keyboard_Key_COMMA         = 44, /* , */
  Keyboard_Key_MINUS         = 45, /* - */
  Keyboard_Key_PERIOD        = 46, /* . */
  Keyboard_Key_SLASH         = 47, /* / */
  Keyboard_Key_SEMICOLON     = 59, /* ; */
  Keyboard_Key_EQUAL         = 61, /* = */
  Keyboard_Key_LEFT_BRACKET  = 91, /* [ */
  Keyboard_Key_BACKSLASH     = 92, /* \ */
  Keyboard_Key_RIGHT_BRACKET = 93, /* ] */
  Keyboard_Key_GRAVE_ACCENT  = 96, /* ` */
  Keyboard_Key_WORLD_1       = 161, /* non-US #1 */
  Keyboard_Key_WORLD_2       = 162, /* non-US #2 */

  /* Alphanumeric characters */
  Keyboard_Key_0 = 48,
  Keyboard_Key_1 = 49,
  Keyboard_Key_2 = 50,
  Keyboard_Key_3 = 51,
  Keyboard_Key_4 = 52,
  Keyboard_Key_5 = 53,
  Keyboard_Key_6 = 54,
  Keyboard_Key_7 = 55,
  Keyboard_Key_8 = 56,
  Keyboard_Key_9 = 57,

  Keyboard_Key_A = 65,
  Keyboard_Key_B = 66,
  Keyboard_Key_C = 67,
  Keyboard_Key_D = 68,
  Keyboard_Key_E = 69,
  Keyboard_Key_F = 70,
  Keyboard_Key_G = 71,
  Keyboard_Key_H = 72,
  Keyboard_Key_I = 73,
  Keyboard_Key_J = 74,
  Keyboard_Key_K = 75,
  Keyboard_Key_L = 76,
  Keyboard_Key_M = 77,
  Keyboard_Key_N = 78,
  Keyboard_Key_O = 79,
  Keyboard_Key_P = 80,
  Keyboard_Key_Q = 81,
  Keyboard_Key_R = 82,
  Keyboard_Key_S = 83,
  Keyboard_Key_T = 84,
  Keyboard_Key_U = 85,
  Keyboard_Key_V = 86,
  Keyboard_Key_W = 87,
  Keyboard_Key_X = 88,
  Keyboard_Key_Y = 89,
  Keyboard_Key_Z = 90,

  /** Function keys **/

  /* Named non-printable keys */
  Keyboard_Key_ESCAPE       = 256,
  Keyboard_Key_ENTER        = 257,
  Keyboard_Key_TAB          = 258,
  Keyboard_Key_BACKSPACE    = 259,
  Keyboard_Key_INSERT       = 260,
  Keyboard_Key_DELETE       = 261,
  Keyboard_Key_RIGHT        = 262,
  Keyboard_Key_LEFT         = 263,
  Keyboard_Key_DOWN         = 264,
  Keyboard_Key_UP           = 265,
  Keyboard_Key_PAGE_UP      = 266,
  Keyboard_Key_PAGE_DOWN    = 267,
  Keyboard_Key_HOME         = 268,
  Keyboard_Key_END          = 269,
  Keyboard_Key_CAPS_LOCK    = 280,
  Keyboard_Key_SCROLL_LOCK  = 281,
  Keyboard_Key_NUM_LOCK     = 282,
  Keyboard_Key_PRINT_SCREEN = 283,
  Keyboard_Key_PAUSE        = 284,

  /* Function keys */
  Keyboard_Key_F1  = 290,
  Keyboard_Key_F2  = 291,
  Keyboard_Key_F3  = 292,
  Keyboard_Key_F4  = 293,
  Keyboard_Key_F5  = 294,
  Keyboard_Key_F6  = 295,
  Keyboard_Key_F7  = 296,
  Keyboard_Key_F8  = 297,
  Keyboard_Key_F9  = 298,
  Keyboard_Key_F10 = 299,
  Keyboard_Key_F11 = 300,
  Keyboard_Key_F12 = 301,
  Keyboard_Key_F13 = 302,
  Keyboard_Key_F14 = 303,
  Keyboard_Key_F15 = 304,
  Keyboard_Key_F16 = 305,
  Keyboard_Key_F17 = 306,
  Keyboard_Key_F18 = 307,
  Keyboard_Key_F19 = 308,
  Keyboard_Key_F20 = 309,
  Keyboard_Key_F21 = 310,
  Keyboard_Key_F22 = 311,
  Keyboard_Key_F23 = 312,
  Keyboard_Key_F24 = 313,
  Keyboard_Key_F25 = 314,

  /* Keypad numbers */
  Keyboard_Key_KP_0 = 320,
  Keyboard_Key_KP_1 = 321,
  Keyboard_Key_KP_2 = 322,
  Keyboard_Key_KP_3 = 323,
  Keyboard_Key_KP_4 = 324,
  Keyboard_Key_KP_5 = 325,
  Keyboard_Key_KP_6 = 326,
  Keyboard_Key_KP_7 = 327,
  Keyboard_Key_KP_8 = 328,
  Keyboard_Key_KP_9 = 329,

  /* Keypad named function keys */
  Keyboard_Key_KP_DECIMAL  = 330,
  Keyboard_Key_KP_DIVIDE   = 331,
  Keyboard_Key_KP_MULTIPLY = 332,
  Keyboard_Key_KP_SUBTRACT = 333,
  Keyboard_Key_KP_ADD      = 334,
  Keyboard_Key_KP_ENTER    = 335,
  Keyboard_Key_KP_EQUAL    = 336,

  /* Modifier keys */
  Keyboard_Key_LEFT_SHIFT    = 340,
  Keyboard_Key_LEFT_CONTROL  = 341,
  Keyboard_Key_LEFT_ALT      = 342,
  Keyboard_Key_LEFT_SUPER    = 343,
  Keyboard_Key_RIGHT_SHIFT   = 344,
  Keyboard_Key_RIGHT_CONTROL = 345,
  Keyboard_Key_RIGHT_ALT     = 346,
  Keyboard_Key_RIGHT_SUPER   = 347,
  Keyboard_Key_MENU          = 348,
}

Keyboard_State :: struct {
  keys: [128]bool
}

Mouse_State :: struct {
  coords: lm.ivec2,
  buttons: [Mouse_Button.Mouse_Button_COUNT]bool
}

Input_State :: struct {
  keyboard_current:  Keyboard_State,
  keyboard_previous: Keyboard_State,

  mouse_current:  Mouse_State,
  mouse_previous: Mouse_State
}

is_key_pressed :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return is_key_down(input_state, key) && was_key_up(input_state, key)
}
is_key_released :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return is_key_up(input_state, key) && was_key_down(input_state, key)
}
is_key_up :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return input_state.keyboard_current.keys[key] == false
}
is_key_down :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return input_state.keyboard_current.keys[key] == true
}
was_key_up :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return input_state.keyboard_previous.keys[key] == false
}
was_key_down :: proc(input_state: Input_State, key: Keyboard_Key) -> bool {
  return input_state.keyboard_previous.keys[key] == true
}

is_button_pressed :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return is_button_down(input_state, button) && was_button_up(input_state, button)
}
is_button_released :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return is_button_up(input_state, button) && was_button_down(input_state, button)
}
is_button_up :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return input_state.mouse_current.buttons[button] == false
}
is_button_down :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return input_state.mouse_current.buttons[button] == true
}
was_button_up :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return input_state.mouse_previous.buttons[button] == false
}
was_button_down :: proc(input_state: Input_State, button: Mouse_Button) -> bool {
  return input_state.mouse_previous.buttons[button] == true
}