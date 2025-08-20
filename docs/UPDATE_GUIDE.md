# Unity WebGL 项目更新指南

## 🎯 简单更新流程

每次更新Unity项目只需要3个步骤：

### 第1步：在本地构建WebGL版本
在您的本地Unity编辑器中：
1. 打开您的Unity项目
2. `File > Build Settings`
3. 选择 `WebGL` 平台
4. 点击 `Build`，构建到本地目录（如：`D:\MyGame-WebGL-Build`）

### 第2步：上传到服务器
将构建文件从本地传输到服务器：

#### 方式A：使用SCP命令（推荐）
```bash
# 在本地执行（将本地路径和服务器IP替换为实际值）
scp -r "D:\MyGame-WebGL-Build" username@server-ip:/home/username/temp/webgl-build
```

#### 方式B：使用SFTP工具
- 使用WinSCP、FileZilla等工具
- 上传到服务器路径：`/home/username/temp/webgl-build`

### 第3步：在服务器上执行更新
登录到服务器后执行：
```bash
# 使用上传的文件更新部署
unity update /home/username/temp/webgl-build

# 或者如果放在其他位置
unity update /path/to/uploaded/webgl/build
```

## 🛠️ 详细步骤说明

### Unity构建要求
您的Unity WebGL构建文件夹应包含：
```
YourGame-WebGL-Build/
├── index.html              # 必需
├── Build/                  # 必需
│   ├── YourGame.data
│   ├── YourGame.framework.js
│   ├── YourGame.loader.js
│   └── YourGame.wasm
├── TemplateData/           # 必需
│   ├── style.css
│   ├── unity-logo-*.png
│   └── ...
└── StreamingAssets/        # 可选
```

### 手动更新步骤
如果您想手动执行：

```bash
# 1. 停止当前服务
unity stop

# 2. 备份当前版本（可选）
cp -r ~/unity-webgl-deployment/unity-build ~/backups/unity-backup-$(date +%Y%m%d)

# 3. 替换Unity文件（保留服务器文件）
# 删除旧的Unity文件
rm -f ~/unity-webgl-deployment/unity-build/index.html
rm -rf ~/unity-webgl-deployment/unity-build/Build
rm -rf ~/unity-webgl-deployment/unity-build/TemplateData
rm -rf ~/unity-webgl-deployment/unity-build/StreamingAssets

# 复制新的Unity文件
cp /path/to/new/build/index.html ~/unity-webgl-deployment/unity-build/
cp -r /path/to/new/build/Build ~/unity-webgl-deployment/unity-build/
cp -r /path/to/new/build/TemplateData ~/unity-webgl-deployment/unity-build/
cp -r /path/to/new/build/StreamingAssets ~/unity-webgl-deployment/unity-build/ # 如果有

# 4. 重启服务
unity start
```

## 🔧 高级选项

### 查看更新历史
```bash
# 查看更新日志
cat ~/unity-webgl-deployment/logs/update_history.log

# 查看可用备份
ls -la ~/unity-webgl-deployment/backups/
```

### 回滚到之前版本
```bash
# 停止服务
unity stop

# 查看备份列表
ls ~/unity-webgl-deployment/backups/

# 恢复备份（将backup-name替换为实际备份名）
rm -rf ~/unity-webgl-deployment/unity-build
cp -r ~/unity-webgl-deployment/backups/unity-build-backup-YYYYMMDD-HHMMSS ~/unity-webgl-deployment/unity-build

# 重启服务
unity start
```

### 验证更新成功
```bash
# 检查服务状态
unity check

# 查看服务日志
unity logs

# 访问管理面板确认新版本
# 访问 https://您的域名/?token=访问令牌
```

## ⚠️ 注意事项

### 重要文件保护
更新脚本会自动保护以下文件：
- ✅ `secure_unity_server.py` - 安全服务器
- ✅ `access_tokens.txt` - 访问令牌
- ✅ `security_access.log` - 访问日志

### 更新最佳实践
1. **测试构建**：先在本地测试Unity WebGL构建
2. **备份确认**：确保重要数据已备份
3. **维护时间**：在用户较少时进行更新
4. **验证更新**：更新后访问网站确认功能正常

### 常见问题解决

#### 更新失败回滚
```bash
# 如果更新失败，脚本会自动回滚
# 手动回滚命令：
unity stop
# 查看最新备份
ls -lt ~/unity-webgl-deployment/backups/ | head -5
# 恢复备份
cp -r ~/unity-webgl-deployment/backups/最新备份名 ~/unity-webgl-deployment/unity-build
unity start
```

#### 服务器文件丢失
```bash
# 如果意外删除了服务器文件，从备份恢复：
cp ~/unity-webgl-deployment/backups/最新备份名/secure_unity_server.py ~/unity-webgl-deployment/unity-build/
cp ~/unity-webgl-deployment/backups/最新备份名/access_tokens.txt ~/unity-webgl-deployment/unity-build/
```

## 📋 快速命令参考

```bash
# 🔄 更新流程
unity upload-help                  # 显示上传指南
unity update /path/to/webgl/build  # 一键更新
unity check                        # 检查状态
unity logs                         # 查看日志

# 🎮 服务管理
unity start                        # 启动服务
unity stop                         # 停止服务
unity restart                      # 重启服务

# 📊 状态监控
unity info                         # 显示部署信息
unity logs                         # 查看服务日志
unity ngrok-logs                   # 查看ngrok日志

# 🧹 维护
unity clean                        # 清理临时文件
```

## ✨ 总结

使用 `unity update` 命令，您可以：
- 🚀 **一键更新** Unity WebGL项目
- 💾 **自动备份** 当前版本
- 🔒 **保护配置** 不丢失访问令牌和设置
- ⚡ **快速部署** 最小化停机时间
- 📝 **记录历史** 追踪所有更新操作

**现在，每次更新Unity项目只需要一行命令！**
