# godot-2d-lite 当前状态

最后同步阶段：`里程碑 5 完成 — 原生地图与资源库`

## 产品目标
- 做一个基于 Godot 的 2D 轻量编辑器框架。
- 用户只负责素材、地图、界面、布局和视觉风格。
- AI 负责移动、碰撞、交互、事件、对话、场景切换等底层逻辑。
- 目标不是复刻完整 Godot，而是做一个更简单、更适合有一点基础的人上手的 2D 搭建器。
- 目标产出水平：星露谷/宝可梦级完整 2D 游戏。
- 分发方式：桌面应用（Windows/Mac 安装包）。
- 商业模式：完全开源免费。
- 核心差异化：AI 驱动（Ollama 本地 + OpenAI API），自然语言生成游戏逻辑。

## 里程碑 1 已完成内容

### 基础修复
- Undo/Redo 系统（50级历史栈，Ctrl+Z / Ctrl+Y）
- 保存 Debounce（1.5秒定时器，不再每次操作都写磁盘）
- Canvas 性能优化（选中对象不再全量 rebuild Button 节点）
- 模板冲突修复（优先级系统解决 trigger_mode 互斥）
- 对象边界检查（拖拽不会超出画布）
- Runtime Preview 修复（背景/网格不再被 Camera2D 偏移）

### 多图层地图系统
- 3 个图层：ground（地面）、decoration（装饰）、collision（碰撞）
- 6 种地形：ground、wall、water、grass、sand、path
- 按图层独立编辑，非活动图层半透明显示
- 画布左下角显示当前图层名称
- 旧数据自动兼容（没有 layer 字段的 tile 默认为 ground）

### AI 客户端
- 支持 Ollama 本地模型（默认 qwen2.5:3b）
- 支持 OpenAI 兼容 API（GPT-4o-mini 等）
- 结构化 JSON Schema 输出，AI 直接返回可消费的对象属性更新
- 启动时自动检测 Ollama 可用性
- AI 不可用时自动回退到内置关键词模板
- AI 返回非法 JSON 时也回退到模板

### CLI/API 层
- 10 个命令：list-objects, add-object, set-property, set-behavior, paint-tile, erase-tile, list-tiles, apply-prompt, export-snapshot, import-snapshot
- 全 JSON 输出，Agent 可直接调用
- 自动定位 Godot 用户数据路径（Win/Mac/Linux）

### 导出配置
- Windows Desktop 导出预设（不嵌入 PCK，避免杀软误报）
- Web (HTML5) 导出预设

## 现在项目里有什么

### 脚本文件
- `scripts/editor_main.gd`: 编辑器主逻辑（undo/redo、debounce、AI、多图层、事件、行为）
- `scripts/scene_canvas.gd`: 画布交互 + 多图层地图绘制 + 性能优化
- `scripts/runtime_preview.gd`: 运行时预览（事件执行、行为驱动、对话UI）
- `scripts/project_store.gd`: 项目快照与数据存储（含事件、图层兼容）
- `scripts/logic_templates.gd`: 内置 AI 逻辑模板（含优先级系统）
- `scripts/undo_redo_manager.gd`: 撤销/重做管理器
- `scripts/ai_client.gd`: AI 客户端（Ollama + OpenAI 双 Provider）
- `scripts/event_system.gd`: 条件-动作事件数据模型（10条件+16动作）
- `scripts/event_runner.gd`: 运行时事件执行引擎
- `scripts/event_editor_panel.gd`: 可视化事件编辑器面板
- `scripts/behavior_system.gd`: 行为预设目录（10种行为）
- `scripts/behavior_runner.gd`: 运行时行为执行器
- `scripts/dialogue_system.gd`: 多轮分支对话数据模型
- `scripts/dialogue_ui.gd`: 运行时对话框 UI 控制器
- `scripts/inventory_system.gd`: 背包/物品系统（物品定义表+增删查改+序列化）
- `scripts/inventory_ui.gd`: 运行时背包UI（网格显示+物品使用）
- `scripts/quest_system.gd`: 任务系统（任务定义+目标检测+奖励发放）
- `scripts/save_system.gd`: 存档系统（10槽位存读档+状态捕获恢复）
- `scripts/animation_system.gd`: 动画数据模型（8种预设+精灵表分割+序列化）
- `scripts/animation_runner.gd`: 运行时动画播放器（自动切换+AtlasTexture）
- `scripts/scene_manager.gd`: 多场景管理（场景索引+独立数据文件+增删改查）
- `scripts/tilemap_builder.gd`: TileMap 构建器（TileSet 生成+物理图层+双向转换）
- `scripts/resource_library.gd`: 内置资源库（占位资源+项目模板+模板应用）
- `scripts/placeholder_target.gd`: 占位目标场景

### 场景文件
- `scenes/editor_main.tscn`: 主编辑器（含事件编辑器Tab、行为面板）
- `scenes/runtime_preview.tscn`: 运行预览
- `scenes/dialogue_ui.tscn`: 对话框 UI
- `scenes/event_editor_panel.tscn`: 事件编辑器面板
- `scenes/inventory_ui.tscn`: 背包 UI
- `scenes/placeholder_target.tscn`: 占位目标场景

### 工具
- `tools/ai_cli_bridge.py`: CLI/API 桥接（10 个命令）

### 配置
- `project.godot`: Godot 项目入口
- `export_presets.cfg`: 导出预设（Windows + Web）

### 参考资料
- `research-report.md`: 5 款竞品调研 + Godot 导出流程 + Ollama API 完整参考（未提交到 git）

## 里程碑 2 已完成内容

