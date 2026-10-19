"""Isolated main-scene crash/restart acceptance; stdlib only, no automatic retries.

Run from any directory. Every Godot process has its own 30 second wall limit.
--tests runs selected existing GDScript tests with isolated user directories.
Logs, configuration, snapshots and a truthful summary remain under .planning.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|FAIL:")
TIMEOUT = 30


class VerificationFailure(RuntimeError):
    pass


class Runner:
    def __init__(self, godot: str, root: Path, gpu: bool = False):
        self.godot, self.root = godot, root
        self.results: list[dict] = []
        self.unverified: list[str] = []
        self.gpu = gpu

    def environment(self, directory: Path) -> dict[str, str]:
        environment = os.environ.copy()
        for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
            path = directory / name.lower()
            path.mkdir(parents=True, exist_ok=True)
            environment[name] = str(path)
        environment["DEEP_SURGE_CRASH_PROBE"] = "isolated"
        return environment

    def run(self, name: str, environment: dict, config: dict | None = None,
            script: str = "res://tests/challenge_crash_probe.gd", kill_ready: bool = False,
            arguments: list[str] | None = None) -> dict:
        log = self.root / f"{name}.log"
        command = [self.godot] + ([] if self.gpu else ["--headless"]) + ["--path", str(PROJECT), "--script", script]
        if config is not None:
            config = {"isolated": True, **config}
            config_path = self.root / f"{name}.config.json"
            config_path.write_text(json.dumps(config, ensure_ascii=False), encoding="utf-8")
            command += ["--", str(config_path)]
        elif arguments:
            command += ["--", *arguments]
        record = {"name": name, "command": command, "log": str(log), "status": "running"}
        self.results.append(record)
        started = time.monotonic()
        process = None
        try:
            with log.open("wb") as output:
                process = subprocess.Popen(command, cwd=PROJECT, env=environment, stdout=output,
                                           stderr=subprocess.STDOUT,
                                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                while True:
                    text = log.read_text(encoding="utf-8", errors="replace")
                    if ERROR.search(text):
                        raise VerificationFailure(f"{name}: script error/failure; see {log}")
                    if kill_ready and Path(config["ready"]).is_file():
                        ready = json.loads(Path(config["ready"]).read_text(encoding="utf-8"))
                        if not ready.get("ready") or process.poll() is not None:
                            raise VerificationFailure(f"{name}: writer exited before live crash checkpoint")
                        process.kill()
                        process.wait(timeout=5)
                        record["status"] = "passed"
                        record["forced_kill"] = True
                        break
                    if process.poll() is not None:
                        if process.returncode:
                            raise VerificationFailure(f"{name}: exit {process.returncode}; see {log}")
                        if kill_ready:
                            raise VerificationFailure(f"{name}: writer exited without readiness marker")
                        record["status"] = "passed"
                        break
                    if time.monotonic() - started >= TIMEOUT:
                        record["status"] = "timeout"
                        raise VerificationFailure(f"{name}: exceeded {TIMEOUT}s; stopped with no retry. User must run any next attempt.")
                    time.sleep(0.05)
            text = log.read_text(encoding="utf-8", errors="replace")
            if ERROR.search(text):
                raise VerificationFailure(f"{name}: final log has script errors; see {log}")
            print(f"PASS {name}", flush=True)
            return record
        except BaseException:
            if record["status"] == "running":
                record["status"] = "failed"
            raise
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            record["elapsed_seconds"] = round(time.monotonic() - started, 3)
            self.summary()

    def summary(self) -> None:
        (self.root / "summary.json").write_text(json.dumps({
            "project": str(PROJECT), "per_process_timeout_seconds": TIMEOUT,
            "results": self.results,
            "unverified": self.unverified,
            "limitations": ["No physical power-loss guarantee.",
                            "Kill during writing or the atomic rename syscall is not deterministically injected.",
                            "GPU, touch and exported release builds are outside this headless verifier."],
        }, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("Godot_v4.7.2-stable_win64_console.exe"))
    parser.add_argument("--tests", nargs="+", metavar="TEST", help="run only these res://tests scripts")
    parser.add_argument("--checkpoints", nargs="+", help="run selected planned crash checkpoints")
    parser.add_argument("--skip-route-gate", action="store_true", help="run crash scenarios independently; record the required route gate as unverified")
    parser.add_argument("--routes-only", action="store_true", help="run each of the seven required routes in its own bounded process")
    parser.add_argument("--gpu", action="store_true", help="show real Godot windows for selected --tests instead of --headless")
    parser.add_argument("--faults-only", action="store_true", help="create only the initial navigation checkpoint and run independent I/O/rejection faults")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot_v4.7.2-stable_win64_console.exe was not found; provide --godot PATH")
    if args.gpu and not args.tests:
        parser.error("--gpu requires --tests")
    root = PROJECT / ".planning" / "challenge-resume" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    root.mkdir(parents=True)
    print(f"Evidence: {root}", flush=True)
    runner = Runner(args.godot, root, args.gpu)
    try:
        if args.tests:
            for index, test in enumerate(args.tests):
                name = Path(test).stem
                script = test if test.startswith("res://") else f"res://tests/{test}"
                runner.run(f"test-{index}-{name}", runner.environment(root / f"test-{index}"), script=script)
            return 0
        if args.skip_route_gate:
            runner.unverified.append("Required seven-route test_routes.gd gate explicitly skipped; this is a partial acceptance run.")
        else:
            required = ["standard-challenge", "standard-story", "hard-challenge", "hard-story", "nightmare-challenge", "nightmare-story", "standard-failure"]
            for route_name in required:
                runner.run("route-" + route_name, runner.environment(root / ("route-" + route_name)),
                           script="res://tests/test_routes.gd", arguments=["--route", route_name])
        if args.routes_only:
            return 0
        planned = root / "planned.json"
        runner.run("plan", runner.environment(root / "planner"), {"mode": "plan", "output": str(planned)})
        plan = json.loads(planned.read_text(encoding="utf-8"))
        checkpoints = plan["checkpoints"]
        if args.faults_only:
            checkpoints = [row for row in checkpoints if row["name"] == "navigation"]
            runner.unverified.append("Only navigation crash and independent faults selected; other crash checkpoints omitted.")
        if args.checkpoints:
            known = {row["name"] for row in checkpoints}
            if set(args.checkpoints) - known:
                raise VerificationFailure("Unknown checkpoints: " + ", ".join(set(args.checkpoints) - known))
            checkpoints = [row for row in checkpoints if row["name"] in args.checkpoints]
        saved_case = None
        for row in checkpoints:
            name = row["name"]
            directory = root / name
            environment = runner.environment(directory)
            expected, ready = directory / "expected.json", directory / "ready.json"
            runner.run(name + "-writer", environment, {**row, "mode": "write", "output": str(expected), "ready": str(ready)}, kill_ready=True)
            info = json.loads(expected.read_text(encoding="utf-8"))
            save_path = Path(info["save_path"])
            if not save_path.resolve().is_relative_to(directory.resolve()):
                raise VerificationFailure(f"Isolation failed: {save_path}")
            if json.loads(save_path.read_text(encoding="utf-8")) != info["snapshot"]:
                raise VerificationFailure(f"{name}: killed writer file differs from complete expected snapshot")
            if info.get("cleanup_tmp"):
                temporary = Path(info["cleanup_tmp"])
                if not temporary.resolve().is_relative_to(directory.resolve()) or temporary != Path(str(save_path) + ".tmp"):
                    raise VerificationFailure("Refusing cleanup outside isolated temporary save target")
                temporary.rmdir()
            runner.run(name + "-reader", environment, {"mode": "read", "expected": str(expected), "output": str(directory / "read.json")})
            if name == "terminal_unsaved":
                runner.run(name + "-second-restart", environment, {"mode": "read", "expected": str(directory / "read.json"), "output": str(directory / "second-read.json")})
            if name == "navigation":
                saved_case = (directory, environment, expected, info)
        if not args.checkpoints and saved_case:
            directory, environment, expected, info = saved_case
            save_path = Path(info["save_path"])
            original = json.dumps(info["snapshot"], ensure_ascii=False)
            # Reset only this isolated shared checkpoint between independent faults.
            for fault in ("temporary", "rename"):
                save_path.write_text(original, encoding="utf-8")
                runner.run("fault-" + fault, environment, {"mode": "fault", "fault": fault, "output": str(directory / f"fault-{fault}.json")})
            invalid = {"truncated": '{"schema":',
                       "version": json.dumps({**info["snapshot"], "content_version": "unsupported"}),
                       "fingerprint": json.dumps({**info["snapshot"], "fingerprint": "0" * 64})}
            for fault, text in invalid.items():
                save_path.write_text(text, encoding="utf-8")
                before = save_path.read_bytes()
                runner.run("reject-" + fault, environment, {"mode": "read", "reject": True, "expected": str(expected), "output": str(directory / f"reject-{fault}.json")})
                if save_path.read_bytes() != before:
                    raise VerificationFailure(f"{fault}: startup modified protected file")
        print(f"All {len(runner.results)} processes passed. Evidence: {root}")
        if runner.unverified:
            print("Partial acceptance: " + " ".join(runner.unverified))
        return 0
    except (VerificationFailure, OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        return 1
    finally:
        runner.summary()


if __name__ == "__main__":
    raise SystemExit(main())
