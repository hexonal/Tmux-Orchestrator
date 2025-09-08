#!/bin/bash
# Tmux Orchestrator 环境变量自动配置脚本
# 使用方法：source ./setup-env.sh

echo "🔧 配置 Tmux Orchestrator 环境变量..."

# 获取当前脚本目录作为项目根目录
CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 自动检测编排器根目录
auto_detect_orchestrator_home() {
    # 方法1: 当前脚本所在目录
    if [ -f "$CURRENT_SCRIPT_DIR/send-claude-message.sh" ]; then
        echo "$CURRENT_SCRIPT_DIR"
        return 0
    fi
    
    # 方法2: 当前工作目录
    if [ -f "$(pwd)/send-claude-message.sh" ]; then
        echo "$(pwd)"
        return 0
    fi
    
    # 方法3: 用户配置目录
    if [ -f "$HOME/.tmux-orchestrator/send-claude-message.sh" ]; then
        echo "$HOME/.tmux-orchestrator"
        return 0
    fi
    
    # 方法4: 在常见路径搜索
    local search_paths=(
        "$HOME/Coding/Tmux-Orchestrator"
        "$HOME/Projects/Tmux-Orchestrator" 
        "$HOME/Code/Tmux-Orchestrator"
        "$HOME/Development/Tmux-Orchestrator"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path/send-claude-message.sh" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # 默认返回当前脚本目录
    echo "$CURRENT_SCRIPT_DIR"
}

# 智能检测所有编程语言项目目录
detect_all_coding_directories() {
    local all_dirs=(
        # 通用开发目录
        "$HOME/Coding"
        "$HOME/Projects" 
        "$HOME/Code"
        "$HOME/Development"
        "$HOME/workspace"
        "$HOME/dev"
        
        # IDE 专用目录
        "$HOME/PycharmProjects"      # PyCharm (Python)
        "$HOME/IdeaProjects"         # IntelliJ IDEA (Java/Kotlin)
        "$HOME/WebstormProjects"     # WebStorm (JavaScript/TypeScript)
        "$HOME/CLionProjects"        # CLion (C/C++)
        
        # 语言特定目录
        "$HOME/python-projects"
        "$HOME/java-projects"
        "$HOME/nodejs-projects"
        "$HOME/go-projects"
        "$HOME/golang-projects"
        "$HOME/rust-projects"
        "$HOME/cpp-projects"
        
        # Go 特殊结构
        "$HOME/go/src"
        "$GOPATH/src"
        
        # 其他常见结构
        "$HOME/src"
        "$HOME/work"
        "$HOME/repos"
        "$HOME/git"
    )
    
    # 返回所有存在的目录
    local existing_dirs=()
    for dir in "${all_dirs[@]}"; do
        if [ -d "$dir" ] && [ -n "$dir" ]; then
            existing_dirs+=("$dir")
        fi
    done
    
    printf '%s\n' "${existing_dirs[@]}"
}

# 自动检测主要代码目录（向后兼容）
detect_coding_directory() {
    local dirs=($(detect_all_coding_directories))
    if [ ${#dirs[@]} -gt 0 ]; then
        echo "${dirs[0]}"  # 返回第一个找到的目录
    else
        # 默认创建 Coding 目录
        mkdir -p "$HOME/Coding"
        echo "$HOME/Coding"
    fi
}

# 设置环境变量
export TMUX_ORCHESTRATOR_HOME="$(auto_detect_orchestrator_home)"
export CODING_DIR="$(detect_coding_directory)"

# 导出所有编程目录（用于高级搜索）
export ALL_CODING_DIRS="$(detect_all_coding_directories | tr '\n' ':')"

# 创建必要的目录结构
mkdir -p "$HOME/.tmux-orchestrator"
mkdir -p "$TMUX_ORCHESTRATOR_HOME/registry/logs"
mkdir -p "$TMUX_ORCHESTRATOR_HOME/registry/notes"

# 验证设置
echo "✅ 环境变量设置完成："
echo "   TMUX_ORCHESTRATOR_HOME = $TMUX_ORCHESTRATOR_HOME"
echo "   CODING_DIR = $CODING_DIR"
echo ""

# 检查关键文件
if [ -f "$TMUX_ORCHESTRATOR_HOME/send-claude-message.sh" ]; then
    echo "✅ 找到消息发送脚本：$TMUX_ORCHESTRATOR_HOME/send-claude-message.sh"
else
    echo "⚠️  警告：未找到 send-claude-message.sh"
fi

if [ -f "$TMUX_ORCHESTRATOR_HOME/schedule_with_note.sh" ]; then
    echo "✅ 找到调度脚本：$TMUX_ORCHESTRATOR_HOME/schedule_with_note.sh"
else
    echo "⚠️  警告：未找到 schedule_with_note.sh"
fi

echo ""
echo "🎯 使用方法："
echo "   1. 临时使用：source ./setup-env.sh"
echo "   2. 永久设置：./setup-env.sh >> ~/.bashrc (或 ~/.zshrc)"
echo "   3. 验证设置：echo \$TMUX_ORCHESTRATOR_HOME"

# 生成用于 shell 配置文件的内容
cat > "$HOME/.tmux-orchestrator/env-config.sh" << 'EOL'
# Tmux Orchestrator 环境配置
# 添加此内容到 ~/.bashrc 或 ~/.zshrc

# 自动检测编排器目录函数
auto_detect_orchestrator_home() {
    if [ -f "$(pwd)/send-claude-message.sh" ]; then
        echo "$(pwd)"
    elif [ -f "$HOME/.tmux-orchestrator/send-claude-message.sh" ]; then
        echo "$HOME/.tmux-orchestrator"
    else
        # 在常见路径搜索
        local search_paths=(
            "$HOME/Coding/Tmux-Orchestrator"
            "$HOME/Projects/Tmux-Orchestrator" 
            "$HOME/Code/Tmux-Orchestrator"
        )
        for path in "${search_paths[@]}"; do
            if [ -f "$path/send-claude-message.sh" ]; then
                echo "$path"
                return 0
            fi
        done
        echo "$HOME/.tmux-orchestrator"  # 默认位置
    fi
}

# 自动检测代码目录函数
detect_coding_directory() {
    local dirs=("$HOME/Coding" "$HOME/Projects" "$HOME/Code" "$HOME/workspace")
    for dir in "${dirs[@]}"; do
        [ -d "$dir" ] && { echo "$dir"; return; }
    done
    mkdir -p "$HOME/Coding" && echo "$HOME/Coding"
}

# 设置环境变量
export TMUX_ORCHESTRATOR_HOME="$(auto_detect_orchestrator_home)"
export CODING_DIR="$(detect_coding_directory)"
EOL

echo "📝 已生成配置文件：$HOME/.tmux-orchestrator/env-config.sh"
echo "   可以添加到您的 shell 配置文件中实现永久配置"