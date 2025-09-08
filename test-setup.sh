#!/bin/bash
# 测试环境配置是否正确

echo "🧪 测试 Tmux Orchestrator 环境配置..."
echo ""

# 测试环境变量
if [ -z "$TMUX_ORCHESTRATOR_HOME" ]; then
    echo "❌ TMUX_ORCHESTRATOR_HOME 未设置"
    echo "   请运行: source ./setup-env.sh"
    exit 1
else
    echo "✅ TMUX_ORCHESTRATOR_HOME = $TMUX_ORCHESTRATOR_HOME"
fi

if [ -z "$CODING_DIR" ]; then
    echo "❌ CODING_DIR 未设置"
    exit 1
else
    echo "✅ CODING_DIR = $CODING_DIR"
fi

echo ""

# 测试关键文件
files_to_check=(
    "send-claude-message.sh"
    "schedule_with_note.sh"
    "CLAUDE.md"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$TMUX_ORCHESTRATOR_HOME/$file" ]; then
        echo "✅ 找到文件: $file"
    else
        echo "❌ 缺少文件: $file"
    fi
done

echo ""

# 测试目录结构
dirs_to_check=(
    "$HOME/.tmux-orchestrator"
    "$TMUX_ORCHESTRATOR_HOME/registry"
    "$CODING_DIR"
)

for dir in "${dirs_to_check[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ 目录存在: $dir"
    else
        echo "⚠️  目录不存在: $dir"
        mkdir -p "$dir"
        echo "   已创建目录: $dir"
    fi
done

echo ""
echo "🎉 环境配置测试完成！"
echo ""
echo "📋 下一步："
echo "   1. 确保所有 ✅ 项目都正常"
echo "   2. 如有 ❌ 项目，请检查路径设置"
echo "   3. 运行 Tmux Orchestrator 脚本测试功能"