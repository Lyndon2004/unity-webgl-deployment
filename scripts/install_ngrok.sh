#!/bin/bash

# Unity WebGL 部署 - ngrok安装脚本

echo "🚀 ngrok 安装工具"
echo "=================="
echo ""

# 检测操作系统和架构
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

echo "📋 系统信息:"
echo "   操作系统: $OS"
echo "   架构: $ARCH"

# 选择正确的下载URL
case "$OS" in
    linux)
        if [ "$ARCH" == "x86_64" ]; then
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
            echo "   选择: Linux 64位"
        elif [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
            echo "   选择: Linux ARM64"
        else
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.tgz"
            echo "   选择: Linux 32位"
        fi
        ;;
    darwin)
        if [ "$ARCH" == "x86_64" ]; then
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip"
            echo "   选择: macOS 64位"
        else
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-arm64.zip"
            echo "   选择: macOS ARM64"
        fi
        ;;
    *)
        echo "❌ 不支持的操作系统: $OS"
        exit 1
        ;;
esac

# 创建临时目录
TEMP_DIR="/tmp/ngrok_install"
mkdir -p "$TEMP_DIR"

# 下载ngrok
echo ""
echo "📥 正在下载 ngrok..."
echo "   URL: $NGROK_URL"
curl -o "$TEMP_DIR/ngrok.tgz" -L "$NGROK_URL"

if [ $? -ne 0 ]; then
    echo "❌ 下载失败，请检查网络连接"
    exit 1
fi

# 解压ngrok
echo ""
echo "📦 解压 ngrok..."
mkdir -p "$TEMP_DIR/ngrok"
if [[ "$NGROK_URL" == *.zip ]]; then
    unzip -q "$TEMP_DIR/ngrok.tgz" -d "$TEMP_DIR/ngrok"
else
    tar -xzf "$TEMP_DIR/ngrok.tgz" -C "$TEMP_DIR/ngrok"
fi

if [ $? -ne 0 ]; then
    echo "❌ 解压失败"
    exit 1
fi

# 安装ngrok
echo ""
echo "📦 安装 ngrok..."

if [ -f "$TEMP_DIR/ngrok/ngrok" ]; then
    cp "$TEMP_DIR/ngrok/ngrok" ~/ngrok
    chmod +x ~/ngrok
    echo "✅ ngrok 安装成功: ~/ngrok"
else
    echo "❌ 未找到 ngrok 可执行文件"
    exit 1
fi

# 配置环境变量
echo ""
echo "🔧 配置环境变量..."

# 检查是否已经添加到PATH
if [ ! -f ~/.bashrc ] || ! grep -q "export PATH=\$PATH:~" ~/.bashrc; then
    echo 'export PATH=$PATH:~' >> ~/.bashrc
    echo "✅ 已添加 ngrok 到 PATH 环境变量"
    echo "   请运行 'source ~/.bashrc' 使改动生效"
else
    echo "✅ ngrok 已在 PATH 环境变量中"
fi

# 测试ngrok
echo ""
echo "🔍 测试 ngrok..."
~/ngrok --version

if [ $? -ne 0 ]; then
    echo "❌ ngrok 测试失败"
    exit 1
fi

# 配置ngrok
echo ""
echo "🔑 配置 ngrok authtoken..."
echo "请从 https://dashboard.ngrok.com 获取您的authtoken"
read -p "请输入您的authtoken（按Enter跳过）: " NGROK_TOKEN

if [ -n "$NGROK_TOKEN" ]; then
    ~/ngrok config add-authtoken "$NGROK_TOKEN"
    if [ $? -eq 0 ]; then
        echo "✅ ngrok authtoken 配置成功"
    else
        echo "❌ ngrok authtoken 配置失败"
    fi
else
    echo "⚠️  跳过配置 authtoken"
    echo "   请稍后使用命令配置: ~/ngrok config add-authtoken YOUR_TOKEN"
fi

# 清理
echo ""
echo "🧹 清理临时文件..."
rm -rf "$TEMP_DIR"
echo "✅ 临时文件已清理"

# 完成
echo ""
echo "✅ ngrok 安装完成!"
echo ""
echo "📋 使用方法:"
echo "   • 运行 ngrok: ~/ngrok http 端口号"
echo "   • 配置 authtoken: ~/ngrok config add-authtoken YOUR_TOKEN"
echo "   • 查看帮助: ~/ngrok help"
echo ""
echo "💡 提示:"
echo "   • 免费版ngrok会话最长运行8小时"
echo "   • 每次重启会获得新的随机域名"
echo "   • 详情请访问: https://ngrok.com/docs"
