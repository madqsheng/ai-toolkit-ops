#!/bin/bash
# ============================================================================
# AI Toolkit Ops - 主菜单入口
# 使用方式: ./main.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$SCRIPT_DIR/ops"

# 加载公共函数
source "$OPS_DIR/common.sh"

# 检查项目完整性
ensure_project_root

# 获取版本号
get_version() {
    if [ -f "$PROJECT_ROOT/version.py" ]; then
        python3 -c "exec(open('$PROJECT_ROOT/version.py').read()); print(VERSION)" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# ============================================================================
# 主菜单
# ============================================================================

main_menu() {
    while true; do
        local version
        version=$(get_version)

        clear
        echo ""
        echo -e "  ${BOLD}${MAGENTA}╔══════════════════════════════════════════╗${NC}"
        echo -e "  ${BOLD}${MAGENTA}║${NC}"
        echo -e "  ${BOLD}${MAGENTA}║${NC}   ${BOLD}🤖 AI Toolkit Ops${NC}"
        echo -e "  ${BOLD}${MAGENTA}║${NC}   ${DIM}v$version${NC}"
        echo -e "  ${BOLD}${MAGENTA}║${NC}"
        echo -e "  ${BOLD}${MAGENTA}╚══════════════════════════════════════════╝${NC}"
        echo ""
        menu_item "1" "🔄" "同步上游仓库"
        menu_item "2" "🐳" "Docker 部署管理"
        menu_item "3" "📋" "日志查看"
        echo ""
        echo -e "    ${BOLD}${DIM}0${NC})  ${DIM}👋  退出${NC}"
        echo ""
        echo -e "  ${DIM}──────────────────────────────────────────${NC}"

        local choice
        choice=$(menu_choice)

        case $choice in
            1) source "$OPS_DIR/sync_upstream.sh"; sync_menu ;;
            2) source "$OPS_DIR/docker_deploy.sh"; docker_menu ;;
            3) source "$OPS_DIR/docker_logs.sh"; logs_menu ;;
            0)
                echo ""
                echo -e "  ${DIM}Bye 👋${NC}"
                echo ""
                exit 0
                ;;
            *)
                warn "无效选择"
                press_enter
                ;;
        esac
    done
}

main_menu
