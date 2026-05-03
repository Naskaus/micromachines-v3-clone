"""
Micromachines V3 — Multiplayer WebSocket relay server.

Phase 1: pure relay (no authoritative physics). Each client sends its own state,
server forwards to all other clients in the same room.

Protocol (JSON messages over WebSocket):
  Client → Server:
    {"type": "create"}                   # Create new room, become host
    {"type": "join", "code": "ABCD"}     # Join existing room
    {"type": "state", "x": ..., ...}     # Forward this state to other clients
    {"type": "start"}                    # Host triggers race start
    {"type": "leave"}                    # Disconnect

  Server → Client:
    {"type": "joined", "code": "ABCD", "is_host": true, "player_id": 123, "peers": [456, 789]}
    {"type": "player_joined", "player_id": 456}
    {"type": "player_left", "player_id": 456}
    {"type": "state", "player_id": 456, "x": ..., ...}   # forwarded from peer
    {"type": "start"}                                     # broadcast to all
    {"type": "error", "msg": "Room not found"}

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
ROOM_TTL_SECONDS = 3600  # auto-purge empty rooms after 1h

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("mv3-server")

# room_code → {"clients": dict[websocket → player_id], "host": websocket, "created_at": float}
rooms: dict[str, dict] = {}

# Monotonic player ID counter
_next_player_id = 1


def _gen_code() -> str:
    """Generate a 4-digit room PIN that's not currently in use."""
    # v0.18.0: switched from A-Z to 0-9 so mobile clients can request the
    # numeric keypad (LineEdit.virtual_keyboard_type = NUMBER).
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
                rooms[code] = {
                    "clients": {ws: player_id},
                    "host": ws,
                    "created_at": time.time(),
                }
                current_room = code
                await _send(ws, {
                    "type": "joined",
                    "code": code,
                    "is_host": True,
                    "player_id": player_id,
                    "peers": [],
                })
                log.info(f"player {player_id} created room {code}")

            elif mtype == "join":
                code = str(msg.get("code", "")).strip()
                if code not in rooms:
                    await _send(ws, {"type": "error", "msg": f"Room {code} not found"})
                    continue
                if len(rooms[code]["clients"]) >= MAX_PLAYERS_PER_ROOM:
                    await _send(ws, {"type": "error", "msg": f"Room {code} is full"})
                    continue
                peers = list(rooms[code]["clients"].values())
                rooms[code]["clients"][ws] = player_id
                current_room = code
                await _send(ws, {
                    "type": "joined",
                    "code": code,
                    "is_host": False,
                    "player_id": player_id,
                    "peers": peers,
                })
                await _broadcast(code, {"type": "player_joined", "player_id": player_id}, exclude=ws)
                log.info(f"player {player_id} joined room {code} ({len(rooms[code]['clients'])} players)")

            elif mtype in ("state", "start", "ping"):
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
            rooms[current_room]["clients"].pop(ws, None)
            if not rooms[current_room]["clients"]:
                del rooms[current_room]
                log.info(f"room {current_room} closed (empty)")
            else:
                # If host left, promote next player
                if rooms[current_room].get("host") is ws:
                    new_host = next(iter(rooms[current_room]["clients"].keys()))
                    rooms[current_room]["host"] = new_host
                await _broadcast(current_room, {"type": "player_left", "player_id": player_id})
        log.info(f"player {player_id} disconnected")


async def _purge_empty_rooms() -> None:
    while True:
        await asyncio.sleep(300)  # every 5 min
        now = time.time()
        stale = [code for code, r in rooms.items()
                 if not r["clients"] and (now - r.get("created_at", now) > ROOM_TTL_SECONDS)]
        for code in stale:
            rooms.pop(code, None)
        if stale:
            log.info(f"purged {len(stale)} stale rooms")


async def main() -> None:
    log.info(f"MV3 multiplayer server starting on 0.0.0.0:{PORT}")
    asyncio.create_task(_purge_empty_rooms())
    async with websockets.serve(handle, "0.0.0.0", PORT, ping_interval=20, ping_timeout=10):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("shutting down")
