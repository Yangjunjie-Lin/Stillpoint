#!/usr/bin/env python3
"""Generate CombatLab scene and upgrade player_3d combat rig nodes."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

COMBAT_LAB = """[gd_scene load_steps=12 format=3 uid="uid://combatlab001"]

[ext_resource type="Script" path="res://scripts/combat/combat_lab_manager.gd" id="1"]
[ext_resource type="Script" path="res://scripts/world/camera_controller.gd" id="2"]
[ext_resource type="Script" path="res://scripts/combat/combat_feedback_controller.gd" id="3"]
[ext_resource type="Script" path="res://scripts/combat/combat_debug_overlay.gd" id="4"]
[ext_resource type="Script" path="res://scripts/characters/npc_controller.gd" id="5"]
[ext_resource type="Resource" path="res://resources/npcs/bandit.tres" id="6"]
[ext_resource type="Script" path="res://scripts/physics/pushable_crate_3d.gd" id="7"]
[ext_resource type="Script" path="res://scripts/physics/breakable_barrel_3d.gd" id="8"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="9"]
[ext_resource type="Script" path="res://scripts/components/energy_component.gd" id="10"]
[ext_resource type="Script" path="res://scripts/components/combat_component.gd" id="11"]
[ext_resource type="Resource" path="res://resources/attacks/basic_melee.tres" id="12"]

[sub_resource type="BoxMesh" id="BoxMesh_floor"]
size = Vector3(30, 0.2, 30)

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(30, 0.2, 30)

[sub_resource type="StandardMaterial3D" id="Mat_floor"]
albedo_color = Color(0.45, 0.45, 0.5, 1)

