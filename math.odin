package odinner

// Vec3
V3 :: struct {
  x: f32,
  y: f32,
  z: f32
}

v3 :: proc(x: f32, y: f32, z: f32) -> V3 {
  result: V3 = { x, y, z }
  return result
}

// Vec4
V4 :: struct {
  x: f32,
  y: f32,
  z: f32,
  w: f32
}

v4 :: proc(x: f32, y: f32, z: f32, w: f32) -> V4 {
  result: V4 = { x, y, z, w }
  return result
}

// Color
Color :: struct {
  r: f32,
  g: f32,
  b: f32,
  a: f32
}

Color_White  :: Color{1.0, 1.0, 1.0, 1.0}
Color_Black  :: Color{0.0, 0.0, 0.0, 1.0}
Color_Red    :: Color{1.0, 0.0, 0.0, 1.0}
Color_Green  :: Color{0.0, 1.0, 0.0, 1.0}
Color_Blue   :: Color{0.0, 0.0, 1.0, 1.0}
Color_Yellow :: Color{1.0, 1.0, 0.0, 1.0}
Color_Orange :: Color{1.0, 0.5, 0.0, 1.0}
Color_Purple :: Color{0.5, 0.0, 0.5, 1.0}

color :: proc(r: f32, g: f32, b: f32, a: f32) -> Color {
  result: Color = { r, g, b, a }
  return result
}