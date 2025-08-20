# Unity WebGL安全部署指南

## 安全概述

Unity WebGL部署系统提供了三个安全级别，从基础保护到高级保护，以满足不同场景的安全需求：

### 安全级别

1. **基础安全 (Level 1)**
   - 访问令牌验证
   - 访问日志记录
   - 适用场景：内部演示、团队测试

2. **增强安全 (Level 2)**
   - 基础安全功能 +
   - IP地址白名单
   - 访问控制
   - 适用场景：有限范围的外部分享

3. **最高安全 (Level 3)**
   - 增强安全功能 +
   - 时间限制访问
   - 单次会话控制
   - 适用场景：机密项目演示、客户展示

## 配置安全级别

安全级别配置在`unity-build/secure_unity_server.py`文件中：

```python
class SecurityConfig:
    # 安全级别: 1=基础安全, 2=增强安全(IP白名单), 3=最高安全(时间限制)
    SECURITY_LEVEL = 1  # 修改此值设置安全级别
```

修改`SECURITY_LEVEL`的值(1, 2或3)以设置所需的安全级别。

## 访问令牌管理

### 生成新令牌

系统会自动在首次启动时生成访问令牌并保存在`unity-build/access_tokens.txt`中。如果需要手动生成新令牌：

```bash
# 停止当前服务
unity stop

# 删除现有令牌文件
rm ~/unity-webgl-deployment/unity-build/access_tokens.txt

# 重新启动服务（将自动生成新令牌）
unity start

# 查看新令牌
cat ~/unity-webgl-deployment/unity-build/access_tokens.txt
```

### 自定义访问令牌

如果要设置自定义的访问令牌，请编辑`unity-build/secure_unity_server.py`文件：

```python
def initialize_security():
    if os.path.exists(SecurityConfig.ACCESS_TOKENS_FILE):
        # 从文件读取现有令牌
        pass
    else:
        # 设置自定义令牌
        security_state.access_token = "您的自定义访问令牌"  # 修改此行
        security_state.admin_token = "您的自定义管理令牌"   # 修改此行
        
        # 保存令牌到文件
        with open(SecurityConfig.ACCESS_TOKENS_FILE, "w") as f:
            f.write(f"访问令牌: {security_state.access_token}\n")
            f.write(f"管理令牌: {security_state.admin_token}\n")
```

## IP白名单配置

当安全级别设置为2或3时，IP白名单功能将启用。配置IP白名单：

```python
class SecurityConfig:
    # ...省略...
    
    # IP白名单 (安全级别2和3启用)
    WHITELISTED_IPS = [
        "127.0.0.1",        # 本地主机
        "192.168.1.100",    # 添加您的IP
        "10.0.0.5",         # 添加更多IP
    ]
```

### 自动添加当前IP

服务启动时，`start_secure_unity.sh`脚本会自动检测并添加当前IP地址到白名单中。

## 时间限制配置

当安全级别设置为3时，时间限制功能将启用：

```python
class SecurityConfig:
    # ...省略...
    
    # 时间限制 (安全级别3启用)
    ACCESS_TIME_LIMIT_HOURS = 24  # 访问令牌有效期(小时)
    SESSION_TIMEOUT_MINUTES = 60  # 单次会话超时时间(分钟)
```

## 安全日志

所有访问和安全事件均被记录在`unity-build/security_access.log`文件中：

```bash
# 查看安全日志
tail -f ~/unity-webgl-deployment/unity-build/security_access.log
```

日志格式示例：
```
2023-05-25 14:30:22 - 访问成功 - IP: 192.168.1.100 - 令牌: abc123
2023-05-25 14:35:45 - 访问拒绝 - IP: 203.0.113.42 - 无效令牌
2023-05-25 15:10:37 - 管理访问 - IP: 127.0.0.1 - 管理令牌: xyz789
```

## 安全最佳实践

### 令牌管理
- 定期更换访问令牌
- 不要共享管理令牌
- 使用安全渠道传递访问令牌

### IP白名单
- 尽量限制允许的IP地址范围
- 移除不再需要的IP地址
- 定期审核白名单

### 服务配置
- 避免在公共Wi-Fi上管理部署
- 使用SSH密钥而非密码进行服务器登录
- 保持服务器软件更新

### 监控
- 定期检查安全日志
- 监控异常访问模式
- 注意失败的认证尝试

## 常见安全问题

### 忘记访问令牌
如果忘记了访问令牌，可以在服务器上查看：
```bash
cat ~/unity-webgl-deployment/unity-build/access_tokens.txt
```

### 被阻止的IP
如果合法IP被意外阻止：
1. 连接到服务器
2. 编辑配置文件添加该IP到白名单
3. 重启服务

```bash
# 编辑配置文件
nano ~/unity-webgl-deployment/unity-build/secure_unity_server.py

# 重启服务
unity restart
```

### 安全级别调整
如果需要在特定场景调整安全级别：

```bash
# 编辑安全配置
nano ~/unity-webgl-deployment/unity-build/secure_unity_server.py
# 修改 SECURITY_LEVEL = X (1, 2 或 3)

# 重启服务
unity restart
```

## 应急响应

如果发现安全漏洞或未授权访问：

1. **立即停止服务**
   ```bash
   unity stop
   ```

2. **检查安全日志**
   ```bash
   cat ~/unity-webgl-deployment/unity-build/security_access.log
   ```

3. **重新生成令牌**
   删除`access_tokens.txt`并重新启动服务

4. **更新安全配置**
   根据需要提高安全级别

5. **重启服务**
   ```bash
   unity start
   ```

---

*记住：安全是一个持续的过程，而不是一次性的设置。定期审查您的配置和日志，根据需要调整安全级别。*
