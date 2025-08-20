#!/bin/bash

# Unity WebGL 部署 - 安装脚本
# 此脚本安装所有必要的依赖和ngrok

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMP_DIR="/tmp/unity_webgl_install"

echo "🚀 Unity WebGL 部署工具 - 安装脚本"
echo "=================================="
echo ""
echo "📁 项目目录: $PROJECT_ROOT"

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 检查Python和pip
echo "🔍 检查Python和pip..."
if command -v python3 &> /dev/null; then
    echo "✅ Python已安装"
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    echo "✅ Python已安装"
    PYTHON_CMD="python"
else
    echo "❌ 未找到Python，请先安装Python 3.6+"
    exit 1
fi

echo "Python版本: $($PYTHON_CMD --version)"

# 检查pip
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo "❌ 未找到pip，请安装pip"
    exit 1
fi

echo "✅ pip已安装"

# 安装Python依赖
echo ""
echo "📦 安装Python依赖..."
$PIP_CMD install flask flask-limiter flask-cors
echo "✅ Flask和依赖已安装"

# 检查ngrok
echo ""
echo "🔍 检查ngrok..."

if [ -f ~/ngrok ] || command -v ngrok &> /dev/null; then
    echo "✅ ngrok已安装"
else
    echo "📥 下载并安装ngrok..."
    
    # 检测操作系统和架构
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    
    case "$OS" in
        linux)
            if [ "$ARCH" == "x86_64" ]; then
                NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
            elif [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
                NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
            else
                NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.tgz"
            fi
            ;;
        darwin)
            if [ "$ARCH" == "x86_64" ]; then
                NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip"
            else
                NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip"
            fi
            ;;
        *)
            echo "❌ 不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    # 下载ngrok
    echo "📥 从 $NGROK_URL 下载 ngrok..."
    curl -o "$TEMP_DIR/ngrok.tgz" -L "$NGROK_URL"
    
    # 解压ngrok
    echo "📦 解压ngrok..."
    mkdir -p "$TEMP_DIR/ngrok"
    tar -xzf "$TEMP_DIR/ngrok.tgz" -C "$TEMP_DIR/ngrok"
    
    # 安装ngrok
    echo "📦 安装ngrok到主目录..."
    cp "$TEMP_DIR/ngrok/ngrok" ~/ngrok
    chmod +x ~/ngrok
    
    echo "✅ ngrok已安装到 ~/ngrok"
    
    # 设置环境变量
    if [ ! -f ~/.bashrc ] || ! grep -q "export PATH=\$PATH:~" ~/.bashrc; then
        echo 'export PATH=$PATH:~' >> ~/.bashrc
        echo "✅ 已添加ngrok到PATH环境变量"
    fi
fi

# 配置ngrok
echo ""
echo "🔧 配置ngrok..."
echo "请输入您的ngrok authtoken (从 https://dashboard.ngrok.com 获取):"
read -p "authtoken: " NGROK_TOKEN

if [ -n "$NGROK_TOKEN" ]; then
    ~/ngrok config add-authtoken "$NGROK_TOKEN"
    echo "✅ ngrok已配置"
else
    echo "⚠️  未提供authtoken，请稍后手动配置: ~/ngrok config add-authtoken YOUR_TOKEN"
fi

# 创建必要的目录
echo ""
echo "📁 创建必要的目录..."
mkdir -p "$PROJECT_ROOT/unity-build"
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/backups"
mkdir -p "$PROJECT_ROOT/configs"

echo "✅ 目录结构已创建"

# 创建配置文件
echo ""
echo "📝 创建配置文件..."
cat > "$PROJECT_ROOT/configs/server_config.sh" << 'EOL'
#!/bin/bash
# Unity WebGL部署配置

# 服务器配置
SERVER_PORT=3000

# 安全配置
DEFAULT_SECURITY_LEVEL=1  # 1=基础, 2=增强, 3=最高

# ngrok配置
USE_CUSTOM_DOMAIN=false
CUSTOM_DOMAIN=""

# 以下IP会被添加到白名单（安全级别2和3时生效）
# 格式: "ip1" "ip2" "ip3"
ALLOWED_IPS=("127.0.0.1" "::1")

# 添加您的IP
PUBLIC_IP=$(curl -s https://api.ipify.org)
if [ -n "$PUBLIC_IP" ]; then
    ALLOWED_IPS+=("$PUBLIC_IP")
fi

# 将您的IP添加到配置中
echo "✅ 检测到您的公网IP: $PUBLIC_IP"
EOL

chmod +x "$PROJECT_ROOT/configs/server_config.sh"
echo "✅ 配置文件已创建"

# 添加可执行权限
echo ""
echo "🔧 设置可执行权限..."
find "$PROJECT_ROOT/bin" -type f -exec chmod +x {} \;
find "$PROJECT_ROOT/scripts" -type f -exec chmod +x {} \;
echo "✅ 可执行权限已设置"

# 创建软链接
echo ""
echo "🔗 创建快捷命令..."
if [ -d ~/bin ]; then
    ln -sf "$PROJECT_ROOT/bin/unity" ~/bin/unity
    echo "✅ 已创建命令链接: ~/bin/unity"
elif [ -d ~/.local/bin ]; then
    ln -sf "$PROJECT_ROOT/bin/unity" ~/.local/bin/unity
    echo "✅ 已创建命令链接: ~/.local/bin/unity"
else
    mkdir -p ~/.local/bin
    ln -sf "$PROJECT_ROOT/bin/unity" ~/.local/bin/unity
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
    echo "✅ 已创建命令链接: ~/.local/bin/unity"
fi

# 清理
echo ""
echo "🧹 清理临时文件..."
rm -rf "$TEMP_DIR"
echo "✅ 临时文件已清理"

# 完成
echo ""
echo "✅ Unity WebGL 部署工具安装完成!"
echo ""
echo "💡 下一步操作:"
echo "  1. 将Unity WebGL构建文件放入 $PROJECT_ROOT/unity-build/ 目录"
echo "  2. 运行 'unity start' 启动服务"
echo "  3. 访问 http://localhost:3000 测试本地访问"
echo ""
echo "📚 更多信息请查看文档: $PROJECT_ROOT/docs/"
echo ""
echo "🎮 享受您的Unity WebGL公网部署之旅!"
