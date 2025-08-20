#!/bin/bash

# Unity WebGL 项目更新脚本
# 使用方法: ./update_unity_build.sh [Unity构建文件路径]

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_BUILD_DIR="$PROJECT_ROOT/unity-build"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOGS_DIR="$PROJECT_ROOT/logs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Unity WebGL 项目更新工具${NC}"
echo "================================="
echo -e "📁 项目目录: ${BLUE}$PROJECT_ROOT${NC}"
echo -e "🎯 部署目录: ${BLUE}$UNITY_BUILD_DIR${NC}"
echo ""

# 检查参数
if [ -z "$1" ]; then
    echo -e "${YELLOW}请提供Unity WebGL构建文件的路径${NC}"
    echo ""
    echo "使用方法:"
    echo "  $0 /path/to/unity/webgl/build"
    echo ""
    echo "构建文件应包含:"
    echo "  - index.html"
    echo "  - Build/ 目录"
    echo "  - TemplateData/ 目录"
    echo "  - StreamingAssets/ 目录（如果有）"
    exit 1
fi

NEW_BUILD_PATH="$1"

# 验证新构建文件
echo -e "${BLUE}🔍 验证新构建文件...${NC}"
if [ ! -d "$NEW_BUILD_PATH" ]; then
    echo -e "${RED}❌ 错误: 构建目录不存在: $NEW_BUILD_PATH${NC}"
    exit 1
fi

if [ ! -f "$NEW_BUILD_PATH/index.html" ]; then
    echo -e "${RED}❌ 错误: 找不到 index.html 文件${NC}"
    exit 1
fi

if [ ! -d "$NEW_BUILD_PATH/Build" ]; then
    echo -e "${RED}❌ 错误: 找不到 Build 目录${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 构建文件验证通过${NC}"

# 检查当前服务状态
echo ""
echo -e "${BLUE}🔍 检查当前服务状态...${NC}"
FLASK_RUNNING=false
NGROK_RUNNING=false

if pgrep -f "secure_unity_server.py" > /dev/null; then
    FLASK_RUNNING=true
    echo -e "${YELLOW}⚠️  Unity安全服务器正在运行${NC}"
fi

if pgrep -f "ngrok" > /dev/null; then
    NGROK_RUNNING=true
    echo -e "${YELLOW}⚠️  ngrok隧道正在运行${NC}"
fi

# 询问是否继续
if [ "$FLASK_RUNNING" = true ] || [ "$NGROK_RUNNING" = true ]; then
    echo ""
    echo -e "${YELLOW}注意: 更新过程中需要暂停服务${NC}"
    read -p "是否继续更新？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}更新已取消${NC}"
        exit 0
    fi
fi

# 创建备份目录
echo ""
echo -e "${BLUE}💾 创建备份...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_NAME="unity-build-backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

if [ -d "$UNITY_BUILD_DIR" ]; then
    cp -r "$UNITY_BUILD_DIR" "$BACKUP_PATH"
    echo -e "${GREEN}✅ 当前版本已备份到: $BACKUP_PATH${NC}"
else
    echo -e "${YELLOW}⚠️  没有找到现有的Unity构建，跳过备份${NC}"
fi

# 停止服务
if [ "$FLASK_RUNNING" = true ] || [ "$NGROK_RUNNING" = true ]; then
    echo ""
    echo -e "${BLUE}🛑 停止当前服务...${NC}"
    
    # 使用项目的停止脚本
    if [ -f "$PROJECT_ROOT/scripts/stop_secure_unity.sh" ]; then
        bash "$PROJECT_ROOT/scripts/stop_secure_unity.sh"
    else
        # 手动停止
        pkill -f "secure_unity_server.py" 2>/dev/null
        pkill -f "ngrok" 2>/dev/null
    fi
    
    sleep 3
    echo -e "${GREEN}✅ 服务已停止${NC}"
fi

# 清理旧文件（保留服务器脚本和配置）
echo ""
echo -e "${BLUE}🧹 清理旧的Unity文件...${NC}"
if [ -d "$UNITY_BUILD_DIR" ]; then
    # 保存重要文件
    TEMP_DIR="/tmp/unity_update_temp"
    mkdir -p "$TEMP_DIR"
    
    # 保存服务器文件和配置
    [ -f "$UNITY_BUILD_DIR/secure_unity_server.py" ] && cp "$UNITY_BUILD_DIR/secure_unity_server.py" "$TEMP_DIR/"
    [ -f "$UNITY_BUILD_DIR/access_tokens.txt" ] && cp "$UNITY_BUILD_DIR/access_tokens.txt" "$TEMP_DIR/"
    [ -f "$UNITY_BUILD_DIR/security_access.log" ] && cp "$UNITY_BUILD_DIR/security_access.log" "$TEMP_DIR/"
    
    # 删除Unity相关文件，保留服务器文件
    find "$UNITY_BUILD_DIR" -name "*.html" -delete 2>/dev/null
    find "$UNITY_BUILD_DIR" -name "*.js" -delete 2>/dev/null  
    find "$UNITY_BUILD_DIR" -name "*.wasm" -delete 2>/dev/null
    find "$UNITY_BUILD_DIR" -name "*.data" -delete 2>/dev/null
    [ -d "$UNITY_BUILD_DIR/Build" ] && rm -rf "$UNITY_BUILD_DIR/Build"
    [ -d "$UNITY_BUILD_DIR/TemplateData" ] && rm -rf "$UNITY_BUILD_DIR/TemplateData"
    [ -d "$UNITY_BUILD_DIR/StreamingAssets" ] && rm -rf "$UNITY_BUILD_DIR/StreamingAssets"
    
    echo -e "${GREEN}✅ 旧的Unity文件已清理${NC}"
