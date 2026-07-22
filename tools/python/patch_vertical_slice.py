from pathlib import Path

path = Path("scenes/world/vertical_slice.tscn")
text = path.read_text(encoding="utf-8")

if "BoxShape3D_floor" not in text:
    insert = (
        '\n[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]\n'
        "size = Vector3(40, 0.2, 40)\n\n"
    )
    idx = text.find('[node name="VerticalSlice"')
    text = text[:idx] + insert + text[idx:]

for region in ["town", "wilderness", "dungeon"]:
    marker = f'[node name="spawn" type="Marker3D" parent="Regions/{region}"]'
    floor_body = (
        f'[node name="FloorBody" type="StaticBody3D" parent="Regions/{region}"]\n'
        "collision_layer = 1\n"
        "collision_mask = 0\n\n"
        f'[node name="CollisionShape3D" type="CollisionShape3D" '
        f'parent="Regions/{region}/FloorBody"]\n'
        'shape = SubResource("BoxShape3D_floor")\n\n'
    )
    needle = f'FloorBody" type="StaticBody3D" parent="Regions/{region}"'
    if needle not in text and marker in text:
        text = text.replace(marker, floor_body + marker, 1)

replacements = [
    (
        '[node name="spawn" type="Marker3D" parent="Regions/town"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)",
        '[node name="spawn" type="Marker3D" parent="Regions/town"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)",
    ),
    (
        '[node name="spawn" type="Marker3D" parent="Regions/wilderness"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)",
        '[node name="spawn" type="Marker3D" parent="Regions/wilderness"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)",
    ),
    (
        '[node name="spawn" type="Marker3D" parent="Regions/dungeon"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)",
        '[node name="spawn" type="Marker3D" parent="Regions/dungeon"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 0)",
    ),
]
for old, new in replacements:
    text = text.replace(old, new)

if 'name="plaza"' not in text:
    shop = (
        '[node name="shop" type="Marker3D" parent="Regions/town"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0.5, 3)"
    )
    plaza = (
        shop
        + "\n\n"
        + '[node name="plaza" type="Marker3D" parent="Regions/town"]\n'
        + "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4, 1.0, -3)"
    )
    text = text.replace(shop, plaza, 1)

for old, new in [
    ("4, 0, 2", "4, 1.0, 2"),
    ("-3, 0, 4", "-3, 1.0, 4"),
    ("3, 0, -5", "3, 1.0, -5"),
    ("-1, 0, -1", "-1, 1.0, -1"),
    ("6, 0, -2", "6, 1.0, -2"),
]:
    text = text.replace(old, new)

# Pet collision
if 'parent="Actors/Pet"]\n\n[node name="Visual"' in text or (
    '[node name="Pet"' in text and 'CollisionShape3D" type="CollisionShape3D" parent="Actors/Pet"' not in text
):
    pet_visual = '[node name="Visual" type="MeshInstance3D" parent="Actors/Pet"]'
    pet_col = (
        '[node name="CollisionShape3D" type="CollisionShape3D" parent="Actors/Pet"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)\n"
        'shape = SubResource("Capsule_npc")\n\n'
        + pet_visual
    )
    if pet_visual in text:
        text = text.replace(pet_visual, pet_col, 1)

# NPC hitboxes for Mira/Ren/Bandit
attack_ext = 'path="res://resources/attacks/basic_melee.tres"'
if attack_ext not in text:
    # bump load_steps roughly; Godot will fix on import
    text = text.replace(
        '[ext_resource type="Script" path="res://scripts/ui/rpg/hud_controller.gd" id="27"]',
        '[ext_resource type="Script" path="res://scripts/ui/rpg/hud_controller.gd" id="27"]\n'
        '[ext_resource type="Resource" path="res://resources/attacks/basic_melee.tres" id="28"]\n'
        '[ext_resource type="Script" path="res://scripts/combat/hitbox_3d.gd" id="29"]\n'
        '[ext_resource type="Script" path="res://scripts/ui/rpg/dialogue_ui.gd" id="30"]\n'
        '[ext_resource type="Script" path="res://scripts/components/energy_component.gd" id="31"]',
    )

