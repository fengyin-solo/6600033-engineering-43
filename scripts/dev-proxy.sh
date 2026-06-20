#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
  local color=$1
  local prefix=$2
  local msg=$3
  echo -e "${color}[${prefix}]${NC} ${msg}"
}

log $YELLOW "INFO" "启动代理联调模式..."
log $YELLOW "INFO" "前端 Vite 会将 /api 请求代理到后端 8000 端口"

if [ ! -f "$FRONTEND_DIR/vite.config.ts" ]; then
  log $YELLOW "WARN" "vite.config.ts 未配置代理，正在配置..."
fi

VITE_CONFIG="$FRONTEND_DIR/vite.config.ts"
if ! grep -q "proxy" "$VITE_CONFIG" 2>/dev/null; then
  log $MAGENTA "CONFIG" "已配置 Vite 代理: /api -> http://localhost:8000"
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

cleanup() {
  echo ""
  log $YELLOW "INFO" "正在停止所有服务..."
  kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
  wait $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
  log $GREEN "INFO" "所有服务已停止"
  exit 0
}
trap cleanup SIGINT SIGTERM

echo ""
log $GREEN "INFO" "=========================================="
log $GREEN "INFO" "  代理联调模式启动成功!"
log $GREEN "INFO" "  前端页面: http://localhost:5173"
log $GREEN "INFO" "  API 代理: /api/* -> http://localhost:8000/*"
log $GREEN "INFO" "=========================================="
echo ""

wait $BACKEND_PID $FRONTEND_PID
