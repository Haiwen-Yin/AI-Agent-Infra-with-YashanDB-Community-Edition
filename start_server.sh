#!/bin/bash
export LD_LIBRARY_PATH="$HOME/.yashandb/client/lib:$LD_LIBRARY_PATH"
cd /root/AI-Agent-Infra-with-YashanDB-Community-Edition
while true; do
    python3.14 -B scripts/visualization/server.py
    echo "[restart] Server crashed, restarting in 2s..."
    sleep 2
done
