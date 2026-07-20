#!/usr/bin/env python3
"""Generate Stillpoint .tscn / .tres assets for Godot 4.7."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def w(rel: str, text: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.lstrip("\n"), encoding="utf-8")
    print(rel)


def main() -> None:
    w(
        "scenes/bootstrap/main.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/core/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")

[node name="CurrentScene" type="Node" parent="."]
''',
    )

    w(
        "scenes/ui/main_menu.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="ColorRect" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.02, 0.027, 0.043, 1)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Center/VBox"]
layout_mode = 2
theme_override_font_sizes/font_size = 48
text = "Stillpoint"
horizontal_alignment = 1

[node name="Subtitle" type="Label" parent="Center/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(0.5, 0.57, 0.68, 1)
text = "Hold the center. Break the swarm."
horizontal_alignment = 1

[node name="NameEdit" type="LineEdit" parent="Center/VBox"]
unique_name_in_owner = true
custom_minimum_size = Vector2(280, 0)
layout_mode = 2
placeholder_text = "Player name"
alignment = 1

[node name="StartButton" type="Button" parent="Center/VBox"]
custom_minimum_size = Vector2(220, 44)
layout_mode = 2
text = "Start Game"

[node name="QuitButton" type="Button" parent="Center/VBox"]
custom_minimum_size = Vector2(220, 44)
layout_mode = 2
text = "Quit"

[node name="LeaderboardList" type="ItemList" parent="Center/VBox"]
unique_name_in_owner = true
custom_minimum_size = Vector2(320, 160)
layout_mode = 2

[connection signal="pressed" from="Center/VBox/StartButton" to="." method="_on_start_pressed"]
[connection signal="pressed" from="Center/VBox/QuitButton" to="." method="_on_quit_pressed"]
''',
    )

    w(
        "scenes/combat/bullet.tscn",
        r'''
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/combat/bullet.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 5.0

[node name="Bullet" type="Area2D"]
collision_layer = 8
collision_mask = 4
script = ExtResource("1")

[node name="Sprite2D" type="Polygon2D" parent="."]
color = Color(1, 0.9, 0.43, 1)
polygon = PackedVector2Array(-4, -4, 4, -4, 4, 4, -4, 4)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
''',
    )

    w(
        "scenes/combat/floating_text.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/floating_text.gd" id="1"]

[node name="FloatingText" type="Node2D"]
script = ExtResource("1")
label = NodePath("Label")

[node name="Label" type="Label" parent="."]
offset_left = -40.0
offset_top = -12.0
offset_right = 40.0
offset_bottom = 12.0
theme_override_font_sizes/font_size = 14
text = "-10"
horizontal_alignment = 1
''',
    )

    w(
        "scenes/actors/player/player.tscn",
        r'''
[gd_scene load_steps=12 format=3]

[ext_resource type="Script" path="res://scripts/actors/player_controller.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/experience_component.gd" id="3"]
[ext_resource type="Script" path="res://scripts/components/weapon_component.gd" id="4"]
[ext_resource type="Script" path="res://scripts/components/movement_component.gd" id="5"]
[ext_resource type="Script" path="res://scripts/components/status_effect_component.gd" id="6"]
[ext_resource type="Script" path="res://scripts/combat/hurtbox.gd" id="7"]
[ext_resource type="Texture2D" path="res://assets/characters/player_up.png" id="8"]
[ext_resource type="Resource" path="res://resources/weapons/basic_blaster.tres" id="9"]
[ext_resource type="Resource" path="res://resources/progression/default_experience_curve.tres" id="10"]

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 18.0

[sub_resource type="CircleShape2D" id="CircleShape2D_hurt"]
radius = 20.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1")
sprite = NodePath("Sprite2D")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("8")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 32
collision_mask = 64
script = ExtResource("7")
team = &"player"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("CircleShape2D_hurt")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_health = 100.0
invulnerability_duration = 0.75

[node name="ExperienceComponent" type="Node" parent="."]
script = ExtResource("3")
curve = ExtResource("10")

[node name="WeaponComponent" type="Node" parent="."]
script = ExtResource("4")
weapon = ExtResource("9")

[node name="MovementComponent" type="Node" parent="."]
script = ExtResource("5")
speed = 420.0

[node name="StatusEffectComponent" type="Node" parent="."]
script = ExtResource("6")
''',
    )

    w(
        "scenes/actors/enemies/enemy_base.tscn",
        r'''
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/actors/enemy_controller.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/combat/hitbox.gd" id="3"]
[ext_resource type="Script" path="res://scripts/combat/hurtbox.gd" id="4"]
[ext_resource type="Script" path="res://scripts/ui/enemy_health_bar.gd" id="5"]
[ext_resource type="Texture2D" path="res://assets/enemies/chase.png" id="6"]

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 18.0

[sub_resource type="CircleShape2D" id="CircleShape2D_box"]
radius = 20.0

[node name="EnemyBase" type="CharacterBody2D"]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
health_bar = NodePath("HealthBar")
sprite = NodePath("Sprite2D")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("6")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_health = 30.0
invulnerability_duration = 0.0

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = 64
collision_mask = 32
script = ExtResource("3")
team = &"enemy"
use_game_clock = true

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]
shape = SubResource("CircleShape2D_box")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 32
collision_mask = 8
script = ExtResource("4")
team = &"enemy"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("CircleShape2D_box")

[node name="HealthBar" type="Control" parent="."]
anchors_preset = 0
offset_left = -20.0
offset_top = -30.0
offset_right = 20.0
offset_bottom = -24.0
script = ExtResource("5")

[node name="Background" type="ColorRect" parent="HealthBar"]
layout_mode = 0
offset_right = 40.0
offset_bottom = 6.0
color = Color(0.1, 0.12, 0.17, 1)

[node name="Fill" type="ColorRect" parent="HealthBar"]
layout_mode = 0
offset_right = 40.0
offset_bottom = 6.0
pivot_offset = Vector2(0, 0)
color = Color(0.25, 0.91, 0.42, 1)
''',
    )

    # Specialized enemies inherit by duplicating base with different default textures via resources.
    for name, tex in (
        ("chaser_enemy", "chase.png"),
        ("runner_enemy", "avoid.png"),
        ("orbit_enemy", "circle.png"),
    ):
        w(
            f"scenes/actors/enemies/{name}.tscn",
            f'''
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/actors/enemies/enemy_base.tscn" id="1"]
[ext_resource type="Texture2D" path="res://assets/enemies/{tex}" id="2"]

[node name="{name}" instance=ExtResource("1")]

[node name="Sprite2D" parent="." index="0"]
texture = ExtResource("2")
''',
        )

    w(
        "scenes/levels/prototype_level.tscn",
        r'''
[gd_scene load_steps=3 format=3]

[ext_resource type="Texture2D" path="res://assets/environments/background.png" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_bound"]
size = Vector2(40, 2400)

[node name="PrototypeLevel" type="Node2D"]

[node name="Background" type="Sprite2D" parent="."]
z_index = -10
position = Vector2(1920, 1200)
scale = Vector2(3.0, 2.4)
texture = ExtResource("1")

[node name="Boundaries" type="StaticBody2D" parent="."]
collision_layer = 1

[node name="Left" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(-20, 1200)
shape = SubResource("RectangleShape2D_bound")

[node name="Right" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(3860, 1200)
shape = SubResource("RectangleShape2D_bound")

[node name="SpawnPoints" type="Node2D" parent="."]

[node name="PlayerSpawn" type="Marker2D" parent="SpawnPoints"]
position = Vector2(1920, 1200)

[node name="TriggerAreas" type="Node2D" parent="."]

[node name="EnemySpawnZones" type="Node2D" parent="."]

[node name="BossZones" type="Node2D" parent="."]

[node name="Props" type="Node2D" parent="."]

[node name="NavigationRegion2D" type="NavigationRegion2D" parent="."]
''',
    )

    w(
        "scenes/ui/gameplay_hud.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/gameplay_hud.gd" id="1"]

[node name="GameplayHUD" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 20
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 20
theme_override_constants/margin_bottom = 16

[node name="VBox" type="VBoxContainer" parent="Margin"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="ScoreLabel" type="Label" parent="Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "Score  0"

[node name="HPLabel" type="Label" parent="Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
text = "HP 100 / 100"

[node name="HPBar" type="Control" parent="Margin/VBox"]
custom_minimum_size = Vector2(220, 14)
layout_mode = 2

[node name="HPBg" type="ColorRect" parent="Margin/VBox/HPBar"]
layout_mode = 0
offset_right = 220.0
offset_bottom = 14.0
color = Color(0.07, 0.09, 0.15, 1)

[node name="HPFill" type="ColorRect" parent="Margin/VBox/HPBar"]
unique_name_in_owner = true
layout_mode = 0
offset_right = 220.0
offset_bottom = 14.0
color = Color(0.25, 0.91, 0.42, 1)

[node name="EXPLabel" type="Label" parent="Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
text = "LV. 1   EXP 0 / 100"

[node name="EXPBar" type="Control" parent="Margin/VBox"]
custom_minimum_size = Vector2(220, 10)
layout_mode = 2

[node name="EXPBg" type="ColorRect" parent="Margin/VBox/EXPBar"]
layout_mode = 0
offset_right = 220.0
offset_bottom = 10.0
color = Color(0.07, 0.09, 0.15, 1)

[node name="EXPFill" type="ColorRect" parent="Margin/VBox/EXPBar"]
unique_name_in_owner = true
layout_mode = 0
offset_right = 220.0
offset_bottom = 10.0
color = Color(0.49, 0.61, 1, 1)

[node name="EffectsLabel" type="Label" parent="Margin/VBox"]
unique_name_in_owner = true
layout_mode = 2
text = ""

[node name="NoticeLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 48.0
offset_right = 200.0
offset_bottom = 80.0
grow_horizontal = 2
theme_override_colors/font_color = Color(1, 0.9, 0.43, 1)
theme_override_font_sizes/font_size = 22
text = ""
horizontal_alignment = 1
''',
    )

    w(
        "scenes/ui/pause_menu.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pause_menu.gd" id="1"]

[node name="PauseMenu" type="Control"]
process_mode = 2
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Dim" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.55)

[node name="Panel" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -120.0
offset_top = -100.0
offset_right = 120.0
offset_bottom = 100.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 12

[node name="Title" type="Label" parent="Panel"]
layout_mode = 2
theme_override_font_sizes/font_size = 28
text = "PAUSED"
horizontal_alignment = 1

[node name="Continue" type="Button" parent="Panel"]
layout_mode = 2
text = "Continue"

[node name="Restart" type="Button" parent="Panel"]
layout_mode = 2
text = "Restart"

[node name="Menu" type="Button" parent="Panel"]
layout_mode = 2
text = "Exit to menu"

[connection signal="pressed" from="Panel/Continue" to="." method="_on_continue_pressed"]
[connection signal="pressed" from="Panel/Restart" to="." method="_on_restart_pressed"]
[connection signal="pressed" from="Panel/Menu" to="." method="_on_menu_pressed"]
''',
    )

    w(
        "scenes/ui/game_over_screen.tscn",
        r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_over_screen.gd" id="1"]

[node name="GameOverScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Dim" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.65)

[node name="Panel" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -220.0
offset_top = -140.0
offset_right = 220.0
offset_bottom = 140.0
theme_override_constants/separation = 14

[node name="Title" type="Label" parent="Panel"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.3, 0.35, 1)
theme_override_font_sizes/font_size = 36
text = "GAME OVER"
horizontal_alignment = 1

[node name="StatsLabel" type="Label" parent="Panel"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 18
text = "Final Score"
horizontal_alignment = 1

[node name="Menu" type="Button" parent="Panel"]
layout_mode = 2
text = "Return to menu"

[connection signal="pressed" from="Panel/Menu" to="." method="_on_menu_pressed"]
''',
    )

    w(
        "scenes/combat/pickup_item.tscn",
        r'''
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/actors/pickup_item.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 12.0

[node name="PickupItem" type="Area2D"]
collision_layer = 16
collision_mask = 2
script = ExtResource("1")

[node name="Visual" type="Polygon2D" parent="."]
color = Color(0.25, 0.91, 0.42, 1)
polygon = PackedVector2Array(-10, -10, 10, -10, 10, 10, -10, 10)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
''',
    )

    w(
        "scenes/gameplay/gameplay.tscn",
        r'''
[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://scripts/levels/gameplay_controller.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/actors/player/player.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/actors/enemies/enemy_base.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/combat/floating_text.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/combat/pickup_item.tscn" id="5"]
[ext_resource type="Resource" path="res://resources/levels/prototype_level.tres" id="6"]
[ext_resource type="PackedScene" path="res://scenes/ui/gameplay_hud.tscn" id="7"]
[ext_resource type="PackedScene" path="res://scenes/ui/pause_menu.tscn" id="8"]
[ext_resource type="PackedScene" path="res://scenes/ui/game_over_screen.tscn" id="9"]

[node name="Gameplay" type="Node2D" groups=["gameplay"]]
script = ExtResource("1")
level_def = ExtResource("6")
player_scene = ExtResource("2")
enemy_scene = ExtResource("3")
floating_text_scene = ExtResource("4")
item_scene = ExtResource("5")

[node name="LevelSlot" type="Node2D" parent="."]

[node name="Actors" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="Enemies" type="Node2D" parent="Actors"]
unique_name_in_owner = true

[node name="Projectiles" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="Pickups" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="Effects" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="Camera2D" type="Camera2D" parent="."]
unique_name_in_owner = true
position_smoothing_enabled = true

[node name="HUDLayer" type="CanvasLayer" parent="."]
unique_name_in_owner = true

[node name="GameplayHUD" parent="HUDLayer" instance=ExtResource("7")]

[node name="PauseMenu" parent="HUDLayer" instance=ExtResource("8")]
unique_name_in_owner = true
visible = false

[node name="GameOverScreen" parent="HUDLayer" instance=ExtResource("9")]
unique_name_in_owner = true
visible = false
''',
    )

    # Resources
    w(
        "resources/progression/default_experience_curve.tres",
        r'''
[gd_resource type="Resource" script_class="ExperienceCurve" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/experience_curve.gd" id="1"]

[resource]
script = ExtResource("1")
base = 100.0
exponent = 1.35
health_gain_per_level = 10.0
health_restore_on_level_up = 20.0
damage_gain_per_level = 1.0
''',
    )

    w(
        "resources/weapons/basic_blaster.tres",
        r'''
[gd_resource type="Resource" script_class="WeaponDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/weapon_definition.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/combat/bullet.tscn" id="2"]

[resource]
script = ExtResource("1")
id = &"basic"
display_name = "Basic Blaster"
damage = 12.0
cooldown = 0.5
projectile_speed = 900.0
projectile_lifetime = 2.0
bullet_scene = ExtResource("2")
''',
    )

    for enemy_id, display, hp, dmg, speed, xp, score, behavior, tex, scene in (
        ("chase", "Chaser", 30, 10, 140, 12, 20, "chase", "chase.png", "chaser_enemy.tscn"),
        ("avoid", "Runner", 20, 6, 160, 8, 15, "avoid", "avoid.png", "runner_enemy.tscn"),
        ("circle", "Orbiter", 45, 15, 120, 18, 30, "circle", "circle.png", "orbit_enemy.tscn"),
    ):
        w(
            f"resources/enemies/{enemy_id}.tres",
            f'''
[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/resources/enemy_definition.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/enemies/{tex}" id="2"]
[ext_resource type="PackedScene" path="res://scenes/actors/enemies/{scene}" id="3"]

[resource]
script = ExtResource("1")
id = &"{enemy_id}"
display_name = "{display}"
max_health = {hp}.0
attack_damage = {dmg}.0
movement_speed = {speed}.0
experience_reward = {xp}
score_reward = {score}
behavior = &"{behavior}"
scene = ExtResource("3")
texture = ExtResource("2")
''',
        )

    w(
        "resources/levels/prototype_level.tres",
        r'''
[gd_resource type="Resource" script_class="LevelDefinition" load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/resources/level_definition.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/levels/prototype_level.tscn" id="2"]
[ext_resource type="Texture2D" path="res://assets/environments/background.png" id="3"]
[ext_resource type="Resource" path="res://resources/enemies/chase.tres" id="4"]
[ext_resource type="Resource" path="res://resources/enemies/avoid.tres" id="5"]
[ext_resource type="Resource" path="res://resources/enemies/circle.tres" id="6"]

[resource]
script = ExtResource("1")
id = &"prototype"
display_name = "Prototype Level"
scene = ExtResource("2")
world_size = Vector2(3840, 2400)
base_enemy_count = 10
max_enemy_count = 60
score_threshold = 200
enemy_pool = Array[ExtResource("1")]([ExtResource("4"), ExtResource("5"), ExtResource("6")])
background = ExtResource("3")
''',
    )

    # Fix enemy_pool type - Array[EnemyDefinition] in tres uses the script path differently.
    # Godot 4 often wants: enemy_pool = [ExtResource("4"), ExtResource("5"), ExtResource("6")]
    w(
        "resources/levels/prototype_level.tres",
        r'''
[gd_resource type="Resource" script_class="LevelDefinition" load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/resources/level_definition.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/levels/prototype_level.tscn" id="2"]
[ext_resource type="Texture2D" path="res://assets/environments/background.png" id="3"]
[ext_resource type="Resource" path="res://resources/enemies/chase.tres" id="4"]
[ext_resource type="Resource" path="res://resources/enemies/avoid.tres" id="5"]
[ext_resource type="Resource" path="res://resources/enemies/circle.tres" id="6"]

[resource]
script = ExtResource("1")
id = &"prototype"
display_name = "Prototype Level"
scene = ExtResource("2")
world_size = Vector2(3840, 2400)
base_enemy_count = 10
max_enemy_count = 60
score_threshold = 200
enemy_pool = [ExtResource("4"), ExtResource("5"), ExtResource("6")]
background = ExtResource("3")
''',
    )

    print("scenes+resources done")


if __name__ == "__main__":
    main()
