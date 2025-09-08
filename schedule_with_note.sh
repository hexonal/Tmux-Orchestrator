#!/bin/bash
# Dynamic scheduler with note for next check - Universal Version
# Usage: ./schedule_with_note.sh <minutes> "<note>" [target_window]

MINUTES=${1:-3}
NOTE=${2:-"Standard check-in"}
TARGET=${3:-"tmux-orc:0"}

# 动态检测脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# 创建配置目录和文件的通用路径
CONFIG_DIR="${CONFIG_DIR:-$HOME/.tmux-orchestrator}"
NOTES_FILE="$CONFIG_DIR/next_check_note.txt"

# 确保配置目录存在
mkdir -p "$CONFIG_DIR"

# Create a note file for the next check
echo "=== Next Check Note ($(date)) ===" > "$NOTES_FILE"
echo "Scheduled for: $MINUTES minutes" >> "$NOTES_FILE"
echo "" >> "$NOTES_FILE"
echo "$NOTE" >> "$NOTES_FILE"

echo "Scheduling check in $MINUTES minutes with note: $NOTE"

# Calculate the exact time when the check will run
CURRENT_TIME=$(date +"%H:%M:%S")
RUN_TIME=$(date -v +${MINUTES}M +"%H:%M:%S" 2>/dev/null || date -d "+${MINUTES} minutes" +"%H:%M:%S" 2>/dev/null)

# 检查目标窗口是否存在
if ! tmux list-windows -a | grep -q "^$TARGET:"; then
    echo "Warning: Target window '$TARGET' may not exist. Proceeding anyway..."
fi

# 动态查找 claude_control.py 脚本
CLAUDE_CONTROL=""
if [ -f "$PROJECT_ROOT/claude_control.py" ]; then
    CLAUDE_CONTROL="$PROJECT_ROOT/claude_control.py"
elif [ -f "$SCRIPT_DIR/claude_control.py" ]; then
    CLAUDE_CONTROL="$SCRIPT_DIR/claude_control.py"
else
    echo "Warning: claude_control.py not found. Using basic status check."
    CLAUDE_CONTROL=""
fi

# Use nohup to completely detach the sleep process
# Use bc for floating point calculation if available, otherwise use arithmetic expansion
if command -v bc >/dev/null 2>&1; then
    SECONDS=$(echo "$MINUTES * 60" | bc)
else
    SECONDS=$((MINUTES * 60))
fi

# 构建通用的检查命令
if [ -n "$CLAUDE_CONTROL" ]; then
    CHECK_COMMAND="Time for orchestrator check! cat '$NOTES_FILE' && python3 '$CLAUDE_CONTROL' status detailed"
else
    CHECK_COMMAND="Time for orchestrator check! cat '$NOTES_FILE'"
fi

nohup bash -c "sleep $SECONDS && tmux send-keys -t '$TARGET' '$CHECK_COMMAND' && sleep 1 && tmux send-keys -t '$TARGET' Enter" > /dev/null 2>&1 &

# Get the PID of the background process
SCHEDULE_PID=$!

echo "Scheduled successfully - process detached (PID: $SCHEDULE_PID)"
echo "SCHEDULED TO RUN AT: $RUN_TIME (in $MINUTES minutes from $CURRENT_TIME)"