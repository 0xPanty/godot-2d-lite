# HANDOFF

## 这个项目是什么

这是一个 **基于 Godot 的 2D 轻量编辑器框架**。

核心方向已经明确：

- 不复刻完整 Godot
- 只保留 2D 相关核心能力
- 用户只负责素材、地图、布局、界面和视觉风格
- AI 负责移动、碰撞、交互、事件、对话、切场景等逻辑
- 目标用户是不会 Godot、不会写代码的小白

## 设计原则

1. **保留能力，不保留复杂操作**
2. **先做逻辑闭环，再做界面美化**
3. **所有功能尽量以可配置 + AI 生成逻辑的方式扩展**
4. **保持跨平台**，避免写死 macOS 路径和系统特性

## 目前做到哪里

### 已完成
- 编辑器主界面骨架
- 资源导入入口
- 对象添加、删除、拖拽、属性编辑
- 地图绘制（ground / wall / water / erase）
- 项目快照保存与读取
- 运行预览闭环
- 玩家移动与相机跟随
- NPC 对话
- 门切换场景
- 宝箱奖励
- 触发区事件
- 占位目标场景
- AI 模板逻辑与 CLI bridge 示例

### 当前关键文件
- `scripts/editor_main.gd`
- `scripts/scene_canvas.gd`
- `scripts/runtime_preview.gd`
- `scripts/project_store.gd`
- `scripts/logic_templates.gd`

## 现阶段架构

### 1. 编辑器层
- `editor_main.tscn`
- 左侧：资源与对象列表
- 中间：画布 + 工具栏
- 右侧：属性 + AI 面板

### 2. 数据层
- `project_store.gd`
- 保存：资源、对象、地图块、对象 ID
- 统一快照路径：`user://editor_state.json`

### 3. 逻辑层
- `logic_templates.gd`
- 通过关键词把自然语言转换成对象行为配置

### 4. 运行预览层
- `runtime_preview.tscn`
- 读取快照并实例化运行时对象

## 当前最重要的限制

1. 还不是正式 TileMap 编辑器，只是轻量网格地图绘制
2. 缺少多图层地图系统
3. 缺少更完整 UI 工作区
4. 缺少背包 / 菜单 / 任务 / 存档系统
5. AI 逻辑还是模板级，未接真实模型工作流
6. 外部素材导入仍需进一步规范化

## 续开发时推荐的优先顺序

### 第一优先级
1. 多图层地图编辑
2. 对象属性扩展
3. 事件旗标与条件系统

### 第二优先级
1. UI 编辑器
2. 对话系统增强
3. 菜单 / 背包 / 任务原型

### 第三优先级
1. 多工作区编辑器布局
2. 更完整的 AI CLI 接入
3. 更像宝可梦 / 星露谷类项目的通用模板化能力

## 验证命令

如果修改了项目结构或脚本，至少跑这些：

```bash
Godot --headless --path <repo> --quit
Godot --headless --path <repo> --scene res://scenes/runtime_preview.tscn --quit-after 1
python3 -m py_compile tools/ai_cli_bridge.py
```

## 下次新窗口怎么接上

新窗口里直接说：

```text
继续做这个仓库：
https://github.com/0xPanty/godot-2d-lite
先看 README.md、STATUS.md、HANDOFF.md，再继续开发
```

## 当前阶段判断

这个仓库已经不是空壳了。

现在它的状态是：

**一个能跑通编辑 -> 保存 -> 预览 -> 返回编辑 的 2D 游戏编辑器框架骨架。**

接下来的重点不该是大改方向，而是持续把地图、对象、事件、UI 和 AI 层补完整。
