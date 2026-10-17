场景输入没有双击专门分支；左右键交由 camera_input，左键还会拾取/选择。
首次格子高亮从 GPU mesh surface_get_arrays 提取顶面；后续按模型缓存。
手牌单击查看经 handle_ui -> render 全量重建 HUD；装备双击经 dispatch -> save -> render。
voyage_world.sync 仅在 cells 签名改变后重建筏格。
用户场景已确认。独立 GPU 测试显示全量 HUD 重建与延迟稳定对应；实例 ID 验证排除筏格重建，快照验证排除规则变化。字体共享无明显改善、纸纹及图标缓存仅部分改善，均不是完整修复。后续应缩小 card 和 settings 的刷新范围。
