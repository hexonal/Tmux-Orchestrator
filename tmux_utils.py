#!/usr/bin/env python3
"""
Tmux Orchestrator 工具类 - Tmux 会话和窗口管理
===========================================

这个模块提供了完整的 tmux 会话管理功能，包括：
- 会话和窗口的创建、监控和管理
- 窗口内容捕获和分析
- 安全的命令发送机制
- 实时状态监控和快照生成

主要用于 Claude AI 代理的 tmux 编排系统，支持多个 AI 代理
在不同的 tmux 窗口中协同工作。

作者：Flink
版本：1.0
最后更新：2024年
"""

import subprocess
import json
import time
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime

@dataclass
class TmuxWindow:
    """
    Tmux 窗口数据结构
    
    用于表示单个 tmux 窗口的状态信息，包含窗口的基本属性
    和当前活动状态。
    
    属性说明:
        session_name (str): 所属会话名称
        window_index (int): 窗口索引号，从 0 开始
        window_name (str): 窗口显示名称
        active (bool): 是否为当前活动窗口
    """
    session_name: str
    window_index: int
    window_name: str
    active: bool
    
@dataclass
class TmuxSession:
    """
    Tmux 会话数据结构
    
    表示完整的 tmux 会话信息，包含会话下的所有窗口
    和会话的连接状态。
    
    属性说明:
        name (str): 会话名称，必须在系统中唯一
        windows (List[TmuxWindow]): 该会话下的所有窗口列表
        attached (bool): 会话是否被客户端连接（活跃状态）
    """
    name: str
    windows: List[TmuxWindow]
    attached: bool

