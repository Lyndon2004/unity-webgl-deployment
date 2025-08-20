#!/bin/bash

# 获取脚本所在目录的父目录（项目根目录）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_BUILD_DIR="$PROJECT_ROOT/unity-build"
LOGS_DIR="$PROJECT_ROOT/logs"
CONFIGS_DIR="$PROJECT_ROOT/configs"

# 检查是否为交互式模式
INTERACTIVE_MODE=""
if [ "$1" = "interactive" ]; then
    INTERACTIVE_MODE="true"
fi

echo "🔒 启动高安全性 Unity WebGL 公网部署"
echo "===================================="
echo "📁 项目目录: $PROJECT_ROOT"
echo "🔧 调试信息: 参数1='$1'"

# 创建必要的目录
mkdir -p "$LOGS_DIR" "$CONFIGS_DIR"

# 检查依赖
if [ ! -f "$UNITY_BUILD_DIR/secure_unity_server.py" ]; then
    echo "❌ 错误: 找不到安全服务器文件"
    echo "请确保 Unity WebGL 文件在 $UNITY_BUILD_DIR 目录下"
    exit 1
fi

if [ ! -f ~/ngrok ]; then
    echo "❌ 错误: 找不到 ngrok"
    exit 1
fi

# 停止现有服务
echo "🛑 停止现有服务..."
pkill -f "secure_unity_server.py" 2>/dev/null
pkill -f "unity_ngrok_server.py" 2>/dev/null
pkill -f "ngrok" 2>/dev/null
sleep 2

# 安全级别配置
if [ "$1" = "configured" ]; then
    # 配置模式，从配置文件读取
    CONFIG_FILE="/tmp/unity_security_config.sh"
    echo "🔍 检查配置文件: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        echo "   ✅ 配置文件存在，正在读取..."
        source "$CONFIG_FILE"
        echo "   📋 读取到的配置："
        echo "      安全级别: $security_level"
        echo "      额外IP: $additional_ips"
        echo "      时间限制: $time_limit"
        echo ""
        echo "🔐 使用配置的安全级别 $security_level"
        if [ -n "$additional_ips" ]; then
            echo "   📝 自定义IP白名单: $additional_ips"
        fi
        if [ -n "$time_limit" ] && [ "$security_level" = "3" ]; then
            echo "   ⏰ 时间限制: $time_limit 分钟"
        fi
    else
        echo "   ❌ 配置文件不存在，使用环境变量..."
        # 备用：使用环境变量
        security_level=${SECURITY_LEVEL_OVERRIDE:-1}
        additional_ips="$ADDITIONAL_IPS_OVERRIDE"
        time_limit=${TIME_LIMIT_OVERRIDE:-60}
        echo ""
        echo "🔐 使用环境变量配置的安全级别 $security_level"
    fi
elif [ "$INTERACTIVE_MODE" = "true" ]; then
    echo ""
    echo "🔐 安全配置选项:"
    echo "1. 基础安全 (访问令牌 + 频率限制)"
    echo "2. 增强安全 (基础安全 + IP白名单)"  
    echo "3. 最高安全 (增强安全 + 时间限制)"
    read -p "请选择安全级别 (1-3，默认1): " security_level
    security_level=${security_level:-1}
else
    # 默认进入交互式选择模式
    echo ""
    echo "🔐 请选择安全配置："
    echo "1. 基础安全 (访问令牌 + 频率限制) - 无IP限制"
    echo "2. 增强安全 (基础安全 + IP白名单) - 需要配置IP"  
    echo "3. 最高安全 (增强安全 + 时间限制) - 需要配置IP和时间"
    echo ""
    read -p "请选择安全级别 (1-3): " security_level
    
    # 验证输入
    case $security_level in
        1|2|3) ;;
        *) 
            echo "❌ 无效选择，请输入1、2或3"
            exit 1
            ;;
    esac
fi

