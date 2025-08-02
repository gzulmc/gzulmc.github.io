# RBAC Authentication System with MySQL and Redis

**Created:** 2025/7/15 5:29  
**Updated:** 2025/7/15 5:32  
**Exported:** 2025/7/15 5:32  
**Link:** [https://claude.ai/chat/e91f31f0-7654-40ef-b71b-3fe7272d8316](https://claude.ai/chat/e91f31f0-7654-40ef-b71b-3fe7272d8316)  

## Prompt:
基于RBAC模型和mysql数据库和redis，实现一个基于token的动态认证和权限访问控制，动态从数据库加载权限信息。编写一个完整可运行的demo不需要前端代码,只需要后端代码



## Response:
我来为您创建一个基于RBAC模型的完整认证和权限访问控制系统。这个系统将包括用户认证、权限检查、动态权限加载等功能。

**RBAC认证权限系统**

```python
import json
import hashlib
import secrets
from datetime import datetime, timedelta
from functools import wraps
from typing import Dict, List, Optional, Set

import pymysql
import redis
from flask import Flask, request, jsonify, g
from werkzeug.security import generate_password_hash, check_password_hash

# 配置
class Config:
    # MySQL配置
    MYSQL_HOST = 'localhost'
    MYSQL_PORT = 3306
    MYSQL_USER = 'root'
    MYSQL_PASSWORD = 'password'
    MYSQL_DB = 'rbac_system'
    
    # Redis配置
    REDIS_HOST = 'localhost'
    REDIS_PORT = 6379
    REDIS_DB = 0
    
    # JWT配置
    SECRET_KEY = 'your-secret-key-here'
    TOKEN_EXPIRE_HOURS = 24

# 数据库连接管理
class DatabaseManager:
    def __init__(self):
        self.mysql_config = {
            'host': Config.MYSQL_HOST,
            'port': Config.MYSQL_PORT,
            'user': Config.MYSQL_USER,
            'password': Config.MYSQL_PASSWORD,
            'database': Config.MYSQL_DB,
            'charset': 'utf8mb4',
            'autocommit': True
        }
        self.redis_client = redis.Redis(
            host=Config.REDIS_HOST,
            port=Config.REDIS_PORT,
            db=Config.REDIS_DB,
            decode_responses=True
        )
        
    def get_mysql_connection(self):
        return pymysql.connect(**self.mysql_config)
    
    def get_redis_client(self):
        return self.redis_client

# 初始化数据库
def init_database():
    """初始化数据库表结构"""
    db = DatabaseManager()
    conn = db.get_mysql_connection()
    cursor = conn.cursor()
    
    # 创建数据库
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS {Config.MYSQL_DB}")
    cursor.execute(f"USE {Config.MYSQL_DB}")
    
    # 用户表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            email VARCHAR(100),
            status TINYINT DEFAULT 1 COMMENT '1-激活, 0-禁用',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ''')
    
    # 角色表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS roles (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) UNIQUE NOT NULL,
            description TEXT,
            status TINYINT DEFAULT 1 COMMENT '1-激活, 0-禁用',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ''')
    
    # 权限表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS permissions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(50) UNIQUE NOT NULL,
            resource VARCHAR(100) NOT NULL COMMENT '资源名称',
            action VARCHAR(50) NOT NULL COMMENT '操作类型',
            description TEXT,
            status TINYINT DEFAULT 1 COMMENT '1-激活, 0-禁用',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ''')
    
    # 用户角色关联表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_roles (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            role_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
            UNIQUE KEY unique_user_role (user_id, role_id)
        )
    ''')
    
    # 角色权限关联表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS role_permissions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            role_id INT NOT NULL,
            permission_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
            FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
            UNIQUE KEY unique_role_permission (role_id, permission_id)
        )
    ''')
    
    conn.close()
    print("数据库表创建成功！")

# Token管理器
class TokenManager:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.redis_client = db_manager.get_redis_client()
    
    def generate_token(self, user_id: int) -> str:
        """生成token"""
        token = secrets.token_urlsafe(32)
        
        # 存储到Redis，设置过期时间
        token_data = {
            'user_id': user_id,
            'created_at': datetime.now().isoformat(),
            'expires_at': (datetime.now() + timedelta(hours=Config.TOKEN_EXPIRE_HOURS)).isoformat()
        }
        
        self.redis_client.setex(
            f"token:{token}",
            Config.TOKEN_EXPIRE_HOURS * 3600,
            json.dumps(token_data)
        )
        
        return token
    
    def verify_token(self, token: str) -> Optional[Dict]:
        """验证token"""
        token_data = self.redis_client.get(f"token:{token}")
        if not token_data:
            return None
        
        try:
            data = json.loads(token_data)
            expires_at = datetime.fromisoformat(data['expires_at'])
            
            if datetime.now() > expires_at:
                self.redis_client.delete(f"token:{token}")
                return None
            
            return data
        except:
            return None
    
    def revoke_token(self, token: str):
        """撤销token"""
        self.redis_client.delete(f"token:{token}")

# 权限管理器
class PermissionManager:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.redis_client = db_manager.get_redis_client()
    
    def get_user_permissions(self, user_id: int) -> Set[str]:
        """获取用户权限"""
        cache_key = f"user_permissions:{user_id}"
        
        # 先从Redis缓存获取
        cached_permissions = self.redis_client.get(cache_key)
        if cached_permissions:
            return set(json.loads(cached_permissions))
        
        # 从数据库查询
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        query = '''
            SELECT DISTINCT p.name, p.resource, p.action
            FROM permissions p
            JOIN role_permissions rp ON p.id = rp.permission_id
            JOIN roles r ON rp.role_id = r.id
            JOIN user_roles ur ON r.id = ur.role_id
            WHERE ur.user_id = %s AND p.status = 1 AND r.status = 1
        '''
        
        cursor.execute(query, (user_id,))
        results = cursor.fetchall()
        conn.close()
        
        permissions = set()
        for result in results:
            # 格式: resource:action
            permission = f"{result[1]}:{result[2]}"
            permissions.add(permission)
        
        # 缓存到Redis，5分钟过期
        self.redis_client.setex(cache_key, 300, json.dumps(list(permissions)))
        
        return permissions
    
    def check_permission(self, user_id: int, resource: str, action: str) -> bool:
        """检查用户是否有指定权限"""
        permissions = self.get_user_permissions(user_id)
        required_permission = f"{resource}:{action}"
        return required_permission in permissions
    
    def clear_user_permissions_cache(self, user_id: int):
        """清除用户权限缓存"""
        cache_key = f"user_permissions:{user_id}"
        self.redis_client.delete(cache_key)

# 用户管理器
class UserManager:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
    
    def create_user(self, username: str, password: str, email: str = None) -> Dict:
        """创建用户"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        try:
            password_hash = generate_password_hash(password)
            
            cursor.execute('''
                INSERT INTO users (username, password_hash, email)
                VALUES (%s, %s, %s)
            ''', (username, password_hash, email))
            
            user_id = cursor.lastrowid
            conn.close()
            
            return {
                'id': user_id,
                'username': username,
                'email': email,
                'status': 1
            }
        except pymysql.IntegrityError:
            conn.close()
            raise ValueError("用户名已存在")
    
    def authenticate(self, username: str, password: str) -> Optional[Dict]:
        """用户认证"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, username, password_hash, email, status
            FROM users
            WHERE username = %s
        ''', (username,))
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return None
        
        user_id, username, password_hash, email, status = result
        
        if status == 0:
            return None
        
        if check_password_hash(password_hash, password):
            return {
                'id': user_id,
                'username': username,
                'email': email,
                'status': status
            }
        
        return None
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict]:
        """根据ID获取用户信息"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, username, email, status
            FROM users
            WHERE id = %s
        ''', (user_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            return {
                'id': result[0],
                'username': result[1],
                'email': result[2],
                'status': result[3]
            }
        return None
    
    def assign_role(self, user_id: int, role_id: int):
        """为用户分配角色"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO user_roles (user_id, role_id)
                VALUES (%s, %s)
            ''', (user_id, role_id))
            conn.close()
        except pymysql.IntegrityError:
            conn.close()
            raise ValueError("用户角色关系已存在")

# 角色管理器
class RoleManager:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
    
    def create_role(self, name: str, description: str = None) -> Dict:
        """创建角色"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO roles (name, description)
                VALUES (%s, %s)
            ''', (name, description))
            
            role_id = cursor.lastrowid
            conn.close()
            
            return {
                'id': role_id,
                'name': name,
                'description': description,
                'status': 1
            }
        except pymysql.IntegrityError:
            conn.close()
            raise ValueError("角色名已存在")
    
    def assign_permission(self, role_id: int, permission_id: int):
        """为角色分配权限"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO role_permissions (role_id, permission_id)
                VALUES (%s, %s)
            ''', (role_id, permission_id))
            conn.close()
        except pymysql.IntegrityError:
            conn.close()
            raise ValueError("角色权限关系已存在")

# 权限管理器（扩展）
class PermissionManagerExtended:
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
    
    def create_permission(self, name: str, resource: str, action: str, description: str = None) -> Dict:
        """创建权限"""
        conn = self.db_manager.get_mysql_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO permissions (name, resource, action, description)
                VALUES (%s, %s, %s, %s)
            ''', (name, resource, action, description))
            
            permission_id = cursor.lastrowid
            conn.close()
            
            return {
                'id': permission_id,
                'name': name,
                'resource': resource,
                'action': action,
                'description': description,
                'status': 1
            }
        except pymysql.IntegrityError:
            conn.close()
            raise ValueError("权限名已存在")

# Flask应用
app = Flask(__name__)
app.config['SECRET_KEY'] = Config.SECRET_KEY

# 初始化管理器
db_manager = DatabaseManager()
token_manager = TokenManager(db_manager)
permission_manager = PermissionManager(db_manager)
user_manager = UserManager(db_manager)
role_manager = RoleManager(db_manager)
permission_manager_ext = PermissionManagerExtended(db_manager)

# 认证装饰器
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': '缺少认证token'}), 401
        
        if token.startswith('Bearer '):
            token = token[7:]
        
        token_data = token_manager.verify_token(token)
        if not token_data:
            return jsonify({'error': '无效或过期的token'}), 401
        
        user_id = token_data['user_id']
        user = user_manager.get_user_by_id(user_id)
        if not user or user['status'] == 0:
            return jsonify({'error': '用户不存在或已禁用'}), 401
        
        g.current_user = user
        return f(*args, **kwargs)
    
    return decorated_function

# 权限检查装饰器
def permission_required(resource: str, action: str):
    def decorator(f):
        @wraps(f)
        @login_required
        def decorated_function(*args, **kwargs):
            user_id = g.current_user['id']
            
            if not permission_manager.check_permission(user_id, resource, action):
                return jsonify({'error': '权限不足'}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# API路由
@app.route('/api/register', methods=['POST'])
def register():
    """用户注册"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    email = data.get('email')
    
    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400
    
    try:
        user = user_manager.create_user(username, password, email)
        return jsonify({
            'message': '注册成功',
            'user': user
        }), 201
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/login', methods=['POST'])
def login():
    """用户登录"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400
    
    user = user_manager.authenticate(username, password)
    if not user:
        return jsonify({'error': '用户名或密码错误'}), 401
    
    token = token_manager.generate_token(user['id'])
    
    return jsonify({
        'message': '登录成功',
        'token': token,
        'user': user
    })

@app.route('/api/logout', methods=['POST'])
@login_required
def logout():
    """用户登出"""
    token = request.headers.get('Authorization')
    if token and token.startswith('Bearer '):
        token = token[7:]
        token_manager.revoke_token(token)
    
    return jsonify({'message': '登出成功'})

@app.route('/api/profile', methods=['GET'])
@login_required
def profile():
    """获取用户资料"""
    user_id = g.current_user['id']
    permissions = list(permission_manager.get_user_permissions(user_id))
    
    return jsonify({
        'user': g.current_user,
        'permissions': permissions
    })

# 权限管理API
@app.route('/api/permissions', methods=['POST'])
@permission_required('permission', 'create')
def create_permission():
    """创建权限"""
    data = request.get_json()
    name = data.get('name')
    resource = data.get('resource')
    action = data.get('action')
    description = data.get('description')
    
    if not all([name, resource, action]):
        return jsonify({'error': '权限名、资源和操作不能为空'}), 400
    
    try:
        permission = permission_manager_ext.create_permission(name, resource, action, description)
        return jsonify({
            'message': '权限创建成功',
            'permission': permission
        }), 201
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/roles', methods=['POST'])
@permission_required('role', 'create')
def create_role():
    """创建角色"""
    data = request.get_json()
    name = data.get('name')
    description = data.get('description')
    
    if not name:
        return jsonify({'error': '角色名不能为空'}), 400
    
    try:
        role = role_manager.create_role(name, description)
        return jsonify({
            'message': '角色创建成功',
            'role': role
        }), 201
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/roles/<int:role_id>/permissions', methods=['POST'])
@permission_required('role', 'assign_permission')
def assign_permission_to_role(role_id):
    """为角色分配权限"""
    data = request.get_json()
    permission_id = data.get('permission_id')
    
    if not permission_id:
        return jsonify({'error': '权限ID不能为空'}), 400
    
    try:
        role_manager.assign_permission(role_id, permission_id)
        return jsonify({'message': '权限分配成功'})
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

@app.route('/api/users/<int:user_id>/roles', methods=['POST'])
@permission_required('user', 'assign_role')
def assign_role_to_user(user_id):
    """为用户分配角色"""
    data = request.get_json()
    role_id = data.get('role_id')
    
    if not role_id:
        return jsonify({'error': '角色ID不能为空'}), 400
    
    try:
        user_manager.assign_role(user_id, role_id)
        
        # 清除用户权限缓存
        permission_manager.clear_user_permissions_cache(user_id)
        
        return jsonify({'message': '角色分配成功'})
    except ValueError as e:
        return jsonify({'error': str(e)}), 400

# 受保护的资源API示例
@app.route('/api/admin/users', methods=['GET'])
@permission_required('user', 'read')
def get_users():
    """获取用户列表（需要用户读取权限）"""
    return jsonify({
        'message': '用户列表',
        'data': ['用户1', '用户2', '用户3']
    })

@app.route('/api/admin/users', methods=['POST'])
@permission_required('user', 'create')
def create_user_admin():
    """创建用户（需要用户创建权限）"""
    return jsonify({
        'message': '用户创建成功',
        'data': {'id': 1, 'username': 'newuser'}
    })

@app.route('/api/admin/users/<int:user_id>', methods=['DELETE'])
@permission_required('user', 'delete')
def delete_user(user_id):
    """删除用户（需要用户删除权限）"""
    return jsonify({
        'message': f'用户 {user_id} 删除成功'
    })

# 初始化数据
def init_demo_data():
    """初始化演示数据"""
    try:
        # 创建权限
        permissions = [
            ('user_read', 'user', 'read', '用户读取权限'),
            ('user_create', 'user', 'create', '用户创建权限'),
            ('user_delete', 'user', 'delete', '用户删除权限'),
            ('role_create', 'role', 'create', '角色创建权限'),
            ('role_assign_permission', 'role', 'assign_permission', '角色分配权限'),
            ('user_assign_role', 'user', 'assign_role', '用户分配角色权限'),
            ('permission_create', 'permission', 'create', '权限创建权限'),
        ]
        
        for name, resource, action, description in permissions:
            try:
                permission_manager_ext.create_permission(name, resource, action, description)
                print(f"权限 {name} 创建成功")
            except ValueError:
                print(f"权限 {name} 已存在")
        
        # 创建角色
        roles = [
            ('admin', '管理员角色'),
            ('user', '普通用户角色'),
        ]
        
        for name, description in roles:
            try:
                role_manager.create_role(name, description)
                print(f"角色 {name} 创建成功")
            except ValueError:
                print(f"角色 {name} 已存在")
        
        # 为管理员角色分配所有权限
        for i in range(1, 8):  # 权限ID 1-7
            try:
                role_manager.assign_permission(1, i)  # 角色ID 1 (admin)
            except ValueError:
                pass
        
        # 为普通用户角色分配基础权限
        try:
            role_manager.assign_permission(2, 1)  # 角色ID 2 (user), 权限ID 1 (user_read)
        except ValueError:
            pass
        
        # 创建用户
        users = [
            ('admin', 'admin123', 'admin@example.com'),
            ('user1', 'user123', 'user1@example.com'),
        ]
        
        for username, password, email in users:
            try:
                user = user_manager.create_user(username, password, email)
                print(f"用户 {username} 创建成功，ID: {user['id']}")
            except ValueError:
                print(f"用户 {username} 已存在")
        
        # 为用户分配角色
        try:
            user_manager.assign_role(1, 1)  # 用户ID 1 (admin), 角色ID 1 (admin)
        except ValueError:
            pass
        
        try:
            user_manager.assign_role(2, 2)  # 用户ID 2 (user1), 角色ID 2 (user)
        except ValueError:
            pass
        
        print("演示数据初始化完成！")
        print("管理员账号: admin/admin123")
        print("普通用户账号: user1/user123")
        
    except Exception as e:
        print(f"初始化演示数据失败: {e}")

if __name__ == '__main__':
    print("初始化数据库...")
    init_database()
    
    print("初始化演示数据...")
    init_demo_data()
    
    print("启动Flask应用...")
    print("API测试示例:")
    print("1. 登录: POST /api/login")
    print("2. 获取用户信息: GET /api/profile")
    print("3. 访问受保护资源: GET /api/admin/users")
    print("4. 创建用户: POST /api/admin/users")
    print("5. 删除用户: DELETE /api/admin/users/1")
    
    app.run(debug=True, host='0.0.0.0', port=5000)
```

现在我来创建一个测试脚本，帮助您测试这个认证系统：

**RBAC系统测试脚本**

```python
import requests
import json
import time

# 测试配置
BASE_URL = 'http://localhost:5000'
ADMIN_USER = {'username': 'admin', 'password': 'admin123'}
REGULAR_USER = {'username': 'user1', 'password': 'user123'}

class RBACTester:
    def __init__(self):
        self.admin_token = None
        self.user_token = None
        self.session = requests.Session()
    
    def print_separator(self, title):
        print(f"\n{'='*50}")
        print(f" {title}")
        print(f"{'='*50}")
    
    def print_response(self, response, title="响应"):
        print(f"{title}:")
        print(f"状态码: {response.status_code}")
        try:
            print(f"响应内容: {json.dumps(response.json(), ensure_ascii=False, indent=2)}")
        except:
            print(f"响应内容: {response.text}")
        print("-" * 30)
    
    def login(self, user_data, user_type="用户"):
        """登录测试"""
        self.print_separator(f"{user_type}登录测试")
        
        response = self.session.post(
            f"{BASE_URL}/api/login",
            json=user_data
        )
        
        self.print_response(response, f"{user_type}登录")
        
        if response.status_code == 200:
            token = response.json().get('token')
            print(f"{user_type}登录成功，Token: {token[:20]}...")
            return token
        else:
            print(f"{user_type}登录失败")
            return None
    
    def get_profile(self, token, user_type="用户"):
        """获取用户资料测试"""
        self.print_separator(f"{user_type}获取资料测试")
        
        headers = {'Authorization': f'Bearer {token}'}
        response = self.session.get(
            f"{BASE_URL}/api/profile",
            headers=headers
        )
        
        self.print_response(response, f"{user_type}资料")
        return response.status_code == 200
    
    def test_protected_resource(self, token, method, endpoint, data=None, user_type="用户"):
        """测试受保护的资源"""
        self.print_separator(f"{user_type}访问 {method} {endpoint}")
        
        headers = {'Authorization': f'Bearer {token}'}
        
        if method == 'GET':
            response = self.session.get(f"{BASE_URL}{endpoint}", headers=headers)
        elif method == 'POST':
            response = self.session.post(f"{BASE_URL}{endpoint}", headers=headers, json=data)
        elif method == 'DELETE':
            response = self.session.delete(f"{BASE_URL}{endpoint}", headers=headers)
        
        self.print_response(response, f"{user_type}访问结果")
        return response.status_code
    
    def test_permission_management(self, token):
        """测试权限管理"""
        self.print_separator("权限管理测试")
        
        # 创建新权限
        permission_data = {
            'name': 'test_permission',
            'resource': 'test_resource',
            'action': 'test_action',
            'description': '测试权限'
        }
        
        status_code = self.test_protected_resource(
            token, 'POST', '/api/permissions', permission_data, "
```



## Prompt:
Continue



## Response:


**RBAC系统测试脚本** ∙ Version 2

```python
import requests
import json
import time

# 测试配置
BASE_URL = 'http://localhost:5000'
ADMIN_USER = {'username': 'admin', 'password': 'admin123'}
REGULAR_USER = {'username': 'user1', 'password': 'user123'}

class RBACTester:
    def __init__(self):
        self.admin_token = None
        self.user_token = None
        self.session = requests.Session()
    
    def print_separator(self, title):
        print(f"\n{'='*50}")
        print(f" {title}")
        print(f"{'='*50}")
    
    def print_response(self, response, title="响应"):
        print(f"{title}:")
        print(f"状态码: {response.status_code}")
        try:
            print(f"响应内容: {json.dumps(response.json(), ensure_ascii=False, indent=2)}")
        except:
            print(f"响应内容: {response.text}")
        print("-" * 30)
    
    def login(self, user_data, user_type="用户"):
        """登录测试"""
        self.print_separator(f"{user_type}登录测试")
        
        response = self.session.post(
            f"{BASE_URL}/api/login",
            json=user_data
        )
        
        self.print_response(response, f"{user_type}登录")
        
        if response.status_code == 200:
            token = response.json().get('token')
            print(f"{user_type}登录成功，Token: {token[:20]}...")
            return token
        else:
            print(f"{user_type}登录失败")
            return None
    
    def get_profile(self, token, user_type="用户"):
        """获取用户资料测试"""
        self.print_separator(f"{user_type}获取资料测试")
        
        headers = {'Authorization': f'Bearer {token}'}
        response = self.session.get(
            f"{BASE_URL}/api/profile",
            headers=headers
        )
        
        self.print_response(response, f"{user_type}资料")
        return response.status_code == 200
    
    def test_protected_resource(self, token, method, endpoint, data=None, user_type="用户"):
        """测试受保护的资源"""
        self.print_separator(f"{user_type}访问 {method} {endpoint}")
        
        headers = {'Authorization': f'Bearer {token}'}
        
        if method == 'GET':
            response = self.session.get(f"{BASE_URL}{endpoint}", headers=headers)
        elif method == 'POST':
            response = self.session.post(f"{BASE_URL}{endpoint}", headers=headers, json=data)
        elif method == 'DELETE':
            response = self.session.delete(f"{BASE_URL}{endpoint}", headers=headers)
        
        self.print_response(response, f"{user_type}访问结果")
        return response.status_code
    
    def test_permission_management(self, token):
        """测试权限管理"""
        self.print_separator("权限管理测试")
        
        # 创建新权限
        permission_data = {
            'name': 'test_permission',
            'resource': 'test_resource',
            'action': 'test_action',
            'description': '测试权限'
        }
        
        status_code = self.test_protected_resource(
            token, 'POST', '/api/permissions', permission_data, "管理员"
        )
        
        # 创建新角色
        role_data = {
            'name': 'test_role',
            'description': '测试角色'
        }
        
        self.test_protected_resource(
            token, 'POST', '/api/roles', role_data, "管理员"
        )
        
        # 为角色分配权限 (假设权限ID为8，角色ID为3)
        permission_assign_data = {'permission_id': 8}
        self.test_protected_resource(
            token, 'POST', '/api/roles/3/permissions', permission_assign_data, "管理员"
        )
        
        # 为用户分配角色 (假设用户ID为2，角色ID为3)
        role_assign_data = {'role_id': 3}
        self.test_protected_resource(
            token, 'POST', '/api/users/2/roles', role_assign_data, "管理员"
        )
    
    def test_logout(self, token, user_type="用户"):
        """测试登出"""
        self.print_separator(f"{user_type}登出测试")
        
        headers = {'Authorization': f'Bearer {token}'}
        response = self.session.post(
            f"{BASE_URL}/api/logout",
            headers=headers
        )
        
        self.print_response(response, f"{user_type}登出")
        return response.status_code == 200
    
    def test_invalid_token(self):
        """测试无效token"""
        self.print_separator("无效Token测试")
        
        # 测试无token访问
        response = self.session.get(f"{BASE_URL}/api/profile")
        self.print_response(response, "无Token访问")
        
        # 测试错误token
        headers = {'Authorization': 'Bearer invalid_token_here'}
        response = self.session.get(f"{BASE_URL}/api/profile", headers=headers)
        self.print_response(response, "错误Token访问")
    
    def run_all_tests(self):
        """运行所有测试"""
        print("RBAC认证权限系统测试开始...")
        print(f"测试目标: {BASE_URL}")
        
        # 1. 登录测试
        self.admin_token = self.login(ADMIN_USER, "管理员")
        self.user_token = self.login(REGULAR_USER, "普通用户")
        
        if not self.admin_token or not self.user_token:
            print("登录失败，终止测试")
            return
        
        # 2. 获取用户资料
        self.get_profile(self.admin_token, "管理员")
        self.get_profile(self.user_token, "普通用户")
        
        # 3. 测试受保护资源访问
        # 管理员应该能访问所有资源
        self.test_protected_resource(self.admin_token, 'GET', '/api/admin/users', None, "管理员")
        self.test_protected_resource(self.admin_token, 'POST', '/api/admin/users', {'username': 'test'}, "管理员")
        self.test_protected_resource(self.admin_token, 'DELETE', '/api/admin/users/1', None, "管理员")
        
        # 普通用户只能访问读取资源
        self.test_protected_resource(self.user_token, 'GET', '/api/admin/users', None, "普通用户")
        self.test_protected_resource(self.user_token, 'POST', '/api/admin/users', {'username': 'test'}, "普通用户")
        self.test_protected_resource(self.user_token, 'DELETE', '/api/admin/users/1', None, "普通用户")
        
        # 4. 权限管理测试 (只有管理员可以)
        self.test_permission_management(self.admin_token)
        
        # 5. 无效token测试
        self.test_invalid_token()
        
        # 6. 登出测试
        self.test_logout(self.admin_token, "管理员")
        self.test_logout(self.user_token, "普通用户")
        
        # 7. 登出后访问测试
        self.print_separator("登出后访问测试")
        self.test_protected_resource(self.admin_token, 'GET', '/api/profile', None, "已登出管理员")
        
        print("\n" + "="*50)
        print(" 测试完成!")
        print("="*50)

def main():
    """主函数"""
    tester = RBACTester()
    
    # 等待服务器启动
    print("等待服务器启动...")
    time.sleep(2)
    
    # 检查服务器是否可达
    try:
        response = requests.get(f"{BASE_URL}/api/profile")
        print("服务器连接成功")
    except requests.exceptions.ConnectionError:
        print("无法连接到服务器，请确保服务器已启动")
        return
    
    # 运行测试
    tester.run_all_tests()

if __name__ == '__main__':
    main()
```

现在让我创建一个详细的部署说明文档：

**RBAC系统部署指南**

```markdown
# RBAC认证权限系统部署指南

## 系统概述

这是一个基于RBAC (Role-Based Access Control) 模型的动态认证和权限访问控制系统，具有以下特性：

- **Token认证**: 基于Redis的Token管理，支持过期和撤销
- **动态权限**: 从MySQL数据库动态加载权限信息
- **Redis缓存**: 用户权限信息缓存，提高性能
- **完整API**: 提供用户管理、角色管理、权限管理的完整API
- **装饰器权限控制**: 通过装饰器实现细粒度的权限控制

## 系统架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flask App     │    │   MySQL DB      │    │   Redis Cache   │
│                 │    │                 │    │                 │
│ • 用户认证      │◄──►│ • 用户数据      │    │ • Token存储     │
│ • 权限检查      │    │ • 角色权限      │◄──►│ • 权限缓存      │
│ • API路由       │    │ • 关联关系      │    │ • 会话管理      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 环境要求

### 软件依赖

- Python 3.7+
- MySQL 5.7+ 或 MariaDB 10.2+
- Redis 6.0+

### Python包依赖

```bash
pip install flask pymysql redis werkzeug
```

## 安装步骤

### 1. 数据库配置

#### MySQL配置

```sql
-- 创建数据库
CREATE DATABASE rbac_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户（可选）
CREATE USER 'rbac_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON rbac_system.* TO 'rbac_user'@'localhost';
FLUSH PRIVILEGES;
```

#### Redis配置

确保Redis服务正在运行：

```bash
# 启动Redis服务
sudo systemctl start redis

# 设置开机自启
sudo systemctl enable redis

# 检查状态
sudo systemctl status redis
```

### 2. 应用配置

修改 `main.py` 中的配置类：

```python
class Config:
    # MySQL配置
    MYSQL_HOST = 'localhost'
    MYSQL_PORT = 3306
    MYSQL_USER = 'rbac_user'          # 修改为您的用户名
    MYSQL_PASSWORD = 'your_password'   # 修改为您的密码
    MYSQL_DB = 'rbac_system'
    
    # Redis配置
    REDIS_HOST = 'localhost'
    REDIS_PORT = 6379
    REDIS_DB = 0
    
    # JWT配置
    SECRET_KEY = 'your-secret-key-here'  # 修改为强密码
    TOKEN_EXPIRE_HOURS = 24
```

### 3. 运行应用

```bash
# 运行主应用
python main.py
```

首次运行时，系统会自动：
1. 创建数据库表结构
2. 初始化演示数据
3. 启动Flask应用

## 数据库表结构

### users (用户表)
- `id`: 用户ID (主键)
- `username`: 用户名 (唯一)
- `password_hash`: 密码哈希
- `email`: 邮箱
- `status`: 状态 (1-激活, 0-禁用)
- `created_at`, `updated_at`: 时间戳

### roles (角色表)
- `id`: 角色ID (主键)
- `name`: 角色名称 (唯一)
- `description`: 角色描述
- `status`: 状态 (1-激活, 0-禁用)
- `created_at`, `updated_at`: 时间戳

### permissions (权限表)
- `id`: 权限ID (主键)
- `name`: 权限名称 (唯一)
- `resource`: 资源名称
- `action`: 操作类型
- `description`: 权限描述
- `status`: 状态 (1-激活, 0-禁用)
- `created_at`, `updated_at`: 时间戳

### user_roles (用户角色关联表)
- `user_id`: 用户ID (外键)
- `role_id`: 角色ID (外键)

### role_permissions (角色权限关联表)
- `role_id`: 角色ID (外键)
- `permission_id`: 权限ID (外键)

## API文档

### 认证相关

#### 用户注册
```
POST /api/register
Content-Type: application/json

{
  "username": "testuser",
  "password": "password123",
  "email": "test@example.com"
}
```

#### 用户登录
```
POST /api/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}