else
    mkdir -p "$UNITY_BUILD_DIR"
    TEMP_DIR="/tmp/unity_update_temp"
    mkdir -p "$TEMP_DIR"
fi

# 复制新的Unity文件
echo ""
echo -e "${BLUE}📦 复制新的Unity WebGL文件...${NC}"

# 复制Unity构建文件
cp "$NEW_BUILD_PATH/index.html" "$UNITY_BUILD_DIR/" 2>/dev/null || {
    echo -e "${RED}❌ 复制 index.html 失败${NC}"
    exit 1
}

cp -r "$NEW_BUILD_PATH/Build" "$UNITY_BUILD_DIR/" 2>/dev/null || {
    echo -e "${RED}❌ 复制 Build 目录失败${NC}"
    exit 1
}

cp -r "$NEW_BUILD_PATH/TemplateData" "$UNITY_BUILD_DIR/" 2>/dev/null || {
    echo -e "${RED}❌ 复制 TemplateData 目录失败${NC}"
    exit 1
}

# 复制StreamingAssets（如果存在）
if [ -d "$NEW_BUILD_PATH/StreamingAssets" ]; then
    cp -r "$NEW_BUILD_PATH/StreamingAssets" "$UNITY_BUILD_DIR/"
    echo -e "${GREEN}✅ StreamingAssets 目录已复制${NC}"
fi

# 恢复服务器文件
if [ -f "$TEMP_DIR/secure_unity_server.py" ]; then
    cp "$TEMP_DIR/secure_unity_server.py" "$UNITY_BUILD_DIR/"
    echo -e "${GREEN}✅ 安全服务器文件已恢复${NC}"
fi

if [ -f "$TEMP_DIR/access_tokens.txt" ]; then
    cp "$TEMP_DIR/access_tokens.txt" "$UNITY_BUILD_DIR/"
    echo -e "${GREEN}✅ 访问令牌文件已恢复${NC}"
fi

if [ -f "$TEMP_DIR/security_access.log" ]; then
    cp "$TEMP_DIR/security_access.log" "$UNITY_BUILD_DIR/"
    echo -e "${GREEN}✅ 访问日志已恢复${NC}"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Unity WebGL文件更新完成${NC}"

# 验证文件完整性
echo ""
echo -e "${BLUE}🔍 验证文件完整性...${NC}"
VERIFICATION_FAILED=false

if [ ! -f "$UNITY_BUILD_DIR/index.html" ]; then
    echo -e "${RED}❌ index.html 缺失${NC}"
    VERIFICATION_FAILED=true
fi

if [ ! -d "$UNITY_BUILD_DIR/Build" ]; then
    echo -e "${RED}❌ Build 目录缺失${NC}"
    VERIFICATION_FAILED=true
fi

if [ ! -d "$UNITY_BUILD_DIR/TemplateData" ]; then
    echo -e "${RED}❌ TemplateData 目录缺失${NC}"
    VERIFICATION_FAILED=true
fi

if [ "$VERIFICATION_FAILED" = true ]; then
    echo -e "${RED}❌ 文件验证失败，正在恢复备份...${NC}"
    if [ -d "$BACKUP_PATH" ]; then
        rm -rf "$UNITY_BUILD_DIR"
        cp -r "$BACKUP_PATH" "$UNITY_BUILD_DIR"
        echo -e "${YELLOW}✅ 已恢复到备份版本${NC}"
    fi
    exit 1
fi

echo -e "${GREEN}✅ 文件完整性验证通过${NC}"

# 询问是否重新启动服务
echo ""
read -p "是否现在重新启动Unity WebGL服务？(Y/n): " restart_service
if [[ ! "$restart_service" =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BLUE}🚀 重新启动服务...${NC}"
    
    if [ -f "$PROJECT_ROOT/scripts/start_secure_unity.sh" ]; then
        bash "$PROJECT_ROOT/scripts/start_secure_unity.sh" configured
    else
        echo -e "${YELLOW}⚠️  找不到启动脚本，请手动启动服务${NC}"
        echo "使用命令: unity start"
    fi
else
    echo -e "${YELLOW}📝 更新完成，请手动启动服务：${NC}"
    echo "使用命令: unity start"
fi

# 记录更新日志
echo ""
echo -e "${BLUE}📝 记录更新日志...${NC}"
mkdir -p "$LOGS_DIR"
cat >> "$LOGS_DIR/update_history.log" << EOF
==========================================
更新时间: $(date)
备份位置: $BACKUP_PATH
源文件路径: $NEW_BUILD_PATH
更新状态: 成功
==========================================

EOF

echo -e "${GREEN}✅ 更新日志已记录${NC}"

echo ""
echo -e "${GREEN}🎉 Unity WebGL 项目更新完成！${NC}"
echo "=================================="
echo -e "📁 部署目录: ${BLUE}$UNITY_BUILD_DIR${NC}"
echo -e "💾 备份位置: ${BLUE}$BACKUP_PATH${NC}"
echo -e "📋 更新日志: ${BLUE}$LOGS_DIR/update_history.log${NC}"
echo ""
echo -e "${YELLOW}💡 提示：${NC}"
echo "  - 使用 'unity start' 启动服务"
echo "  - 使用 'unity check' 检查服务状态"
echo "  - 使用 'unity logs' 查看运行日志"
echo ""
echo -e "${GREEN}更新流程完成！${NC}"
