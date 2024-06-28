package odinner

import lm "core:math/linalg/glsl"

Game_State :: struct {
  entities: [dynamic]Entity
}

GameState: Game_State

Transform :: struct {
  position: lm.vec3,
  rotation: quaternion64,
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

push_entity :: proc (mesh: Mesh, texture: u32) -> (obj: Entity) {
  obj.id = u32(len(GameState.entities))
  obj.mesh = mesh
  obj.texture = texture
  obj.transform.rotation.w = 1
  append(&GameState.entities, obj)
  return obj
}

