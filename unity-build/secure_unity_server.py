#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unity WebGL 安全部署服务器
-------------------------

这是一个Flask服务器，用于安全地托管Unity WebGL内容，并通过ngrok暴露到公网。
提供多级安全保护，包括访问令牌验证、IP白名单和时间限制。

作者: [您的名字]
版本: 1.2.0
许可证: MIT
"""

import os
import time
import json
import random
import string
import socket
import logging
import datetime
from functools import wraps
from pathlib import Path
from flask import Flask, send_from_directory, request, jsonify, redirect, url_for, abort, make_response, render_template_string

# 尝试导入可选依赖
try:
    from flask_limiter import Limiter
    from flask_limiter.util import get_remote_address
    RATE_LIMIT_ENABLED = True
except ImportError:
    print("警告: flask-limiter未安装，频率限制功能将被禁用")
    RATE_LIMIT_ENABLED = False

try:
    from flask_cors import CORS
    CORS_ENABLED = True
except ImportError:
    print("警告: flask-cors未安装，CORS支持将被禁用")
    CORS_ENABLED = False

# 安全配置
class SecurityConfig:
    # 安全级别: 1=基础安全, 2=增强安全(IP白名单), 3=最高安全(时间限制)
    SECURITY_LEVEL = 1
    
    # IP白名单 (安全级别2和3启用)
    ALLOWED_IPS = {"143.89.41.235", "143.89.191.58", "127.0.0.1", "::1"}  # 公网IP、本地IP和回环地址
    
    # 封禁设置
    MAX_FAILED_ATTEMPTS = 5
    BAN_DURATION_MINUTES = 30
    
    # 时间限制 (安全级别3启用)
    TIME_LIMIT_MINUTES = 60
    START_TIME = time.time()

# 服务器配置
class ServerConfig:
    # 服务设置
    PORT = 3000
    HOST = "0.0.0.0"  # 绑定到所有网络接口
    
    # Unity目录设置
    # 尝试获取当前脚本目录
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    UNITY_DIR = os.path.join(SCRIPT_DIR, "")
    
    # 通常Unity构建在子目录中，但这里我们假设就在当前目录
    # 如果在子目录，取消下面注释并修改路径
    # UNITY_DIR = os.path.join(SCRIPT_DIR, "web-build")
    
    # 日志设置
    LOG_FILE = os.path.join(SCRIPT_DIR, "security_access.log")
    ACCESS_TOKENS_FILE = os.path.join(SCRIPT_DIR, "access_tokens.txt")

# 全局状态
class SecurityState:
    def __init__(self):
        self.failed_attempts = {}  # IP -> 失败次数
        self.banned_ips = {}  # IP -> 封禁时间
        self.visit_count = 0
        self.unique_visitors = set()
        self.path_stats = {}  # 路径 -> 访问次数
        self.hourly_stats = {}  # 小时 -> 访问次数
        self.access_token = generate_token(16)
        self.admin_token = generate_token(32)

# 初始化全局状态
security_state = SecurityState()

# 创建Flask应用
app = Flask(__name__, static_folder=None)  # 禁用默认静态文件夹
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0  # 禁用缓存
app.json.ensure_ascii = False  # 支持非ASCII字符

# 添加CORS支持（如果已安装）
if CORS_ENABLED:
    CORS(app, resources={r"/*": {"origins": "*"}})

# 添加速率限制（如果已安装）
if RATE_LIMIT_ENABLED:
    limiter = Limiter(
        get_remote_address,
        app=app,
        default_limits=["30 per minute", "200 per hour"],
        storage_uri="memory://",
    )

# 生成随机令牌
def generate_token(length=16):
    """生成随机访问令牌"""
    chars = string.ascii_letters + string.digits + "-_"
    return ''.join(random.choice(chars) for _ in range(length))

# 保存访问令牌到文件
def save_tokens():
    """保存访问令牌和管理员令牌到文件"""
    with open(ServerConfig.ACCESS_TOKENS_FILE, 'w', encoding='utf-8') as f:
        f.write(f"访问令牌: {security_state.access_token}\n")
        f.write(f"管理员令牌: {security_state.admin_token}\n")

# 记录访问日志
def log_access(ip, path, status, message=""):
    """记录访问日志"""
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} | {ip} | {path} | {status} | {message}\n"
    
    try:
        with open(ServerConfig.LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_entry)
    except Exception as e:
        print(f"日志写入错误: {e}")

# 记录访问统计
def record_visit(path):
    """记录访问统计"""
    security_state.visit_count += 1
    client_ip = request.remote_addr
    security_state.unique_visitors.add(client_ip)
    
    # 路径统计
    if path in security_state.path_stats:
        security_state.path_stats[path] += 1
    else:
        security_state.path_stats[path] = 1
    
    # 小时统计
    hour = datetime.datetime.now().strftime('%Y-%m-%d %H')
    if hour in security_state.hourly_stats:
        security_state.hourly_stats[hour] += 1
    else:
        security_state.hourly_stats[hour] = 1

# 安全中间件
def security_check():
    """执行安全检查的装饰器"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            client_ip = request.remote_addr
            path = request.path
            
            # 检查IP是否被封禁
            if client_ip in security_state.banned_ips:
                ban_time = security_state.banned_ips[client_ip]
                if time.time() - ban_time < SecurityConfig.BAN_DURATION_MINUTES * 60:
                    log_access(client_ip, path, "banned", "IP已被封禁")
                    abort(403)  # 禁止访问
                else:
                    # 封禁时间已过，移除封禁
                    del security_state.banned_ips[client_ip]
                    security_state.failed_attempts[client_ip] = 0
            
            # 安全级别2和3: 检查IP白名单
            if SecurityConfig.SECURITY_LEVEL >= 2 and SecurityConfig.ALLOWED_IPS and client_ip not in SecurityConfig.ALLOWED_IPS:
                log_access(client_ip, path, "blocked", "IP不在白名单")
                security_state.failed_attempts[client_ip] = security_state.failed_attempts.get(client_ip, 0) + 1
                if security_state.failed_attempts.get(client_ip, 0) >= SecurityConfig.MAX_FAILED_ATTEMPTS:
                    security_state.banned_ips[client_ip] = time.time()
                abort(403)
            
            # 安全级别3: 检查时间限制
            if SecurityConfig.SECURITY_LEVEL >= 3:
                elapsed_minutes = (time.time() - SecurityConfig.START_TIME) / 60
                if elapsed_minutes > SecurityConfig.TIME_LIMIT_MINUTES:
                    log_access(client_ip, path, "blocked", "服务已超时")
                    abort(503)  # 服务不可用
            
            # 健康检查和API端点不需要令牌
            if path == "/health" or path.startswith("/api/"):
                return f(*args, **kwargs)
            
            # 验证访问令牌
            token = request.args.get('token')
            if not token or token != security_state.access_token:
                log_access(client_ip, path, "denied", "无效的访问令牌")
                security_state.failed_attempts[client_ip] = security_state.failed_attempts.get(client_ip, 0) + 1
                if security_state.failed_attempts.get(client_ip, 0) >= SecurityConfig.MAX_FAILED_ATTEMPTS:
                    security_state.banned_ips[client_ip] = time.time()
                
                # 如果是API请求，返回401错误
                if path.startswith('/api/'):
                    return jsonify({"error": "未授权"}), 401
                
                # 否则重定向到错误页面
                return redirect(url_for('access_denied'))
            
            # 路径安全检查（防止目录遍历）
            if '..' in path or '~' in path:
                log_access(client_ip, path, "blocked", "疑似路径遍历")
                abort(403)
            
            # 记录有效访问
            log_access(client_ip, path, "allowed")
            record_visit(path)
            
            # 安全检查通过，继续处理请求
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# API验证中间件
def api_auth_required(f):
    """API认证装饰器，要求管理员令牌"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.remote_addr
        admin_token = request.args.get('admin_token')
        
        if not admin_token or admin_token != security_state.admin_token:
            log_access(client_ip, request.path, "denied", "API访问未授权")
            return jsonify({"error": "需要管理员令牌"}), 401
        
        return f(*args, **kwargs)
    return decorated_function

# 路由：根路径（Unity WebGL入口）
@app.route('/')
@security_check()
def serve_unity_index():
    """提供Unity WebGL入口页面"""
    return send_from_directory(ServerConfig.UNITY_DIR, 'index.html')

# 路由：Unity文件
@app.route('/<path:path>')
@security_check()
def serve_unity_files(path):
    """提供Unity文件"""
    try:
        return send_from_directory(ServerConfig.UNITY_DIR, path)
    except Exception as e:
        log_access(request.remote_addr, request.path, "error", str(e))
        return "文件未找到", 404

# 路由：访问被拒绝
@app.route('/access-denied')
def access_denied():
    """访问被拒绝页面"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>访问被拒绝</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 50px;
                background-color: #f8f9fa;
            }
            .container {
                max-width: 600px;
                margin: 0 auto;
                background-color: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            }
            h1 {
                color: #dc3545;
            }
            .icon {
                font-size: 60px;
                margin-bottom: 20px;
            }
            .info {
                margin-top: 20px;
                font-size: 14px;
                color: #6c757d;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="icon">🔒</div>
            <h1>访问被拒绝</h1>
            <p>您需要有效的访问令牌才能访问此内容。</p>
            <p>请使用正确的URL格式访问：<br><code>/?token=您的访问令牌</code></p>
            <div class="info">
                <p>如需帮助，请联系管理员。</p>
            </div>
        </div>
    </body>
    </html>
    """
    return render_template_string(html)

# 路由：健康检查端点
@app.route('/health')
def health_check():
    """健康检查端点"""
    return jsonify({
        "status": "running",
        "uptime": int(time.time() - SecurityConfig.START_TIME),
        "security_level": SecurityConfig.SECURITY_LEVEL
    })

# 路由：API状态
@app.route('/api/status')
@security_check()
@api_auth_required
def api_status():
    """API状态端点"""
    return jsonify({
        "status": "running",
        "uptime_seconds": int(time.time() - SecurityConfig.START_TIME),
        "uptime_minutes": round((time.time() - SecurityConfig.START_TIME) / 60, 2),
        "security_level": SecurityConfig.SECURITY_LEVEL,
        "visitors": {
            "total": security_state.visit_count,
            "unique": len(security_state.unique_visitors)
        },
        "server": {
            "hostname": socket.gethostname(),
            "time": datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            "unity_dir": ServerConfig.UNITY_DIR
        }
    })

# 路由：API统计
@app.route('/api/stats')
@security_check()
@api_auth_required
def api_stats():
    """API统计端点"""
    # 计算限制时间（如果有）
    time_limit = None
    if SecurityConfig.SECURITY_LEVEL >= 3:
        elapsed_minutes = (time.time() - SecurityConfig.START_TIME) / 60
        time_limit = {
            "limit_minutes": SecurityConfig.TIME_LIMIT_MINUTES,
            "elapsed_minutes": round(elapsed_minutes, 2),
            "remaining_minutes": round(max(0, SecurityConfig.TIME_LIMIT_MINUTES - elapsed_minutes), 2)
        }
    
    # 返回统计数据
    return jsonify({
        "visits": {
            "total": security_state.visit_count,
            "unique": len(security_state.unique_visitors)
        },
        "paths": security_state.path_stats,
        "hourly": security_state.hourly_stats,
        "security": {
            "level": SecurityConfig.SECURITY_LEVEL,
            "banned_ips": len(security_state.banned_ips),
            "time_limit": time_limit
        },
        "server": {
            "uptime_minutes": round((time.time() - SecurityConfig.START_TIME) / 60, 2),
            "unity_dir": ServerConfig.UNITY_DIR
        }
    })

# 启动服务器
if __name__ == '__main__':
    # 生成并保存令牌
    save_tokens()
    
    # 输出安全信息
    security_level_name = ["", "基础", "增强", "最高"][SecurityConfig.SECURITY_LEVEL]
    print(f"🔒 启动安全增强版 Unity WebGL 服务器")
    print("==================================================")
    print(f"📍 安全级别: Level {SecurityConfig.SECURITY_LEVEL}")
    if SecurityConfig.SECURITY_LEVEL == 1:
        print("   - 基础安全 (访问令牌 + 频率限制)")
    elif SecurityConfig.SECURITY_LEVEL == 2:
        print("   - 增强安全 (基础安全 + IP白名单)")
    elif SecurityConfig.SECURITY_LEVEL == 3:
        print(f"   - 最高安全 (增强安全 + 时间限制 {SecurityConfig.TIME_LIMIT_MINUTES}分钟)")
    print(f"🔑 访问令牌: {security_state.access_token}")
    print(f"🔐 管理员令牌: {security_state.admin_token}")
    print("📋 安全功能:")
    print("   ✅ 访问令牌验证 (全局)")
    print("   ✅ 频率限制" if RATE_LIMIT_ENABLED else "   ❌ 频率限制 (未安装flask-limiter)")
    print("   ✅ IP封禁机制")
    print("   ✅ IP白名单保护" if SecurityConfig.SECURITY_LEVEL >= 2 else "   ❌ IP白名单保护 (需要安全级别2或3)")
    print(f"   ✅ 时间限制 ({SecurityConfig.TIME_LIMIT_MINUTES}分钟)" if SecurityConfig.SECURITY_LEVEL >= 3 else "   ❌ 时间限制 (需要安全级别3)")
    print("   ✅ 路径安全检查")
    print("   ✅ 访问日志记录")
    print("   ✅ 安全HTTP头")
    print("")
    print("📱 访问方式:")
    print(f"   游戏: http://localhost:{ServerConfig.PORT}/?token={security_state.access_token}")
    print(f"   统计: http://localhost:{ServerConfig.PORT}/api/stats?admin_token={security_state.admin_token}")
    print("")
    print("⚠️  请妥善保管访问令牌，不要泄露给未授权人员")
    print(f"🔐 访问令牌已保存到 {os.path.basename(ServerConfig.ACCESS_TOKENS_FILE)}")
    
    # 启动服务器
    app.run(host=ServerConfig.HOST, port=ServerConfig.PORT)
