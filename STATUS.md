# godot-2d-lite 当前状态

最后同步阶段：`里程碑 1 完成 — MVP 可用版`

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
- `scripts/editor_main.gd`: 编辑器主逻辑（含 undo/redo、debounce、AI 集成、多图层）
- `scripts/scene_canvas.gd`: 画布交互 + 多图层地图绘制 + 性能优化
- `scripts/runtime_preview.gd`: 运行时预览逻辑（Camera2D 修复版）
- `scripts/project_store.gd`: 项目快照与数据存储（含图层兼容）
- `scripts/logic_templates.gd`: 内置 AI 逻辑模板（含优先级系统）
- `scripts/undo_redo_manager.gd`: 撤销/重做管理器
- `scripts/ai_client.gd`: AI 客户端（Ollama + OpenAI 双 Provider）
- `scripts/placeholder_target.gd`: 占位目标场景

### 场景文件
- `scenes/editor_main.tscn`: 主编辑器（含装饰层按钮）
- `scenes/runtime_preview.tscn`: 运行预览
- `scenes/placeholder_target.tscn`: 占位目标场景

### 工具
- `tools/ai_cli_bridge.py`: CLI/API 桥接（10 个命令）

### 配置
- `project.godot`: Godot 项目入口
- `export_presets.cfg`: 导出预设（Windows + Web）

### 参考资料
- `research-report.md`: 5 款竞品调研 + Godot 导出流程 + Ollama API 完整参考（未提交到 git）

## 里程碑 2 方向（下一步）

### 第一优先级
1. 条件-动作事件编辑器（参考 GDevelop/Construct 3 的可视化事件表）
2. 行为(Behaviors)系统（选一个行为=自动获得物理/寻路/平台跳跃）
3. 对话系统增强（多轮对话、分支对话、NPC 头像）

### 第二优先级
4. 背包/物品系统（物品定义表 + 拾取/使用逻辑）
5. 任务系统原型（任务定义 + 条件触发 + 完成检测）
6. 存档系统（运行时游戏存档/读档）

### 第三优先级
7. 多工作区编辑器布局（Tab 式，参考 GDevelop）
8. 内置资源库/模板项目
9. 游戏导出（让用户做的游戏也能打包发布）

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
