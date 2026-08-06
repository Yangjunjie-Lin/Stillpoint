#!/usr/bin/env python3
"""Generate region scenes and world_session from vertical_slice structure."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TOWN_REGION = r'''[gd_scene load_steps=18 format=3]

[ext_resource type="Script" path="res://scripts/characters/npc_controller.gd" id="1"]
[ext_resource type="Resource" path="res://resources/npcs/mira.tres" id="2"]
[ext_resource type="Resource" path="res://resources/npcs/ren.tres" id="3"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="4"]
[ext_resource type="Script" path="res://scripts/components/energy_component.gd" id="5"]
[ext_resource type="Script" path="res://scripts/components/faction_component.gd" id="6"]
[ext_resource type="Script" path="res://scripts/components/relationship_component.gd" id="7"]
[ext_resource type="Script" path="res://scripts/components/interaction_component.gd" id="8"]
[ext_resource type="Script" path="res://scripts/components/combat_component.gd" id="9"]
[ext_resource type="Script" path="res://scripts/components/skill_component.gd" id="10"]
[ext_resource type="Script" path="res://scripts/components/status_effect_component.gd" id="11"]
[ext_resource type="Script" path="res://scripts/components/schedule_component.gd" id="12"]
[ext_resource type="Resource" path="res://resources/schedules/mira_schedule.tres" id="13"]
[ext_resource type="Script" path="res://scripts/combat/hurtbox_3d.gd" id="14"]
[ext_resource type="Script" path="res://scripts/combat/hitbox_3d.gd" id="15"]
[ext_resource type="Resource" path="res://resources/attacks/basic_melee.tres" id="16"]
[ext_resource type="Script" path="res://scripts/world/entities/world_entity_identity.gd" id="17"]
[ext_resource type="Script" path="res://scripts/interaction/npc_interactable.gd" id="18"]
[ext_resource type="Script" path="res://scripts/world/transition_portal.gd" id="19"]
[ext_resource type="Script" path="res://scripts/interaction/chest_interactable_3d.gd" id="20"]
[ext_resource type="Script" path="res://scripts/interaction/pet_interactable.gd" id="21"]
[ext_resource type="Script" path="res://scripts/interaction/mount_interactable.gd" id="22"]

[sub_resource type="BoxMesh" id="BoxMesh_floor"]
size = Vector3(40, 0.2, 40)

[sub_resource type="StandardMaterial3D" id="Mat_town"]
albedo_color = Color(0.55, 0.7, 0.45, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(40, 0.2, 40)

[sub_resource type="CapsuleShape3D" id="Capsule_npc"]
radius = 0.4
height = 1.6

[sub_resource type="BoxMesh" id="BoxMesh_npc"]
size = Vector3(0.7, 1.5, 0.7)

[sub_resource type="StandardMaterial3D" id="Mat_mira"]
albedo_color = Color(0.9, 0.5, 0.7, 1)

[sub_resource type="StandardMaterial3D" id="Mat_ren"]
albedo_color = Color(0.5, 0.6, 0.9, 1)

[node name="RegionRoot" type="Node3D"]

[node name="Environment" type="Node3D" parent="."]

[node name="Floor" type="MeshInstance3D" parent="Environment"]
mesh = SubResource("BoxMesh_floor")
surface_material_override/0 = SubResource("Mat_town")

[node name="StaticPhysics" type="Node3D" parent="."]

[node name="FloorBody" type="StaticBody3D" parent="StaticPhysics"]
collision_layer = 1
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticPhysics/FloorBody"]
shape = SubResource("BoxShape3D_floor")

[node name="Navigation" type="Node3D" parent="."]

[node name="SpawnPoints" type="Node3D" parent="."]

[node name="spawn" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)

[node name="shop" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0.5, 3)

[node name="plaza" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4, 1.0, -3)

[node name="EntitySpawns" type="Node3D" parent="."]

[node name="StaticEntities" type="Node3D" parent="."]

[node name="Mira" type="CharacterBody3D" parent="StaticEntities"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 1.0, 2)
script = ExtResource("1")
npc_definition = ExtResource("2")

[node name="WorldEntityIdentity" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("17")
persistent_id = &"base:town/npc/mira"
definition_id = &"mira"
region_id = &"base:town"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Mira"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
shape = SubResource("Capsule_npc")

[node name="Visual" type="MeshInstance3D" parent="StaticEntities/Mira"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.75, 0)
mesh = SubResource("BoxMesh_npc")
surface_material_override/0 = SubResource("Mat_mira")

[node name="HealthComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("4")

[node name="EnergyComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("5")

[node name="FactionComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("6")

[node name="RelationshipComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("7")

[node name="InteractionComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("8")

[node name="CombatComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("9")
attack = ExtResource("16")

[node name="SkillComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("10")

[node name="StatusEffectComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("11")

[node name="ScheduleComponent" type="Node" parent="StaticEntities/Mira"]
script = ExtResource("12")
schedule = ExtResource("13")

[node name="HitboxRoot" type="Node3D" parent="StaticEntities/Mira"]

[node name="Hitbox3D" type="Area3D" parent="StaticEntities/Mira/HitboxRoot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -1)
script = ExtResource("15")
team = &"npc"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Mira/HitboxRoot/Hitbox3D"]
shape = SubResource("Capsule_npc")

[node name="Hurtbox3D" type="Area3D" parent="StaticEntities/Mira"]
script = ExtResource("14")
team = &"npc"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Mira/Hurtbox3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
shape = SubResource("Capsule_npc")

[node name="Ren" type="CharacterBody3D" parent="StaticEntities"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3, 1.0, 4)
script = ExtResource("1")
npc_definition = ExtResource("3")

[node name="WorldEntityIdentity" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("17")
persistent_id = &"base:town/npc/ren"
definition_id = &"ren"
region_id = &"base:town"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Ren"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
shape = SubResource("Capsule_npc")

[node name="Visual" type="MeshInstance3D" parent="StaticEntities/Ren"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.75, 0)
mesh = SubResource("BoxMesh_npc")
surface_material_override/0 = SubResource("Mat_ren")

[node name="HealthComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("4")

[node name="EnergyComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("5")

[node name="FactionComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("6")

[node name="RelationshipComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("7")

[node name="InteractionComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("8")

[node name="CombatComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("9")
attack = ExtResource("16")

[node name="SkillComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("10")

[node name="StatusEffectComponent" type="Node" parent="StaticEntities/Ren"]
script = ExtResource("11")

[node name="HitboxRoot" type="Node3D" parent="StaticEntities/Ren"]

[node name="Hitbox3D" type="Area3D" parent="StaticEntities/Ren/HitboxRoot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -1)
script = ExtResource("15")
team = &"npc"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Ren/HitboxRoot/Hitbox3D"]
shape = SubResource("Capsule_npc")

[node name="Hurtbox3D" type="Area3D" parent="StaticEntities/Ren"]
script = ExtResource("14")
team = &"npc"

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticEntities/Ren/Hurtbox3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
shape = SubResource("Capsule_npc")

[node name="Interactables" type="Node3D" parent="."]

[node name="MiraTalk" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 1.0, 2)
script = ExtResource("18")
region_id = &"base:town"
npc_path = NodePath("../../StaticEntities/Mira")

[node name="RenTalk" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3, 1.0, 4)
script = ExtResource("18")
region_id = &"base:town"
npc_path = NodePath("../../StaticEntities/Ren")

[node name="WildernessPortal" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 8, 0, 0)
script = ExtResource("19")
region_id = &"base:town"
target_region_id = &"base:wilderness"
prompt_text = "Enter Forest"

[node name="DungeonPortal" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -8, 0, 0)
script = ExtResource("19")
region_id = &"base:town"
target_region_id = &"base:dungeon"
prompt_text = "Enter Mine"

[node name="Chest" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -3)
script = ExtResource("20")
region_id = &"base:town"

[node name="PetInteract" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1, 1.0, -1)
script = ExtResource("21")
region_id = &"base:town"

[node name="MountInteract" type="Node3D" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6, 1.0, -2)
script = ExtResource("22")
region_id = &"base:town"

[node name="LocalEffects" type="Node3D" parent="."]

[node name="RegionServices" type="Node3D" parent="."]
'''


def write(rel: str, content: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.lstrip("\n"), encoding="utf-8")
    print(f"wrote {rel}")


def main() -> None:
    write("scenes/regions/town/town_region.tscn", TOWN_REGION)
    print("done")


if __name__ == "__main__":
    main()
