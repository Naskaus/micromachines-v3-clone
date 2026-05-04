"""
Micromachines V3 — Multiplayer WebSocket server.

v0.19.0 (Phase 3): server is now AUTHORITATIVE BOOKKEEPER.
- Each room tracks per-player state (pos, yaw, speed, path_phase, laps,
  next_arch_index, lives, eliminated, finished, role).
- Server computes ranking + leader_id from the trusted phase data and
  broadcasts a `race_state` message at 5Hz to all clients.
- Bots are registered by the host with negative player_ids (-1, -2, …).
  The server forwards their state to peers exactly like a human.
- Lobby option: elimination_mode = "lives3" (default) or "perma".
  Set by host before race start; server includes it in race_state.

v0.18.x kept relay forwarding (state, start, ping). We keep that path so
clients that haven't been upgraded continue working — but adds the
authoritative race_state on top.

Protocol (JSON over WebSocket):
  Client → Server:
    {"type": "create"}
    {"type": "join",    "code": "1234"}
    {"type": "reclaim", "code": "1234"}
    {"type": "set_options", "elimination_mode": "lives3" | "perma"}   (host only)
    {"type": "register_bot", "bot_id": -1, "color": [r,g,b]}           (host only)
    {"type": "state", "x":…, "y":…, "z":…, "yaw":…, "v":…,
                      "phase":…, "laps":…, "next_arch":…,
                      "for_bot": -1 (optional, host echoing a bot)}
    {"type": "elim_event", "for": <player_id>, "reason": "off_screen"} (host only)
    {"type": "start"}                                                  (host only)
    {"type": "leave"}

  Server → Client:
    {"type": "joined", "code": "1234", "is_host": true,
                       "player_id": 123, "peers": [...],
                       "elimination_mode": "lives3"}
    {"type": "player_joined", "player_id": 456, "role": "human"|"bot"}
    {"type": "player_left",   "player_id": 456}
    {"type": "options_changed", "elimination_mode": "perma"}
    {"type": "state", "player_id": 456, "x":…, ...}    (relay, unchanged)
    {"type": "race_state",
        "leader_id": 123,
        "rankings":   [{"id": 123, "laps": 2, "next_arch": 1, "phase": 0.42}, ...],
        "eliminated": [...],
        "lives":      {123: 3, 456: 2, ...},
        "finished":   [...],
        "elimination_mode": "lives3"
    }
    {"type": "start"}
    {"type": "error", "msg": "..."}

Run: python3 mv3_server.py
Port: 8060
"""

import asyncio
import json
import logging
import random
import string
import time
from typing import Optional

import websockets
from websockets.server import WebSocketServerProtocol

PORT = 8060
ROOM_CODE_LEN = 4
MAX_PLAYERS_PER_ROOM = 6
ROOM_TTL_SECONDS = 3600
ROOM_GRACE_SECONDS = 300
RACE_STATE_BROADCAST_HZ = 5.0
RACE_STATE_INTERVAL = 1.0 / RACE_STATE_BROADCAST_HZ

DEFAULT_LIVES = 3

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("mv3-server")

# room_code → room dict (see _new_room)
rooms: dict[str, dict] = {}

_next_player_id = 1


def _new_room() -> dict:
    return {
        "clients": {},                    # ws → player_id (humans only)
        "host": None,                     # ws of current host
        "host_player_id": None,
        "created_at": time.time(),
        "abandoned_at": None,
        # Phase 3 authoritative state
        "elimination_mode": "lives3",     # "lives3" | "perma"
        "default_lives": DEFAULT_LIVES,
        "race_started": False,
        "players": {},                    # player_id (incl. bots <0) → state dict
        "bot_ids": [],                    # negative ids registered by host
        "bot_colors": {},                 # bot_id → [r,g,b]
    }


def _new_player_state(role: str, lives: int) -> dict:
    return {
        "role": role,                     # "human" | "bot"
        "x": 0.0, "y": 0.5, "z": 0.0,
        "yaw": 0.0, "v": 0.0,
        "phase": 0.0,
        "laps": 0,
        "next_arch": 0,
        "lives": lives,
        "eliminated": False,
        "finished": False,
        "last_update": 0.0,
    }


def _gen_code() -> str:
    while True:
        code = "".join(random.choices(string.digits, k=ROOM_CODE_LEN))
        if code not in rooms:
            return code


def _next_id() -> int:
    global _next_player_id
    pid = _next_player_id
    _next_player_id += 1
    return pid