class TmuxOrchestrator:
    """
    Tmux 编排器主类
    
    这是整个 tmux 管理系统的核心类，提供了所有必要的功能来管理
    tmux 会话、窗口，以及与运行中的程序进行交互。
    
    设计理念：
    - 安全第一：所有操作都有安全检查和确认机制
    - 非侵入式：不会干扰正在运行的程序，只读取状态
    - 可扩展：支持多种类型的监控和交互模式
    
    典型用例：
    - AI 代理协调：管理多个 Claude 实例在不同窗口中工作
    - 开发环境监控：监控多个开发服务器和工具的状态
    - 自动化运维：批量管理和监控系统服务
    """
    
    def __init__(self):
        """
        初始化 Tmux 编排器
        
        设置默认的安全模式和限制参数，确保系统稳定运行。
        
        配置项说明:
            safety_mode (bool): 启用安全模式，需要用户确认敏感操作
            max_lines_capture (int): 单次捕获窗口内容的最大行数，防止内存溢出
        """
        self.safety_mode = True  # 默认启用安全模式，需要确认才能发送命令
        self.max_lines_capture = 1000  # 限制捕获的最大行数，避免内存问题
        
    def get_tmux_sessions(self) -> List[TmuxSession]:
        """
        获取所有 tmux 会话和窗口信息
        
        这是系统的核心信息收集方法，通过调用 tmux 命令获取当前系统中
        所有活跃会话的完整状态信息。
        
        执行步骤:
        1. 获取所有会话列表及其连接状态
        2. 对每个会话获取其下所有窗口信息
        3. 构建完整的会话-窗口层次结构
        
        返回:
            List[TmuxSession]: 包含所有会话信息的列表，如果出现错误则返回空列表
            
        异常处理:
            如果 tmux 命令执行失败（比如 tmux 未启动），会打印错误信息并返回空列表
            
        注意:
            - 此方法只读取状态，不会修改任何 tmux 配置
            - 返回的信息是调用时刻的快照，不会自动更新
        """
        try:
            # 获取所有会话的名称和连接状态
            # -F 参数指定输出格式，#{} 是 tmux 的变量语法
            sessions_cmd = ["tmux", "list-sessions", "-F", "#{session_name}:#{session_attached}"]
            sessions_result = subprocess.run(sessions_cmd, capture_output=True, text=True, check=True)
            
            sessions = []
            # 逐行解析会话信息，格式为 "session_name:0/1"
            for line in sessions_result.stdout.strip().split('\n'):
                if not line:  # 跳过空行
                    continue
                session_name, attached = line.split(':')
                
                # 获取指定会话下的所有窗口信息
                # -t 指定目标会话，-F 设置输出格式
                windows_cmd = ["tmux", "list-windows", "-t", session_name, "-F", "#{window_index}:#{window_name}:#{window_active}"]
                windows_result = subprocess.run(windows_cmd, capture_output=True, text=True, check=True)
                
                windows = []
                # 解析窗口信息，格式为 "index:name:0/1"
                for window_line in windows_result.stdout.strip().split('\n'):
                    if not window_line:  # 跳过空行
                        continue
                    window_index, window_name, window_active = window_line.split(':')
                    windows.append(TmuxWindow(
                        session_name=session_name,
                        window_index=int(window_index),
                        window_name=window_name,
                        active=window_active == '1'
                    ))
                
                # 创建会话对象，attached 状态：'1'=连接，'0'=分离
                sessions.append(TmuxSession(
                    name=session_name,
                    windows=windows,
                    attached=attached == '1'  # 字符串 '1' 转换为布尔值 True
                ))
            
            return sessions
        except subprocess.CalledProcessError as e:
            print(f"Error getting tmux sessions: {e}")
            return []
    
    def capture_window_content(self, session_name: str, window_index: int, num_lines: int = 50) -> str:
        """
        安全地捕获 tmux 窗口的内容
        
        这是一个核心的监控方法，用于获取指定窗口的输出内容，
        通常用于监控程序运行状态、查看日志输出等。
        
        参数:
            session_name (str): 目标会话名称
            window_index (int): 目标窗口索引（从0开始）
            num_lines (int): 要捕获的行数，默认50行
            
        返回:
            str: 窗口的文本内容，包含换行符
            
        安全限制:
            - 自动限制捕获行数不超过 max_lines_capture 设置
            - 防止内存溢出和系统负载过高
            - 如果命令执行失败，返回错误信息而非抛出异常
            
        典型用法:
            # 获取最近50行输出
            content = orchestrator.capture_window_content("ai-session", 0)
            
            # 获取更多历史记录
            content = orchestrator.capture_window_content("ai-session", 0, 200)
        """
        # 安全限制：防止请求过多行数导致内存问题
        if num_lines > self.max_lines_capture:
            num_lines = self.max_lines_capture
            
        try:
            # capture-pane: 捕获窗格内容
            # -t: 指定目标 (session:window)
            # -p: 输出到 stdout 而不是文件
            # -S: 指定开始行数，负数表示从末尾向前数
            cmd = ["tmux", "capture-pane", "-t", f"{session_name}:{window_index}", "-p", "-S", f"-{num_lines}"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout
        except subprocess.CalledProcessError as e:
            return f"Error capturing window content: {e}"
    
    def get_window_info(self, session_name: str, window_index: int) -> Dict:
        """Get detailed information about a specific window"""
        try:
            cmd = ["tmux", "display-message", "-t", f"{session_name}:{window_index}", "-p", 
                   "#{window_name}:#{window_active}:#{window_panes}:#{window_layout}"]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            if result.stdout.strip():
                parts = result.stdout.strip().split(':')
                return {
                    "name": parts[0],
                    "active": parts[1] == '1',
                    "panes": int(parts[2]),
                    "layout": parts[3],
                    "content": self.capture_window_content(session_name, window_index)
                }
        except subprocess.CalledProcessError as e:
            return {"error": f"Could not get window info: {e}"}
    
    def send_keys_to_window(self, session_name: str, window_index: int, keys: str, confirm: bool = True) -> bool:
        """
        安全地向 tmux 窗口发送按键序列
        
        这是一个关键的交互方法，用于向运行中的程序发送输入。
        设计为高安全性，默认需要用户确认，防止意外操作。
        
        参数:
            session_name (str): 目标会话名称
            window_index (int): 目标窗口索引
            keys (str): 要发送的按键序列（支持 tmux 按键格式，如 'C-c', 'Enter' 等）
            confirm (bool): 是否需要用户确认，默认 True
            
        返回:
            bool: 操作是否成功执行
            
        安全机制:
            - 在安全模式下会显示要执行的操作并请求确认
            - 用户必须输入 'yes' 才能继续执行
            - 如果用户拒绝或命令失败，返回 False
            
        支持的按键格式:
            - 普通文本：直接输入字符
            - 控制键：'C-c' (Ctrl+C), 'C-d' (Ctrl+D)
            - 特殊键：'Enter', 'Tab', 'Space'
            - 功能键：'F1', 'F2' 等
            
        使用示例:
            # 发送文本（需要确认）
            orchestrator.send_keys_to_window("dev", 0, "ls -la")
            
            # 发送 Ctrl+C（跳过确认）
            orchestrator.send_keys_to_window("dev", 0, "C-c", confirm=False)
        """
        # 安全检查：在安全模式下需要用户明确确认
        if self.safety_mode and confirm:
            print(f"SAFETY CHECK: About to send '{keys}' to {session_name}:{window_index}")
            response = input("Confirm? (yes/no): ")
            if response.lower() != 'yes':  # 必须输入完整的 'yes' 才能继续
                print("Operation cancelled")
                return False
        
        try:
            cmd = ["tmux", "send-keys", "-t", f"{session_name}:{window_index}", keys]
            subprocess.run(cmd, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Error sending keys: {e}")
            return False
    
    def send_command_to_window(self, session_name: str, window_index: int, command: str, confirm: bool = True) -> bool:
        """
        向窗口发送完整命令（自动添加回车执行）
        
        这是 send_keys_to_window 的便利包装方法，专门用于发送需要执行的命令。
        自动在命令后添加回车键，使命令立即执行。
        
        参数:
            session_name (str): 目标会话名称
            window_index (int): 目标窗口索引
            command (str): 要执行的命令字符串
            confirm (bool): 是否需要用户确认，默认 True
            
        返回:
            bool: 命令是否成功发送和执行
            
        执行流程:
        1. 首先发送命令文本（可能需要用户确认）
        2. 如果文本发送成功，自动发送回车键执行命令
        3. 两个步骤都成功才返回 True
        
        与 send_keys_to_window 的区别:
        - 专门用于命令执行场景
        - 自动处理回车键发送
        - 更适合脚本自动化场景
        
        使用示例:
            # 执行 shell 命令
            orchestrator.send_command_to_window("dev", 0, "python --version")
            
            # 启动开发服务器
            orchestrator.send_command_to_window("dev", 0, "npm run dev")
        """
        # 分两步执行：1) 发送命令文本 2) 发送回车键执行
        if not self.send_keys_to_window(session_name, window_index, command, confirm):
            return False
        # 发送回车键执行命令，C-m 是 tmux 中回车键的表示法
        try:
            cmd = ["tmux", "send-keys", "-t", f"{session_name}:{window_index}", "C-m"]
            subprocess.run(cmd, check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Error sending Enter key: {e}")
            return False
    
    def get_all_windows_status(self) -> Dict:
        """
        获取所有会话中所有窗口的完整状态信息
        
        这是一个综合性的状态收集方法，为系统监控和分析提供完整的数据快照。
        包含会话信息、窗口详情和实时内容。
        
        返回:
            Dict: 包含以下结构的状态字典:
            {
                "timestamp": "2024-xx-xx ISO 时间戳",
                "sessions": [
                    {
                        "name": "会话名",
                        "attached": true/false,
                        "windows": [
                            {
                                "index": 窗口索引,
                                "name": "窗口名",
                                "active": true/false,
                                "info": {详细窗口信息，包含内容}
                            }
                        ]
                    }
                ]
            }
            
        数据用途:
        - 系统监控仪表板显示
        - AI 代理状态分析
        - 问题诊断和调试
        - 历史状态记录和比较
        
        性能考虑:
        - 此方法会调用多个 tmux 命令，可能耗时较长
        - 在高频调用场景下建议添加缓存机制
        - 窗口内容捕获受 max_lines_capture 限制
        """
        sessions = self.get_tmux_sessions()
        status = {
            "timestamp": datetime.now().isoformat(),
            "sessions": []
        }
        
        # 遍历所有会话，构建完整的状态数据结构
        for session in sessions:
            session_data = {
                "name": session.name,
                "attached": session.attached,
                "windows": []  # 初始化空的窗口列表
            }
            
            # 为每个窗口获取详细信息（包括内容快照）
            for window in session.windows:
                window_info = self.get_window_info(session.name, window.window_index)
                window_data = {
                    "index": window.window_index,
                    "name": window.window_name,
                    "active": window.active,
                    "info": window_info  # 包含窗口内容和详细信息
                }
                session_data["windows"].append(window_data)
            
            status["sessions"].append(session_data)
        
        return status
    
    def find_window_by_name(self, window_name: str) -> List[Tuple[str, int]]:
        """Find windows by name across all sessions"""
        sessions = self.get_tmux_sessions()
        matches = []
        
        # 在所有会话和窗口中搜索匹配的窗口名称
        for session in sessions:
            for window in session.windows:
                # 使用不区分大小写的部分匹配
                if window_name.lower() in window.window_name.lower():
                    matches.append((session.name, window.window_index))  # 返回 (session, window_index) 元组
        
        return matches
    
    def create_monitoring_snapshot(self) -> str:
        """
        创建用于 Claude AI 分析的综合监控快照
        
        这是专门为 AI 代理设计的格式化报告生成方法。将复杂的系统状态
        转换为人类和 AI 都易于理解的文本格式。
        
        返回:
            str: 格式化的文本报告，包含：
            - 报告头部（时间戳、分隔符）
            - 每个会话的详细信息
            - 每个窗口的状态和最近输出
            - 清晰的层次结构和视觉分隔
            
        报告格式特点:
        - 使用分隔线和缩进提高可读性
        - 突出显示活动窗口和连接状态
        - 只显示最近10行输出，避免信息过载
        - 过滤空白行，专注于有效内容
        
        典型用途:
        - Claude AI 代理状态分析
        - 问题诊断报告
        - 系统健康检查
        - 日志记录和历史追踪
        
        使用建议:
        - 定期生成快照进行状态对比
        - 在问题发生时立即生成快照保存现场
        - 可配合日志系统自动化监控
        """
        status = self.get_all_windows_status()
        
        # Format for Claude consumption
        snapshot = f"Tmux Monitoring Snapshot - {status['timestamp']}\n"
        snapshot += "=" * 50 + "\n\n"
        
        # 遍历所有会话，生成格式化的文本报告
        for session in status['sessions']:
            # 会话头部：显示会话名和连接状态
            snapshot += f"Session: {session['name']} ({'ATTACHED' if session['attached'] else 'DETACHED'})\n"
            snapshot += "-" * 30 + "\n"  # 分隔线
            
            # 窗口列表：显示每个窗口的基本信息
            for window in session['windows']:
                snapshot += f"  Window {window['index']}: {window['name']}"
                if window['active']:  # 标记当前活跃窗口
                    snapshot += " (ACTIVE)"
                snapshot += "\n"
                
                # 如果窗口有内容，显示最近的输出
                if 'content' in window['info']:
                    # 只显示最后10行，避免信息过载
                    content_lines = window['info']['content'].split('\n')
                    recent_lines = content_lines[-10:] if len(content_lines) > 10 else content_lines
                    snapshot += "    Recent output:\n"
                    for line in recent_lines:
                        if line.strip():  # 过滤空行，只显示有内容的行
                            snapshot += f"    | {line}\n"  # 使用 '|' 作为缩进标记
                snapshot += "\n"  # 窗口间的分隔
        
        return snapshot

def main():
    """
    主函数 - 演示基本用法
    
    当直接运行此脚本时，会展示系统的基本功能：
    获取并打印所有 tmux 会话的状态信息。
    """
    orchestrator = TmuxOrchestrator()
    status = orchestrator.get_all_windows_status()
    print(json.dumps(status, indent=2))


# ============================================================================
# 使用示例和最佳实践
# ============================================================================

"""
使用示例：

1. 基本监控 - 获取系统状态
    ```python
    from tmux_utils import TmuxOrchestrator
    
    # 初始化编排器
    orchestrator = TmuxOrchestrator()
    
    # 获取所有会话信息
    sessions = orchestrator.get_tmux_sessions()
    for session in sessions:
        print(f"会话: {session.name}, 连接状态: {session.attached}")
        for window in session.windows:
            print(f"  窗口 {window.window_index}: {window.window_name}")
    
    # 生成监控快照
    snapshot = orchestrator.create_monitoring_snapshot()
    print(snapshot)
    ```

2. 窗口内容监控 - 实时查看程序输出
    ```python
    # 捕获特定窗口的最近输出
    content = orchestrator.capture_window_content("ai-session", 0, 100)
    print("最近的输出:")
    print(content)
    
    # 监控多个窗口的状态
    status = orchestrator.get_all_windows_status()
    for session_data in status['sessions']:
        for window_data in session_data['windows']:
            if 'error' in window_data.get('info', {}):
                print(f"窗口 {window_data['name']} 出现错误!")
    ```

3. 安全的命令交互 - 向程序发送指令
    ```python
    # 发送简单命令（需要确认）
    success = orchestrator.send_command_to_window("dev-session", 0, "ls -la")
    if success:
        print("命令发送成功")
    
    # 发送紧急停止命令（跳过确认）
    orchestrator.send_keys_to_window("dev-session", 0, "C-c", confirm=False)
    
    # 关闭安全模式进行批量操作
    orchestrator.safety_mode = False
    commands = ["cd /home/user", "python script.py", "exit"]
    for cmd in commands:
        orchestrator.send_command_to_window("automation", 0, cmd, confirm=False)
    ```

4. AI 代理协调 - 多代理管理
    ```python
    # 查找 Claude 代理窗口
    claude_windows = orchestrator.find_window_by_name("claude")
    for session_name, window_index in claude_windows:
        print(f"找到 Claude 代理: {session_name}:{window_index}")
        
        # 获取代理当前状态
        content = orchestrator.capture_window_content(session_name, window_index, 50)
        
        # 发送任务指令
        task = "请分析最新的代码提交并生成测试计划"
        orchestrator.send_command_to_window(session_name, window_index, task)
    ```

5. 系统监控和自动化 - 定期检查
    ```python
    import time
    import json
    from datetime import datetime
    
    def monitor_system():
        orchestrator = TmuxOrchestrator()
        while True:
            # 生成状态快照
            snapshot = orchestrator.create_monitoring_snapshot()
            
            # 保存到日志文件
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            with open(f"tmux_status_{timestamp}.log", "w") as f:
                f.write(snapshot)
            
            # 检查异常情况
            sessions = orchestrator.get_tmux_sessions()
            for session in sessions:
                if not session.attached:
                    print(f"警告: 会话 {session.name} 已分离")
            
            time.sleep(300)  # 5分钟检查一次
    ```

注意事项和最佳实践：

1. 安全使用指南：
   - 默认启用安全模式，避免意外操作
   - 在自动化脚本中谨慎关闭安全模式
   - 发送命令前先捕获窗口内容确认状态
   - 重要操作前备份当前会话状态

2. 性能优化建议：
   - 大量窗口时限制 max_lines_capture 的值
   - 频繁调用时考虑缓存机制
   - 避免在循环中反复获取全部状态
   - 使用 find_window_by_name 精确定位目标

3. 错误处理策略：
   - 所有方法都有异常处理，不会抛出未捕获异常
   - 检查返回值确认操作成功
   - tmux 未运行时方法会返回空结果而不是报错
   - 网络问题可能影响长时间运行的监控

4. AI 代理集成建议：
   - 为每个 AI 代理使用独立的 tmux 窗口
   - 定期生成快照供 AI 分析
   - 使用描述性的窗口名称便于识别
   - 设置合理的监控间隔避免过度负载

5. 调试和故障排除：
   - 使用 tmux list-sessions 手动确认会话存在
   - 检查 tmux 版本兼容性（推荐 3.0+）
   - 长时间运行时注意内存使用情况
   - 保存重要的监控日志用于问题分析

6. 扩展开发建议：
   - 继承 TmuxOrchestrator 类添加专用功能
   - 使用数据类扩展窗口和会话信息
   - 集成消息队列实现异步通信
   - 添加 Web 界面进行可视化监控
"""

if __name__ == "__main__":
    main()