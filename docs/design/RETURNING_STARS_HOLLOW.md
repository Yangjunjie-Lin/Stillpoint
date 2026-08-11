# 归星幽渊（Hollow of Returning Stars）

## 公开参考与取舍

本功能参考了公开机制资料与开源项目的结构性思路，不复制代码、地图、角色模型或影视资产：

- [Stardew Valley Wiki — The Mines](https://stardewvalleywiki.com/The_Mines)：120 层、分段主题、固定间隔电梯、敌人击败后出现下层路径，以及危险模式改变敌人与资源。Stillpoint 采用“分层主题 + 守卫检查 + 深度出生点 + 资源/敌人随深度提升”，但保留连续世界而不是菜单副本。
- [RuneScape Wiki — Instance](https://runescape.wiki/w/Instance)：说明了“按队伍生成区域副本”和 Boss 区域入口钥匙的边界。Stillpoint 不创建不可见的副本；Boss 状态属于世界存档，按实体 ID 和复活日持久化。
- [CodyI20/ProceduralDungeonGodot](https://github.com/CodyI20/ProceduralDungeonGodot) 与 [mrchameleon/procedural_dungeon_godot4](https://github.com/mrchameleon/procedural_dungeon_godot4)：检索到的 Godot 地牢生成参考。仓库没有被直接拷贝；当前实现继续使用 Stillpoint 自己的区域场景、实体快照和本体目录。
- [DanMachi（Wikipedia）](https://en.wikipedia.org/wiki/Is_It_Wrong_to_Try_to_Pick_Up_Girls_in_a_Dungeon%3F)：提供“城市—冒险者—地下城”叙事框架的灵感，入口守卫与冒险者报告因此被建模为世界关系。
- [Made in Abyss（Wikipedia）](https://en.wikipedia.org/wiki/Made_in_Abyss)：提供深度递进、每层生态和信息不对称的叙事启发；Stillpoint 的 NPC 不会因为世界目录存在就自动知道未见过的楼层。

## 世界命名与结构

| 本体 ID | 玩家可见名称 | 关系 |
| --- | --- | --- |
| `base:wilderness` | Greywake Wilds（灰醒荒野） | 地表区域 |
| `returning_stars_hollow` | Hollow of Returning Stars（归星幽渊） | 位于灰醒荒野下方的地下城板块 |
| `location:wardens_threshold` | Warden's Threshold（守渊关） | 地表入口，关联守卫 Aster |
| `location:returning_stars_hollow:depth_1` | Echo Gallery（回声廊） | 等级 1 |
| `location:returning_stars_hollow:depth_2` | Lantern Web（灯网层） | 等级 3 |
| `location:returning_stars_hollow:depth_3` | Fallen Star Vault（陨星库） | 等级 5 |

Boss：

| Boss | 深度 | 最低等级 | 复活周期 | 主题 |
| --- | ---: | ---: | ---: | --- |
| Mossjaw, the Buried Fang | 1 | 1 | 3 天 | 根甲、近战冲撞 |
| Veyra, the Lantern Widow | 2 | 3 | 5 天 | 发光蛛网、区域控制 |
| Orryx, Fallen-Star Warden | 3 | 5 | 7 天 | 星铸构装体、封锁审判 |

## 玩法闭环

1. 玩家从灰醒荒野的守渊关与 Aster 对话；等级不足的深度不会出现在可用选择中。
2. 守卫选择会调用 `DungeonProgressionService.travel_to_depth()`，进入同一个 `base:dungeon` 区域的深度出生点；地表道路仍保持连通，不把地下城做成脱离世界的传送菜单。
3. 普通敌人与 Boss 使用现有 `ActorFactory`、`WorldEntityRepository`、经验组件和掉落槽。Boss 的 `dungeon_boss_id`、深度和周期属于 NPC 本体定义。
4. Boss 被玩家击败后，实体快照记录死亡，区域 `custom_state.dungeon_progression` 记录 `last_defeated_day`、`next_respawn_day` 和累计击败次数。跨区域、重启和 Continue 都保留该状态。
5. 世界日历到达 `next_respawn_day` 后，服务清除死亡快照，从 authored spawn marker 重建 Boss，并重置对应掉落槽；同一个周期不会重复发放 XP/掉落。

## NPC 局部视角与知识升级

NPC 看到的是受限的根节点集合：自身实例、当前区域、玩家当前可见对象、自己 authored `knowledge_seeds`。后端图遍历最多两层；未进入视角的楼层和 Boss 不会因为它们存在于世界目录就自动注入。

玩家明确教给 NPC 的地下城信息会形成两部分：

- 一条 `semantic` / `told` 记忆，保留玩家原话并使用真实向量检索；
- 一条从 `npc_instance:<id>` 到公开本体节点的 `KNOWS_ABOUT` 边，边置信度按重复、带证据的报告提升：`rumor → aware → familiar → well_understood`。

这些边只能由 NPC 自己拥有，且必须引用本次记忆作为证据；LLM 不能写入 `HAS_BOSS`、`CONNECTED_TO`、`GUARDED_BY`、`REQUIRES_LEVEL` 等 canonical 世界事实。这样 Mira 可以逐步知道玩家告诉她的 Boss 情报，但不会获得 Bandit 的私有记忆，也不会拥有上帝视角。

## 自动化覆盖

- Godot：`test_dungeon_boss_cycle_and_guard.gd` 覆盖守卫出生、深度等级门槛、Boss 击败、3 天复活、掉落槽重置前提和保存。
- Backend：`test_dungeon_knowledge_progression.py` 覆盖地下城本体边、局部图检索、玩家报告形成 `told` 知识边及了解程度升级。
- NPC catalog：新增 4 个认知档案（守卫 + 3 个 Boss），导出目录包含入口、楼层、守卫、Boss、等级要求与复活周期关系。
