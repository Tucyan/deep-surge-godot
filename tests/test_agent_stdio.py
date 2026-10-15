"""Real-process protocol tests; no GUI or external dependencies."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AgentStdioTests(unittest.TestCase):
    def test_persistent_process_and_replay(self):
        self.assertTrue((ROOT / "tools/agent_stdio.gd").is_file(), "missing stdio entry")
        self.assertTrue((ROOT / "tools/agent_client.py").is_file(), "missing Python client")
        spec = importlib.util.spec_from_file_location("agent_client", ROOT / "tools/agent_client.py")
        client = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(client)
        with client.AgentClient(project=ROOT) as game:
            self.assertFalse(game.raw("{bad-json")["ok"])
            self.assertFalse(game.raw("[]")["ok"])
            reset = game.request("reset", {"seed": 22})
            self.assertTrue(reset["ok"], reset)
            observation = reset["data"]["observation"]
            choices = game.request("actions")["data"]["actions"]
            move = next(a for a in choices if a["command"] == "voyage")
            self.assertTrue(game.request("act", {"action_id": move["action_id"], "revision": observation["revision"]})["ok"])
            trace = game.request("trace")["data"]
            self.assertGreater(len(json.dumps(trace)), 1024, "exercise input beyond default stdin buffer")
            self.assertTrue(game.request("replay", {"trace": trace})["ok"])
            self.assertEqual(game.request("observe")["data"]["phase"], "preparation")
            self.assertFalse(game.errors, game.errors)

    def test_automatic_game_and_full_trace(self):
        self.assertTrue((ROOT / "tools/agent_client.py").is_file(), "missing Python client")
        spec = importlib.util.spec_from_file_location("agent_client", ROOT / "tools/agent_client.py")
        client = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(client)
        with client.AgentClient(project=ROOT) as game:
            run = client.play(game, seed=22, max_steps=600)
            self.assertTrue(run["terminal"], run)
            self.assertGreater(run["completed"], 0)
            trace = game.request("trace")["data"]
            self.assertGreater(len(trace["steps"]), 20)
            self.assertTrue(game.request("replay", {"trace": trace})["ok"])
            self.assertFalse(game.errors, game.errors)

    def test_story_policy_reaches_terminal(self):
        self.assertTrue((ROOT / "tools/agent_client.py").is_file())
        spec = importlib.util.spec_from_file_location("agent_client", ROOT / "tools/agent_client.py")
        client = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(client)
        with client.AgentClient(project=ROOT) as game:
            run = client.play(game, seed=22, mode="story", max_steps=600)
            self.assertTrue(run["terminal"])
            self.assertGreater(run["completed"], 0)
            self.assertTrue(game.request("replay", {"trace": game.request("trace")["data"]})["ok"])
            self.assertFalse(game.errors, game.errors)


if __name__ == "__main__":
    unittest.main()
