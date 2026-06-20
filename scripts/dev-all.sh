#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() {
  local color=$1
  local prefix=$2
  local msg=$3
  echo -e "${color}[${prefix}]${NC} ${msg}"
}

cleanup() {
  echo ""
  log $YELLOW "INFO" "正在停止所有服务..."
  if [ -n "$BACKEND_PID" ] && kill -0 $BACKEND_PID 2>/dev/null; then
    kill $BACKEND_PID 2>/dev/null || true
  fi
  if [ -n "$FRONTEND_PID" ] && kill -0 $FRONTEND_PID 2>/dev/null; then
    kill $FRONTEND_PID 2>/dev/null || true
  fi
  wait $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
  log $GREEN "INFO" "所有服务已停止"
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

log $YELLOW "INFO" "检查依赖..."
if [ ! -d "$BACKEND_DIR/.venv" ]; then
  log $YELLOW "WARN" "后端虚拟环境不存在，正在创建..."
  cd "$BACKEND_DIR" && python3 -m venv .venv
fi

if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
  log $YELLOW "WARN" "前端依赖不存在，正在安装..."
  cd "$FRONTEND_DIR" && npm install
fi

log $MAGENTA "BACKEND" "启动后端服务 (端口 8000)..."
cd "$BACKEND_DIR"
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

sleep 2

log $CYAN "FRONTEND" "启动前端服务 (端口 5173)..."
cd "$FRONTEND_DIR"
npm run dev &
FRONTEND_PID=$!

echo ""
log $GREEN "INFO" "=========================================="
log $GREEN "INFO" "  开发环境启动成功!"
log $GREEN "INFO" "  后端 API: http://localhost:8000"
log $GREEN "INFO" "  前端页面: http://localhost:5173"
log $GREEN "INFO" "  API 文档: http://localhost:8000/docs"
log $GREEN "INFO" "=========================================="
log $YELLOW "INFO" "  按 Ctrl+C 停止所有服务"
echo ""

wait $BACKEND_PID $FRONTEND_PID
