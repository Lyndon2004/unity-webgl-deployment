# 快速更新流程指南

## 3步更新Unity WebGL项目

### 第1步：构建WebGL
在Unity编辑器中:
- `File` > `Build Settings` 
- 选择 `WebGL` 平台
- 点击 `Build`

### 第2步：上传到服务器
- 使用SCP命令:
  ```bash
  scp -r "本地WebGL构建目录" username@server-ip:/home/username/temp/webgl-build
  ```
- 或使用WinSCP等SFTP工具上传

### 第3步：执行更新
登录服务器执行:
```bash
unity update /home/username/temp/webgl-build
```

## 检查更新状态
```bash
unity check
unity logs
```

## 常用命令
```bash
unity start    # 启动服务
unity stop     # 停止服务
unity restart  # 重启服务
unity info     # 查看访问信息
```

*详细说明请参阅完整的 [UPDATE_GUIDE.md](UPDATE_GUIDE.md)*
