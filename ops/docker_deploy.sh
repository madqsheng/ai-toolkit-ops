#!/bin/bash
# ============================================================================
# AI Toolkit Ops - Docker 部署
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
ensure_project_root
cd "$PROJECT_ROOT"

# ============================================================================
# 功能函数
# ============================================================================

# 获取 compose 命令
_compose() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd) || return 1
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" "$@"
}

# 显示当前 Docker 状态摘要
_show_status() {
    echo ""
    echo -e "  ${DIM}── 当前状态 ──${NC}"

    # 镜像
    local image_info
    image_info=$(docker images "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG" --format "{{.Size}}  创建于 {{.CreatedSince}}" 2>/dev/null)
    if [ -n "$image_info" ]; then
        echo -e "  镜像: ${GREEN}$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG${NC}  ($image_info)"
    else
        echo -e "  镜像: ${DIM}未构建${NC}"
    fi

    # 容器
    local container_status
    container_status=$(docker ps -a --filter "name=$DOCKER_SERVICE_NAME" --format "{{.Status}}" 2>/dev/null | head -1)
    if [ -n "$container_status" ]; then
        if echo "$container_status" | grep -q "Up"; then
            echo -e "  容器: ${GREEN}运行中${NC}  ($container_status)"
        else
            echo -e "  容器: ${YELLOW}已停止${NC}  ($container_status)"
        fi
    else
        echo -e "  容器: ${DIM}不存在${NC}"
    fi
    echo ""
}

# 1) 构建 Docker 镜像
build_image() {
    title "构建 Docker 镜像"

    check_docker || return

    _show_status

    info "将使用以下配置构建："
    echo -e "  Dockerfile:  ${CYAN}docker/Dockerfile${NC}"
    echo -e "  镜像名称:    ${CYAN}$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG${NC}"
    echo -e "  构建上下文:  ${CYAN}$PROJECT_ROOT${NC}"
    echo ""

    if ! confirm "开始构建？"; then
        info "已取消"
        return
    fi

    echo ""
    info "开始构建镜像..."
    echo -e "${DIM}"

    docker build \
        -t "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG" \
        -f docker/Dockerfile \
        .

    local exit_code=$?
    echo -e "${NC}"

    if [ $exit_code -eq 0 ]; then
        success "镜像构建成功 ✓"
        echo ""
        docker images "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"
    else
        error "镜像构建失败 (exit code: $exit_code)"
    fi
}

# 2) 启动服务
start_service() {
    title "启动服务"

    check_docker || return

    # 检查镜像是否存在
    if ! docker images "$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG" --format "{{.ID}}" | grep -q .; then
        warn "镜像 $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG 不存在"
        echo ""
        if confirm "是否先构建镜像？"; then
            build_image
            echo ""
        else
            info "已取消"
            return
        fi
    fi

    # 检查是否已在运行
    local running
    running=$(docker ps --filter "name=$DOCKER_SERVICE_NAME" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$running" ]; then
        warn "服务已在运行中"
        _show_status
        if ! confirm "是否重启？"; then
            return
        fi
        info "正在停止现有服务..."
        _compose down
        echo ""
    fi

    info "正在启动服务..."
    _compose up -d

    if [ $? -eq 0 ]; then
        success "服务启动成功 ✓"
        _show_status

        # 显示访问信息
        local port
        port=$(docker port "${DOCKER_SERVICE_NAME}" 8675 2>/dev/null | head -1)
        if [ -n "$port" ]; then
            echo -e "  🌐 访问地址: ${BOLD}${GREEN}http://$port${NC}"
        else
            echo -e "  🌐 访问地址: ${BOLD}${GREEN}http://localhost:8675${NC}"
        fi
        echo ""
    else
        error "服务启动失败"
    fi
}

# 3) 停止服务
stop_service() {
    title "停止服务"

    check_docker || return

    local running
    running=$(docker ps --filter "name=$DOCKER_SERVICE_NAME" --format "{{.Names}}" 2>/dev/null)
    if [ -z "$running" ]; then
        info "服务未在运行"
        return
    fi

    _show_status

    if ! confirm "确认停止服务？"; then
        info "已取消"
        return
    fi

    info "正在停止服务..."
    _compose down

    if [ $? -eq 0 ]; then
        success "服务已停止 ✓"
    else
        error "停止服务失败"
    fi
}

# 4) 重启服务
restart_service() {
    title "重启服务"

    check_docker || return

    info "正在重启服务..."
    _compose restart

    if [ $? -eq 0 ]; then
        success "服务重启成功 ✓"
        _show_status
    else
        error "重启失败"
    fi
}

# 5) 查看服务状态
show_service_status() {
    title "服务状态"

    check_docker || return

    _show_status

    # 容器详细信息
    local container_id
    container_id=$(docker ps -a --filter "name=$DOCKER_SERVICE_NAME" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -n "$container_id" ]; then
        info "容器详情："
        docker inspect "$container_id" --format '
  ID:       {{.ID}}
  Name:     {{.Name}}
  Image:    {{.Config.Image}}
  Created:  {{.Created}}
  Status:   {{.State.Status}}
  Pid:      {{.State.Pid}}' 2>/dev/null

        echo ""
        info "端口映射："
        docker port "$container_id" 2>/dev/null | while read -r line; do
            echo "  $line"
        done

        echo ""
        info "资源使用："
        docker stats "$container_id" --no-stream --format "  CPU: {{.CPUPerc}}  内存: {{.MemUsage}}  网络I/O: {{.NetIO}}" 2>/dev/null
    else
        info "没有找到相关容器"
    fi
}

# ============================================================================
# 子菜单
# ============================================================================

docker_menu() {
    while true; do
        menu_header "🐳 Docker 部署管理"

        # 简要状态显示
        if check_docker 2>/dev/null; then
            _show_status
        fi

        menu_item "1" "🔨" "构建 Docker 镜像"
        menu_item "2" "🚀" "启动服务"
        menu_item "3" "⏹ " "停止服务"
        menu_item "4" "🔄" "重启服务"
        menu_item "5" "📊" "查看服务状态"
        menu_footer

        local choice
        choice=$(menu_choice)

        case $choice in
            1) build_image; press_enter ;;
            2) start_service; press_enter ;;
            3) stop_service; press_enter ;;
            4) restart_service; press_enter ;;
            5) show_service_status; press_enter ;;
            0) return ;;
            *) warn "无效选择"; press_enter ;;
        esac
    done
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    docker_menu
fi
