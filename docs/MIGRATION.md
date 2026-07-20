# Feature mapping: Python prototype → Godot

| Python | Godot |
| --- | --- |
| `engine.GameState` | `GameplayController` + actor components |
| `engine.calculate_damage` / combat helpers | `CombatMath` |
| `PlayerCombat` | `HealthComponent` + `ExperienceComponent` + `StatusEffectComponent` |
| `Obstacle` + behaviours | `EnemyController` + `EnemyDefinition` |
| `Bullet` + pierce IDs | `Bullet` + `_hit_ids` |
| `render.GameRenderer` | scenes + `GameplayHUD` + `Camera2D` |
| `game.GameWindow` | `GameplayController` + InputMap |
| `menu.MainMenu` | `scenes/ui/main_menu.tscn` |
| `storage.GameStorage` | `SaveService` (`user://`) |
| `config.GameConfig` / archetypes | `.tres` resources |
| Canvas tiled/cover background | `PrototypeLevel/Background` Sprite2D |
| Tk `after` loop | Godot `_physics_process` / `_process` |

## Migrated in Godot (v0.4)

- Main menu → prototype level loop
- WASD + mouse shoot
- Camera2D follow + world bounds
- Three enemy behaviours (chase / avoid / circle)
- Player HP, enemy HP + world-space bars
- Session XP / level-up
- Pickups (shield/speed/score/weapon mods)
- Score, survival time, dynamic difficulty scaling at spawn
- Pause, game over, leaderboard, run autosave
- Fullscreen toggle via InputMap

## Deferred (interfaces only)

- Full narrative / chapters / quests
- Skill tree, equipment inventory, shop
- Multiplayer
- TileMap-based large worlds (Background + NavigationRegion reserved)
