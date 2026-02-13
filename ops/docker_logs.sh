#!/bin/bash
# ============================================================================
# AI Toolkit Ops - 日志查看
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
ensure_project_root
cd "$PROJECT_ROOT"

# ============================================================================
# 功能函数
# ============================================================================

# 获取容器 ID
_get_container_id() {
    docker ps -a --filter "name=$DOCKER_SERVICE_NAME" --format "{{.ID}}" 2>/dev/null | head -1
}

# 检查容器是否存在
_ensure_container() {
    check_docker || return 1

    local container_id
    container_id=$(_get_container_id)
    if [ -z "$container_id" ]; then
        error "未找到容器 $DOCKER_SERVICE_NAME"
        info "请先启动服务: 主菜单 → Docker 部署 → 启动服务"
        return 1
    fi
    return 0
}

# 1) 查看最近日志
view_recent_logs() {
    title "查看最近日志"

    _ensure_container || return

    echo -ne "  ${BOLD}显示最近多少行？[默认 100]: ${NC}"
    read -r lines
    lines=${lines:-100}

    echo ""
    echo -e "  ${DIM}══════════════ 日志开始 ══════════════${NC}"
    echo ""

    docker logs "$(_get_container_id)" --tail "$lines" 2>&1

    echo ""
    echo -e "  ${DIM}══════════════ 日志结束 ══════════════${NC}"
}

# 2) 实时跟踪日志
follow_logs() {
    title "实时跟踪日志"

    _ensure_container || return

    info "正在跟踪日志... (Ctrl+C 退出)"
    echo ""
    echo -e "  ${DIM}══════════════ 实时日志 ══════════════${NC}"
    echo ""

    docker logs "$(_get_container_id)" --follow --tail 50 2>&1

    echo ""
    echo -e "  ${DIM}══════════════ 跟踪结束 ══════════════${NC}"
}

# 3) 导出日志到文件
export_logs() {
    title "导出日志到文件"

    _ensure_container || return

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_dir="$PROJECT_ROOT/output/logs"
    local log_file="$log_dir/aitk_${timestamp}.log"

    mkdir -p "$log_dir"

    info "正在导出日志..."
    docker logs "$(_get_container_id)" >"$log_file" 2>&1

    if [ $? -eq 0 ]; then
        local size
        size=$(du -h "$log_file" | cut -f1)
        success "日志已导出 ✓"
        echo ""
        echo -e "  文件: ${CYAN}$log_file${NC}"
        echo -e "  大小: ${CYAN}$size${NC}"
    else
        error "日志导出失败"
    fi
}

# 4) 查看训练输出目录
view_training_outputs() {
    title "训练输出目录"

    local output_dir="$PROJECT_ROOT/output"

    if [ ! -d "$output_dir" ]; then
        info "输出目录不存在: $output_dir"
        return
    fi

    info "输出目录内容："
    echo ""

    # 列出目录，按修改时间排序
    local count=0
    while IFS= read -r dir; do
        if [ -d "$dir" ]; then
            local name
            name=$(basename "$dir")
            local mod_time
            mod_time=$(stat -c '%y' "$dir" 2>/dev/null | cut -d. -f1)
            local file_count
            file_count=$(find "$dir" -type f | wc -l)
            echo -e "  📁 ${CYAN}$name${NC}  ${DIM}($file_count 个文件, 修改于 $mod_time)${NC}"
            count=$((count + 1))
        fi
    done < <(ls -dt "$output_dir"/*/ 2>/dev/null)

    if [ "$count" -eq 0 ]; then
        echo -e "  ${DIM}(空)${NC}"
    fi
}

# ============================================================================
# 子菜单
# ============================================================================

logs_menu() {
    while true; do
        menu_header "📋 日志查看"
        menu_item "1" "📄" "查看最近日志"
        menu_item "2" "🔴" "实时跟踪日志 (Ctrl+C 退出)"
        menu_item "3" "💾" "导出日志到文件"
        menu_item "4" "📁" "查看训练输出目录"
        menu_footer

        local choice
        choice=$(menu_choice)

        case $choice in
            1) view_recent_logs; press_enter ;;
            2) follow_logs; press_enter ;;
            3) export_logs; press_enter ;;
            4) view_training_outputs; press_enter ;;
            0) return ;;
            *) warn "无效选择"; press_enter ;;
        esac
    done
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    logs_menu
fi
