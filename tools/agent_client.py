"""Persistent Godot Agent JSONL client and a small example play policy.

Only the Python standard library is required. Import AgentClient for an external
Agent; CLI defaults to JSONL passthrough, --play runs the example policy.
"""
import argparse
from collections import deque
import json
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import threading

PROTOCOL = "deep-surge-agent-v1"
ROOT = Path(__file__).resolve().parents[1]


class AgentClient:
    def __init__(self, godot=None, project=ROOT, timeout=15):
        executable = godot or shutil.which("Godot_v4.7.2-stable_win64_console.exe") or shutil.which("godot")
        if not executable:
            raise FileNotFoundError("Godot not found; pass --godot with its executable path")
        self.timeout = timeout
        self.errors = deque(maxlen=100)
        self._responses = queue.Queue()
        self._next_id = 0
        self._closed = False
        self.process = subprocess.Popen(
            [str(executable), "--headless", "--path", str(project), "--script", "res://tools/agent_stdio.gd"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", bufsize=1,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        self._out_thread = threading.Thread(target=self._read_stdout, daemon=True)
        self._err_thread = threading.Thread(target=self._read_stderr, daemon=True)
        self._out_thread.start()
        self._err_thread.start()

    def _read_stdout(self):
        try:
            for line in self.process.stdout:
                try:
                    response = json.loads(line)
                except json.JSONDecodeError:
                    continue  # Godot startup banner is not a protocol response.
                if isinstance(response, dict) and response.get("protocol") == PROTOCOL:
                    self._responses.put(response)
        finally:
            self._responses.put(None)

    def _read_stderr(self):
        for line in self.process.stderr:
            self.errors.append(line.rstrip())

    def raw(self, line):
        if self._closed:
            raise RuntimeError("Agent client is closed")
        self.process.stdin.write(line + "\n")
        self.process.stdin.flush()
        try:
            response = self._responses.get(timeout=self.timeout)
        except queue.Empty as exc:
            self.close(force=True)
            raise TimeoutError("Godot request timed out; process stopped, no retry. " + "\n".join(self.errors)) from exc
        if response is None:
            raise RuntimeError("Godot process exited: " + "\n".join(self.errors))
        return response

    def request(self, method, params=None):
        self._next_id += 1
        response = self.raw(json.dumps({"id": self._next_id, "method": method, "params": params or {}}, ensure_ascii=False))
        if response.get("id") != self._next_id:
            raise RuntimeError("Godot response id mismatch")
        return response

    def close(self, force=False):
        if self._closed:
            return
        try:
            if not force and self.process.poll() is None:
                self.request("quit")
            if force and self.process.poll() is None:
                self.process.kill()
            self.process.wait(timeout=3)
        except (OSError, RuntimeError, TimeoutError, subprocess.TimeoutExpired):
            if self.process.poll() is None:
                self.process.kill()
            self.process.wait(timeout=3)
        finally:
            self._closed = True
            self._out_thread.join(timeout=1)
            self._err_thread.join(timeout=1)
            for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
                stream.close()

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()


def data(response):
    if not response["ok"]:
        raise RuntimeError(json.dumps(response["error"], ensure_ascii=False))
    return response["data"]


def choose_action(observation, actions):
    """Example heuristic, separate from the game protocol; not a balance verdict."""
    def first(command, predicate=lambda a: True):
        return next((a for a in actions if a["command"] == command and predicate(a)), None)

    phase = observation["phase"]
    if phase in ("navigation", "preparation", "aftermath", "battle"):
        survival = {c["uid"] for c in observation["hand"] if c["definition"]["kind"] == "survival"}
        action = first("play", lambda a: a["args"]["uid"] in survival and a["effective"])
        if action:
            return action
    if phase in ("preparation", "aftermath"):
        tutorial = observation.get("tutorial_operation", "")
        if tutorial:
            action = first(tutorial, lambda a: tutorial != "craft" or a["args"].get("id") == "filter")
            if action:
                return action
        devices = {c["equipment"].get("id") for c in observation["cells"]}
        cards = {c["uid"]: c["id"] for c in observation["hand"]}
        action = first("install", lambda a: cards.get(a["args"].get("uid")) in ("crossbow", "lamp", "filter", "planter"))
        if action:
            return action
        if "crossbow" not in devices and "crossbow" not in cards.values():
            action = first("craft", lambda a: a["args"].get("id") == "crossbow")
            if action:
                return action
        action = first("enter" if phase == "preparation" else "end_voyage")
        if action:
            return action
    if phase == "navigation":
        camp = next((n["visit_id"] for n in observation["candidates"] if n["id"] == "camp"), None)
        return first("voyage", lambda a: a["args"]["id"] == camp) or first("voyage")
    if phase == "story":
        action = first("advance")
        if action:
            return action
        if observation["node"].get("boss"):
            action = first("fight")
        else:
            action = first("leave_encounter")
        return action or first("fight") or first("option", lambda a: a["args"].get("id") == "rest") or first("option") or first("shop_enter")
    if phase == "battle":
        action = first("play") or first("battle_action", lambda a: a["args"] == {"action": "attack"})
        return action or first("battle_end")
    if phase == "discard":
        return first("discard")
    if phase == "interaction":
        return first("shop_leave")
    if phase == "nightHub":
        return (first("submit_quest") or first("accept_quest") or first("night_actions")
                or first("night_action", lambda a: a["args"]["id"] != "rest") or first("night_action")
                or first("night_ack") or first("finish_night"))
    return None


def play(game, seed=22, mode="challenge", max_steps=600):
    observation = data(game.request("reset", {"seed": seed, "mode": mode}))["observation"]
    for step in range(max_steps):
        if observation["terminal"]:
            result = data(game.request("result"))
            return {**result, "steps": step, "seed": seed, "mode": mode}
        actions = data(game.request("actions"))["actions"]
        chosen = choose_action(observation, actions)
        if chosen is None:
            raise RuntimeError("Policy has no decision at " + observation["phase"])
        observation = data(game.request("act", {"action_id": chosen["action_id"], "revision": observation["revision"]}))["observation"]
    raise RuntimeError(f"Policy exceeded {max_steps} steps; run left available for inspection")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--play", action="store_true")
    parser.add_argument("--seed", type=int, default=22)
    parser.add_argument("--mode", choices=("challenge", "story"), default="challenge")
    parser.add_argument("--max-steps", type=int, default=600)
    parser.add_argument("--trace", type=Path)
    args = parser.parse_args()
    with AgentClient(godot=args.godot) as game:
        if args.play:
            result = play(game, args.seed, args.mode, args.max_steps)
            if args.trace:
                args.trace.write_text(json.dumps(data(game.request("trace")), ensure_ascii=False), encoding="utf-8")
            print(json.dumps(result, ensure_ascii=False))
        else:
            for line in sys.stdin:
                print(json.dumps(game.raw(line.rstrip("\r\n")), ensure_ascii=False), flush=True)
        if game.errors:
            raise RuntimeError("Godot stderr: " + "\n".join(game.errors))


if __name__ == "__main__":
    main()
