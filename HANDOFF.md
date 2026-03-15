# HANDOFF

## 这个项目是什么

基于 Godot 的 2D 轻量编辑器框架 — **Lite2D Studio**。

用户负责素材、地图、布局和视觉风格。AI 负责移动、碰撞、交互、事件、对话、切场景等逻辑。目标用户是有一点基础但不想学 Godot 的人。最终导出为独立桌面应用。

## 产品愿景

**用户 = 美术总监，AI = 程序员。**

目标体验流程：
1. 用户下载 Lite2D-Studio.exe（~50MB），双击打开
2. 从 itch.io / OpenGameArt 等社区下载素材包（角色、地块、道具 png）
3. 导入素材到编辑器
4. 拖拽摆放场景：角色放这里、树放那里、房子放那里、地图画好
5. 用自然语言告诉 AI 逻辑：
   - "这个NPC走到门口就停下，跟他说话给一个送信任务"
   - "这个怪物看到玩家就追，碰到就掉血"
   - "捡到钥匙才能开这扇门"
6. AI 自动配好：碰撞、事件、对话、任务、行为逻辑
7. 点"运行预览"试玩
8. 满意后点"发布游戏"→ 导出独立 .exe 分享

**用户完全不需要理解碰撞体、信号、状态机等编程概念。**

### 目前缺失（需要补的能力）
1. **图片素材导入** — 目前只有色块占位，需要加"选择 png 文件→作为精灵"
2. **AI 理解力升级** — 目前只能改单个对象属性，需要升级为理解整句自然语言生成完整玩法
3. **独立 App 导出** — 目前必须在 Godot 里运行，需要打包成独立 exe
4. **用户游戏导出** — 目前没有发布功能，需要内嵌 export template

## 设计原则

1. **保留能力，不保留复杂操作** — Godot 几百个属性压缩成 10-20 个"人话"选项
2. **先做逻辑闭环，再做界面美化**
3. **AI 兜底** — 用户说不清楚的需求交给 AI 处理
4. **三层处理策略** — 默认值自动化 / 简化成人话开关 / AI 兜底处理边缘情况
5. **保持跨平台**

## 当前完成状态：里程碑 1 ~ 里程碑 5

### 里程碑 1 已完成
- ✅ 编辑器主界面骨架（三栏布局）
- ✅ 资源导入
- ✅ 对象添加、删除、拖拽、属性编辑
- ✅ Undo/Redo（50级，Ctrl+Z/Y）
- ✅ 保存 Debounce（1.5秒）
- ✅ 多图层地图（ground/decoration/collision，6种地形）
- ✅ 运行预览闭环（编辑->保存->预览->返回）
- ✅ 玩家移动、相机跟随、NPC 对话、门切场景、宝箱奖励、区域触发
- ✅ AI 客户端（Ollama 本地 + OpenAI API，结构化输出，自动回退模板）
- ✅ CLI/API（10 个命令，JSON 输出）
- ✅ 导出预设（Windows + Web）

### 里程碑 2 已完成
- ✅ 条件-动作事件系统（10条件+16动作，GDevelop风格可视化编辑器，运行时执行）
- ✅ 行为系统（10种预设：俯视角/平台跳跃/巡逻/追逐/逃跑/悬浮/投射/跟随/游走）
- ✅ 对话系统（多节点对话树、选择支、旗标条件分支、底部对话框UI）

### 里程碑 3 已完成
- 背包/物品系统（8种内置物品、6种分类、堆叠、容量、运行时网格UI、Tab切换）
- 任务系统（5种状态、6种目标类型、前置条件、奖励、自动进度检测、Q键任务日志）
- 存档系统（10槽位、F5存档/F9读档、保存玩家位置+背包+任务+旗标+已消耗对象）
- 事件系统扩展（HAS_ITEM/QUEST_STATUS条件、REMOVE_ITEM/ACCEPT_QUEST/COMPLETE_QUEST动作）

### 里程碑 4 已完成
- 动画系统（8种预设、精灵表分割、编辑器面板管理、运行时自动切换行走/待机）
- 多场景管理（场景索引、独立数据文件、编辑器下拉切换、新增/删除场景）

### 里程碑 5 已完成
- TileMap 正式化（原生 TileMap 替代自定义绘制、物理图层自动配置、tile_cells 双向转换）
- 内置资源库（6种占位资源、3个项目模板、编辑器底部资源库 Tab）

