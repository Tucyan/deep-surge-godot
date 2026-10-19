# 出身 v1 验证记录

日期：2026-10-18（Asia/Singapore）

## 规则与界面

Godot 4.7.2 stable 测试结果：

```text
test_origins_v1       PASS (0 failures)
test_origins_edges    PASS (0 failures)
test_origins_ui       PASS
test_save             PASS
test_battle_actions   PASS
test_auto_progress    PASS
test_action_query     PASS
test_formal_shop      PASS (82 checks)
test_battle_equipment_ui PASS
test_tutorial_enchantment PASS
```

UI 以无头模式和 NVIDIA RTX 4060 的 OpenGL compatibility 渲染各运行一次，均通过；截图证据为 `origins-v1-setup.png`、`origins-v1-zealot.png` 和 `origins-v1-skeptic.png`。

## 跨运行时检查

```text
python -m unittest discover -s tests -p test_agent_stdio.py -v
Ran 3 tests ... OK

node --test tests/content.test.mjs tests/node_content.test.mjs
15 passed, 0 failed

python -m py_compile tools/smart_playtest.py
```

8 个启用出身各执行一次标准 Agent 完整流程（seed=22，500 步上限），均到达 `finished survived`，无引擎错误。这只证明流程可运行，不代表数值平衡已经确认。

## 范围与限制

- 拾荒者保留定义和说明，但 `enabled:false`；新局、存档校验和 Agent reset 都拒绝选择。
- 本次没有进行长时间平衡模拟，也没有把 Agent 通关结果当作平衡结论。
- 未提交或推送 Git；工作区中的其他既有修改保持原状。
