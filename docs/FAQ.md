# Unity WebGL部署常见问题解答

## 基本问题

### Q: Unity WebGL部署工具是什么？
**A:** 这是一套工具，用于简化将Unity WebGL构建部署到公网的过程。它使用Flask服务器托管WebGL内容，并通过ngrok提供公共访问，同时提供多级安全保护。

### Q: 我需要具备什么技术知识才能使用这个工具？
**A:** 基本的Linux命令行操作知识。所有复杂的操作都已封装在简单的`unity`命令中，使得部署和管理变得简单直观。

### Q: 这套工具适合哪些使用场景？
**A:** 
- 游戏开发团队需要快速分享WebGL原型
- 需要向客户演示Unity项目
- 在没有正式服务器的情况下测试WebGL构建
- 小型团队的内部演示和测试

## 安装与配置

### Q: 如何安装这套工具？
**A:** 克隆GitHub仓库并运行安装脚本：
```bash
git clone https://github.com/yourusername/unity-webgl-deployment.git
cd unity-webgl-deployment
chmod +x install.sh
./install.sh
```

### Q: 我需要ngrok账号吗？
**A:** 是的，您需要一个ngrok账号并获取authtoken。您可以在https://dashboard.ngrok.com 注册并获取免费authtoken。

### Q: 如何更改默认端口？
**A:** 编辑`unity-build/secure_unity_server.py`文件，修改`PORT`变量：
```python
class SecurityConfig:
    # ...其他配置...
    PORT = 5000  # 修改为您想要的端口
```

### Q: 如何在不同服务器上安装？
**A:** 这套工具设计为可移植的，只需克隆仓库并在新服务器上运行安装脚本。确保新服务器上安装了Python 3和必要的依赖。

## 使用与操作

### Q: 如何更新我的Unity WebGL构建？
**A:** 使用`unity update`命令：
```bash
unity update /path/to/your/new/webgl/build
```
详细步骤请查看[更新指南](UPDATE_GUIDE.md)。

### Q: 如何查看当前部署的访问链接？
**A:** 运行：
```bash
unity info
```
这将显示公共访问URL和令牌。

### Q: 为什么访问时显示403错误？
**A:** 这可能是因为：
1. 没有提供有效的访问令牌
2. 您的IP不在白名单中（当安全级别设为2或3时）
3. 令牌已过期（当安全级别设为3时）

查看[安全指南](SECURITY_GUIDE.md)了解更多信息。

### Q: 如何查看访问日志？
**A:** 运行：
```bash
unity logs
```
或直接查看日志文件：
```bash
cat ~/unity-webgl-deployment/unity-build/security_access.log
```

### Q: 如何停止和重新启动服务？
**A:** 使用以下命令：
```bash
unity stop    # 停止服务
unity start   # 启动服务
unity restart # 重启服务
```

## 故障排除

### Q: 我的Unity WebGL部署无法访问怎么办？
**A:**
1. 检查服务是否正在运行：`unity check`
2. 查看日志了解错误：`unity logs`
3. 确保ngrok隧道已建立：`unity ngrok-logs`
4. 尝试重启服务：`unity restart`

### Q: 我的Unity构建在本地运行正常，但在部署后不工作
**A:**
1. 确保您构建的WebGL模块正确，并包含所有必要文件
2. 检查浏览器控制台是否有JavaScript错误
3. 确保您的Unity项目设置适合WebGL导出
4. 尝试在部署前在本地测试WebGL构建

### Q: ngrok隧道创建失败怎么办？
**A:**
1. 确保您已正确配置ngrok authtoken
2. 检查是否有其他ngrok进程正在运行：`ps aux | grep ngrok`
3. 查看ngrok日志：`unity ngrok-logs`
4. 尝试手动重启ngrok服务

### Q: 如何处理"地址已被使用"错误？
**A:**
1. 检查是否已有服务在使用相同端口：`sudo lsof -i :5000`
2. 停止所有现有Unity服务：`unity stop`
3. 如果问题仍然存在，尝试更改端口号
4. 重启服务器进程：`unity restart`

### Q: 备份文件占用太多空间怎么办？
**A:** 您可以手动清理旧的备份文件：
```bash
# 列出所有备份
ls -la ~/unity-webgl-deployment/backups

# 删除旧备份
rm -rf ~/unity-webgl-deployment/backups/unity-build-backup-20250820-120000
```

## 安全问题

### Q: 如何提高我的部署的安全性？
**A:** 
1. 提高安全级别（1到3）
2. 使用更复杂的访问令牌
3. 限制IP白名单
4. 定期更换访问令牌
5. 查看[安全指南](SECURITY_GUIDE.md)获取详细建议

### Q: 如何更改访问令牌？
**A:** 删除现有令牌文件并重启服务：
```bash
unity stop
rm ~/unity-webgl-deployment/unity-build/access_tokens.txt
unity start
```

### Q: 我可以限制特定用户的访问时间吗？
**A:** 是的，设置安全级别为3并配置时间限制：
```python
# 在 secure_unity_server.py 中
class SecurityConfig:
    SECURITY_LEVEL = 3
    # ...
    ACCESS_TIME_LIMIT_HOURS = 2  # 将访问时间限制为2小时
```

## 高级使用

### Q: 如何自定义Unity WebGL模板？
**A:** 在上传新的Unity构建之前，您可以自定义您的Unity WebGL模板。在Unity编辑器中：
1. 转到Player Settings > WebGL选项卡
2. 选择或创建自定义模板
3. 修改模板以满足您的需求
4. 构建并部署

### Q: 我可以使用自己的域名而不是ngrok URL吗？
**A:** 可以，但需要额外配置：
1. 使用付费ngrok账户自定义域名
2. 或者配置反向代理（如Nginx）并指向您的域名

### Q: 我可以部署多个Unity WebGL项目吗？
**A:** 是的，有两种方法：
1. 创建多个部署实例，每个使用不同端口
2. 修改服务器代码以支持多个项目路径

### Q: 如何贡献或修改这个项目？
**A:**
1. Fork仓库
2. 创建功能分支
3. 提交您的修改
4. 创建Pull Request

如有其他问题或需要进一步帮助，请提交Issue或联系项目维护者。