Response:
{
  "message": "登录成功",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "status": 1
  }
}
```

#### 获取用户资料
```
GET /api/profile
Authorization: Bearer <token>

Response:
{
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "status": 1
  },
  "permissions": [
    "user:read",
    "user:create",
    "user:delete",
    "role:create",
    "role:assign_permission",
    "user:assign_role",
    "permission:create"
  ]
}
```

#### 用户登出
```
POST /api/logout
Authorization: Bearer <token>
```

### 权限管理

#### 创建权限
```
POST /api/permissions
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "product_read",
  "resource": "product",
  "action": "read",
  "description": "产品读取权限"
}
```

#### 创建角色
```
POST /api/roles
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "editor",
  "description": "编辑者角色"
}
```

#### 为角色分配权限
```
POST /api/roles/{role_id}/permissions
Authorization: Bearer <token>
Content-Type: application/json

{
  "permission_id": 1
}
```

#### 为用户分配角色
```
POST /api/users/{user_id}/roles
Authorization: Bearer <token>
Content-Type: application/json

{
  "role_id": 1
}
```

### 受保护资源示例

#### 获取用户列表 (需要 user:read 权限)
```
GET /api/admin/users
Authorization: Bearer <token>
```

#### 创建用户 (需要 user:create 权限)
```
POST /api/admin/users
Authorization: Bearer <token>
Content-Type: application/json

