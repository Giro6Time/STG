class_name CollisionLayers
extends RefCounted

const PLAYER := 1 << 0
const PLAYER_BULLET := 1 << 1
const ENEMY := 1 << 2
const ENEMY_BULLET := 1 << 3

const PLAYER_MASK := ENEMY | ENEMY_BULLET
const PLAYER_BULLET_MASK := ENEMY
const ENEMY_MASK := PLAYER | PLAYER_BULLET
const ENEMY_BULLET_MASK := PLAYER