[sub_resource type="BoxMesh" id="BoxMesh_crate"]
size = Vector3(1, 1, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_crate"]
size = Vector3(1, 1, 1)

[sub_resource type="CylinderMesh" id="CylinderMesh_barrel"]
top_radius = 0.45
bottom_radius = 0.5
height = 1.1

[sub_resource type="CylinderShape3D" id="CylinderShape3D_barrel"]
height = 1.1
radius = 0.5

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_npc"]
radius = 0.4
height = 1.8

[node name="CombatLab" type="Node3D"]
script = ExtResource("1")

[node name="Floor" type="StaticBody3D" parent="."]
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Floor"]
mesh = SubResource("BoxMesh_floor")
surface_material_override/0 = SubResource("Mat_floor")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("BoxShape3D_floor")

[node name="SpawnPoints" type="Node3D" parent="."]

[node name="PlayerSpawn" type="Marker3D" parent="SpawnPoints"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 4)

[node name="CameraRig" type="Node3D" parent="."]
script = ExtResource("2")

[node name="Camera3D" type="Camera3D" parent="CameraRig"]
transform = Transform3D(1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 6, 8)

[node name="TrainingDummy" type="CharacterBody3D" parent="." groups=["combat_lab_target"]]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
script = ExtResource("5")

[node name="CollisionShape3D" type="CollisionShape3D" parent="TrainingDummy"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_npc")

[node name="HealthComponent" type="Node" parent="TrainingDummy"]
script = ExtResource("9")

[node name="EnergyComponent" type="Node" parent="TrainingDummy"]
script = ExtResource("10")

[node name="CombatComponent" type="Node" parent="TrainingDummy"]
script = ExtResource("11")

[node name="PushableCrate" type="RigidBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3, 0.6, 1)
script = ExtResource("7")

[node name="Mesh" type="MeshInstance3D" parent="PushableCrate"]
mesh = SubResource("BoxMesh_crate")

[node name="CollisionShape3D" type="CollisionShape3D" parent="PushableCrate"]
shape = SubResource("BoxShape3D_crate")

[node name="BreakableBarrel" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3, 0.55, 1)
script = ExtResource("8")

[node name="Mesh" type="MeshInstance3D" parent="BreakableBarrel"]
mesh = SubResource("CylinderMesh_barrel")

[node name="CollisionShape3D" type="CollisionShape3D" parent="BreakableBarrel"]
shape = SubResource("CylinderShape3D_barrel")

[node name="Bandit" type="CharacterBody3D" parent="." groups=["combat_lab_target"]]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -4)
script = ExtResource("5")
npc_definition = ExtResource("6")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Bandit"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_npc")

[node name="HealthComponent" type="Node" parent="Bandit"]
script = ExtResource("9")

[node name="EnergyComponent" type="Node" parent="Bandit"]
script = ExtResource("10")

[node name="CombatComponent" type="Node" parent="Bandit"]
script = ExtResource("11")
attack = ExtResource("12")

[node name="CombatFeedback" type="Node" parent="."]
script = ExtResource("3")

[node name="CombatDebugOverlay" type="CanvasLayer" parent="."]
script = ExtResource("4")
"""


def patch_player_scene() -> None:
    path = ROOT / "scenes/characters/player_3d.tscn"
    text = path.read_text(encoding="utf-8")
    if "CombatAnimationController" in text:
        print("player_3d already patched")
        return
    extra_scripts = '''
[ext_resource type="Script" path="res://scripts/components/combat_animation_controller.gd" id="15"]
[ext_resource type="Script" path="res://scripts/components/knockback_component.gd" id="16"]
[ext_resource type="Script" path="res://scripts/components/ragdoll_controller.gd" id="17"]
[ext_resource type="Script" path="res://scripts/combat/melee_sweep_3d.gd" id="18"]
[ext_resource type="Resource" path="res://resources/attacks/attack_light_1.tres" id="19"]
'''
    text = text.replace(
        '[ext_resource type="Resource" path="res://resources/attacks/basic_melee.tres" id="14"]\n',
        '[ext_resource type="Resource" path="res://resources/attacks/basic_melee.tres" id="14"]\n'
        + extra_scripts,
    )
    text = text.replace(
        '[node name="Visual" type="MeshInstance3D" parent="."]',
        '[node name="VisualRoot" type="Node3D" parent="."]\n\n'
        '[node name="CharacterModel" type="Node3D" parent="VisualRoot"]\n\n'
        '[node name="Visual" type="MeshInstance3D" parent="VisualRoot/CharacterModel"]',
    )
    insert = '''
[node name="CombatAnimationController" type="Node" parent="."]
script = ExtResource("15")

[node name="AnimationPlayer" type="AnimationPlayer" parent="CombatAnimationController"]

[node name="KnockbackComponent" type="Node" parent="."]
script = ExtResource("16")

[node name="RagdollController" type="Node" parent="."]
script = ExtResource("17")

[node name="CombatPivot" type="Node3D" parent="."]

[node name="WeaponSocket" type="Node3D" parent="CombatPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.1, -0.8)

[node name="VfxSocket" type="Node3D" parent="CombatPivot"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.0, -1.0)

[node name="AudioSocket" type="Node3D" parent="CombatPivot"]

[node name="MeleeSweepRoot" type="Node3D" parent="."]

[node name="MeleeSweep3D" type="Node3D" parent="MeleeSweepRoot"]
script = ExtResource("18")
_tip_path = NodePath("../../CombatPivot/WeaponSocket")

[node name="GroundCheck" type="RayCast3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 0)
target_position = Vector3(0, -0.5, 0)
'''
    text = text.replace('[node name="HitboxRoot" type="Node3D" parent="."]', insert + '\n[node name="HitboxRoot" type="Node3D" parent="CombatPivot"]')
    text = text.replace(
        'attack = ExtResource("14")',
        'attack = ExtResource("19")\nlight_attack_ids = Array[StringName]([&"attack_light_1", &"attack_light_2", &"attack_light_3"])',
    )
    text = text.replace("load_steps=16", "load_steps=20")
    path.write_text(text, encoding="utf-8")
    print("patched player_3d.tscn")


def write_combat_lab() -> None:
    out = ROOT / "scenes/combat/combat_lab.tscn"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(COMBAT_LAB.lstrip(), encoding="utf-8")
    print("wrote combat_lab.tscn")


def main() -> None:
    patch_player_scene()
    write_combat_lab()


if __name__ == "__main__":
    main()
