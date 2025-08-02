# Spring Security Dynamic Authorization Demo

**Created:** 2025/7/15 5:07  
**Updated:** 2025/7/15 5:11  
**Exported:** 2025/7/15 5:19  
**Link:** [https://claude.ai/chat/a6b92fc9-7083-4086-9bd7-c1d3df627711](https://claude.ai/chat/a6b92fc9-7083-4086-9bd7-c1d3df627711)  

## Response:


**undefined**

```plaintext
// 添加自定义的FilterSecurityInterceptor
        FilterSecurityInterceptor filterSecurityInterceptor = new FilterSecurityInterceptor();
        filterSecurityInterceptor.setSecurityMetadataSource(customFilterInvocationSecurityMetadataSource);
        filterSecurityInterceptor.setAccessDecisionManager(customAccessDecisionManager);
        
        http.addFilterBefore(filterSecurityInterceptor, FilterSecurityInterceptor.class);
        
        return http.build();
    }
}
```

### RedisConfig.java

```java
package com.example.security.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

@Configuration
public class RedisConfig {
    
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        
        // 设置序列化器
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        
        template.afterPropertiesSet();
        return template;
    }
}
```

## 13. 控制器

### AuthController.java

```java
package com.example.security.controller;

import com.example.security.security.CustomSecurityContextRepository;
import com.example.security.security.JwtTokenProvider;
import com.example.security.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    
    @Autowired
    private AuthenticationManager authenticationManager;
    
    @Autowired
    private JwtTokenProvider tokenProvider;
    
    @Autowired
    private UserService userService;
    
    @Autowired
    private CustomSecurityContextRepository securityContextRepository;
    
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest loginRequest) {
        try {
            Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                    loginRequest.getUsername(),
                    loginRequest.getPassword()
                )
            );
            
            SecurityContextHolder.getContext().setAuthentication(authentication);
            String token = tokenProvider.generateToken(authentication);
            
            Map<String, Object> response = new HashMap<>();
            response.put("token", token);
            response.put("type", "Bearer");
            response.put("username", authentication.getName());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> response = new HashMap<>();
            response.put("error", "Invalid username or password");
            return ResponseEntity.badRequest().body(response);
        }
    }
    
    @PostMapping("/logout")
    public ResponseEntity<?> logout(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token)) {
            securityContextRepository.removeToken(token);
        }
        
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Logged out successfully");
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest registerRequest) {
        if (userService.existsByUsername(registerRequest.getUsername())) {
            Map<String, Object> response = new HashMap<>();
            response.put("error", "Username already exists");
            return ResponseEntity.badRequest().body(response);
        }
        
        userService.createUser(registerRequest.getUsername(), registerRequest.getPassword());
        
        Map<String, Object> response = new HashMap<>();
        response.put("message", "User registered successfully");
        return ResponseEntity.ok(response);
    }
    
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
    
    // 内部类
    public static class LoginRequest {
        private String username;
        private String password;
        
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }
    
    public static class RegisterRequest {
        private String username;
        private String password;
        
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }
}
```

### TestController.java

```java
package com.example.security.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class TestController {
    
    @GetMapping("/user/profile")
    public ResponseEntity<?> getUserProfile() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        Map<String, Object> response = new HashMap<>();
        response.put("username", authentication.getName());
        response.put("authorities", authentication.getAuthorities());
        response.put("message", "User profile accessed successfully");
        
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/user/update")
    public ResponseEntity<?> updateUserProfile(@RequestBody Map<String, Object> request) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        Map<String, Object> response = new HashMap<>();
        response.put("username", authentication.getName());
        response.put("message", "User profile updated successfully");
        response.put("data", request);
        
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/admin/users")
    public ResponseEntity<?> getAllUsers() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        Map<String, Object> response = new HashMap<>();
        response.put("admin", authentication.getName());
        response.put("message", "Admin accessed user list successfully");
        response.put("users", new String[]{"admin", "user", "guest"});
        
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/admin/user")
    public ResponseEntity<?> createUser(@RequestBody Map<String, Object> request) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        Map<String, Object> response = new HashMap<>();
        response.put("admin", authentication.getName());
        response.put("message", "Admin created user successfully");
        response.put("newUser", request);
        
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/public/info")
    public ResponseEntity<?> getPublicInfo() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "This is public information");
        response.put("timestamp", System.currentTimeMillis());
        
        return ResponseEntity.ok(response);
    }
}
```

## 14. 测试说明

### 启动应用

1. 确保Redis服务器正在运行
2. 运行 `SecurityDemoApplication` 主类
3. 应用将在 `http://localhost:8080` 启动

### 测试API

#### 1. 登录获取Token

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

返回：
```json
{
  "token": "eyJhbGciOiJIUzUxMiJ9...",
  "type": "Bearer",
  "username": "admin"
}
```

#### 2. 使用Token访问受保护的资源

```bash
# 访问用户资源 (admin和user都可以访问)
curl -X GET http://localhost:8080/api/user/profile \
  -H "Authorization: Bearer YOUR_TOKEN"

# 访问管理员资源 (只有admin可以访问)
curl -X GET http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 3. 更新用户信息

```bash
curl -X POST http://localhost:8080/api/user/update \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name","email":"updated@example.com"}'
```

#### 4. 登出

```bash
curl -X POST http://localhost:8080/api/auth/logout \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 5. 用普通用户登录测试

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"admin123"}'
```

然后尝试访问管理员资源（应该被拒绝）：
```bash
curl -X GET http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer USER_TOKEN"
```

## 15. 系统特性

### 核心功能

1. **自定义SecurityContextRepository**：
   - 使用Redis存储和验证Token
   - 实现Token的自动刷新
   - 支持Token的主动失效

2. **动态权限控制**：
   - 从数据库动态加载权限配置
   - 支持URL模式匹配
   - 支持HTTP方法级别的权限控制

3. **JWT Token认证**：
   - 无状态的Token认证
   - Token过期时间配置
   - 支持Token撤销

4. **RBAC权限模型**：
   - 用户-角色-权限的三层模型
   - 支持多角色和多权限
   - 灵活的权限分配

### 扩展性

- 可以轻松添加新的权限和角色
- 支持动态权限配置
- 可以集成其他认证方式
- 支持分布式部署

### 安全性

- 密码加密存储
- Token有效期控制
- 防止Token重放攻击
- 支持Token黑名单

这个完整的demo实现了基于Spring Security + Redis的token认证和动态权限控制系统，可以直接运行和测试。
```

