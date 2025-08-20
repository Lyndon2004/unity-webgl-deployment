#!/bin/bash

# Unity WebGL 部署 - 服务状态检查脚本

# 获取脚本所在目录的父目录（项目根目录）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_BUILD_DIR="$PROJECT_ROOT/unity-build"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 显示头部
echo ""
echo -e "╔══════════════════════════════════════════════════════════════╗"
echo -e "║               Unity WebGL 服务状态检查                       ║"
echo -e "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 检查Flask服务状态
echo -e "[INFO] 检查 Flask 服务器状态..."
FLASK_RUNNING=false
FLASK_PID=$(pgrep -f "secure_unity_server.py" | head -1)

if [ -n "$FLASK_PID" ]; then
    FLASK_RUNNING=true
    echo -e "[${GREEN}✓${NC}] Flask 服务器运行中 (PID: $FLASK_PID)"
    
    # 检查启动时间
    if command -v ps &> /dev/null; then
        FLASK_START_TIME=$(ps -o lstart= -p $FLASK_PID 2>/dev/null)
        if [ -n "$FLASK_START_TIME" ]; then
            echo -e "[INFO] 启动时间: $FLASK_START_TIME"
        fi
    fi
else
    echo -e "[${RED}✗${NC}] Flask 服务器未运行"
fi

# 检查ngrok状态
echo ""
echo -e "[INFO] 检查 ngrok 隧道状态..."
NGROK_RUNNING=false
NGROK_PID=$(pgrep -f "ngrok" | head -1)

if [ -n "$NGROK_PID" ]; then
    NGROK_RUNNING=true
    echo -e "[${GREEN}✓${NC}] ngrok 隧道运行中 (PID: $NGROK_PID)"
    
    # 尝试获取公网地址
    if curl -s http://localhost:4040/api/tunnels > /dev/null; then
        PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*ngrok-free\.app' | head -1)
        
        if [ -n "$PUBLIC_URL" ]; then
            echo -e "[${GREEN}✓${NC}] 公网地址: $PUBLIC_URL"
            
            # 测试公网连通性
            echo -e "[INFO] 测试公网连通性..."
            if curl -s "$PUBLIC_URL/health" > /dev/null; then
                echo -e "[${GREEN}✓${NC}] 公网访问正常"
            else
                echo -e "[${RED}✗${NC}] 公网访问异常"
            fi
        else
            echo -e "[${RED}✗${NC}] 无法获取公网地址"
        fi
    else
        echo -e "[${RED}✗${NC}] ngrok API 无法访问"
    fi
else
    echo -e "[${RED}✗${NC}] ngrok 隧道未运行"
fi

# 检查端口状态
echo ""
echo -e "[INFO] 检查端口状态..."
if command -v netstat &> /dev/null; then
    # 检查端口3000（Flask）
    if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
        echo -e "[${GREEN}✓${NC}] 端口 3000 已占用"
        PORT_3000_PID=$(netstat -tlnp 2>/dev/null | grep ":3000 " | awk '{print $7}' | cut -d/ -f1 | head -1)
        if [ -n "$PORT_3000_PID" ]; then
            PORT_3000_PROC=$(ps -p $PORT_3000_PID -o comm= 2>/dev/null)
            echo -e "[INFO] 占用进程: $PORT_3000_PID/$PORT_3000_PROC"
        fi
    else
        echo -e "[${RED}✗${NC}] 端口 3000 未占用"
    fi
    
    # 检查端口4040（ngrok）
    if netstat -tlnp 2>/dev/null | grep -q ":4040 "; then
        echo -e "[${GREEN}✓${NC}] ngrok 监控端口 4040 已开启"
    else
        echo -e "[${RED}✗${NC}] ngrok 监控端口 4040 未开启"
    fi
else
    echo -e "[${YELLOW}!${NC}] 无法检查端口状态（需要netstat命令）"
fi

# 检查日志文件
echo ""
echo -e "[INFO] 检查日志文件..."
if [ -f "$LOGS_DIR/secure_unity.log" ]; then
    LOG_SIZE=$(du -h "$LOGS_DIR/secure_unity.log" | cut -f1)
    LOG_LINES=$(wc -l < "$LOGS_DIR/secure_unity.log")
    echo -e "[${GREEN}✓${NC}] Flask 日志文件存在 (大小: $LOG_SIZE, 行数: $LOG_LINES)"
    
    # 检查日志中的最新错误
    if grep -q "ERROR" "$LOGS_DIR/secure_unity.log"; then
        LAST_ERROR=$(grep "ERROR" "$LOGS_DIR/secure_unity.log" | tail -1)
        echo -e "[${YELLOW}!${NC}] 最近错误: $LAST_ERROR"
    fi
else
    echo -e "[${YELLOW}!${NC}] Flask 日志文件不存在"
fi

# 检查系统资源
echo ""
echo -e "[INFO] 系统资源状态..."
if command -v top &> /dev/null; then
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    echo -e "[INFO] CPU 使用率: $CPU_USAGE"
fi

if command -v free &> /dev/null; then
    MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')
    echo -e "[INFO] 内存使用率: $MEM_USAGE"
fi

if command -v df &> /dev/null; then
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}')
    DISK_VALUE=${DISK_USAGE%\%}
    if [ "$DISK_VALUE" -gt 90 ]; then
        echo -e "[${RED}✗${NC}] 磁盘空间不足: $DISK_USAGE"
    elif [ "$DISK_VALUE" -gt 80 ]; then
        echo -e "[${YELLOW}!${NC}] 磁盘空间警告: $DISK_USAGE"
    else
        echo -e "[${GREEN}✓${NC}] 磁盘空间充足: $DISK_USAGE"
    fi
fi

# 检查网络连接
echo ""
echo -e "[INFO] 网络连接状态..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "[${GREEN}✓${NC}] 外网连接正常"
else
    echo -e "[${RED}✗${NC}] 外网连接异常"
fi

# 总体状态
echo ""
if $FLASK_RUNNING && $NGROK_RUNNING; then
    echo -e "[${GREEN}✓${NC}] 服务运行正常"
    if [ -n "$PUBLIC_URL" ]; then
        # 尝试获取访问令牌
        if [ -f "$UNITY_BUILD_DIR/access_tokens.txt" ]; then
            ACCESS_TOKEN=$(grep "访问令牌:" "$UNITY_BUILD_DIR/access_tokens.txt" 2>/dev/null | cut -d' ' -f2)
            if [ -n "$ACCESS_TOKEN" ]; then
                echo -e "[INFO] 访问链接: $PUBLIC_URL/?token=$ACCESS_TOKEN"
            fi
        fi
    fi
elif $FLASK_RUNNING || $NGROK_RUNNING; then
    echo -e "[${YELLOW}!${NC}] ⚠️  服务部分运行"
    echo -e "[INFO] 运行 'unity restart' 重启服务"
else
    echo -e "[${RED}!${NC}] ❌ 服务未运行"
    echo -e "[INFO] 运行 'unity start' 启动服务"
fi

echo ""
echo -e "[INFO] 💡 常用命令："
echo -e "[INFO]    查看实时日志: tail -f $LOGS_DIR/secure_unity.log"
echo -e "[INFO]    重启服务: unity restart"
echo -e "[INFO]    查看详细状态: unity info"
