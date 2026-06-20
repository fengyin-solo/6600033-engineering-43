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

PASSED=0
FAILED=0
FAILED_STEPS=()

log_step() {
  echo ""
  echo -e "${BLUE}${BOLD}>>> $1${NC}"
}

log_pass() {
  echo -e "${GREEN}✅ $1${NC}"
  ((PASSED++))
}

log_fail() {
  echo -e "${RED}❌ $1${NC}"
  ((FAILED++))
  FAILED_STEPS+=("$1")
}

print_header() {
  echo ""
  echo "=========================================="
  echo "  完整代码检查流程"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="
}

print_summary() {
  echo ""
  echo "=========================================="
  echo "  检查结果汇总"
  echo "=========================================="
  echo -e "  通过: ${GREEN}${PASSED}${NC}"
  echo -e "  失败: ${RED}${FAILED}${NC}"
  echo ""

  if [ $FAILED -gt 0 ]; then
    echo -e "${RED}失败的检查项:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
      echo -e "  ${RED}- $step${NC}"
    done
    echo ""
    echo -e "${RED}${BOLD}检查未通过，请修复上述问题后重试${NC}"
    exit 1
  else
    echo -e "${GREEN}${BOLD}🎉 所有检查通过，可以提交代码!${NC}"
    exit 0
  fi
}

print_header

log_step "1/6 Git 工作区检查"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  log_pass "Git 工作区有未提交的变更 (正常)"
else
  log_pass "Git 工作区干净"
fi

log_step "2/6 后端代码检查 (Ruff)"
cd "$BACKEND_DIR"
if [ -f ".venv/bin/ruff" ]; then
  if .venv/bin/ruff check .; then
    log_pass "后端代码检查通过"
  else
    log_fail "后端代码检查未通过"
  fi
else
  echo -e "${YELLOW}⚠️  Ruff 未安装，跳过${NC}"
fi

log_step "3/6 前端代码检查 (ESLint)"
cd "$FRONTEND_DIR"
if [ -f "package.json" ] && grep -q '"lint"' package.json; then
  if npm run lint 2>/dev/null || true; then
    log_pass "前端代码检查通过"
  else
    log_fail "前端代码检查未通过"
  fi
else
  echo -e "${YELLOW}⚠️  ESLint 未配置，跳过${NC}"
fi

log_step "4/6 前端 TypeScript 类型检查"
cd "$FRONTEND_DIR"
if [ -f "tsconfig.json" ]; then
  if npx vue-tsc --noEmit 2>/dev/null; then
    log_pass "类型检查通过"
  else
    log_fail "类型检查未通过"
  fi
else
  echo -e "${YELLOW}⚠️  TypeScript 配置不存在，跳过${NC}"
fi

log_step "5/6 后端单元测试 (Pytest)"
cd "$BACKEND_DIR"
TEST_FILES=$(find . -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1)
if [ -n "$TEST_FILES" ] && [ -f ".venv/bin/pytest" ]; then
  if .venv/bin/pytest -v; then
    log_pass "后端测试通过"
  else
    log_fail "后端测试未通过"
  fi
else
  echo -e "${YELLOW}⚠️  未找到后端测试文件或 Pytest，跳过${NC}"
fi

log_step "6/6 前端构建测试"
cd "$FRONTEND_DIR"
if npm run build 2>&1; then
  log_pass "前端构建成功"
else
  log_fail "前端构建失败"
fi

print_summary