我已经为您创建了一个完整的Spring Security + Redis token认证和权限访问控制系统。这个系统包含以下核心功能：

## 🔑 核心特性

1. **自定义SecurityContextRepository** - 使用Redis存储和管理Token
2. **动态权限加载** - 从数据库实时加载权限配置  
3. **JWT Token认证** - 无状态的token认证机制
4. **RBAC权限模型** - 完整的用户-角色-权限体系

## 🚀 快速启动

1. **启动Redis服务器**
2. **运行应用**：执行`SecurityDemoApplication`主类
3. **测试API**：应用会在`http://localhost:8080`启动

## 🧪 测试流程

### 1. 登录获取Token
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 2. 使用Token访问资源
```bash
# 用户资源（admin和user都可访问）
curl -X GET http://localhost:8080/api/user/profile \
  -H "Authorization: Bearer YOUR_TOKEN"

# 管理员资源（只有admin可访问）
curl -X GET http://localhost:8080/api/admin/users \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. 权限测试
- **admin用户**：可以访问所有资源
- **user用户**：只能访问用户相关资源，访问管理员资源会被拒绝

## 🔧 系统架构

- **CustomSecurityContextRepository**：负责Token的Redis存储和验证
- **CustomFilterInvocationSecurityMetadataSource**：动态从数据库加载权限配置
- **CustomAccessDecisionManager**：自定义权限决策逻辑
- **JwtTokenProvider**：JWT Token的生成和验证

## 💾 数据初始化

系统会自动创建测试数据：
- 用户：admin/admin123, user/admin123
- 角色：ROLE_ADMIN, ROLE_USER
- 权限：针对不同URL和HTTP方法的访问控制

这个系统完全可运行，支持动态权限配置、Token管理、用户认证等完整功能。您可以根据需要进行扩展和定制。





---
Powered by [Claude Exporter](https://www.claudexporter.com)