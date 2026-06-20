#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_step() { echo -e "\n${BLUE}${BOLD}>>> $1${NC}"; }
log_pass() { echo -e "${GREEN}✅ $1${NC}"; }
log_fail() { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

API_PORT=${API_PORT:-8000}
BASE_URL="http://localhost:${API_PORT}"

check_endpoint() {
  local method=$1
  local path=$2
  local desc=$3

  echo -n "  [$method] $path - "

  local response
  local status_code

  case $method in
    GET)
      status_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$path" 2>/dev/null || echo "000")
      ;;
    POST)
      status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" "$BASE_URL$path" 2>/dev/null || echo "000")
      ;;
    *)
      status_code="000"
      ;;
  esac

  if [ "$status_code" = "000" ]; then
    echo -e "${YELLOW}连接失败 (服务未启动?)${NC}"
    return 1
  elif [ "$status_code" -lt 400 ]; then
    echo -e "${GREEN}$status_code OK${NC} - $desc"
    return 0
  else
    echo -e "${YELLOW}$status_code${NC} - $desc"
    return 0
  fi
}

echo ""
echo "=========================================="
echo "  API 接口契约检查"
echo "=========================================="

log_step "检查后端服务是否启动"
if ! curl -s -o /dev/null -w "" "$BASE_URL/" 2>/dev/null; then
  log_warn "后端服务未在 ${BASE_URL} 启动"
  log_step "尝试临时启动后端服务..."

  cd "$BACKEND_DIR"
  source .venv/bin/activate
  uvicorn app.main:app --host 0.0.0.0 --port "$API_PORT" &
  BACKEND_PID=$!
  sleep 3

  if ! curl -s -o /dev/null "$BASE_URL/" 2>/dev/null; then
    log_fail "后端服务启动失败"
    kill $BACKEND_PID 2>/dev/null
    exit 1
  fi
  log_pass "后端服务已临时启动 (PID: $BACKEND_PID)"
  AUTO_STARTED=true
fi

log_pass "后端服务运行中: $BASE_URL"

log_step "检查 OpenAPI 文档"
if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/openapi.json" 2>/dev/null | grep -q "200"; then
  log_pass "OpenAPI 文档可用: $BASE_URL/docs"
else
  log_warn "OpenAPI 文档未找到"
fi

log_step "检查已注册的 API 端点"

ENDPOINTS=$(curl -s "$BASE_URL/openapi.json" 2>/dev/null | python3 -c "
import sys, json
try:
    spec = json.load(sys.stdin)
    for path, methods in spec.get('paths', {}).items():
        for method in methods.keys():
            desc = methods[method].get('summary', methods[method].get('description', ''))
            print(f'{method.upper()}|{path}|{desc[:50]}')
except:
    pass
" 2>/dev/null)

if [ -z "$ENDPOINTS" ]; then
  log_warn "未从 OpenAPI 获取到端点，使用默认检查列表"
  echo ""
  check_endpoint "GET" "/" "健康检查"
  check_endpoint "GET" "/docs" "Swagger UI"
  check_endpoint "GET" "/openapi.json" "OpenAPI JSON"
else
  echo ""
  while IFS='|' read -r method path desc; do
    [ -z "$method" ] && continue
    check_endpoint "$method" "$path" "$desc"
  done <<< "$ENDPOINTS"
fi

log_step "检查前端 API 调用"
echo "  扫描前端代码中的 API 调用..."

API_CALLS=$(grep -rn "fetch\|axios\|request\|/api/" "$FRONTEND_DIR/src" 2>/dev/null | \
  grep -E "(fetch\(|axios\.|/api/)" | \
  grep -v node_modules | \
  grep -v ".css" | \
  head -20)

if [ -n "$API_CALLS" ]; then
  echo ""
  echo "  检测到的 API 调用:"
  echo "$API_CALLS" | while IFS= read -r line; do
    echo "    $line"
  done
else
  echo "  未检测到 API 调用"
fi

echo ""
echo "=========================================="
log_pass "API 检查完成"

if [ "$AUTO_STARTED" = true ]; then
  echo ""
  log_step "停止临时启动的后端服务"
  kill $BACKEND_PID 2>/dev/null || true
  wait $BACKEND_PID 2>/dev/null || true
  log_pass "后端服务已停止"
fi
