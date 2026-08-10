# Character Customization GitHub Research

Research date: 2026-08-10
Target runtime: Godot 4.7, GDScript, GL Compatibility renderer

This review checked repository-owned license files and project documentation before considering any import. No third-party code, model, texture, animation, or binary asset was copied into Stillpoint.

| Candidate | Verified license | Activity / engine | Modular and animation support | Decision and risk |
| --- | --- | --- | --- | --- |
| [Team-Figoose/Configura](https://github.com/Team-Figoose/Configura) | MIT for the plugin; demo art is not separately clear | Active July 2026; Godot 4, exact 4.7 support not demonstrated | Body parts, hair, clothing, accessories, mesh swaps, blend shapes, skeletal deformation, state save/load | Best architectural reference. Adopt data-driven slots and a canonical appearance state; do not copy demo art or the young, untested plugin wholesale. |
| [Flynsarmy/gd-synty-fantasy-heroes-import-scripts](https://github.com/Flynsarmy/gd-synty-fantasy-heroes-import-scripts) | CC0-1.0 for helper scripts only | Last activity October 2023; Godot 4.1 | Shared `Skeleton3D`, 27 stable mesh slots, editor import and runtime swaps | Adopt the shared-skeleton and stable-slot naming pattern. Synty models are a separate commercial product and are not included or licensed by this repository. |
| [KayKit Character Pack: Adventurers](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | CC0 | Last activity September 2023; README lists Godot | GLTF/FBX, four rigged characters, 75 animations, 25+ separate accessories | Safest future visual prototype source. It provides fixed heroes and accessories, not a full body/hair/garment creator, so nothing is imported in this change. |
| [michae107/humanizer](https://github.com/michae107/humanizer) | Unlicense for repository code; bundled third-party rights are not itemized | Last code activity November 2024; targets Godot 4.3 | Extensive morphs, garments, Mixamo-compatible rigs and runtime creation | Not suitable: roughly 527 MB, realistic art direction, uncertain per-binary provenance and unproven Godot 4.7 support. Reference only. |
| [anu-prakash-dev/Godot4CharacterCreator](https://github.com/anu-prakash-dev/Godot4CharacterCreator) | MIT code; CC0 MakeHuman base with some possible CC-BY additions | Last activity January 2024; Godot 4.2+ C#/.NET | Morphs, wardrobe, overlays, body hiding, automatic skinning and facial features | Not suitable now: about 405 MB, mixed asset attribution and a new C#/.NET export/CI surface. Reference wardrobe conflict handling only. |
| [V-Sekai/godot-vrm](https://github.com/V-Sekai/godot-vrm) | MIT code; example models have separate licenses | Active July 2026; Godot 4.0+ | VRM/glTF import, humanoid skeleton profile, expressions and spring bones; no modular garment assembly | Do not install now. Open Godot 4.7 parse/compile reports make it release-risky. Use `SkeletonProfileHumanoid` as a future rig target. |
| [makehumancommunity/mpfb2](https://github.com/makehumancommunity/mpfb2) | GPLv3 tool code; built-in assets CC0; generated output unclaimed | Active July 2026; Blender 4.2+ offline tool | Parametric bodies, clothes, rigs, poses and expressions | Viable only as an optional offline art tool. Community add-ons require individual license checks; GPL code will not be embedded in the game. |
| [gdquest-demos/godot-3d-mannequin](https://github.com/gdquest-demos/godot-3d-mannequin) | MIT code, CC-BY 4.0 art | Last activity August 2021; Godot 3.2+ | GLB rig and animations; only body/head separation | Animation reference only. Porting its old controller would duplicate current architecture and require attribution. |

## Stillpoint decision

Stillpoint keeps its small, asset-free procedural low-poly models and introduces a versioned appearance state rather than replacing the working player controller. The first supported runtime slots are:

```text
body_id
skin_id
hair_id
headwear_id
palette_id
accessory_id
```

They are independent of origin, faction and profession. Origin supplies the recognizable cultural-fantasy silhouette; the modular state changes body proportion, skin palette, hair/headwear treatment, garment palette and back accessory. The state is saved as plain IDs so procedural parts can later be replaced by licensed GLB meshes without changing saves.

Future imported humanoids should share a single `Skeleton3D`, use stable slot IDs, and target Godot's `SkeletonProfileHumanoid`. Every model, texture and animation still requires its own license/provenance check before import; a repository-level software license must not be assumed to cover third-party art.

## Balance boundary

Appearance and origin carry no power. A deterministic six-point random allocation redistributes a fixed budget, a faction contributes one two-point signature attribute, and a profession contributes one four-point signature attribute. Every combination therefore has the same twelve-point total. All professions receive the same complete starter inventory; the balance values are internal authoring checks, not prices and not an NPC economy.
