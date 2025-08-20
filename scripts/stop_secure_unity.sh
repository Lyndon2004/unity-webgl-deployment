#!/bin/bash

# Unity WebGL 部署 - 停止服务脚本

# 获取脚本所在目录的父目录（项目根目录）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_BUILD_DIR="$PROJECT_ROOT/unity-build"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

echo "🛑 停止 Unity WebGL 安全部署"
echo "=========================="

# 读取部署信息
DEPLOYMENT_INFO="$CONFIGS_DIR/deployment_info.txt"
echo "📋 读取部署信息: $DEPLOYMENT_INFO"

if [ -f "$DEPLOYMENT_INFO" ]; then
    FLASK_PID=$(grep "Flask PID:" "$DEPLOYMENT_INFO" 2>/dev/null | cut -d' ' -f3)
    NGROK_PID=$(grep "ngrok PID:" "$DEPLOYMENT_INFO" 2>/dev/null | cut -d' ' -f3)
    
    echo "🔍 发现进程:"
    if [ -n "$FLASK_PID" ]; then
        echo "   Flask服务器 PID: $FLASK_PID"
    fi
    if [ -n "$NGROK_PID" ]; then
        echo "   ngrok隧道 PID: $NGROK_PID"
    fi
    
    # 停止Flask服务器
    if [ -n "$FLASK_PID" ] && kill -0 $FLASK_PID 2>/dev/null; then
        echo "🛑 停止 Flask 服务器 (PID: $FLASK_PID)..."
        kill $FLASK_PID
        sleep 2
        if ! kill -0 $FLASK_PID 2>/dev/null; then
            echo "   ✅ Flask 服务器已停止"
        else
            echo "   ⚠️  Flask 服务器未响应，尝试强制终止..."
            kill -9 $FLASK_PID 2>/dev/null
            sleep 1
            if ! kill -0 $FLASK_PID 2>/dev/null; then
                echo "   ✅ Flask 服务器已强制停止"
            else
                echo "   ❌ 无法停止 Flask 服务器"
            fi
        fi
    fi
    
    # 停止ngrok隧道
    if [ -n "$NGROK_PID" ] && kill -0 $NGROK_PID 2>/dev/null; then
        echo "🛑 停止 ngrok 隧道 (PID: $NGROK_PID)..."
        kill $NGROK_PID
        sleep 2
        if ! kill -0 $NGROK_PID 2>/dev/null; then
            echo "   ✅ ngrok 隧道已停止"
        else
            echo "   ⚠️  ngrok 隧道未响应，尝试强制终止..."
            kill -9 $NGROK_PID 2>/dev/null
            sleep 1
            if ! kill -0 $NGROK_PID 2>/dev/null; then
                echo "   ✅ ngrok 隧道已强制停止"
            else
                echo "   ❌ 无法停止 ngrok 隧道"
            fi
        fi
    fi
else
    echo "⚠️  找不到部署信息文件，尝试查找运行中的进程..."
fi

# 检查并停止所有相关进程
echo "🔍 检查并停止剩余相关进程..."

# 查找和停止所有Unity服务器进程
UNITY_PIDS=$(pgrep -f "secure_unity_server.py" 2>/dev/null)
if [ -n "$UNITY_PIDS" ]; then
    echo "   发现 Unity 服务器进程: $UNITY_PIDS"
    for pid in $UNITY_PIDS; do
        kill $pid 2>/dev/null
        sleep 1
    done
    
    # 检查是否仍有进程运行
    if pgrep -f "secure_unity_server.py" > /dev/null; then
        echo "   ⚠️  尝试强制终止服务器进程..."
        pkill -9 -f "secure_unity_server.py" 2>/dev/null
    fi
    
    if pgrep -f "secure_unity_server.py" > /dev/null; then
        echo "   ❌ 无法停止所有 Unity 服务器进程"
    else
        echo "   ✅ 所有 Unity 服务器进程已停止"
    fi
else
    echo "   ℹ️  未发现 Unity 服务器进程"
fi

# 查找和停止所有ngrok进程
NGROK_PIDS=$(pgrep -f "ngrok" 2>/dev/null)
if [ -n "$NGROK_PIDS" ]; then
    echo "   发现 ngrok 进程: $NGROK_PIDS"
    for pid in $NGROK_PIDS; do
        kill $pid 2>/dev/null
        sleep 1
    done
    
    # 检查是否仍有进程运行
    if pgrep -f "ngrok" > /dev/null; then
        echo "   ⚠️  尝试强制终止 ngrok 进程..."
        pkill -9 -f "ngrok" 2>/dev/null
    fi
    
    if pgrep -f "ngrok" > /dev/null; then
        echo "   ❌ 无法停止所有 ngrok 进程"
    else
        echo "   ✅ 所有 ngrok 进程已停止"
    fi
else
    echo "   ℹ️  未发现 ngrok 进程"
fi

# 验证端口状态
echo "🔍 验证端口状态..."
if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
    echo "   ⚠️  端口 3000 仍被占用，尝试释放..."
    fuser -k 3000/tcp 2>/dev/null
    sleep 1
    if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
        echo "   ❌ 无法释放端口 3000"
    else
        echo "   ✅ 端口 3000 已释放"
    fi
else
    echo "   ✅ 端口 3000 已释放"
fi

if netstat -tlnp 2>/dev/null | grep -q ":4040 "; then
    echo "   ⚠️  端口 4040 仍被占用，尝试释放..."
    fuser -k 4040/tcp 2>/dev/null
    sleep 1
    if netstat -tlnp 2>/dev/null | grep -q ":4040 "; then
        echo "   ❌ 无法释放端口 4040"
    else
        echo "   ✅ 端口 4040 已释放"
    fi
else
    echo "   ✅ 端口 4040 已释放"
fi

# 最终状态检查
if pgrep -f "secure_unity_server.py" > /dev/null || pgrep -f "ngrok" > /dev/null; then
    echo ""
    echo "⚠️  警告: 仍有相关进程在运行"
    echo "    可以尝试手动强制终止:"
    echo "    pkill -9 -f \"secure_unity_server.py\" && pkill -9 -f \"ngrok\""
else
    echo ""
    echo "✅ Unity WebGL 安全部署已完全停止"
fi

echo ""
echo "📋 后续操作:"
echo "   重新启动: $PROJECT_ROOT/scripts/start_secure_unity.sh"
echo "   快速重启: $PROJECT_ROOT/scripts/restart_secure_unity.sh"
echo "   查看日志: ls -la $LOGS_DIR/"

echo ""
echo "🔒 安全提醒:"
echo "   - 访问令牌在下次启动时会重新生成"
echo "   - 公网地址已不可访问"
echo "   - 所有安全日志已保存"