### 条件-动作事件系统
- 10 种条件类型（碰撞、距离、按键、属性比较、旗标检查、定时器等）
- 16 种动作类型（设置属性、显示对话、切换场景、生成对象、设置旗标、等待等）
- GDevelop 风格的可视化事件编辑器（左侧条件、右侧动作、颜色区分）
- 编辑器底部 Tab 切换（日志 / 事件编辑器）
- 运行时事件执行引擎，支持子事件嵌套、旗标系统、定时器管理
- 事件数据持久化到存档文件，支持 Undo/Redo

### 行为(Behaviors)系统
- 10 种行为预设：俯视角玩家、平台跳跃玩家、巡逻NPC、追逐NPC、逃跑NPC、静止障碍物、悬浮物体、投射物、跟随玩家、随机游走
- 每种行为带颜色标记、分类、默认参数
- 编辑器属性面板内行为管理（添加/移除/查看）
- 运行时行为执行器，每种行为有独立状态机

### 对话系统
- 多节点对话树模型（文本/选择支/设置旗标/条件分支/结束）
- 底部对话框 UI（说话人名字、富文本内容、选择按钮、继续提示）
- 旗标驱动的条件分支对话
- 构建辅助函数：build_linear() 线性对话、build_with_choice() 选择分支
- NPC 交互时自动弹出对话 UI（替代之前的简单消息显示）

## 里程碑 3 已完成内容

### 背包/物品系统
- 物品定义表（8种内置物品：消耗品、关键道具、装备、素材、任务物品、杂项）
- 6 种物品分类 + 颜色标记 + 效果系统
- 背包增删查改（堆叠、容量上限、溢出处理）
- 运行时背包 UI（Tab 键开关，5列网格，物品详情，使用按钮）
- 事件系统集成（ADD_ITEM / REMOVE_ITEM 动作，HAS_ITEM 条件）
- 宝箱奖励自动进入背包

### 任务系统
- 任务数据模型（5种状态：未解锁/可接取/进行中/已完成/已交付）
- 6 种目标类型（收集物品、对话、到达位置、设置旗标、击杀计数、自定义）
- 任务前置条件（前置任务 + 前置旗标）
- 奖励系统（物品奖励、旗标奖励）
- 运行时任务进度自动检测
- 事件系统集成（ACCEPT_QUEST / COMPLETE_QUEST 动作，QUEST_STATUS 条件）
- Q 键查看当前任务日志

### 存档系统
- 10 个存档槽位（user://saves/ 目录）
- 存档内容：玩家位置、背包、任务进度、旗标、已消耗对象
- F5 快速存档 / F9 快速读档
- JSON 格式，含存档时间戳和版本号
- 支持列出/删除存档

## 里程碑 4 已完成内容

### 动画系统
- 8 种预设动画（待机、四方向行走、攻击、受伤、死亡）
- 精灵帧动画数据模型（帧列表 + FPS + 循环标记）
- Spritesheet 分割支持（按行列切割精灵表为帧）
- 编辑器属性面板内动画管理（添加/移除动画预设）
- 运行时 AnimationRunner（AnimatedSprite2D 驱动，根据速度自动切换行走/待机方向动画）
- AtlasTexture 区域纹理支持

### 多场景管理
- 场景索引系统（user://scene_index.json）
- 每个场景独立数据文件（user://scenes/*.litescene）
- 编辑器左侧场景选择下拉 + 新增/删除场景按钮
- 场景切换时自动保存/加载
- 默认主场景不可删除
- 场景复制、重命名接口

### 注意
- TileMap 正式化（Godot 原生 TileMap 节点）推迟到里程碑 5，当前地图绘制系统可用

## 里程碑 5 已完成内容

### TileMap 正式化
- TileMapBuilder 工具类（程序化生成 TileSet + TileMap）
- 每种地形一个 TileSetAtlasSource（纯色纹理，32x32）
- 物理图层自动配置（wall/water 自动加碰撞多边形）
- 运行时用原生 TileMap 替代自定义 Node2D 绘制（删减 ~60 行旧代码）
- 双向转换：tile_cells ↔ TileMap

### 内置资源库
- 6 种内置占位资源（玩家/NPC/敌人角色、基础地块、对话框、粒子效果）
- 3 个项目模板（俯视角RPG、横版平台跳跃、空白项目）
- 模板自动生成对象 + 地图（围墙边框、平台地面）
- 编辑器底部资源库 Tab（资源网格 + 模板选择器 + 一键应用）

## 里程碑 6 方向（下一步）

### 第一优先级
1. 多工作区编辑器布局（Tab 式，参考 GDevelop）
2. 游戏导出（让用户做的游戏也能打包发布）

### 第二优先级
3. 插件商店（内置扩展下载机制）

## 调研报告中的关键设计建议

根据 research-report.md 中 5 款竞品（RPG Maker MZ、GDevelop、Construct 3、GameMaker、Scratch）的分析，最值得借鉴的设计：

1. **条件-动作事件表 + 颜色高亮**（Construct 3）— 不写代码也能表达复杂逻辑
2. **行为(Behaviors)一键添加物理**（Construct 3 / GDevelop）— 选一个行为=自动获得平台跳跃/寻路
3. **积木式颜色编码分类**（Scratch）— 按颜色找功能，降低记忆负担
4. **内嵌商店和学习资源**（GDevelop / Scratch）— 解决"没有素材"的障碍
5. **DnD + 代码双模式**（GameMaker）— 可视化入门，代码进阶

## 运行方式
- 用 Godot 4.3+ 打开仓库根目录。
- 主编辑器入口：`res://scenes/editor_main.tscn`
- 运行预览入口：`res://scenes/runtime_preview.tscn`
- CLI 工具：`python tools/ai_cli_bridge.py --help`
