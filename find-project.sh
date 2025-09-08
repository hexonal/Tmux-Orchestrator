#!/bin/bash
# 智能项目发现工具 - 跨所有编程语言目录搜索项目
# 使用方法: ./find-project.sh [project-name] [--type language]

PROJECT_NAME="$1"
PROJECT_TYPE="$2"

# 确保环境变量已加载
if [ -z "$ALL_CODING_DIRS" ]; then
    source "$(dirname "$0")/setup-env.sh" >/dev/null 2>&1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}🔍 智能项目发现工具${NC}"
    echo -e "${BLUE}==============================${NC}"
}

# 检测项目类型的函数
detect_project_type() {
    local dir="$1"
    local types=()
    
    # 检测各种项目类型
    [ -f "$dir/package.json" ] && types+=("Node.js")
    [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] && types+=("Java")
    [ -f "$dir/requirements.txt" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/pyproject.toml" ] && types+=("Python")
    [ -f "$dir/go.mod" ] && types+=("Go")
    [ -f "$dir/Cargo.toml" ] && types+=("Rust")
    [ -f "$dir/composer.json" ] && types+=("PHP")
    [ -f "$dir/CMakeLists.txt" ] && types+=("C/C++")
    [ -f "$dir/Gemfile" ] && types+=("Ruby")
    [ -f "$dir/.csproj" ] || find "$dir" -name "*.csproj" -type f | head -1 | grep -q "." && types+=("C#")
    [ -f "$dir/pubspec.yaml" ] && types+=("Dart/Flutter")
    
    if [ ${#types[@]} -eq 0 ]; then
        echo "Unknown"
    else
        printf '%s, ' "${types[@]}" | sed 's/, $//'
    fi
}

# 搜索项目函数
search_projects() {
    local search_term="$1"
    local type_filter="$2"
    local found_projects=()
    
    echo -e "${YELLOW}🔎 搜索范围：${NC}"
    IFS=':' read -ra DIRS <<< "$ALL_CODING_DIRS"
    for dir in "${DIRS[@]}"; do
        if [ -n "$dir" ] && [ -d "$dir" ]; then
            echo "   📁 $dir"
        fi
    done
    echo ""
    
    echo -e "${YELLOW}🔍 搜索结果：${NC}"
    
    for base_dir in "${DIRS[@]}"; do
        if [ -z "$base_dir" ] || [ ! -d "$base_dir" ]; then
            continue
        fi
        
        # 在每个基础目录中搜索项目
        while IFS= read -r -d '' project_dir; do
            project_name=$(basename "$project_dir")
            
            # 如果指定了搜索词，进行模糊匹配
            if [ -n "$search_term" ]; then
                if [[ ! "$project_name" =~ .*"$search_term".* ]]; then
                    continue
                fi
            fi
            
            # 检测项目类型
            project_type=$(detect_project_type "$project_dir")
            
            # 如果指定了类型过滤器
            if [ -n "$type_filter" ]; then
                if [[ ! "$project_type" =~ .*"$type_filter".* ]]; then
                    continue
                fi
            fi
            
            echo -e "   ${GREEN}✓${NC} $project_name"
            echo -e "     ${BLUE}路径:${NC} $project_dir"
            echo -e "     ${BLUE}类型:${NC} $project_type"
            echo ""
            
            found_projects+=("$project_dir")
            
        done < <(find "$base_dir" -maxdepth 2 -mindepth 1 -type d -print0 2>/dev/null)
    done
    
    echo -e "${YELLOW}📊 搜索统计：${NC}"
    echo "   找到项目: ${#found_projects[@]} 个"
    
    # 如果只找到一个项目，提供快速设置建议
    if [ ${#found_projects[@]} -eq 1 ]; then
        echo ""
        echo -e "${GREEN}💡 快速启动建议：${NC}"
        echo "   export PROJECT_PATH=\"${found_projects[0]}\""
        echo "   cd \"${found_projects[0]}\""
    fi
}

# 列出所有项目
list_all_projects() {
    echo -e "${YELLOW}📋 发现的所有项目：${NC}"
    echo ""
    
    local total_count=0
    IFS=':' read -ra DIRS <<< "$ALL_CODING_DIRS"
    
    for base_dir in "${DIRS[@]}"; do
        if [ -z "$base_dir" ] || [ ! -d "$base_dir" ]; then
            continue
        fi
        
        echo -e "${BLUE}📁 $base_dir${NC}"
        local dir_count=0
        
        while IFS= read -r -d '' project_dir; do
            project_name=$(basename "$project_dir")
            project_type=$(detect_project_type "$project_dir")
            
            echo -e "   ${GREEN}├─${NC} $project_name ${YELLOW}($project_type)${NC}"
            
            ((dir_count++))
            ((total_count++))
            
        done < <(find "$base_dir" -maxdepth 2 -mindepth 1 -type d -print0 2>/dev/null)
        
        if [ $dir_count -eq 0 ]; then
            echo -e "   ${RED}└─ 未找到项目${NC}"
        fi
        echo ""
    done
    
    echo -e "${YELLOW}📊 总计: $total_count 个项目${NC}"
}

# 主函数
main() {
    print_header
    echo ""
    
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "使用方法："
        echo "  $0                     # 列出所有项目"
        echo "  $0 <project-name>      # 搜索特定项目"
        echo "  $0 '' --type <type>    # 按类型过滤项目"
        echo "  $0 <name> --type <type> # 组合搜索"
        echo ""
        echo "支持的类型: Python, Java, Node.js, Go, Rust, PHP, C/C++, Ruby, C#, Dart"
        exit 0
    fi
    
    if [ -z "$PROJECT_NAME" ]; then
        list_all_projects
    else
        # 解析参数
        type_filter=""
        if [ "$2" = "--type" ] && [ -n "$3" ]; then
            type_filter="$3"
        fi
        
        search_projects "$PROJECT_NAME" "$type_filter"
    fi
}

main "$@"