# HANDOFF

## 这个项目是什么

基于 Godot 的 2D 轻量编辑器框架 — **Lite2D Studio**。

用户负责素材、地图、布局和视觉风格。AI 负责移动、碰撞、交互、事件、对话、切场景等逻辑。目标用户是有一点基础但不想学 Godot 的人。最终导出为独立桌面应用。

## 设计原则

1. **保留能力，不保留复杂操作** — Godot 几百个属性压缩成 10-20 个"人话"选项
2. **先做逻辑闭环，再做界面美化**
3. **AI 兜底** — 用户说不清楚的需求交给 AI 处理
4. **三层处理策略** — 默认值自动化 / 简化成人话开关 / AI 兜底处理边缘情况
5. **保持跨平台**

## 当前完成状态：里程碑 1

### 已完成功能清单
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

### 关键文件
| 文件 | 作用 |
|------|------|
| `scripts/editor_main.gd` | 编辑器主逻辑（undo/redo、debounce、AI 集成、多图层） |
| `scripts/scene_canvas.gd` | 画布交互 + 多图层渲染 + 性能优化 |
| `scripts/runtime_preview.gd` | 运行时预览（Camera2D 修复版） |
| `scripts/project_store.gd` | 项目数据序列化/反序列化（含图层兼容） |
| `scripts/logic_templates.gd` | 内置关键词模板（含优先级系统） |
| `scripts/undo_redo_manager.gd` | 撤销/重做管理器 |
| `scripts/ai_client.gd` | AI 客户端（Ollama + OpenAI） |
| `tools/ai_cli_bridge.py` | CLI/API 桥接（10 个命令） |
| `export_presets.cfg` | 导出预设 |
| `research-report.md` | 竞品调研报告（5 款产品 + 导出流程 + Ollama API） |

## 架构

```
编辑器层 (editor_main.gd + scene_canvas.gd)
    ↓ 数据
数据层 (project_store.gd → user://editor_state.json)
    ↓ 读取
运行预览层 (runtime_preview.gd)
    
AI 层 (ai_client.gd → Ollama/OpenAI)
    ↓ 回退
模板层 (logic_templates.gd)

CLI 层 (ai_cli_bridge.py → editor_state.json)
```

## 里程碑 2 要做什么

### 第一优先级
1. **条件-动作事件编辑器** — 参考 GDevelop/Construct 3，用可视化条件-动作表替代纯文本。研报里有详细参考。
2. **行为(Behaviors)系统** — 用户给对象选一个行为（如"平台角色"、"巡逻NPC"），自动配置物理和逻辑。
3. **对话系统增强** — 多轮分支对话、NPC 头像显示。

### 第二优先级
4. 背包/物品系统
5. 任务系统原型
6. 存档系统

### 第三优先级
7. 多工作区编辑器（Tab 式）
8. 内置资源库
9. 游戏导出（用户的游戏也能打包）

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

给新窗口发仓库链接即可：
```
继续做这个仓库：https://github.com/0xPanty/godot-2d-lite
先看 STATUS.md 和 HANDOFF.md，然后开始里程碑 2
```