# 设置安全选项
case $security_level in
    1)
        echo ""
        echo "📝 配置基础安全..."
        # 修改安全级别为1
        sed -i 's/SECURITY_LEVEL = [0-9]/SECURITY_LEVEL = 1/' "$UNITY_BUILD_DIR/secure_unity_server.py"
        echo "   ✅ 已设置为基础安全 (无IP白名单限制)"
        ;;
    2)
        echo ""
        echo "📝 配置增强安全 (IP白名单)..."
        # 修改安全级别为2
        sed -i 's/SECURITY_LEVEL = [0-9]/SECURITY_LEVEL = 2/' "$UNITY_BUILD_DIR/secure_unity_server.py"
        
        # 获取本地IP
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        PUBLIC_IP=$(curl -s https://api.ipify.org || echo "无法获取")
        
        echo "当前默认白名单IP："
        echo "   - $PUBLIC_IP (您的公网IP)"
        echo "   - $LOCAL_IP (您的本地IP)"
        echo "   - 127.0.0.1, ::1 (本地回环地址)"
        echo ""
        echo "⚠️  重要提醒: 如果您的实际IP不在上述列表中，您将无法访问服务！"
        echo "请添加您的真实IP地址到白名单。"
        echo ""
        read -p "请输入您的IP地址 (多个用空格分隔): " additional_ips
        
        if [ -n "$additional_ips" ]; then
            echo "🔧 添加额外IP到白名单..."
            # 构建新的IP列表
            new_ips="\"$PUBLIC_IP\", \"$LOCAL_IP\", \"127.0.0.1\", \"::1\""
            for ip in $additional_ips; do
                new_ips="$new_ips, \"$ip\""
            done
            
            # 更新IP白名单
            sed -i "s/ALLOWED_IPS = {[^}]*}/ALLOWED_IPS = {$new_ips}/" "$UNITY_BUILD_DIR/secure_unity_server.py"
            echo "   ✅ 已添加IP: $additional_ips"
        else
            echo "   ⚠️  仅使用默认IP白名单，请确保您的IP在列表中"
        fi
        ;;
    3)
        echo ""
        echo "📝 配置最高安全 (时间限制)..."
        # 修改安全级别为3
        sed -i 's/SECURITY_LEVEL = [0-9]/SECURITY_LEVEL = 3/' "$UNITY_BUILD_DIR/secure_unity_server.py"
        
        read -p "服务运行时长(分钟，默认60): " time_limit
        time_limit=${time_limit:-60}
        
        # 获取本地IP
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        PUBLIC_IP=$(curl -s https://api.ipify.org || echo "无法获取")
        
        echo "当前默认白名单IP："
        echo "   - $PUBLIC_IP (您的公网IP)"
        echo "   - $LOCAL_IP (您的本地IP)"
        echo "   - 127.0.0.1, ::1 (本地回环地址)"
        echo ""
        echo "⚠️  重要提醒: 如果您的实际IP不在上述列表中，您将无法访问服务！"
        echo "请添加您的真实IP地址到白名单。"
        echo ""
        read -p "请输入您的IP地址 (多个用空格分隔): " additional_ips
        
        # 更新时间限制
        sed -i "s/TIME_LIMIT_MINUTES = [0-9]*/TIME_LIMIT_MINUTES = $time_limit/" "$UNITY_BUILD_DIR/secure_unity_server.py"
        
        if [ -n "$additional_ips" ]; then
            echo "🔧 添加额外IP到白名单..."
            # 构建新的IP列表
            new_ips="\"$PUBLIC_IP\", \"$LOCAL_IP\", \"127.0.0.1\", \"::1\""
            for ip in $additional_ips; do
                new_ips="$new_ips, \"$ip\""
            done
            
            # 更新IP白名单
            sed -i "s/ALLOWED_IPS = {[^}]*}/ALLOWED_IPS = {$new_ips}/" "$UNITY_BUILD_DIR/secure_unity_server.py"
            echo "   ✅ 已添加IP: $additional_ips"
        else
            echo "   ✅ 使用默认IP白名单"
        fi
        
        echo "   ⏰ 服务将在 ${time_limit} 分钟后自动停止"
        ;;
    *)
        echo "❌ 无效选择，使用默认安全级别1"
        security_level=1
        sed -i 's/SECURITY_LEVEL = [0-9]/SECURITY_LEVEL = 1/' "$UNITY_BUILD_DIR/secure_unity_server.py"
        ;;
esac

# 启动安全服务器
echo ""
echo "🚀 启动安全服务器..."
cd "$UNITY_BUILD_DIR"

# 启动服务器
python3 secure_unity_server.py > "$LOGS_DIR/secure_unity.log" 2>&1 &
FLASK_PID=$!
echo "✅ 安全服务器已启动 (PID: $FLASK_PID)"

# 等待服务器启动
echo "⏳ 等待服务器初始化..."
sleep 5

# 测试本地服务器
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ 安全服务器运行正常"
else
    echo "❌ 安全服务器启动失败，请检查日志"
    echo "日志位置: $LOGS_DIR/secure_unity.log"
    exit 1
fi

# 启动 ngrok 隧道
echo "🌐 启动 ngrok 隧道..."
~/ngrok http 3000 > "$LOGS_DIR/ngrok_secure.log" 2>&1 &
NGROK_PID=$!

