#!/bin/bash
# 快速启动项目开发环境脚本
# 使用方法: ./start-dev-project.sh <project-name> [project-type]

PROJECT_NAME="$1"
PROJECT_TYPE="${2:-web}"

if [ -z "$PROJECT_NAME" ]; then
    echo "使用方法: $0 <project-name> [project-type]"
    echo "项目类型: web, api, mobile, desktop, ai"
    exit 1
fi

# 确保环境配置已加载
source "$(dirname "$0")/setup-env.sh" >/dev/null 2>&1

echo "🚀 启动项目开发环境: $PROJECT_NAME"
echo "项目类型: $PROJECT_TYPE"
echo ""

# 检查项目是否存在
PROJECT_PATHS=($(find_project_in_all_dirs "$PROJECT_NAME"))
if [ ${#PROJECT_PATHS[@]} -gt 0 ]; then
    PROJECT_PATH="${PROJECT_PATHS[0]}"
    echo "📁 找到现有项目: $PROJECT_PATH"
else
    # 创建新项目
    CODING_DIR=$(detect_coding_directory)
    PROJECT_PATH="$CODING_DIR/$PROJECT_NAME"
    mkdir -p "$PROJECT_PATH"
    echo "📁 创建新项目: $PROJECT_PATH"
fi

# 创建 tmux 会话
SESSION_NAME="${PROJECT_NAME}-dev"
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "⚠️  会话 $SESSION_NAME 已存在"
    echo "是否要重新创建? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        tmux kill-session -t "$SESSION_NAME"
    else
        echo "连接到现有会话..."
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    fi
fi

# 创建开发会话
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_PATH"

# 根据项目类型设置窗口
case "$PROJECT_TYPE" in
    "web")
        tmux rename-window -t "$SESSION_NAME:0" "PM-Fullstack"
        tmux new-window -t "$SESSION_NAME" -n "Frontend-Dev" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Backend-Dev" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "QA-Tester" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Dev-Server" -c "$PROJECT_PATH"
        ;;
    "api")
        tmux rename-window -t "$SESSION_NAME:0" "PM-Backend"
        tmux new-window -t "$SESSION_NAME" -n "API-Dev" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "DB-Admin" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "API-Test" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Server" -c "$PROJECT_PATH"
        ;;
    "ai")
        tmux rename-window -t "$SESSION_NAME:0" "AI-Architect"
        tmux new-window -t "$SESSION_NAME" -n "ML-Engineer" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Data-Scientist" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "MLOps" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Jupyter" -c "$PROJECT_PATH"
        ;;
    *)
        tmux rename-window -t "$SESSION_NAME:0" "Project-Manager"
        tmux new-window -t "$SESSION_NAME" -n "Developer" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "QA-Tester" -c "$PROJECT_PATH"
        tmux new-window -t "$SESSION_NAME" -n "Tools" -c "$PROJECT_PATH"
        ;;
esac

echo "✅ 开发环境已创建！"
echo ""
echo "会话信息:"
tmux list-windows -t "$SESSION_NAME" -F "  #{window_index}: #{window_name}"

echo ""
echo "🎯 下一步操作:"
echo "1. 连接到会话:"
echo "   tmux attach-session -t $SESSION_NAME"
echo ""
echo "2. 在需要的窗口启动 Claude 代理:"
echo "   claude --dangerously-skip-permissions"
echo ""
echo "3. 使用编排器分配任务:"
echo "   \"$TMUX_ORCHESTRATOR_HOME/send-claude-message.sh\" $SESSION_NAME:0 \"你的任务...\""
echo ""
echo "4. 设置定期检查:"
echo "   ./schedule_with_note.sh 15 \"开发进度检查\" \"$SESSION_NAME:0\""

# 提示是否立即连接
echo ""
echo "是否立即连接到开发环境? (Y/n): "
read -r connect
if [[ ! "$connect" =~ ^[Nn]$ ]]; then
    tmux attach-session -t "$SESSION_NAME"
fi