for npc in ["Mira", "Ren", "Bandit"]:
    combat_node = f'[node name="CombatComponent" type="Node" parent="Actors/{npc}"]\nscript = ExtResource("13")'
    combat_with_attack = (
        f'[node name="CombatComponent" type="Node" parent="Actors/{npc}"]\n'
        'script = ExtResource("13")\n'
        'attack = ExtResource("28")'
    )
    if combat_node in text and f'parent="Actors/{npc}"]\nscript = ExtResource("13")\nattack' not in text:
        text = text.replace(combat_node, combat_with_attack, 1)
    hitbox_marker = f'[node name="Hurtbox3D" type="Area3D" parent="Actors/{npc}"]'
    hitbox_block = (
        f'[node name="HitboxRoot" type="Node3D" parent="Actors/{npc}"]\n\n'
        f'[node name="Hitbox3D" type="Area3D" parent="Actors/{npc}/HitboxRoot"]\n'
        "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, -1)\n"
        'script = ExtResource("29")\n'
        'team = &"npc"\n\n'
        f'[node name="CollisionShape3D" type="CollisionShape3D" parent="Actors/{npc}/HitboxRoot/Hitbox3D"]\n'
        'shape = SubResource("Capsule_npc")\n\n'
        + hitbox_marker
    )
    if f'HitboxRoot" type="Node3D" parent="Actors/{npc}"' not in text and hitbox_marker in text:
        text = text.replace(hitbox_marker, hitbox_block, 1)

# Mount energy
if 'EnergyComponent" type="Node" parent="Actors/Mount"' not in text:
    mount_col = '[node name="CollisionShape3D" type="CollisionShape3D" parent="Actors/Mount"]'
    mount_energy = (
        '[node name="EnergyComponent" type="Node" parent="Actors/Mount"]\n'
        'script = ExtResource("31")\n\n'
        + mount_col
    )
    if mount_col in text:
        text = text.replace(mount_col, mount_energy, 1)

# Dialogue panel under HUD
if 'name="DialoguePanel"' not in text:
    hud_end = '[node name="QuestLabel" type="Label" parent="HUD/VBox"]\ntext = "Quest: --"'
    dialogue = (
        hud_end
        + "\n\n"
        + '[node name="DialoguePanel" type="PanelContainer" parent="HUD"]\n'
        + "visible = false\n"
        + "anchors_preset = 7\n"
        + "anchor_left = 0.5\n"
        + "anchor_top = 1.0\n"
        + "anchor_right = 0.5\n"
        + "anchor_bottom = 1.0\n"
        + "offset_left = -280.0\n"
        + "offset_top = -260.0\n"
        + "offset_right = 280.0\n"
        + "offset_bottom = -20.0\n"
        + 'script = ExtResource("30")\n\n'
        + '[node name="Margin" type="MarginContainer" parent="HUD/DialoguePanel"]\n'
        + "theme_override_constants/margin_left = 12\n"
        + "theme_override_constants/margin_top = 12\n"
        + "theme_override_constants/margin_right = 12\n"
        + "theme_override_constants/margin_bottom = 12\n\n"
        + '[node name="VBox" type="VBoxContainer" parent="HUD/DialoguePanel/Margin"]\n\n'
        + '[node name="SpeakerLabel" type="Label" parent="HUD/DialoguePanel/Margin/VBox"]\n'
        + "unique_name_in_owner = true\n"
        + 'text = "Speaker"\n\n'
        + '[node name="BodyLabel" type="Label" parent="HUD/DialoguePanel/Margin/VBox"]\n'
        + "unique_name_in_owner = true\n"
        + "autowrap_mode = 3\n"
        + 'text = "..."\n\n'
        + '[node name="ChoicesContainer" type="VBoxContainer" parent="HUD/DialoguePanel/Margin/VBox"]\n'
        + "unique_name_in_owner = true\n\n"
        + '[node name="ContinueHint" type="Label" parent="HUD/DialoguePanel/Margin/VBox"]\n'
        + "unique_name_in_owner = true\n"
        + 'text = "..."\n'
    )
    text = text.replace(hud_end, dialogue, 1)

# Hotbar + target labels
if 'name="HotbarLabel"' not in text:
    text = text.replace(
        '[node name="QuestLabel" type="Label" parent="HUD/VBox"]\ntext = "Quest: --"',
        '[node name="HotbarLabel" type="Label" parent="HUD/VBox"]\n'
        'text = "Hotbar: 1"\n\n'
        '[node name="TargetLabel" type="Label" parent="HUD/VBox"]\n'
        'text = ""\n\n'
        '[node name="QuestLabel" type="Label" parent="HUD/VBox"]\n'
        'text = "Quest: --"',
        1,
    )

# Interactable region ids
for name, rid in [
    ("MiraTalk", "town"),
    ("RenTalk", "town"),
    ("ForestPortal", "town"),
    ("DungeonPortal", "town"),
    ("Chest", "town"),
    ("PetInteract", "town"),
    ("MountInteract", "town"),
    ("HerbPickup", "wilderness"),
]:
    node = f'[node name="{name}"'
    if node in text and f'{name}"' in text:
        # add region_id after script line if missing nearby
        pass

path.write_text(text, encoding="utf-8")
print("OK floors", text.count("FloorBody"))
print("plaza", 'name="plaza"' in text)
print("dialogue", 'DialoguePanel' in text)
print("hitbox", text.count("HitboxRoot"))
