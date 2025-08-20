#!/bin/bash

# Unity WebGL 文件上传助手脚本
# 在服务器上运行，帮助从本地上传Unity WebGL文件

echo "📁 Unity WebGL 文件上传助手"
echo "============================"
echo ""

# 创建临时目录
TEMP_UPLOAD_DIR="/home/yuquan/temp"
mkdir -p "$TEMP_UPLOAD_DIR"

# 获取服务器IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="127.0.0.1"  # 默认IP
fi

echo "📋 文件上传指南："
echo ""
echo "🔸 方式1：使用SCP命令"
echo "   在您的本地电脑上执行："
echo "   scp -r \"本地WebGL构建路径\" yuquan@$SERVER_IP:$TEMP_UPLOAD_DIR/webgl-build"
echo ""
echo "   例如："
echo "   scp -r \"D:\\MyGame-WebGL-Build\" yuquan@$SERVER_IP:$TEMP_UPLOAD_DIR/webgl-build"
echo ""

echo "🔸 方式2：使用SFTP工具"
echo "   - 服务器地址: $SERVER_IP"
echo "   - 用户名: yuquan"
echo "   - 上传目标: $TEMP_UPLOAD_DIR/webgl-build"
echo ""

echo "🔸 方式3：使用rsync（Linux/Mac）"
echo "   rsync -avz 本地路径/ yuquan@$SERVER_IP:$TEMP_UPLOAD_DIR/webgl-build/"
echo ""

echo "⏳ 等待文件上传..."
echo "   上传完成后，执行以下命令更新：" 
echo "   unity update $TEMP_UPLOAD_DIR/webgl-build"
echo ""

# 监控文件上传
check_upload() {
    while true; do
        if [ -d "$TEMP_UPLOAD_DIR/webgl-build" ] && [ -f "$TEMP_UPLOAD_DIR/webgl-build/index.html" ]; then
            echo "✅ 检测到WebGL文件已上传!"
            echo ""
            echo "📂 上传的文件："
            ls -la "$TEMP_UPLOAD_DIR/webgl-build/"
            echo ""
            
            # 验证文件完整性
            MISSING_FILES=""
            [ ! -f "$TEMP_UPLOAD_DIR/webgl-build/index.html" ] && MISSING_FILES="$MISSING_FILES index.html"
            [ ! -d "$TEMP_UPLOAD_DIR/webgl-build/Build" ] && MISSING_FILES="$MISSING_FILES Build/"
            [ ! -d "$TEMP_UPLOAD_DIR/webgl-build/TemplateData" ] && MISSING_FILES="$MISSING_FILES TemplateData/"
            
            if [ -n "$MISSING_FILES" ]; then
                echo "❌ 缺少必要文件: $MISSING_FILES"
                echo "请确保上传完整的Unity WebGL构建文件"
                return 1
            else
                echo "✅ 文件完整性验证通过"
                echo ""
                echo "🚀 现在可以执行更新："
                echo "   unity update $TEMP_UPLOAD_DIR/webgl-build"
                echo ""
                
                # 询问是否立即更新
                read -p "是否现在就执行更新？(Y/n): " do_update
                if [[ ! "$do_update" =~ ^[Nn]$ ]]; then
                    echo ""
                    echo "🔄 开始更新..."
                    if [ -f "/home/yuquan/unity-webgl-deployment/scripts/update_unity_build.sh" ]; then
                        bash "/home/yuquan/unity-webgl-deployment/scripts/update_unity_build.sh" "$TEMP_UPLOAD_DIR/webgl-build"
                    else
                        echo "❌ 找不到更新脚本"
                        return 1
                    fi
                else
                    echo "💡 稍后执行: unity update $TEMP_UPLOAD_DIR/webgl-build"
                fi
                return 0
            fi
        fi
        
        echo "⏳ 等待文件上传... (按Ctrl+C取消监控)"
        sleep 5
    done
}

# 询问是否监控上传
read -p "是否监控文件上传状态？(Y/n): " monitor_upload
if [[ ! "$monitor_upload" =~ ^[Nn]$ ]]; then
    echo ""
    echo "🔍 开始监控 $TEMP_UPLOAD_DIR/webgl-build 目录..."
    check_upload
else
    echo ""
    echo "💡 手动检查上传状态："
    echo "   ls -la $TEMP_UPLOAD_DIR/webgl-build"
    echo ""
    echo "💡 上传完成后执行："
    echo "   unity update $TEMP_UPLOAD_DIR/webgl-build"
fi

# 清理说明
echo ""
echo "📝 注意事项："
echo "   - 上传路径: $TEMP_UPLOAD_DIR/webgl-build"
echo "   - 更新完成后，临时文件会自动清理"
echo "   - 如需手动清理: rm -rf $TEMP_UPLOAD_DIR/webgl-build"
