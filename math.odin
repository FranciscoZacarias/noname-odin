package odinner

// Vec3
Vec3f32 :: struct {
  x: f32,
  y: f32,
  z: f32
}

v3f32 :: proc(x: f32, y: f32, z: f32) -> Vec3f32 {
  result: Vec3f32 = { x, y, z }
  return result
}

// Vec4
Vec4f32 :: struct {
  x: f32,
  y: f32,
  z: f32,
  w: f32
}

v4f32 :: proc(x: f32, y: f32, z: f32, w: f32) -> Vec4f32 {
  result: Vec4f32 = { x, y, z, w }
  return result
}

// Color
Color :: struct {
  r: f32,
  g: f32,
  b: f32,
  a: f32
}

color :: proc(r: f32, g: f32, b: f32, a: f32) -> Color {
  result: Color = { r, g, b, a }
  return result
}

Color_White  :: Color{1.0, 1.0, 1.0, 1.0}
Color_Black  :: Color{0.0, 0.0, 0.0, 1.0}
Color_Red    :: Color{1.0, 0.0, 0.0, 1.0}
Color_Green  :: Color{0.0, 1.0, 0.0, 1.0}
Color_Blue   :: Color{0.0, 0.0, 1.0, 1.0}
Color_Yellow :: Color{1.0, 1.0, 0.0, 1.0}
Color_Orange :: Color{1.0, 0.5, 0.0, 1.0}
Color_Purple :: Color{0.5, 0.0, 0.5, 1.0}