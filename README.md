# 🚀 Unity WebGL 公网部署工具包

这是一个完整的工具包，用于将Unity WebGL项目部署到公网，即使服务器位于NAT网络或防火墙后面。该工具包使用Flask服务器托管Unity WebGL内容，通过ngrok隧道将其暴露到公网。

## ✨ 主要功能

- 🔒 **安全性**: 多级安全保护（访问令牌、IP白名单、时间限制）
- 🌐 **公网访问**: 通过ngrok隧道暴露本地服务
- 📊 **访问统计**: 记录访问量和用户行为
- 🔄 **简单更新**: 一键更新Unity内容
- 🛠️ **完整工具链**: 启动、停止、监控、日志等全套管理工具

## 📋 目录结构

```
unity-webgl-deployment/
├── bin/                  # 可执行命令
│   ├── unity            # 主命令（启动、停止、更新等）
│   └── ...              # 其他命令
├── scripts/              # 管理脚本
│   ├── start_secure_unity.sh
│   ├── stop_secure_unity.sh
│   ├── update_unity_build.sh
│   ├── check_unity_status.sh
│   └── ...
├── configs/              # 配置文件
│   ├── deployment_info.txt
│   └── ...
├── docs/                 # 文档
│   ├── QUICK_UPDATE_FLOW.md
│   ├── UPDATE_GUIDE.md
│   └── ...
├── unity-build/          # Unity WebGL文件
│   ├── index.html
│   ├── secure_unity_server.py
│   ├── Build/
│   ├── TemplateData/
│   └── ...
└── logs/                 # 日志文件
    ├── secure_unity.log
    ├── ngrok_secure.log
    └── ...
```

## 🚀 快速开始

### 安装

1. 克隆仓库
```bash
git clone https://github.com/yourusername/unity-webgl-deployment.git
cd unity-webgl-deployment
```

2. 安装依赖
```bash
pip install -r requirements.txt
```

3. 下载安装ngrok（如未安装）
```bash
bash scripts/install_ngrok.sh
```

### 使用方法

1. 部署Unity WebGL
```bash
# 启动服务
unity start

# 停止服务
unity stop

# 检查状态
unity check

# 查看日志
unity logs
```

2. 更新Unity项目
```bash
# 显示上传指南
unity upload-help

# 更新项目
unity update /path/to/webgl-build
```

## 🔒 安全特性

本工具提供三级安全保护：

1. **基础安全 (Level 1)**
   - 访问令牌验证
   - 请求频率限制
   - 异常访问封禁

2. **增强安全 (Level 2)**
   - 基础安全 +
   - IP白名单保护

3. **最高安全 (Level 3)**
   - 增强安全 +
   - 服务时间限制

## 📋 命令参考

```bash
unity <command> [options]

可用命令:
  start, s       启动安全服务
  stop           停止服务
  restart, r     重启服务
  upload-help, uh 显示文件上传指南
  update, u      更新Unity项目
  check, c       检查服务状态
  logs, l        查看服务日志
  ngrok-logs, nl 查看ngrok日志
  info, i        显示部署信息
  clean          清理临时文件
```

## 📚 详细文档

- [更新指南](docs/UPDATE_GUIDE.md)
- [安全配置](docs/SECURITY_GUIDE.md)
- [故障排除](docs/TROUBLESHOOTING.md)

## 📌 注意事项

- 免费版ngrok最长运行8小时，之后需重启
- 每次重启ngrok会获得新的随机域名
- 默认使用http而非https（ngrok免费版限制）
- 请妥善保存访问令牌和管理员令牌

## 🛠️ 系统要求

- Python 3.6+
- Flask
- ngrok账号和authtoken
- Linux/Unix系统（Windows支持有限）

## 🔄 版本历史

- v1.0.0 (2025-08-20): 首次发布

## 📝 许可证

License

## 👨‍💻 作者

Lyndon2004

## 🤝 贡献

欢迎提交Issues和Pull Requests！
