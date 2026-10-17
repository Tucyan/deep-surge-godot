# 独立剧情数据结构 v1

2026-10-14。对应 `story/story_player.gd`、`story/demo_story.json`。这是独立 VN 页面的程序设计契约，没有 AP、物资奖励或 GameSession 命令。

2026-10-18：本 schema 现在是剧情层的实际运行格式。`narrative/content/scenes/*.json` 在 v1 字段之外增加了可选 `requires_affinity`（选项好感门槛）和 `affinity` / `set_flags`（选项结算），`story_player.gd` 只读已知字段，因此不改变原有校验。旧 `content/data/story_nodes.json` 已随旧剧情模式删除。

## 内容定义

JSON 可序列化，无 Node、Texture、Callable、DOM 或场景引用。

| 层级 | 字段 | 类型 / 约束 |
| --- | --- | --- |
| StoryDefinition | schema_version | 当前仅支持 1 |
| | id | 非空 String，稳定剧情 ID |
| | title | String，最多 40 字符 |
| | entry | String，存在的节点 ID |
| | nodes | 非空 Array<StoryNode> |
| StoryNode | id | 非空 String，剧情内唯一 |
| | speaker | 可选 String，默认“旁白”，最多 24 字符 |
| | description | 可选 String，默认空，最多 80 字符；显示场景/行动说明 |
| | text | 非空 String，最多 160 字符 |
| | next | 可选 String，默认空；空表示终点 |
| | choices | 可选 Array<StoryChoice>，默认空，最多 3 项 |
| StoryChoice | id | 非空 String，当前节点内唯一 |
| | text | 非空 String，最多 20 字符 |
| | next | 非空 String，存在的目标节点 ID |

所有可见文字均为单段文字，不含 CR/LF；长段落拆成多个节点。Godot Label 自动换行并在范围内缩小字体。`next` 非空与 `choices` 非空不能并存；拒绝悬空跳转和任何环路，保证 SKIP 有限。失败加载保持已有状态完整，未知额外字段暂不参与执行。

```json
{
  "schema_version": 1,
  "id": "example.harbor",
  "title": "入港",
  "entry": "arrival",
  "nodes": [
    {"id":"arrival", "speaker":"旁白", "description":"港口 · 黄昏", "text":"你看见了一盏灯。", "choices":[
      {"id":"approach", "text":"靠近灯光", "next":"end"}
    ]},
    {"id":"end", "text":"海雾散去。"}
  ]
}
```

## 运行视图与日志

`StoryView = {story_id:String, title:String, status:"idle"|"playing"|"completed", node:StoryNode|{}, log_count:int}`。

`LogEntry = {node_id:String, speaker:String, description:String, text:String, choice_id:String, choice_text:String}`；未选择时两个 choice 字段为空。进入节点时登记全文一次，尚在打字的当前段也允许在 LOG 阅读全文；不会提前记录未来或未选择的分支。SKIP 实际经过的段落同样可回看。选择结果写在来源节点的日志条目中。

`StoryResult = {story_id:String, reason:"finished"|"skipped", choices:Array<{node_id:String, choice_id:String}>}`，只包含实际选择顺序。日志及 view 深拷贝，调用方不能通过改副本改变会话。

私有运行状态：内容副本、节点索引、当前节点 ID、status、日志和选择记录。打字计时、LOG 页码、焦点和纹理由页面独立持有。页面本身仍不持有存档；剧情进度由 `narrative/narrative_session.gd` 在场景结束后写入独立剧情档。

配套调用约定：[接口文档](story-interface.md)。
