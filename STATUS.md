# godot-2d-lite 当前状态

最后同步阶段：`MVP 框架骨架 + 基础地图编辑 + 运行预览闭环`

## 产品目标
- 做一个基于 Godot 的 2D 轻量编辑器框架。
- 用户只负责素材、地图、界面、布局和视觉风格。
- AI 负责移动、碰撞、交互、事件、对话、场景切换等底层逻辑。
- 目标不是复刻完整 Godot，而是做一个更简单、更适合小白上手的 2D 搭建器。

## 当前进度
- 已完成编辑器骨架：资源区、对象列表、场景画布、属性面板、AI 指令面板。
- 已完成对象系统基础：主角、NPC、门、宝箱、触发区。
- 已完成基础地图绘制：地面、墙体、水域、擦除。
- 已完成运行预览闭环：编辑 -> 保存 -> 运行预览 -> 返回编辑器。
- 已完成基础运行逻辑：玩家移动、相机跟随、NPC 对话、门切场景、宝箱奖励、触发区事件。
- 已预留 AI CLI 桥接：`tools/ai_cli_bridge.py`。

## 现在项目里有什么
- `project.godot`: Godot 项目入口。
- `scenes/editor_main.tscn`: 主编辑器界面。
- `scenes/runtime_preview.tscn`: 运行预览。
- `scripts/editor_main.gd`: 编辑器主逻辑。
- `scripts/scene_canvas.gd`: 画布拖拽和地图绘制。
- `scripts/runtime_preview.gd`: 运行时预览逻辑。
- `scripts/project_store.gd`: 项目快照与数据存储。
- `scripts/logic_templates.gd`: 内置 AI 逻辑模板。

## 下一步优先级
1. 做更完整的 TileMap / 多图层地图编辑。
2. 扩展对象属性系统和事件旗标。
3. 做更完整的 UI 编辑能力（对话框、菜单、背包）。
4. 增强 AI CLI 接入，把自然语言真正转成可复用逻辑模块。
5. 把单窗口骨架升级成多工作区编辑器。

## 运行方式
- 用 Godot 4.6.1 或兼容的 Godot 4.x 打开仓库根目录。
- 主编辑器入口：`res://scenes/editor_main.tscn`
- 运行预览入口：`res://scenes/runtime_preview.tscn`

## 给下次续开发的建议
- 先看 `README.md`
- 再看 `HANDOFF.md`
- 最后再改脚本和场景

## 当前判断
当前版本是“可继续迭代的框架骨架”，不是完整成品。
重点已经从纯界面原型进入“逻辑闭环可运行”的阶段。
