package odinner

import lm "core:math/linalg/glsl"

Game_State :: struct {
  entities: [dynamic]Entity
}

GameState: Game_State

Transform :: struct {
  position: lm.vec3,
  rotation: lm.quat,
  scale:    lm.vec3,
}

Entity :: struct {
	id:        u32,
	mesh:      Mesh,
	texture:   u32,
	transform: Transform,
}

game_state_init :: proc () {
  GameState.entities = make([dynamic]Entity, 0)
  reserve(&GameState.entities, 32)
}

game_state_push_entity :: proc (mesh: Mesh, texture: u32) -> (obj: Entity) {
  obj.id = u32(len(GameState.entities))
  obj.mesh = mesh
  obj.texture = texture
  obj.transform.scale = lm.vec3{1.0, 1.0, 1.0}
  obj.transform.rotation.w = 1
  append(&GameState.entities, obj)
  return obj
}

get_model_matrix_from_entity :: proc (entity: Entity) -> (model: lm.mat4) {
  translation := lm.mat4Translate(entity.transform.position)
  rotation    := lm.mat4FromQuat(entity.transform.rotation)
  scale       := lm.mat4Scale(entity.transform.scale)
  model = translation * rotation * scale
  return model
}