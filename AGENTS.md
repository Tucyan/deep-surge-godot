# Deep Surge Godot 协作约定

## 默认工程与分支

- 默认开发分支为 **`codex/integrate-v03-relics`**，开发基于0.3版本；执行前核对当前Git分支与工作区状态。
- 本机默认工作树为 `C:/Users/ALmerb/.codex/worktrees/deep-surge-integrated-20261020`。其他机器使用本仓库的对应分支，不依赖此绝对路径运行。
- 根文档仓库与本游戏仓库独立管理。保留原 `codex/origins-v1`、`codex/v03-development` 工作现场及未提交内容，不批量添加嵌套仓库、不自动切换或覆盖其他工作树。
- Godot 4.7.2 / GDScript；入口为 `project.godot` → `scenes/main.tscn` → `flow_app.gd`。按需阅读[文档索引](docs/README.md)、[当前机制](docs/current-game-mechanics.md)、[应用架构](docs/application-architecture.md)和[Agent接口](docs/agent-interface.md)。当前契约优先于旧提案及历史证据，冲突时核对实际执行分支。

## 剧情与保存边界

- 剧情模式暂停开发；未经用户明确要求，不新增、扩展或重做。`flow_app.gd` 的 `story_mode_visible` 默认关闭，剧情入口、选档、相关设置和帮助保持隐藏。
- 保留现有剧情代码、章节、配对保存和好感逻辑；独立序章、首页“回溯潮涌”只读回廊及挑战普通节点事件继续可用。范围见[剧情保存契约](docs/narrative-and-save.md)和[回廊契约](docs/story-gallery.md)。
- 当前不做旧版本存档兼容或迁移；不兼容时拒绝并保留原文件。同版本保存恢复及数据完整性仍须验证。旧剧情回廊读取是明确例外，浏览不得推进玩法、耗随机、发奖励或写回旧归档。

## 程序与资产

- `core/` 不依赖UI/3D节点或存储；UI与Agent通过 `GameSession.dispatch` 执行，查询和预览使用副本。应用协调属于 `application/`，文件读写属于 `adapters/`。
- 内容定义与实例分离，实例以唯一ID跟踪；状态可JSON序列化。规则随机使用可恢复的固定算法及独立流，与表现随机分离；查看、取消、预览和恢复不重掷或重复结算。保存记录schema、内容和随机算法版本。
- 资产使用稳定AssetId，登记来源、版本、依赖、运行映射及尺寸/hash；程序化资源同样登记。共享资源走缓存，私有资源随实例释放；个人Downloads路径不进入运行内容。
- 不删除 `.bin`、`.planning`、源资产或实验文件；不为设计或文档工作安装依赖、升级软件或修改全局Unity/Blender/MCP配置。

## 执行与验证

- 长时间执行、下载或权限不足的命令最多尝试3次；实际超时后停止重试并交由用户执行，除非用户明确要求继续，或已知超时原因且能解决。下载尽可能选国内镜像。
- 不自动添加远程或推送；用户要求推送时，先确认GitHub CLI当前账户为 **Tucyan**。
- 使用固定种子规则/集成测试及真实Agent路线；当前版本必需路线必须实际执行，不能全部stale跳过仍报告通过。GPU、触摸和发行导出分别验收，不以无头通过代替。
- 测试隔离APPDATA/LOCALAPPDATA，不读写玩家实际保存；结果按当次输出记录，未覆盖项明确说明。
- 文档改动执行 `python tools/check_docs.py`，同步受影响契约、来源和验证入口。文档分层见[维护规则](docs/documentation-governance.md)；逐次更新写入[更新日志](CHANGELOG.md)及对应证据，不追加到本约定。