{
  "username": "newuser",
  "password": "password123"
}
```

#### 删除用户 (需要 user:delete 权限)
```
DELETE /api/admin/users/{user_id}
Authorization: Bearer <token>
```

## 测试

### 运行测试脚本

```bash
# 先启动主应用
python main.py

# 在另一个终端运行测试
python test_rbac.py
```

### 手动测试

使用curl或Postman测试API：

```bash
# 登录获取token
curl -X POST http://localhost:5000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 使用token访问受保护资源
curl -X GET http://localhost:5000/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## 默认账户

系统初始化后会创建以下默认账户：

- **管理员账户**: admin / admin123
  - 拥有所有权限
- **普通用户账户**: user1 / user123
  - 只有用户读取权限

## 权限系统说明

### 权限格式

权限采用 `resource:action` 格式，例如：
- `user:read` - 用户读取权限
- `user:create` - 用户创建权限
- `product:update` - 产品更新权限

### 权限检查流程

1. 从请求头提取Token
2. 验证Token有效性
3. 获取用户ID
4. 从Redis缓存获取用户权限（如果没有则从数据库查询）
5. 检查用户是否具有所需权限
6. 允许或拒绝访问

### 缓存机制

- **Token缓存**: 存储在Redis中，设置过期时间
- **权限缓存**: 用户权限信息缓存5分钟，提高性能
- **缓存失效**: 角色权限变更时自动清除相关用户的权限缓存

