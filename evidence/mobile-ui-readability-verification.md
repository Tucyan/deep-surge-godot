# 手机 UI 阅读与触控优化验证

日期：2026-10-19。Godot 4.7.2 / Windows / NVIDIA RTX 4060 Laptop / OpenGL Compatibility。发布标签：`v0.2.0-20261019-mobile`，来源分支：`codex/origins-v1`。包含手机端阅读与触控体验优化、字号与命中区规范及 Noto Sans SC 中文字库支持。

## 已实施范围

手机设置整页、返回导航、设置分类独立滚动与位置恢复；名称22/说明18/按钮20和60高控件；滑条加减、下拉菜单；导航及关闭命中区、四属性数字；手机事件两栏；合成三列6项/转化纵向；图鉴两列/遗物三列6项；剧情独立文字布局、滚动正文/选项/LOG；教程战斗提示避让。当前细节见[手机布局契约](../docs/mobile-ui-readability.md)。

## 运行结果

所有测试通过独立APPDATA/LOCALAPPDATA运行，应用夹具persistence=false，不接触玩家实际存档。规则测试和表现测试使用固定种子22。

| 测试 | 当次结果 |
|---|---|
| test_mobile_readability.gd | PASS；整页尺寸、字号/命中高度、各分类切换/滚动恢复、返回、快照不变、合成/图鉴/遗物密度、手机剧情长文/换段/LOG、桌面弹窗保留 |
| test_mobile_transmute_scroll.gd | PASS；真实触摸注入从材料卡及已投入槽滑动不选料/撤回，明确按钮选料后保留滚动位置；AP/库存/RNG不变 |
| test_display_settings.gd | PASS |
| test_mobile_hand.gd | PASS |
| test_mobile_hover.gd | PASS |
| test_mobile_scroll.gd | PASS |
| test_narrative_flow.gd | 19 checks, 0 failures |
| test_story_player.gd | 31 checks, 0 failures |
| test_recall_restore.gd | 9 checks, 0 failures |
| test_craft_upgrade.gd | PASS |
| test_ui_layout_controls.gd | PASS |
| test_tutorial_event_layout.gd | PASS；执行完整教程事件及战斗步骤，提示与面板不相交 |
| test_routes.gd | PASS（executed=7, stale=13, failed=0）；当前七条必需路线全部实际执行 |

文档检查：`python tools/check_docs.py` PASS（45 entry/topic files、9 current documents、0 errors）；文档工具单元测试8项通过。本次19条程序化资产登记的源文件hash一致；考虑工作树已有CRLF文件，`git -c core.whitespace=cr-at-eol diff --check`通过，未修改Git设置。

结构回归先执行失败版本（MOBILE READABILITY: FAIL，191项），再实施并转为PASS。新增测试使用合法剧情schema，每段最多160字，并用受限阅读区域验证滚动；没有修改剧情内容限制。

GPU运行 `tests/test_mobile_readability.gd -- --capture` 正常退出并输出PASS，覆盖1260×540、1280×720、1680×720的125%设置分类/航行截图，以及合成、转化、图鉴、遗物和剧情。另做1260×540的100%/125%设置及真实z=400叙事遮挡专项截图。

截图：[125%整页设置](mobile-readable-1260x540-settings-125.png)、[100%整页设置](mobile-readable-1260x540-settings-100.png)、[航行](mobile-readable-1260x540-voyage.png)、[合成](mobile-readable-craft.png)、[转化](mobile-readable-transmute.png)、[图鉴](mobile-readable-encyclopedia.png)、[剧情选项](mobile-readable-story-choices.png)、[剧情LOG](mobile-readable-story-log.png)。

原test_craft_grid.gd无条件等待RenderingServer.frame_post_draw，误以无头方式运行后无法结束，已停止该进程，未将其计为通过；合成由新表现回归、GPU截图及test_craft_upgrade验证。其他测试曾暴露的测试路由/夹具错误和新增代码类型推断错误已修正后验证；此前失败日志留在本地.planning，不冒充成功记录。

## 产物

产物与本次原始导出日志位于忽略的 `builds/release-20261019-mobile/`，产物另上传 GitHub Release。

| 文件 | 字节 | SHA256 |
|---|---:|---|
| DeepSurge.exe | 269999592 | `dcca9ed86c2d3a4bf0996186b76a25bba32820c1664343325e59d6da14fbe23d` |
| DeepSurge-v0.2-android-debug.apk | 217804979 | `4b9c34150d0b2f5a72acd865bbcc6af7e7403d081e8860d1f5998386277af697` |

## 限制

以上真实触摸为Godot输入事件注入，不能代替Android设备触控验收。系统安全区域、系统返回键、屏幕密度、手势导航边缘和性能仍待真机确认。没有GPU验证2520×1080；无头窗口变更结果不作为真实分辨率证明。

未实施独立文字缩放、150%UI上限或图鉴/遗物列表详情分离路由；当前以统一字号、减少密度与滚动解决阅读空间。剧情手机采用独立排版，桌面保留既有构图。
