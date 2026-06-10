#!/usr/bin/env python3
"""
Docker Desktop on macOS: containers on a user-defined bridge often cannot open TCP
to other LAN hosts (e.g. 192.168.1.223:3310) while host.docker.internal works.

Run this script ON THE APP TIER Mac (same machine as Docker), before/while the app
stack is up. It listens on RELAY_LOCAL_BASE..RELAY_LOCAL_BASE+RELAY_COUNT-1 and
forwards each socket byte-stream to RELAY_UPSTREAM_HOST at ports RELAY_REMOTE_BASE+offset.

Default: local 13310..13319 -> upstream 3310..3319 (matches split-deploy MySQL ports).

  RELAY_UPSTREAM_HOST=192.168.1.223 RELAY_LOCAL_BASE=13310 python3 scripts/mysql_tcp_relays_mac_app_host.py

Stop with Ctrl+C. For background: nohup ... > /tmp/mysql_tcp_relays.log 2>&1 &
"""
from __future__ import annotations

import os
import select
import socket
import threading


def relay_pair(client: socket.socket, remote_host: str, remote_port: int) -> None:
    try:
        upstream = socket.create_connection((remote_host, remote_port), timeout=15)
    except OSError:
        client.close()
        return
    try:
        upstream.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        client.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except OSError:
        pass
    pair = (client, upstream)
    for s in pair:
        s.setblocking(True)
    try:
        # MySQL sends the server handshake first. Prefer upstream in the read loop so a
        # spurious empty read on the client side does not tear down the session.
        first = upstream.recv(65536)
        if not first:
            return
        client.sendall(first)
        while True:
            r, _, x = select.select(pair, [], [], 3600)
            if x:
                break
            if not r:
                continue
            for s in sorted(r, key=lambda sk: 0 if sk is upstream else 1):
                data = s.recv(65536)
                if not data:
                    return
                dest = upstream if s is client else client
                dest.sendall(data)
    except OSError:
        pass
    finally:
        for s in pair:
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                s.close()
            except OSError:
                pass


def main() -> None:
    remote_host = os.environ.get("RELAY_UPSTREAM_HOST", "192.168.1.223")
    local_base = int(os.environ.get("RELAY_LOCAL_BASE", "13310"))
    remote_base = int(os.environ.get("RELAY_REMOTE_BASE", "3310"))
    count = int(os.environ.get("RELAY_COUNT", "10"))
    bind_addr = os.environ.get("RELAY_BIND", "0.0.0.0")

    listeners: list[socket.socket] = []
    for i in range(count):
        lp = local_base + i
        rp = remote_base + i
        ls = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        ls.bind((bind_addr, lp))
        ls.listen(128)
        listeners.append(ls)
        print(f"relay listen {bind_addr}:{lp} -> {remote_host}:{rp}", flush=True)

    def accept_loop(ls: socket.socket, rport: int) -> None:
        while True:
            client, _ = ls.accept()
            threading.Thread(
                target=relay_pair, args=(client, remote_host, rport), daemon=True
            ).start()

    threads = []
    for i, ls in enumerate(listeners):
        rport = remote_base + i
        th = threading.Thread(target=accept_loop, args=(ls, rport), daemon=True)
        th.start()
        threads.append(th)
    for th in threads:
        th.join()


if __name__ == "__main__":
    main()