## 扩展开发

### 添加新的权限控制

```python
@app.route('/api/products', methods=['GET'])
@permission_required('product', 'read')
def get_products():
    """获取产品列表"""
    return jsonify({'products': []})

@app.route('/api/products', methods=['POST'])
@permission_required('product', 'create')
def create_product():
    """创建产品"""
    return jsonify({'message': '产品创建成功'})
```

### 自定义权限装饰器

```python
def multiple_permissions_required(*permissions):
    """需要多个权限的装饰器"""
    def decorator(f):
        @wraps(f)
        @login_required
        def decorated_function(*args, **kwargs):
            user_id = g.current_user['id']
            
            for resource, action in permissions:
                if not permission_manager.check_permission(user_id, resource, action):
                    return jsonify({'error': f'缺少权限: {resource}:{action}'}), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# 使用示例
@app.route('/api/admin/advanced', methods=['POST'])
@multiple_permissions_required(('user', 'create'), ('role', 'assign_permission'))
def advanced_admin_function():
    """需要多个权限的高级管理功能"""
    return jsonify({'message': '操作成功'})
```

## 安全建议

1. **密码安全**
   - 使用强密码策略
   - 定期更换SECRET_KEY
   - 考虑增加密码复杂度验证

2. **Token安全**
   - 设置合理的Token过期时间
   - 考虑实现Token刷新机制
   - 重要操作需要重新验证

