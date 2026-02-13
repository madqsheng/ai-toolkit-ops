#!/bin/bash
# ============================================================================
# AI Toolkit Ops - 公共函数库
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# 项目根目录（基于 common.sh 的位置反推）
OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$OPS_DIR/.." && pwd)"

# Docker 配置
DOCKER_IMAGE_NAME="ai-toolkit-ops"
DOCKER_IMAGE_TAG="latest"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
DOCKER_SERVICE_NAME="ai-toolkit"

# 上游仓库
UPSTREAM_URL="https://github.com/ostris/ai-toolkit.git"
UPSTREAM_REMOTE_NAME="upstream"

# ============================================================================
# 输出函数
# ============================================================================

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

title() {
    echo ""
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${DIM}$(printf '─%.0s' $(seq 1 50))${NC}"
}

# ============================================================================
# 菜单框架
# ============================================================================

# 显示菜单头部
menu_header() {
    local title="$1"
    clear
    echo ""
    echo -e "  ${BOLD}${MAGENTA}╔══════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}${MAGENTA}║${NC}  ${BOLD}$title${NC}"
    echo -e "  ${BOLD}${MAGENTA}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示菜单项
menu_item() {
    local num="$1"
    local icon="$2"
    local text="$3"
    echo -e "    ${BOLD}${CYAN}$num${NC})  $icon  $text"
}

# 显示菜单底部分隔线和返回选项
menu_footer() {
    echo ""
    echo -e "    ${BOLD}${DIM}0${NC})  ${DIM}↩  返回上级${NC}"
    echo ""
    echo -e "  ${DIM}──────────────────────────────────────────${NC}"
}

# 读取用户选择
menu_choice() {
    echo ""
    echo -ne "  ${BOLD}请选择 [0-9]: ${NC}"
    read -r choice
    echo "$choice"
}

# 按回车继续
press_enter() {
    echo ""
    echo -ne "  ${DIM}按 Enter 继续...${NC}"
    read -r
}

# 确认操作
confirm() {
    local msg="$1"
    echo -ne "  ${YELLOW}$msg [y/N]: ${NC}"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ============================================================================
# 工具函数
# ============================================================================

# 确保在项目根目录执行
ensure_project_root() {
    if [ ! -f "$PROJECT_ROOT/run.py" ]; then
        error "无法定位项目根目录，请确保脚本位置正确"
        exit 1
    fi
}

# 检查命令是否存在
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        error "需要 $cmd 但未安装"
        return 1
    fi
}

# 检查 Docker 是否可用
check_docker() {
    if ! require_cmd docker; then
        error "Docker 未安装。请先安装 Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    if ! docker info &>/dev/null; then
        error "Docker daemon 未运行，或当前用户无权限执行 docker"
        return 1
    fi
    return 0
}

# 检查 docker compose 是否可用（兼容 v1 和 v2）
get_compose_cmd() {
    if docker compose version &>/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        error "docker compose 未安装"
        return 1
    fi
}

# 检查 upstream remote 是否已配置
check_upstream() {
    cd "$PROJECT_ROOT"
    if ! git remote get-url "$UPSTREAM_REMOTE_NAME" &>/dev/null; then
        return 1
    fi
    return 0
}

# 配置 upstream remote
setup_upstream() {
    cd "$PROJECT_ROOT"
    if check_upstream; then
        local current_url
        current_url=$(git remote get-url "$UPSTREAM_REMOTE_NAME")
        success "upstream 已配置: $current_url"
        return 0
    fi

    info "正在添加 upstream remote..."
    git remote add "$UPSTREAM_REMOTE_NAME" "$UPSTREAM_URL"
    if [ $? -eq 0 ]; then
        success "upstream 已添加: $UPSTREAM_URL"
        return 0
    else
        error "添加 upstream 失败"
        return 1
    fi
}