async def _send(ws: WebSocketServerProtocol, msg: dict) -> None:
    try:
        await ws.send(json.dumps(msg))
    except websockets.ConnectionClosed:
        pass


async def _broadcast(room_code: str, msg: dict, exclude: Optional[WebSocketServerProtocol] = None) -> None:
    if room_code not in rooms:
        return
    payload = json.dumps(msg)
    dead = []
    for ws in list(rooms[room_code]["clients"].keys()):
        if ws is exclude:
            continue
        try:
            await ws.send(payload)
        except websockets.ConnectionClosed:
            dead.append(ws)
    for ws in dead:
        rooms[room_code]["clients"].pop(ws, None)


def _compute_rankings(room: dict) -> list[dict]:
    """Sort known players by progress = laps + next_arch/N + phase*0.001."""
    arch_count = 6  # matches Godot ARCH_COLOR_NAMES.size()
    out = []
    for pid, st in room["players"].items():
        if st.get("finished"):
            progress = st["laps"] + (st["next_arch"] / arch_count) + st["phase"] * 0.001 + 100.0
        else:
            progress = st["laps"] + (st["next_arch"] / arch_count) + st["phase"] * 0.001
        out.append({
            "id": pid,
            "laps": st["laps"],
            "next_arch": st["next_arch"],
            "phase": round(st["phase"], 4),
            "progress": progress,
            "eliminated": st.get("eliminated", False),
            "finished": st.get("finished", False),
        })
    out.sort(key=lambda r: r["progress"], reverse=True)
    return out


def _pick_leader(rankings: list[dict]) -> Optional[int]:
    for r in rankings:
        if not r["eliminated"] and not r["finished"]:
            return r["id"]
    if rankings:
        return rankings[0]["id"]
    return None


async def _broadcast_race_state(room_code: str) -> None:
    if room_code not in rooms:
        return
    room = rooms[room_code]
    if not room["race_started"]:
        return
    rankings = _compute_rankings(room)
    leader_id = _pick_leader(rankings)
    eliminated = [r["id"] for r in rankings if r["eliminated"]]
    finished = [r["id"] for r in rankings if r["finished"]]
    lives = {pid: st["lives"] for pid, st in room["players"].items()}
    msg = {
        "type": "race_state",
        "leader_id": leader_id,
        "rankings": rankings,
        "eliminated": eliminated,
        "finished": finished,
        "lives": lives,
        "elimination_mode": room["elimination_mode"],
        "ts": round(time.time(), 3),
    }
    await _broadcast(room_code, msg)


