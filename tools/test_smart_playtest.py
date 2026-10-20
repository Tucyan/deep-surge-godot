"""Policy behavior using only public observations/actions; no game state access."""
import unittest
from smart_playtest import SmartPlayer
from generate_regression_routes import metric_step, prefix_hash


def observation(phase="battle"):
    return {"phase": phase, "ap": 3, "voyage": 1, "hand": [], "cells": [],
            "player": {"hp": 12, "hp_max": 16, "hunger": 80, "hunger_max": 100,
                       "hydration": 80, "hydration_max": 100, "sanity": 90, "sanity_max": 100,
                       "limit": 10, "damage": 0},
            "battle": {"hp": 1, "ap": 1, "enemy_direct_damage": 4},
            "enemy": {"hp": 99, "damage": 1}}


def action(command, **args):
    return {"command": command, "args": args, "effective": True}


class PublicPolicyTests(unittest.TestCase):
    def choose(self, obs, actions):
        return SmartPlayer(False).choose_action(obs, actions)

    def test_lethal_uses_remaining_enemy_hp(self):
        obs = observation()
        attack = action("battle_action", action="attack")
        self.assertEqual(self.choose(obs, [action("battle_action", action="block"), attack]), attack)

    def test_one_damage_not_false_two_damage_lethal(self):
        obs = observation()
        obs["battle"]["hp"] = 2
        block = action("battle_action", action="block")
        self.assertEqual(self.choose(obs, [action("battle_action", action="attack"), block]), block)

    def test_player_damage_enables_lethal(self):
        obs = observation()
        obs["player"]["damage"] = 2
        obs["battle"]["hp"] = 3
        attack = action("battle_action", action="attack")
        self.assertEqual(self.choose(obs, [action("battle_action", action="block"), attack]), attack)

    def test_enemy_direct_damage_prioritizes_rope(self):
        obs = observation()
        obs["battle"]["hp"] = 20
        obs["hand"] = [{"uid": "r", "id": "rope"}]
        block = action("battle_action", action="block", resource_uid="r")
        self.assertEqual(self.choose(obs, [action("battle_action", action="attack"), block]), block)

    def test_public_combination_enables_iron_lethal(self):
        obs = observation()
        obs["battle"]["hp"] = 2
        obs["hand"] = [{"uid": "i", "id": "iron"}]
        obs["battle_combinations"] = {"iron": {"attack": {"damage": 1}}}
        attack = action("battle_action", action="attack", resource_uid="i")
        self.assertEqual(self.choose(obs, [action("battle_action", action="block"), attack]), attack)

    def test_shop_object_stock_buys_missing_production(self):
        obs = observation("interaction")
        obs["shop"] = {"stock": [{"id": "filter"}]}
        buy = action("buy", id="filter", payment="coin")
        self.assertEqual(self.choose(obs, [action("shop_leave"), buy]), buy)

    def test_shop_no_duplicate_hand_device(self):
        obs = observation("interaction")
        obs["hand"] = [{"uid": "f", "id": "filter"}]
        obs["shop"] = {"stock": [{"id": "filter"}]}
        leave = action("shop_leave")
        self.assertEqual(self.choose(obs, [leave, action("buy", id="filter", payment="coin")]), leave)

    def test_shop_collectible_purchase(self):
        obs = observation("interaction")
        buy = action("buy_collectible", id="salt")
        self.assertEqual(self.choose(obs, [action("shop_leave"), buy]), buy)

    def test_metrics_public_events(self):
        obs = observation()
        obs["node"] = {"boss": True}
        metrics = {}
        metric_step(metrics, obs, obs, [{"kind": "battle_enter"}, {"kind": "attribute", "source": "deprivation", "delta": -3}])
        self.assertEqual(metrics["battles"], 1)
        self.assertEqual(metrics["deprivation_damage"], 3)
        self.assertEqual(metrics["boss_entry_hp"], [{"voyage": 1, "hp": 12}])
        self.assertEqual(prefix_hash({"a": 1, "b": 2}), prefix_hash({"b": 2, "a": 1}))

    def test_pending_weather_starts_episode_only_when_active(self):
        obs = observation()
        obs["environments"] = [{"id": "storm", "pending": True}]
        metrics = {}
        metric_step(metrics, obs, obs, [])
        self.assertEqual(metrics["weather_episodes"], 0)
        self.assertEqual(metrics["weather_voyages"], {"1": []})
        obs["environments"][0]["pending"] = False
        metric_step(metrics, obs, obs, [])
        self.assertEqual(metrics["weather_episodes"], 1)
        self.assertEqual(metrics["weather_voyages"], {"1": ["storm"]})


if __name__ == "__main__":
    unittest.main()