### 关键文件
| 文件 | 作用 |
|------|------|
| `scripts/editor_main.gd` | 编辑器主逻辑（undo/redo、debounce、AI、多图层、事件、行为） |
| `scripts/scene_canvas.gd` | 画布交互 + 多图层渲染 + 性能优化 |
| `scripts/runtime_preview.gd` | 运行时预览（事件执行、行为驱动、对话UI） |
| `scripts/project_store.gd` | 项目数据序列化/反序列化（含事件、图层兼容） |
| `scripts/event_system.gd` | 条件-动作事件数据模型（10条件+16动作） |
| `scripts/event_runner.gd` | 运行时事件执行引擎（旗标、定时器、子事件） |
| `scripts/event_editor_panel.gd` | GDevelop 风格可视化事件编辑器 |
| `scripts/behavior_system.gd` | 行为预设目录（10种行为+默认参数+颜色标记） |
| `scripts/behavior_runner.gd` | 运行时行为执行器（状态机驱动） |
| `scripts/dialogue_system.gd` | 多轮分支对话数据模型 |
| `scripts/dialogue_ui.gd` | 运行时对话框 UI（选择支、旗标分支） |
| `scripts/ai_client.gd` | AI 客户端（Ollama + OpenAI） |
| `scripts/logic_templates.gd` | 内置关键词模板（AI不可用时回退） |
| `scripts/inventory_system.gd` | 背包/物品系统（物品定义表+增删查改+序列化） |
| `scripts/inventory_ui.gd` | 运行时背包 UI（网格+详情+使用） |
| `scripts/quest_system.gd` | 任务系统（定义+目标检测+奖励+序列化） |
| `scripts/save_system.gd` | 存档系统（10槽位+状态捕获恢复） |
| `scripts/animation_system.gd` | 动画数据模型（8种预设+精灵表分割） |
| `scripts/animation_runner.gd` | 运行时动画播放器（自动切换+AtlasTexture） |
| `scripts/scene_manager.gd` | 多场景管理（索引+独立数据文件） |
| `scripts/tilemap_builder.gd` | TileMap 构建器（TileSet+物理图层） |
| `scripts/resource_library.gd` | 内置资源库（占位资源+项目模板） |
| `scripts/undo_redo_manager.gd` | 撤销/重做管理器 |
| `tools/ai_cli_bridge.py` | CLI/API 桥接（10 个命令） |
| `export_presets.cfg` | 导出预设 |
| `research-report.md` | 竞品调研报告（5 款产品 + 导出流程 + Ollama API） |

## 架构

```
编辑器层 (editor_main.gd + scene_canvas.gd + event_editor_panel.gd)
    ↓ 数据（对象 + 事件 + 行为 + 对话）
数据层 (project_store.gd → user://editor_state.json)
    ↓ 读取
运行预览层 (runtime_preview.gd)
    ├── event_runner.gd     ← 条件-动作事件执行
    ├── behavior_runner.gd  ← 行为状态机驱动
    ├── dialogue_ui.gd     ← 对话框交互
    ├── inventory_ui.gd    ← 背包 UI（Tab 切换）
    ├── inventory_system.gd ← 物品增删查改
    ├── quest_system.gd    ← 任务进度检测
    ├── save_system.gd     ← 存档/读档
    ├── animation_runner.gd ← 精灵动画播放
    └── tilemap (native)   ← 原生 TileMap 地图渲染
    
AI 层 (ai_client.gd → Ollama/OpenAI)
    ↓ 回退
模板层 (logic_templates.gd)

CLI 层 (ai_cli_bridge.py → editor_state.json)
```

## 方向调整（里程碑 5 后）

> 功能够了，形态不对。不再继续堆功能模块，转向产品化。

### 第一优先级：独立 App 导出
- 用 Godot 导出功能把编辑器场景打包成 Windows/Mac 独立 .exe
- 用户双击打开就是 Lite2D Studio，不需要装 Godot
- export_presets.cfg 已有基础配置，需要测试 headless 导出流程
- 命令：`godot --headless --export-release "Windows Desktop" lite2d-studio.exe`

### 第二优先级：AI 工作流升级
- 现在 AI 只能"选一个对象→补属性"，太弱
- 目标：对话式生成整个玩法块
- 输入："做一个有围墙的村庄，一个NPC给玩家送信任务"
- 输出：自动生成场景对象 + 地图 + 事件 + 对话 + 任务
- 这是核心差异化，市面上没有同类产品做到这个

### 第三优先级：用户游戏导出
- 用户在编辑器里点"发布游戏"→ 生成独立 .exe
- 内嵌 Godot export template，自动打包用户项目
- 让用户做完的游戏可以分享给朋友玩

### 不再做（暂缓）
- 多工作区编辑器布局（Tab 式）— 形态转变后再考虑
- 插件商店 — 需要先有用户基础

## 调研报告摘要

`research-report.md` 包含：
- **RPG Maker MZ** — 表格驱动数据管理、自动图块、模式切换面板
- **GDevelop** — 条件-动作事件编辑器、行为系统、内置商店、AI 助手
- **Construct 3** — 事件表行业标杆、事件组折叠、Z Order 可视化
- **GameMaker** — DnD + GML 双模式、内置精灵编辑器
- **Scratch** — 颜色编码、形状防错、即时反馈
- **Godot 导出流程** — Export Template 机制、命令行导出、代码签名注意事项
- **Ollama API** — /api/chat、结构化输出、工具调用、GDScript 完整实现

## 验证命令

```bash
# Godot headless 验证
Godot --headless --path <仓库路径> --quit
Godot --headless --path <仓库路径> --scene res://scenes/runtime_preview.tscn --quit-after 1

# Python CLI 验证
python tools/ai_cli_bridge.py --help
python tools/ai_cli_bridge.py list-objects
python -m py_compile tools/ai_cli_bridge.py
```

## 下次新窗口怎么接上

给新窗口发仓库链接即可（STATUS.md 和 HANDOFF.md 已包含完整状态）：
```
继续做这个仓库：https://github.com/0xPanty/godot-2d-lite
先看 STATUS.md 和 HANDOFF.md，然后开始独立 App 导出
```
