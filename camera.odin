package odinner

import lm "core:math/linalg/glsl"

World_Up :: lm.vec3{0.0, 1.0, 0.0}
Camera_Speed :: 16.0

Camera_Mode :: enum {
  Mode_Fly,
  Mode_Select
}

Camera :: struct {
  position: lm.vec3,
  front:    lm.vec3,
  right:    lm.vec3,
  up:       lm.vec3,
  yaw:      f32,
  pitch:    f32,
  mode:     Camera_Mode
}

camera_init :: proc() -> (camera: Camera) {
  camera.position = lm.vec3{0.0, 0.0,  3.0}
  camera.front    = lm.vec3{0.0, 0.0, -1.0}
  camera.up       = World_Up
  camera.right    = lm.vec3{1.0, 0.0,  0.0}
  camera.yaw      = -90.0
  camera.pitch    = 0.0
  camera.mode     = .Mode_Select
  camera_update(&camera)
  return camera
}

camera_update :: proc(camera: ^Camera) {
  front: lm.vec3 = {
    lm.cos(lm.radians(camera.yaw)) * lm.cos(lm.radians(camera.pitch)),
    lm.sin(lm.radians(camera.pitch)),
    lm.sin(lm.radians(camera.yaw)) * lm.cos(lm.radians(camera.pitch))
  }

  camera.front   = lm.normalize_vec3(front)
  right: lm.vec3 = lm.cross_vec3(camera.front, World_Up)
  camera.right   = lm.normalize_vec3(right)
  up: lm.vec3    = lm.cross_vec3(camera.right, camera.front)
  camera.up      = lm.normalize_vec3(up)
}