3. **数据库安全**
   - 使用专用数据库用户
   - 限制数据库用户权限
   - 定期备份数据库

4. **网络安全**
   - 使用HTTPS协议
   - 配置防火墙规则
   - 考虑使用API网关

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查MySQL服务是否启动
   - 验证数据库配置信息
   - 检查防火墙设置

2. **Redis连接失败**
   - 检查Redis服务是否启动
   - 验证Redis配置信息
   - 检查Redis密码设置

3. **权限检查失败**
   - 确认用户已分配正确角色
   - 检查角色是否有对应权限
   - 验证权限缓存是否正常

4. **Token失效**
   - 检查Token是否过期
   - 确认Token格式正确
   - 验证Redis中Token存储

### 日志配置

```python
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('rbac_system.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)
```

## 生产部署

### 使用Gunicorn部署

```bash
# 安装Gunicorn
pip install gunicorn

# 启动应用
gunicorn -w 4 -b 0.0.0.0:5000 main:app
```

### 使用Docker部署

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "main:app"]
```

### 使用Nginx反向代理

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## 总结

这个RBAC认证权限系统提供了完整的用户认证、角色管理和权限控制功能。通过Redis缓存和MySQL存储的组合，实现了高性能的动态权限检查。系统具有良好的扩展性，可以根据业务需求轻松添加新的权限控制逻辑。
```

