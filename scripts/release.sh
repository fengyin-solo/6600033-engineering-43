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

DRY_RUN=false
SKIP_CHECKS=false
VERSION=""

log_step() { echo -e "\n${BLUE}${BOLD}>>> $1${NC}"; }
log_pass() { echo -e "${GREEN}✅ $1${NC}"; }
log_fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "  ${BOLD}$1${NC}"; }

usage() {
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  --dry-run       预演发布流程，不实际执行"
  echo "  --skip-checks   跳过代码检查步骤"
  echo "  --version <ver> 指定版本号 (如: 1.2.0)"
  echo "  -h, --help      显示帮助信息"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --skip-checks) SKIP_CHECKS=true; shift ;;
    --version) VERSION="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}${BOLD}  ⚠️  DRY RUN 模式 - 不会实际执行发布操作${NC}"
fi

echo ""
echo "=========================================="
echo "  发布流程"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

if [ -n "$VERSION" ]; then
  log_info "目标版本: v$VERSION"
fi

if [ "$SKIP_CHECKS" = false ]; then
  log_step "1/6 运行完整代码检查"
  if [ "$DRY_RUN" = true ]; then
    log_warn "[DRY RUN] 跳过代码检查执行"
  else
    if ! bash "$ROOT_DIR/scripts/check-all.sh"; then
      log_fail "代码检查未通过，发布中止"
    fi
  fi
else
  log_warn "已跳过代码检查步骤 (--skip-checks)"
fi

log_step "2/6 检查 Git 状态"
cd "$ROOT_DIR"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo ""
  git status --short
  echo ""
  log_fail "Git 工作区有未提交的变更，请先提交或 stash"
fi
log_pass "Git 工作区干净"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
log_info "当前分支: $CURRENT_BRANCH"

if [ -n "$VERSION" ]; then
  log_step "3/6 更新版本号"
  if [ "$DRY_RUN" = true ]; then
    log_warn "[DRY RUN] 将更新版本号为 v$VERSION"
  else
    if [ -f "$FRONTEND_DIR/package.json" ]; then
      cd "$FRONTEND_DIR"
      npm version "$VERSION" --no-git-tag-version
      log_pass "前端 package.json 版本已更新为 v$VERSION"
    fi
    cd "$ROOT_DIR"
  fi
fi

log_step "4/6 构建生产包"
if [ "$DRY_RUN" = true ]; then
  log_warn "[DRY RUN] 将执行前端构建"
else
  cd "$FRONTEND_DIR"
  if npm run build; then
    log_pass "前端构建成功"
    BUILD_SIZE=$(du -sh dist 2>/dev/null | cut -f1)
    log_info "构建产物大小: $BUILD_SIZE"
  else
    log_fail "前端构建失败"
  fi
fi

log_step "5/6 创建 Git 标签"
if [ -n "$VERSION" ]; then
  TAG_NAME="v$VERSION"
  if [ "$DRY_RUN" = true ]; then
    log_warn "[DRY RUN] 将创建 Git 标签: $TAG_NAME"
  else
    cd "$ROOT_DIR"
    if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
      log_fail "Git 标签 $TAG_NAME 已存在"
    fi
    git add -A
    git commit -m "release: $TAG_NAME" --allow-empty
    git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
    log_pass "Git 标签已创建: $TAG_NAME"
  fi
else
  log_warn "未指定版本号，跳过 Git 标签创建 (使用 --version <ver> 指定)"
fi

log_step "6/6 推送远程仓库"
if [ "$DRY_RUN" = true ]; then
  log_warn "[DRY RUN] 将推送代码和标签到远程仓库"
else
  if git remote get-url origin >/dev/null 2>&1; then
    cd "$ROOT_DIR"
    echo ""
    read -p "是否推送到远程仓库? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git push origin "$CURRENT_BRANCH"
      if [ -n "$TAG_NAME" ]; then
        git push origin "$TAG_NAME"
      fi
      log_pass "已推送到远程仓库"
    else
      log_warn "已跳过远程推送，可手动执行:"
      log_info "  git push origin $CURRENT_BRANCH"
      if [ -n "$TAG_NAME" ]; then
        log_info "  git push origin $TAG_NAME"
      fi
    fi
  else
    log_warn "未配置远程仓库，跳过推送"
  fi
fi

echo ""
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}${BOLD}  🎉 发布流程预演完成!${NC}"
  echo -e "${YELLOW}  确认无误后，移除 --dry-run 参数执行正式发布${NC}"
else
  echo -e "${GREEN}${BOLD}  🎉 发布流程完成!${NC}"
  if [ -n "$VERSION" ]; then
    echo -e "${GREEN}  版本: v${VERSION}${NC}"
  fi
fi
echo "=========================================="
echo ""
