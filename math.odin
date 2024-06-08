package odinner

Vec3f32 :: struct {
  x: f32,
  y: f32,
  z: f32
}

v3f32 :: proc(x: f32, y: f32, z: f32) -> Vec3f32 {
  result: Vec3f32 = { x, y, z }
  return result
}

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

Color_Red   :: Vec4f32{1.0, 0.0, 0.0, 1.0}
Color_Green :: Vec4f32{0.0, 1.0, 0.0, 1.0}
Color_Blue  :: Vec4f32{0.0, 0.0, 1.0, 1.0}