async def handle(ws: WebSocketServerProtocol) -> None:
    player_id = _next_id()
    current_room: Optional[str] = None
    log.info(f"player {player_id} connected (peer={ws.remote_address})")

    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await _send(ws, {"type": "error", "msg": "Invalid JSON"})
                continue
            mtype = msg.get("type")

            if mtype == "create":
                code = _gen_code()
                room = _new_room()
                room["clients"][ws] = player_id
                room["host"] = ws
                room["host_player_id"] = player_id
                room["players"][player_id] = _new_player_state("human", room["default_lives"])
                rooms[code] = room
                current_room = code
                await _send(ws, {
                    "type": "joined",
                    "code": code,
                    "is_host": True,
                    "player_id": player_id,
                    "peers": [],
                    "elimination_mode": room["elimination_mode"],
                })
                log.info(f"player {player_id} created room {code}")

            elif mtype == "reclaim":
                code = str(msg.get("code", "")).strip()
                if code not in rooms:
                    await _send(ws, {"type": "error", "msg": f"Salle {code} introuvable"})
                    continue
                room = rooms[code]
                if len(room["clients"]) >= MAX_PLAYERS_PER_ROOM:
                    await _send(ws, {"type": "error", "msg": f"Salle {code} pleine"})
                    continue
                peers = list(room["clients"].values())
                room["clients"][ws] = player_id
                room["abandoned_at"] = None
                if room.get("host") is None:
                    room["host"] = ws
                    room["host_player_id"] = player_id
                if player_id not in room["players"]:
                    room["players"][player_id] = _new_player_state("human", room["default_lives"])
                is_host = room["host"] is ws
                current_room = code
                await _send(ws, {
                    "type": "joined",
                    "code": code,
                    "is_host": is_host,
                    "player_id": player_id,
                    "peers": peers,
                    "elimination_mode": room["elimination_mode"],
                })
                if peers:
                    await _broadcast(code, {"type": "player_joined", "player_id": player_id, "role": "human"}, exclude=ws)
                log.info(f"player {player_id} reclaimed room {code} (is_host={is_host})")

            elif mtype == "join":
                code = str(msg.get("code", "")).strip()
                if code not in rooms:
                    await _send(ws, {"type": "error", "msg": f"Room {code} not found"})
                    continue
                room = rooms[code]
                if len(room["clients"]) >= MAX_PLAYERS_PER_ROOM:
                    await _send(ws, {"type": "error", "msg": f"Room {code} is full"})
                    continue
                peers = list(room["clients"].values())
                room["clients"][ws] = player_id
                room["players"][player_id] = _new_player_state("human", room["default_lives"])
                current_room = code
                await _send(ws, {
                    "type": "joined",
                    "code": code,
                    "is_host": False,
                    "player_id": player_id,
                    "peers": peers,
                    "elimination_mode": room["elimination_mode"],
                })
                # Tell the new joiner about already-registered bots so they can
                # spawn ghost cars for them as soon as state messages flow.
                for bid in room["bot_ids"]:
                    await _send(ws, {"type": "player_joined", "player_id": bid, "role": "bot"})
                await _broadcast(code, {"type": "player_joined", "player_id": player_id, "role": "human"}, exclude=ws)
                log.info(f"player {player_id} joined room {code} ({len(room['clients'])} humans, {len(room['bot_ids'])} bots)")

            elif mtype == "set_options":
                # Host-only — toggle elimination mode (and any future room option).
                if current_room and current_room in rooms:
                    room = rooms[current_room]
                    if room.get("host") is ws:
                        mode = str(msg.get("elimination_mode", room["elimination_mode"]))
                        if mode not in ("lives3", "perma"):
                            mode = "lives3"
                        room["elimination_mode"] = mode
                        room["default_lives"] = DEFAULT_LIVES if mode == "lives3" else 1
                        # Update existing players' lives so the toggle is retroactive
                        # for anyone who joined the lobby before the host chose.
                        for pid, st in room["players"].items():
                            if not st.get("finished") and not st.get("eliminated"):
                                st["lives"] = room["default_lives"]
                        await _broadcast(current_room, {"type": "options_changed", "elimination_mode": mode})
                        log.info(f"room {current_room} elimination_mode={mode}")

            elif mtype == "register_bot":
                # Host-only — register a synthetic bot peer with negative id.
                if current_room and current_room in rooms:
                    room = rooms[current_room]
                    if room.get("host") is ws:
                        bid = int(msg.get("bot_id", 0))
                        if bid < 0 and bid not in room["bot_ids"]:
                            room["bot_ids"].append(bid)
                            color = msg.get("color", [0.6, 0.6, 0.6])
                            room["bot_colors"][bid] = color
                            room["players"][bid] = _new_player_state("bot", room["default_lives"])
                            await _broadcast(current_room, {"type": "player_joined", "player_id": bid, "role": "bot"})
                            log.info(f"room {current_room}: bot {bid} registered")

            elif mtype == "state":
                # State for either the local human OR a host-controlled bot
                # (host echoes bot state with for_bot=<negative id>).
                if current_room and current_room in rooms:
                    room = rooms[current_room]
                    target_id: int
                    if "for_bot" in msg and room.get("host") is ws:
                        target_id = int(msg.get("for_bot", 0))
                    else:
                        target_id = player_id
                    if target_id in room["players"]:
                        st = room["players"][target_id]
                        st["x"] = float(msg.get("x", st["x"]))
                        st["y"] = float(msg.get("y", st["y"]))
                        st["z"] = float(msg.get("z", st["z"]))
                        st["yaw"] = float(msg.get("yaw", st["yaw"]))
                        st["v"] = float(msg.get("v", st["v"]))
                        if "phase" in msg:
                            st["phase"] = float(msg["phase"])
                        if "laps" in msg:
                            new_laps = int(msg["laps"])
                            # Anti-cheat: laps can only ever go up by 1 per update
                            if new_laps >= st["laps"] and new_laps - st["laps"] <= 1:
                                st["laps"] = new_laps
                        if "next_arch" in msg:
                            st["next_arch"] = int(msg["next_arch"])
                        if "finished" in msg:
                            st["finished"] = bool(msg["finished"])
                        st["last_update"] = time.time()
                    # Forward to peers, tagging the player_id for everyone
                    out = dict(msg)
                    out["player_id"] = target_id
                    await _broadcast(current_room, out, exclude=ws)

            elif mtype == "elim_event":
                # Host signals an elimination decision (lost a life or perma).
                if current_room and current_room in rooms:
                    room = rooms[current_room]
                    if room.get("host") is ws:
                        target_id = int(msg.get("for", 0))
                        reason = str(msg.get("reason", "off_screen"))
                        if target_id in room["players"]:
                            st = room["players"][target_id]
                            if room["elimination_mode"] == "perma":
                                st["eliminated"] = True
                                st["lives"] = 0
                            else:
                                st["lives"] = max(0, st["lives"] - 1)
                                if st["lives"] <= 0:
                                    st["eliminated"] = True
                            await _broadcast(current_room, {
                                "type": "elim_event",
                                "for": target_id,
                                "reason": reason,
                                "lives": st["lives"],
                                "eliminated": st["eliminated"],
                            })

            elif mtype == "start":
                if current_room and current_room in rooms:
                    room = rooms[current_room]
                    if room.get("host") is ws:
                        room["race_started"] = True
                        # Reset all players' race-state so a re-race from the
                        # same room starts clean.
                        for pid, st in room["players"].items():
                            st["laps"] = 0
                            st["next_arch"] = 0
                            st["lives"] = room["default_lives"]
                            st["eliminated"] = False
                            st["finished"] = False
                        await _broadcast(current_room, {"type": "start"})
                        log.info(f"room {current_room} race started ({len(room['players'])} racers)")

            elif mtype == "ping":
                if current_room and current_room in rooms:
                    msg["player_id"] = player_id
                    await _broadcast(current_room, msg, exclude=ws)

            elif mtype == "leave":
                break

            else:
                await _send(ws, {"type": "error", "msg": f"Unknown type: {mtype}"})
    except websockets.ConnectionClosed:
        pass
    except Exception as e:
        log.exception(f"player {player_id} handler error: {e}")
    finally:
        if current_room and current_room in rooms:
            room = rooms[current_room]
            room["clients"].pop(ws, None)
            # Drop the player's state after a leave so rankings don't include ghosts.
            room["players"].pop(player_id, None)
            if not room["clients"]:
                room["abandoned_at"] = time.time()
                room["host"] = None
                # When everyone's gone, the bot state is also stale.
                for bid in room["bot_ids"]:
                    room["players"].pop(bid, None)
                room["bot_ids"] = []
                room["bot_colors"] = {}
                room["race_started"] = False
                log.info(f"room {current_room} abandoned (kept {ROOM_GRACE_SECONDS}s for reclaim)")
            else:
                if room.get("host") is ws:
                    room["host"] = None
                    # Host left mid-race → drop all bot peers since nobody will
                    # be feeding their state. New host can re-register on reclaim.
                    for bid in room["bot_ids"]:
                        room["players"].pop(bid, None)
                    room["bot_ids"] = []
                    room["bot_colors"] = {}
                await _broadcast(current_room, {"type": "player_left", "player_id": player_id})
        log.info(f"player {player_id} disconnected")


async def _purge_empty_rooms() -> None:
    while True:
        await asyncio.sleep(60)
        now = time.time()
        stale = []
        for code, r in rooms.items():
            abandoned_at = r.get("abandoned_at")
            if abandoned_at is not None and (now - abandoned_at) > ROOM_GRACE_SECONDS:
                stale.append(code)
                continue
            if (now - r.get("created_at", now)) > ROOM_TTL_SECONDS:
                stale.append(code)
        for code in stale:
            rooms.pop(code, None)
        if stale:
            log.info(f"purged {len(stale)} stale rooms")


async def _race_state_pump() -> None:
    while True:
        await asyncio.sleep(RACE_STATE_INTERVAL)
        for code in list(rooms.keys()):
            try:
                await _broadcast_race_state(code)
            except Exception as e:
                log.warning(f"race_state pump error for {code}: {e}")


async def main() -> None:
    log.info(f"MV3 multiplayer server v0.19.0 (authoritative bookkeeper) starting on 0.0.0.0:{PORT}")
    asyncio.create_task(_purge_empty_rooms())
    asyncio.create_task(_race_state_pump())
    async with websockets.serve(handle, "0.0.0.0", PORT, ping_interval=20, ping_timeout=10):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("shutting down")