echo "⏳ 等待 ngrok 连接..."
sleep 8

# 获取公网地址和访问令牌
PUBLIC_URL=""
for i in {1..10}; do
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^"]*ngrok-free\.app' | head -1)
    if [ -n "$PUBLIC_URL" ]; then
        break
    fi
    sleep 2
done

if [ -f "$UNITY_BUILD_DIR/access_tokens.txt" ]; then
    ACCESS_TOKEN=$(grep "访问令牌:" "$UNITY_BUILD_DIR/access_tokens.txt" | cut -d' ' -f2)
    ADMIN_TOKEN=$(grep "管理员令牌:" "$UNITY_BUILD_DIR/access_tokens.txt" | cut -d' ' -f2)
else
    echo "❌ 访问令牌文件不存在"
    exit 1
fi

# 保存部署信息
cat > "$CONFIGS_DIR/deployment_info.txt" << EOF
部署时间: $(date)
公网地址: $PUBLIC_URL
访问链接: $PUBLIC_URL/?token=$ACCESS_TOKEN
管理面板: $PUBLIC_URL/api/stats?admin_token=$ADMIN_TOKEN
Flask PID: $FLASK_PID
ngrok PID: $NGROK_PID
安全级别: $security_level
项目目录: $PROJECT_ROOT
EOF

echo ""
echo "🎉 安全部署完成！"
echo "=================="

if [ -n "$PUBLIC_URL" ]; then
    echo "🌐 公网访问地址: $PUBLIC_URL/?token=$ACCESS_TOKEN"
    echo "📊 管理员面板: $PUBLIC_URL/api/stats?admin_token=$ADMIN_TOKEN"
    echo ""
    echo "🔐 访问信息:"
    echo "   访问令牌: $ACCESS_TOKEN"
    echo "   管理员令牌: $ADMIN_TOKEN"
    echo "   (令牌已保存到 $UNITY_BUILD_DIR/access_tokens.txt)"
else
    echo "⚠️  无法获取公网地址，请检查 ngrok 状态"
    echo "本地访问: http://localhost:3000/?token=$ACCESS_TOKEN"
fi

echo ""
echo "🛡️ 安全功能已启用:"
echo "   ✅ 访问令牌验证"
echo "   ✅ 频率限制 (30/分钟, 200/小时)"
echo "   ✅ IP封禁机制 (5次失败尝试)"
echo "   ✅ IP白名单保护"
echo "   ✅ 路径安全检查"
echo "   ✅ 访问日志记录"
echo "   ✅ 安全HTTP头"

# 时间限制
if [ "$security_level" = "3" ]; then
    echo "   ✅ 时间限制: ${time_limit}分钟"
    echo ""
    echo "⏰ 服务将在 ${time_limit} 分钟后自动停止"
    
    # 创建定时停止任务
    (sleep $((time_limit * 60)) && kill $FLASK_PID $NGROK_PID && echo "⏰ 服务已按计划停止") &
fi

echo ""
echo "📋 管理命令:"
echo "   查看访问日志: tail -f $LOGS_DIR/secure_unity.log"
echo "   查看ngrok日志: tail -f $LOGS_DIR/ngrok_secure.log" 
echo "   停止服务: $PROJECT_ROOT/scripts/stop_secure_unity.sh"
if [ -n "$PUBLIC_URL" ]; then
    echo "   查看实时统计: curl -s \"$PUBLIC_URL/api/stats?admin_token=$ADMIN_TOKEN\" | python3 -m json.tool"
fi

# 保存管理信息到项目目录
cat > "$CONFIGS_DIR/secure_deployment_info.txt" << EOF
部署时间: $(date)
公网地址: $PUBLIC_URL
访问链接: $PUBLIC_URL/?token=$ACCESS_TOKEN
管理面板: $PUBLIC_URL/api/stats?admin_token=$ADMIN_TOKEN
Flask PID: $FLASK_PID
ngrok PID: $NGROK_PID
安全级别: $security_level
项目目录: $PROJECT_ROOT
EOF

echo ""
echo "📄 部署信息已保存到: $CONFIGS_DIR/secure_deployment_info.txt"

if [ "$security_level" != "3" ]; then
    echo ""
    echo "⚠️  重要提醒:"
    echo "   - 请妥善保管访问令牌"
    echo "   - 仅分享给需要访问的人员"
    echo "   - 定期检查访问日志"
    echo "   - 使用完毕请立即停止服务"
    echo ""
    echo "✅ 服务正在后台运行，您可以关闭此终端"
    echo "💡 使用 stop_secure_unity.sh 停止服务"
fi