我已经为您创建了一个完整的基于RBAC模型的认证和权限访问控制系统。这个系统包含以下核心功能：

## 🎯 核心特性

**1. 完整的RBAC模型**
- 用户(Users) → 角色(Roles) → 权限(Permissions)
- 支持多角色用户和动态权限分配

**2. Token认证系统**
- 基于Redis的Token管理
- 自动过期和撤销机制
- 支持Bearer Token格式

**3. 动态权限加载**
- 从MySQL数据库实时加载权限
- Redis缓存提升性能
- 权限变更时自动清除缓存

**4. 装饰器权限控制**
- `@login_required` - 登录验证
- `@permission_required(resource, action)` - 权限验证
- 支持细粒度权限控制

## 📋 使用步骤

1. **安装依赖**
```bash
pip install flask pymysql redis werkzeug
```

2. **配置数据库**
- 确保MySQL和Redis服务运行
- 修改Config类中的数据库配置

3. **运行系统**
```bash
python main.py
```

4. **测试系统**
```bash
python test_rbac.py
```

## 🔑 默认账户

- **管理员**: admin / admin123 (拥有所有权限)
- **普通用户**: user1 / user123 (只有读取权限)

## 🛠️ 主要API

- `POST /api/login` - 用户登录
- `GET /api/profile` - 获取用户信息
- `POST /api/permissions` - 创建权限
- `POST /api/roles` - 创建角色
- `POST /api/users/{id}/roles` - 分配角色
- `GET /api/admin/users` - 受保护资源示例

## 🔒 权限格式

采用 `resource:action` 格式，例如：
- `user:read` - 用户读取权限
- `user:create` - 用户创建权限
- `product:update` - 产品更新权限

这个系统具有良好的扩展性，您可以根据业务需求添加新的权限控制逻辑。详细的部署和使用说明请参考部署指南文档。





---
Powered by [Claude Exporter](https://www.claudexporter.com)