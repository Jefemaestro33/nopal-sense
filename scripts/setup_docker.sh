#!/bin/bash
# Nopal-Sense: Docker setup for IIC-OSIC-TOOLS chipathon environment
# Prerequisites: Docker Desktop running
# Usage: ./scripts/setup_docker.sh [vnc|jupyter]

set -e

MODE="${1:-vnc}"
IMAGE="hpretl/iic-osic-tools:chipathon26"
CONTAINER="nopal-chipathon"

echo "=== Nopal-Sense Docker Setup (mode: $MODE) ==="
echo ""

# Check Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon not running. Open Docker Desktop first."
    exit 1
fi
echo "[OK] Docker daemon running"

# Pull image if not present
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "[OK] Image $IMAGE already present"
else
    echo "[..] Pulling $IMAGE (~18 GB, one time)..."
    docker pull "$IMAGE"
    echo "[OK] Image pulled"
fi

# Remove existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[..] Removing existing container..."
    docker rm -f "$CONTAINER" >/dev/null
fi

# Common volume mounts
VOLS="-v $HOME/nopal-sense:/foss/designs/nopal-sense"
VOLS="$VOLS -v $HOME/sscs-chipathon-2026/examples/analog_tutorial:/foss/designs/analog_tutorial"
VOLS="$VOLS -v $HOME/sscs-chipathon-2026/examples/librelane_rtl2gds_gf180:/foss/designs/librelane_rtl2gds_gf180"
VOLS="$VOLS -v $HOME/gLayout:/foss/designs/gLayout"

if [ "$MODE" = "vnc" ]; then
    echo "[..] Starting container in VNC mode (port 80)..."
    docker run -d --name "$CONTAINER" -p 80:80 -p 8888:8888 $VOLS "$IMAGE" --vnc --wait
    echo ""
    echo "=== READY (VNC) ==="
    echo "Browser desktop: http://localhost:80  (password: abc123)"
    echo "Jupyter Lab:     http://localhost:8888"
elif [ "$MODE" = "jupyter" ]; then
    echo "[..] Starting container in Jupyter mode (port 8888)..."
    docker run -d --name "$CONTAINER" -p 8888:8888 $VOLS "$IMAGE" --skip \
        bash -c "jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' --notebook-dir=/foss/designs"
    echo ""
    echo "=== READY (Jupyter) ==="
    echo "Jupyter Lab: http://localhost:8888"
fi

echo ""
echo "Designs dir: /foss/designs/ (inside container)"
echo "Your repo:   /foss/designs/nopal-sense/"
echo ""
echo "To get a shell inside:"
echo "  docker exec -it $CONTAINER bash"
echo ""
echo "To run xschem inverter tutorial (VNC mode):"
echo "  1. Open http://localhost:80 in browser"
echo "  2. Open terminal inside VNC desktop"
echo "  3. cd /foss/designs/analog_tutorial"
echo "  4. xschem inv_tb.sch"
echo ""
echo "To stop:"
echo "  docker stop $CONTAINER"
