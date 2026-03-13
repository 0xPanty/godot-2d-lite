# godot-2d-lite

一个基于 Godot 的 2D 轻量编辑器框架。

目标不是复刻完整 Godot，而是把常用 2D 能力重新组织成更简单的工作流：

- 用户负责素材、地图、界面、布局和视觉风格
- AI 负责移动、碰撞、交互、事件、对话、场景切换等逻辑
- 最终做成适合小白上手的 2D 游戏搭建器

## 当前状态

当前仓库是 **MVP 骨架**，重点已经从静态原型进入到“逻辑闭环可运行”的阶段。

目前已经具备：

- 编辑器主界面
- 资源导入入口
- 对象摆放与拖拽
- 基础地图绘制（地面 / 墙体 / 水域 / 擦除）
- 属性面板
- AI 指令面板
- 运行预览场景
- 基础运行逻辑（移动 / 相机 / 对话 / 奖励 / 切场景 / 触发区）

## 当前工作流

1. 在编辑器中导入素材
2. 绘制基础地图
3. 摆放主角、NPC、门、宝箱、触发区
4. 用自然语言给对象补逻辑
5. 点击“运行预览”验证玩法闭环
6. 返回编辑器继续修改

## 已实现功能

### 编辑器层
- 主画布
- 对象列表
- 属性面板
- AI 指令输入
- 地图画笔工具
- 删除对象

### 地图层
- 32x32 网格
- 地面绘制
- 墙体绘制
- 水域绘制
- 擦除地图块
- 地图数据持久化

### 对象层
- 主角
- NPC
- 门
- 宝箱
- 触发区
- 基础位置 / 类型 / 交互属性编辑

### 运行预览层
- 玩家移动
- 相机跟随
- NPC 对话
- 门切换场景
- 宝箱奖励
- 区域触发事件
- Esc 返回编辑器

### AI 桥接层
- 内置关键词模板：移动 / 镜头 / 对话 / 传送 / 宝箱 / 触发事件
- 预留 Python CLI 桥接：`tools/ai_cli_bridge.py`

## 目录结构

```text
assets/                 图标等基础资源
scenes/                 Godot 场景
  editor_main.tscn      主编辑器
  runtime_preview.tscn  运行预览
  placeholder_target.tscn  占位目标场景
scripts/                核心脚本
  editor_main.gd        编辑器逻辑
  scene_canvas.gd       画布交互 + 地图绘制
  runtime_preview.gd    运行时逻辑
  project_store.gd      项目快照存储
  logic_templates.gd    AI 逻辑模板
tools/
  ai_cli_bridge.py      外部 AI CLI 桥接示例
STATUS.md               当前进度摘要
HANDOFF.md              续开发说明
```

## 运行方式

### macOS / Windows / Linux

1. 安装 `Godot 4.6.1` 或兼容的 `Godot 4.x`
2. 打开 Godot
3. 导入本仓库目录
4. 运行主场景 `scenes/editor_main.tscn`

### 当前验证方式

开发时使用过以下校验：

```bash
Godot --headless --path <repo> --quit
Godot --headless --path <repo> --scene res://scenes/runtime_preview.tscn --quit-after 1
python3 -m py_compile tools/ai_cli_bridge.py
```

## 当前限制

- 还不是完整产品，只是框架骨架
- 还没有多图层 TileMap 编辑器
- 还没有背包、菜单、任务、存档等完整系统
- 当前导入的外部素材路径仍然偏开发态，后面要整理成更稳的项目内资源工作流
- 当前 UI 仍是单窗口骨架，后续会拆成多个工作区

## 下一步路线

1. 更完整的 TileMap / 多图层地图编辑
2. 更强的对象属性系统和事件旗标
3. UI 编辑能力（对话框、菜单、背包、任务）
4. AI CLI 深度接入
5. 多工作区编辑器结构
6. 更接近宝可梦 / 星露谷类 2D 游戏的通用框架能力

## 适合做什么类型的游戏

目标是支持类似下面这些 2D 游戏方向：

- 顶视角 RPG
- 宝可梦式探索游戏
- 星露谷式经营 / 生活模拟
- 2D 剧情探索游戏
- 带交互和事件系统的像素游戏

## 继续开发建议

如果你是新开窗口继续做，先读：

1. `STATUS.md`
2. `HANDOFF.md`

然后再继续扩展功能，不要直接重构现有骨架。
