#!/bin/bash
# ============================================================================
# AI Toolkit Ops - 同步上游仓库
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
ensure_project_root
cd "$PROJECT_ROOT"

# ============================================================================
# 功能函数
# ============================================================================

# 1) 查看上游最新更新
view_upstream_updates() {
    title "查看上游最新更新"

    setup_upstream || return

    info "正在获取上游仓库信息..."
    git fetch "$UPSTREAM_REMOTE_NAME" --quiet
    if [ $? -ne 0 ]; then
        error "获取上游仓库失败，请检查网络连接"
        return
    fi

    # 获取当前分支
    local current_branch
    current_branch=$(git branch --show-current)

    # 对应的上游分支
    local upstream_branch="$UPSTREAM_REMOTE_NAME/main"

    # 检查是否有新的提交
    local behind_count
    behind_count=$(git rev-list --count HEAD.."$upstream_branch" 2>/dev/null)

    if [ "$behind_count" = "0" ]; then
        success "当前已是最新，与上游无差异 ✓"
    else
        warn "上游有 ${BOLD}$behind_count${NC}${YELLOW} 个新提交${NC}"
        echo ""
        info "上游最近的提交："
        echo -e "  ${DIM}──────────────────────────────────────────${NC}"
        git log --oneline --no-merges HEAD.."$upstream_branch" | head -20 | while read -r line; do
            echo -e "  ${GREEN}●${NC} $line"
        done

        if [ "$behind_count" -gt 20 ]; then
            echo -e "  ${DIM}... 还有 $((behind_count - 20)) 个提交${NC}"
        fi
    fi

    # 显示本地独有的提交（我们的 ops 修改）
    local ahead_count
    ahead_count=$(git rev-list --count "$upstream_branch"..HEAD 2>/dev/null)
    if [ "$ahead_count" -gt 0 ]; then
        echo ""
        info "本地独有的提交（${ahead_count} 个）："
        echo -e "  ${DIM}──────────────────────────────────────────${NC}"
        git log --oneline --no-merges "$upstream_branch"..HEAD | while read -r line; do
            echo -e "  ${CYAN}●${NC} $line"
        done
    fi
}

# 2) 合并上游更新
merge_upstream() {
    title "合并上游更新到本地"

    setup_upstream || return

    # 检查工作区是否干净
    if ! git diff --quiet || ! git diff --cached --quiet; then
        error "工作区有未提交的修改，请先提交或暂存"
        echo ""
        git status --short
        return
    fi

    info "正在获取上游仓库..."
    git fetch "$UPSTREAM_REMOTE_NAME" --quiet
    if [ $? -ne 0 ]; then
        error "获取上游仓库失败"
        return
    fi

    local current_branch
    current_branch=$(git branch --show-current)
    local upstream_branch="$UPSTREAM_REMOTE_NAME/main"

    local behind_count
    behind_count=$(git rev-list --count HEAD.."$upstream_branch" 2>/dev/null)

    if [ "$behind_count" = "0" ]; then
        success "已是最新，无需合并"
        return
    fi

    warn "即将合并上游的 $behind_count 个提交到 $current_branch"
    echo ""

    if ! confirm "确认合并？"; then
        info "已取消"
        return
    fi

    echo ""
    info "正在合并 $upstream_branch → $current_branch ..."
    git merge "$upstream_branch" --no-edit

    if [ $? -eq 0 ]; then
        success "合并成功 ✓"
        echo ""
        info "如需推送到远程仓库，请执行: git push origin $current_branch"
    else
        error "合并出现冲突！"
        echo ""
        warn "冲突文件："
        git diff --name-only --diff-filter=U | while read -r file; do
            echo -e "  ${RED}✗${NC} $file"
        done
        echo ""
        info "请手动解决冲突后执行:"
        echo -e "  ${DIM}git add .${NC}"
        echo -e "  ${DIM}git commit${NC}"
        echo ""
        info "或放弃合并:"
        echo -e "  ${DIM}git merge --abort${NC}"
    fi
}

# 3) 查看与上游的文件差异
view_diff() {
    title "查看与上游的文件差异"

    setup_upstream || return

    info "正在获取上游仓库..."
    git fetch "$UPSTREAM_REMOTE_NAME" --quiet

    local upstream_branch="$UPSTREAM_REMOTE_NAME/main"

    # 显示差异文件列表
    local diff_files
    diff_files=$(git diff --stat HEAD..."$upstream_branch" 2>/dev/null)

    if [ -z "$diff_files" ]; then
        success "与上游完全一致，无差异"
    else
        info "差异文件："
        echo ""
        echo "$diff_files"
    fi
}

# ============================================================================
# 子菜单
# ============================================================================

sync_menu() {
    while true; do
        menu_header "🔄 同步上游仓库"
        menu_item "1" "👀" "查看上游最新更新"
        menu_item "2" "📥" "合并上游更新到本地"
        menu_item "3" "📊" "查看与上游的文件差异"
        menu_footer

        local choice
        choice=$(menu_choice)

        case $choice in
            1) view_upstream_updates; press_enter ;;
            2) merge_upstream; press_enter ;;
            3) view_diff; press_enter ;;
            0) return ;;
            *) warn "无效选择"; press_enter ;;
        esac
    done
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sync_menu
fi
