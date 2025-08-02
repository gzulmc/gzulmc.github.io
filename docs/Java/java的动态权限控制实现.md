# Spring Security RBAC Authentication System

**Created:** 2025/7/15 13:11  
**Updated:** 2025/7/15 13:14  
**Exported:** 2025/7/15 13:16  
**Link:** [https://claude.ai/chat/abba8596-588b-434e-b899-efd2a09a8116](https://claude.ai/chat/abba8596-588b-434e-b899-efd2a09a8116)  

## Prompt:
使用springboot和spring security技术,基于RBAC模型和mysql数据库和redis,实现一个基于token的动态认证和权限访问控制,动态从数据库加载权限信息。编写一个完整可运行的demo,不需要前端代码,只需要后端代码。写清楚每步的注释,重点在filtersecurityinterceptor的授权部分,这个部分是我想要掌握清楚的知识点,包括自定义数据源和自定义决策等。



## Response:
我将为您创建一个基于Spring Boot、Spring Security、RBAC模型的完整认证和权限访问控制系统。重点关注FilterSecurityInterceptor的授权部分，包括自定义数据源和自定义决策管理器。

**RBAC权限控制系统 - 完整项目结构**

```java
# Spring Boot RBAC 权限控制系统完整Demo

## 项目结构
```
src/main/java/com/example/rbac/
├── RbacApplication.java                    # 主启动类
├── config/
│   ├── SecurityConfig.java                # Spring Security核心配置
│   ├── RedisConfig.java                   # Redis配置
│   └── DataSourceConfig.java             # 数据源配置
├── security/
│   ├── JwtTokenProvider.java              # JWT工具类
│   ├── JwtAuthenticationFilter.java       # JWT认证过滤器
│   ├── CustomUserDetailsService.java     # 自定义用户详情服务
│   ├── CustomSecurityMetadataSource.java # 自定义权限数据源（重点）
│   ├── CustomAccessDecisionManager.java  # 自定义访问决策管理器（重点）
│   └── CustomAuthenticationEntryPoint.java # 自定义认证入口点
├── entity/
│   ├── User.java                          # 用户实体
│   ├── Role.java                          # 角色实体
│   ├── Permission.java                    # 权限实体
│   └── UserRole.java                      # 用户角色关联实体
├── repository/
│   ├── UserRepository.java                # 用户仓库
│   ├── RoleRepository.java                # 角色仓库
│   └── PermissionRepository.java          # 权限仓库
├── service/
│   ├── UserService.java                   # 用户服务
│   ├── AuthService.java                   # 认证服务
│   └── PermissionService.java             # 权限服务
├── controller/
│   ├── AuthController.java                # 认证控制器
│   ├── UserController.java                # 用户控制器
│   └── AdminController.java               # 管理员控制器
└── dto/
    ├── LoginRequest.java                  # 登录请求DTO
    ├── LoginResponse.java                 # 登录响应DTO
    └── ApiResponse.java                   # 通用响应DTO
```

## 1. 主启动类

```java
package com.example.rbac;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@SpringBootApplication
@EnableCaching
@EnableTransactionManagement
public class RbacApplication {
    public static void main(String[] args) {
        SpringApplication.run(RbacApplication.class, args);
    }
}
```

## 2. 数据库实体类

### User.java
```java
package com.example.rbac.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @JsonIgnore
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private String email;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    // 多对多关系：用户-角色
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // 构造函数
    public User() {}
    
    public User(String username, String password, String email) {
        this.username = username;
        this.password = password;
        this.email = email;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "roles")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    // 多对多关系：角色-权限
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "role_permissions",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Role() {}
    
    public Role(String name, String description) {
        this.name = name;
        this.description = description;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "permissions")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "resource_url")
    private String resourceUrl; // 资源URL匹配模式
    
    @Column(name = "http_method")
    private String httpMethod; // HTTP方法：GET, POST, PUT, DELETE等
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String description, String resourceUrl, String httpMethod) {
        this.name = name;
        this.description = description;
        this.resourceUrl = resourceUrl;
        this.httpMethod = httpMethod;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public String getResourceUrl() { return resourceUrl; }
    public void setResourceUrl(String resourceUrl) { this.resourceUrl = resourceUrl; }
    
    public String getHttpMethod() { return httpMethod; }
    public void setHttpMethod(String httpMethod) { this.httpMethod = httpMethod; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
```

## 3. 数据访问层

### UserRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * 根据用户名查找用户，同时预加载角色和权限信息
     * 使用左连接避免N+1查询问题
     */
    @Query("SELECT DISTINCT u FROM User u " +
           "LEFT JOIN FETCH u.roles r " +
           "LEFT JOIN FETCH r.permissions " +
           "WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
    
    /**
     * 根据用户名查找用户
     */
    Optional<User> findByUsername(String username);
    
    /**
     * 检查用户名是否存在
     */
    boolean existsByUsername(String username);
    
    /**
     * 检查邮箱是否存在
     */
    boolean existsByEmail(String email);
}
```

### RoleRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    
    /**
     * 根据角色名查找角色
     */
    Optional<Role> findByName(String name);
    
    /**
     * 查找所有角色并预加载权限信息
     */
    @Query("SELECT DISTINCT r FROM Role r LEFT JOIN FETCH r.permissions")
    List<Role> findAllWithPermissions();
    
    /**
     * 检查角色名是否存在
     */
    boolean existsByName(String name);
}
```

### PermissionRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    
    /**
     * 根据权限名查找权限
     */
    Optional<Permission> findByName(String name);
    
    /**
     * 根据资源URL和HTTP方法查找权限
     */
    Optional<Permission> findByResourceUrlAndHttpMethod(String resourceUrl, String httpMethod);
    
    /**
     * 查找所有权限资源配置，用于动态权限验证
     * 返回所有包含资源URL的权限
     */
    @Query("SELECT p FROM Permission p WHERE p.resourceUrl IS NOT NULL")
    List<Permission> findAllResourcePermissions();
    
    /**
     * 根据用户ID查找该用户拥有的所有权限
     * 通过用户->角色->权限的关联查询
     */
    @Query("SELECT DISTINCT p FROM Permission p " +
           "JOIN p.roles r " +
           "JOIN r.users u " +
           "WHERE u.id = :userId")
    List<Permission> findPermissionsByUserId(@Param("userId") Long userId);
    
    /**
     * 检查权限名是否存在
     */
    boolean existsByName(String name);
}
```

## 4. JWT工具类

### JwtTokenProvider.java
```java
package com.example.rbac.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

/**
 * JWT Token 提供者
 * 负责生成、解析和验证JWT令牌
 */
@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    // JWT密钥，从配置文件读取
    @Value("${app.jwt.secret:mySecretKey}")
    private String jwtSecret;
    
    // JWT过期时间（毫秒），默认24小时
    @Value("${app.jwt.expiration:86400000}")
    private long jwtExpiration;
    
    /**
     * 生成JWT令牌
     * @param authentication 认证信息
     * @return JWT令牌字符串
     */
    public String generateToken(Authentication authentication) {
        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        // 使用HMAC SHA算法签名
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        return Jwts.builder()
                .setSubject(userDetails.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }
    
    /**
     * 从JWT令牌中获取用户名
     * @param token JWT令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    /**
     * 验证JWT令牌
     * @param token JWT令牌
     * @return 是否有效
     */
    public boolean validateToken(String token) {
        try {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
            Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token);
            return true;
        } catch (SecurityException ex) {
            logger.error("Invalid JWT signature: {}", ex.getMessage());
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token: {}", ex.getMessage());
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token: {}", ex.getMessage());
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token: {}", ex.getMessage());
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty: {}", ex.getMessage());
        }
        return false;
    }
}
```

## 5. 自定义用户详情服务

### CustomUserDetailsService.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.User;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.Permission;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * 自定义用户详情服务
 * 实现Spring Security的UserDetailsService接口
 * 负责从数据库加载用户信息和权限信息
 */
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * 根据用户名加载用户详情
     * 这个方法在用户认证时被调用
     * @param username 用户名
     * @return UserDetails 用户详情对象
     * @throws UsernameNotFoundException 用户不存在异常
     */
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 从数据库查找用户，同时预加载角色和权限信息
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        // 构建用户权限列表
        List<GrantedAuthority> authorities = buildUserAuthorities(user.getRoles());
        
        // 创建Spring Security的User对象
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword())
                .authorities(authorities)
                .accountExpired(false)
                .accountLocked(false)
                .credentialsExpired(false)
                .disabled(!user.getEnabled())
                .build();
    }
    
    /**
     * 构建用户权限列表
     * 将角色和权限转换为Spring Security的GrantedAuthority
     * @param roles 用户角色集合
     * @return 权限列表
     */
    private List<GrantedAuthority> buildUserAuthorities(Set<Role> roles) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        for (Role role : roles) {
            // 添加角色权限，角色名前缀为ROLE_
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getName()));
            
            // 添加角色下的具体权限
            for (Permission permission : role.getPermissions()) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return authorities;
    }
}
```

继续下一部分...
```

**RBAC权限控制系统 - 完整项目结构** ∙ Version 2

```java
# Spring Boot RBAC 权限控制系统完整Demo

## 项目结构
```
src/main/java/com/example/rbac/
├── RbacApplication.java                    # 主启动类
├── config/
│   ├── SecurityConfig.java                # Spring Security核心配置
│   ├── RedisConfig.java                   # Redis配置
│   └── DataSourceConfig.java             # 数据源配置
├── security/
│   ├── JwtTokenProvider.java              # JWT工具类
│   ├── JwtAuthenticationFilter.java       # JWT认证过滤器
│   ├── CustomUserDetailsService.java     # 自定义用户详情服务
│   ├── CustomSecurityMetadataSource.java # 自定义权限数据源（重点）
│   ├── CustomAccessDecisionManager.java  # 自定义访问决策管理器（重点）
│   └── CustomAuthenticationEntryPoint.java # 自定义认证入口点
├── entity/
│   ├── User.java                          # 用户实体
│   ├── Role.java                          # 角色实体
│   ├── Permission.java                    # 权限实体
│   └── UserRole.java                      # 用户角色关联实体
├── repository/
│   ├── UserRepository.java                # 用户仓库
│   ├── RoleRepository.java                # 角色仓库
│   └── PermissionRepository.java          # 权限仓库
├── service/
│   ├── UserService.java                   # 用户服务
│   ├── AuthService.java                   # 认证服务
│   └── PermissionService.java             # 权限服务
├── controller/
│   ├── AuthController.java                # 认证控制器
│   ├── UserController.java                # 用户控制器
│   └── AdminController.java               # 管理员控制器
└── dto/
    ├── LoginRequest.java                  # 登录请求DTO
    ├── LoginResponse.java                 # 登录响应DTO
    └── ApiResponse.java                   # 通用响应DTO
```

## 1. 主启动类

```java
package com.example.rbac;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@SpringBootApplication
@EnableCaching
@EnableTransactionManagement
public class RbacApplication {
    public static void main(String[] args) {
        SpringApplication.run(RbacApplication.class, args);
    }
}
```

## 2. 数据库实体类

### User.java
```java
package com.example.rbac.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @JsonIgnore
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private String email;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    // 多对多关系：用户-角色
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // 构造函数
    public User() {}
    
    public User(String username, String password, String email) {
        this.username = username;
        this.password = password;
        this.email = email;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "roles")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    // 多对多关系：角色-权限
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "role_permissions",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Role() {}
    
    public Role(String name, String description) {
        this.name = name;
        this.description = description;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "permissions")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "resource_url")
    private String resourceUrl; // 资源URL匹配模式
    
    @Column(name = "http_method")
    private String httpMethod; // HTTP方法：GET, POST, PUT, DELETE等
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String description, String resourceUrl, String httpMethod) {
        this.name = name;
        this.description = description;
        this.resourceUrl = resourceUrl;
        this.httpMethod = httpMethod;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public String getResourceUrl() { return resourceUrl; }
    public void setResourceUrl(String resourceUrl) { this.resourceUrl = resourceUrl; }
    
    public String getHttpMethod() { return httpMethod; }
    public void setHttpMethod(String httpMethod) { this.httpMethod = httpMethod; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
```

## 3. 数据访问层

### UserRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * 根据用户名查找用户，同时预加载角色和权限信息
     * 使用左连接避免N+1查询问题
     */
    @Query("SELECT DISTINCT u FROM User u " +
           "LEFT JOIN FETCH u.roles r " +
           "LEFT JOIN FETCH r.permissions " +
           "WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
    
    /**
     * 根据用户名查找用户
     */
    Optional<User> findByUsername(String username);
    
    /**
     * 检查用户名是否存在
     */
    boolean existsByUsername(String username);
    
    /**
     * 检查邮箱是否存在
     */
    boolean existsByEmail(String email);
}
```

### RoleRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    
    /**
     * 根据角色名查找角色
     */
    Optional<Role> findByName(String name);
    
    /**
     * 查找所有角色并预加载权限信息
     */
    @Query("SELECT DISTINCT r FROM Role r LEFT JOIN FETCH r.permissions")
    List<Role> findAllWithPermissions();
    
    /**
     * 检查角色名是否存在
     */
    boolean existsByName(String name);
}
```

### PermissionRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    
    /**
     * 根据权限名查找权限
     */
    Optional<Permission> findByName(String name);
    
    /**
     * 根据资源URL和HTTP方法查找权限
     */
    Optional<Permission> findByResourceUrlAndHttpMethod(String resourceUrl, String httpMethod);
    
    /**
     * 查找所有权限资源配置，用于动态权限验证
     * 返回所有包含资源URL的权限
     */
    @Query("SELECT p FROM Permission p WHERE p.resourceUrl IS NOT NULL")
    List<Permission> findAllResourcePermissions();
    
    /**
     * 根据用户ID查找该用户拥有的所有权限
     * 通过用户->角色->权限的关联查询
     */
    @Query("SELECT DISTINCT p FROM Permission p " +
           "JOIN p.roles r " +
           "JOIN r.users u " +
           "WHERE u.id = :userId")
    List<Permission> findPermissionsByUserId(@Param("userId") Long userId);
    
    /**
     * 检查权限名是否存在
     */
    boolean existsByName(String name);
}
```

## 4. JWT工具类

### JwtTokenProvider.java
```java
package com.example.rbac.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

/**
 * JWT Token 提供者
 * 负责生成、解析和验证JWT令牌
 */
@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    // JWT密钥，从配置文件读取
    @Value("${app.jwt.secret:mySecretKey}")
    private String jwtSecret;
    
    // JWT过期时间（毫秒），默认24小时
    @Value("${app.jwt.expiration:86400000}")
    private long jwtExpiration;
    
    /**
     * 生成JWT令牌
     * @param authentication 认证信息
     * @return JWT令牌字符串
     */
    public String generateToken(Authentication authentication) {
        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        // 使用HMAC SHA算法签名
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        return Jwts.builder()
                .setSubject(userDetails.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }
    
    /**
     * 从JWT令牌中获取用户名
     * @param token JWT令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    /**
     * 验证JWT令牌
     * @param token JWT令牌
     * @return 是否有效
     */
    public boolean validateToken(String token) {
        try {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
            Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token);
            return true;
        } catch (SecurityException ex) {
            logger.error("Invalid JWT signature: {}", ex.getMessage());
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token: {}", ex.getMessage());
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token: {}", ex.getMessage());
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token: {}", ex.getMessage());
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty: {}", ex.getMessage());
        }
        return false;
    }
}
```

## 5. 自定义用户详情服务

### CustomUserDetailsService.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.User;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.Permission;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * 自定义用户详情服务
 * 实现Spring Security的UserDetailsService接口
 * 负责从数据库加载用户信息和权限信息
 */
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * 根据用户名加载用户详情
     * 这个方法在用户认证时被调用
     * @param username 用户名
     * @return UserDetails 用户详情对象
     * @throws UsernameNotFoundException 用户不存在异常
     */
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 从数据库查找用户，同时预加载角色和权限信息
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        // 构建用户权限列表
        List<GrantedAuthority> authorities = buildUserAuthorities(user.getRoles());
        
        // 创建Spring Security的User对象
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword())
                .authorities(authorities)
                .accountExpired(false)
                .accountLocked(false)
                .credentialsExpired(false)
                .disabled(!user.getEnabled())
                .build();
    }
    
    /**
     * 构建用户权限列表
     * 将角色和权限转换为Spring Security的GrantedAuthority
     * @param roles 用户角色集合
     * @return 权限列表
     */
    private List<GrantedAuthority> buildUserAuthorities(Set<Role> roles) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        for (Role role : roles) {
            // 添加角色权限，角色名前缀为ROLE_
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getName()));
            
            // 添加角色下的具体权限
            for (Permission permission : role.getPermissions()) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return authorities;
    }
}
```

## 6. JWT认证过滤器

### JwtAuthenticationFilter.java
```java
package com.example.rbac.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * JWT认证过滤器
 * 继承OncePerRequestFilter确保每个请求只执行一次
 * 负责从请求头中提取JWT令牌并验证用户身份
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    
    @Autowired
    private JwtTokenProvider jwtTokenProvider;
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    /**
     * 执行JWT认证过滤
     * @param request HTTP请求
     * @param response HTTP响应
     * @param filterChain 过滤器链
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response, 
                                   FilterChain filterChain) throws ServletException, IOException {
        try {
            // 从请求头中提取JWT令牌
            String jwt = getJwtFromRequest(request);
            
            // 验证令牌并设置认证信息
            if (StringUtils.hasText(jwt) && jwtTokenProvider.validateToken(jwt)) {
                String username = jwtTokenProvider.getUsernameFromToken(jwt);
                
                // 加载用户详情
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                // 创建认证令牌
                UsernamePasswordAuthenticationToken authentication = 
                    new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                
                // 设置到安全上下文中
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        } catch (Exception ex) {
            logger.error("Could not set user authentication in security context", ex);
        }
        
        // 继续执行过滤器链
        filterChain.doFilter(request, response);
    }
    
    /**
     * 从请求头中提取JWT令牌
     * @param request HTTP请求
     * @return JWT令牌字符串
     */
    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
```

## 7. 自定义权限数据源（重点）

### CustomSecurityMetadataSource.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.Permission;
import com.example.rbac.repository.PermissionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;

import javax.annotation.PostConstruct;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 自定义权限数据源（重点类）
 * 实现FilterInvocationSecurityMetadataSource接口
 * 
 * 核心作用：
 * 1. 根据请求的URL和HTTP方法，动态确定访问该资源所需的权限
 * 2. 从数据库动态加载权限配置，支持权限的动态更新
 * 3. 使用Redis缓存提高性能
 * 4. 为FilterSecurityInterceptor提供权限配置信息
 */
@Component
public class CustomSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomSecurityMetadataSource.class);
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    // 路径匹配器，用于匹配URL模式
    private final AntPathMatcher pathMatcher = new AntPathMatcher();
    
    // Redis缓存key前缀
    private static final String PERMISSION_CACHE_PREFIX = "permission:";
    private static final String ALL_PERMISSIONS_CACHE_KEY = "all_permissions";
    
    // 权限配置本地缓存
    private Map<String, List<String>> resourcePermissionMap = new HashMap<>();
    
    /**
     * 初始化权限数据源
     * 系统启动时加载所有权限配置到缓存
     */
    @PostConstruct
    public void init() {
        logger.info("初始化权限数据源...");
        loadAllPermissions();
        logger.info("权限数据源初始化完成，共加载{}个权限配置", resourcePermissionMap.size());
    }
    
    /**
     * 核心方法：根据请求获取所需权限
     * 这个方法在每次请求时被FilterSecurityInterceptor调用
     * 
     * @param object FilterInvocation对象，包含请求信息
     * @return 访问该资源所需的权限配置集合
     */
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String httpMethod = filterInvocation.getRequest().getMethod();
        
        logger.debug("获取资源权限配置: URL={}, Method={}", requestUrl, httpMethod);
        
        // 移除查询参数，只保留路径部分
        String path = requestUrl.split("\\?")[0];
        
        // 构建缓存key
        String cacheKey = PERMISSION_CACHE_PREFIX + httpMethod + ":" + path;
        
        // 1. 先从Redis缓存中查找
        List<String> cachedPermissions = (List<String>) redisTemplate.opsForValue().get(cacheKey);
        if (cachedPermissions != null) {
            logger.debug("从Redis缓存获取权限: {}", cachedPermissions);
            return createConfigAttributes(cachedPermissions);
        }
        
        // 2. 从本地缓存查找匹配的权限
        List<String> requiredPermissions = findMatchingPermissions(path, httpMethod);
        
        // 3. 如果没有找到匹配的权限，检查是否需要重新加载
        if (requiredPermissions.isEmpty()) {
            logger.debug("本地缓存中未找到匹配权限，尝试重新加载...");
            loadAllPermissions();
            requiredPermissions = findMatchingPermissions(path, httpMethod);
        }
        
        // 4. 缓存结果到Redis（TTL 10分钟）
        if (!requiredPermissions.isEmpty()) {
            redisTemplate.opsForValue().set(cacheKey, requiredPermissions, 10, TimeUnit.MINUTES);
            logger.debug("权限配置已缓存到Redis: {} -> {}", cacheKey, requiredPermissions);
        }
        
        // 5. 返回权限配置
        if (requiredPermissions.isEmpty()) {
            logger.debug("资源不需要特定权限: {}", path);
            return null; // 返回null表示该资源不需要特定权限
        }
        
        logger.debug("资源需要权限: {} -> {}", path, requiredPermissions);
        return createConfigAttributes(requiredPermissions);
    }
    
    /**
     * 查找匹配的权限
     * @param path 请求路径
     * @param httpMethod HTTP方法
     * @return 匹配的权限列表
     */
    private List<String> findMatchingPermissions(String path, String httpMethod) {
        List<String> matchedPermissions = new ArrayList<>();
        
        // 遍历所有权限配置，查找匹配的URL模式
        for (Map.Entry<String, List
```



## Prompt:
Continue



## Response:


**RBAC权限控制系统 - 完整项目结构** ∙ Version 3

```java
# Spring Boot RBAC 权限控制系统完整Demo

## 项目结构
```
src/main/java/com/example/rbac/
├── RbacApplication.java                    # 主启动类
├── config/
│   ├── SecurityConfig.java                # Spring Security核心配置
│   ├── RedisConfig.java                   # Redis配置
│   └── DataSourceConfig.java             # 数据源配置
├── security/
│   ├── JwtTokenProvider.java              # JWT工具类
│   ├── JwtAuthenticationFilter.java       # JWT认证过滤器
│   ├── CustomUserDetailsService.java     # 自定义用户详情服务
│   ├── CustomSecurityMetadataSource.java # 自定义权限数据源（重点）
│   ├── CustomAccessDecisionManager.java  # 自定义访问决策管理器（重点）
│   └── CustomAuthenticationEntryPoint.java # 自定义认证入口点
├── entity/
│   ├── User.java                          # 用户实体
│   ├── Role.java                          # 角色实体
│   ├── Permission.java                    # 权限实体
│   └── UserRole.java                      # 用户角色关联实体
├── repository/
│   ├── UserRepository.java                # 用户仓库
│   ├── RoleRepository.java                # 角色仓库
│   └── PermissionRepository.java          # 权限仓库
├── service/
│   ├── UserService.java                   # 用户服务
│   ├── AuthService.java                   # 认证服务
│   └── PermissionService.java             # 权限服务
├── controller/
│   ├── AuthController.java                # 认证控制器
│   ├── UserController.java                # 用户控制器
│   └── AdminController.java               # 管理员控制器
└── dto/
    ├── LoginRequest.java                  # 登录请求DTO
    ├── LoginResponse.java                 # 登录响应DTO
    └── ApiResponse.java                   # 通用响应DTO
```

## 1. 主启动类

```java
package com.example.rbac;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@SpringBootApplication
@EnableCaching
@EnableTransactionManagement
public class RbacApplication {
    public static void main(String[] args) {
        SpringApplication.run(RbacApplication.class, args);
    }
}
```

## 2. 数据库实体类

### User.java
```java
package com.example.rbac.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @JsonIgnore
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private String email;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    // 多对多关系：用户-角色
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // 构造函数
    public User() {}
    
    public User(String username, String password, String email) {
        this.username = username;
        this.password = password;
        this.email = email;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "roles")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    // 多对多关系：角色-权限
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "role_permissions",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Role() {}
    
    public Role(String name, String description) {
        this.name = name;
        this.description = description;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "permissions")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "resource_url")
    private String resourceUrl; // 资源URL匹配模式
    
    @Column(name = "http_method")
    private String httpMethod; // HTTP方法：GET, POST, PUT, DELETE等
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String description, String resourceUrl, String httpMethod) {
        this.name = name;
        this.description = description;
        this.resourceUrl = resourceUrl;
        this.httpMethod = httpMethod;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public String getResourceUrl() { return resourceUrl; }
    public void setResourceUrl(String resourceUrl) { this.resourceUrl = resourceUrl; }
    
    public String getHttpMethod() { return httpMethod; }
    public void setHttpMethod(String httpMethod) { this.httpMethod = httpMethod; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
```

## 3. 数据访问层

### UserRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * 根据用户名查找用户，同时预加载角色和权限信息
     * 使用左连接避免N+1查询问题
     */
    @Query("SELECT DISTINCT u FROM User u " +
           "LEFT JOIN FETCH u.roles r " +
           "LEFT JOIN FETCH r.permissions " +
           "WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
    
    /**
     * 根据用户名查找用户
     */
    Optional<User> findByUsername(String username);
    
    /**
     * 检查用户名是否存在
     */
    boolean existsByUsername(String username);
    
    /**
     * 检查邮箱是否存在
     */
    boolean existsByEmail(String email);
}
```

### RoleRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    
    /**
     * 根据角色名查找角色
     */
    Optional<Role> findByName(String name);
    
    /**
     * 查找所有角色并预加载权限信息
     */
    @Query("SELECT DISTINCT r FROM Role r LEFT JOIN FETCH r.permissions")
    List<Role> findAllWithPermissions();
    
    /**
     * 检查角色名是否存在
     */
    boolean existsByName(String name);
}
```

### PermissionRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    
    /**
     * 根据权限名查找权限
     */
    Optional<Permission> findByName(String name);
    
    /**
     * 根据资源URL和HTTP方法查找权限
     */
    Optional<Permission> findByResourceUrlAndHttpMethod(String resourceUrl, String httpMethod);
    
    /**
     * 查找所有权限资源配置，用于动态权限验证
     * 返回所有包含资源URL的权限
     */
    @Query("SELECT p FROM Permission p WHERE p.resourceUrl IS NOT NULL")
    List<Permission> findAllResourcePermissions();
    
    /**
     * 根据用户ID查找该用户拥有的所有权限
     * 通过用户->角色->权限的关联查询
     */
    @Query("SELECT DISTINCT p FROM Permission p " +
           "JOIN p.roles r " +
           "JOIN r.users u " +
           "WHERE u.id = :userId")
    List<Permission> findPermissionsByUserId(@Param("userId") Long userId);
    
    /**
     * 检查权限名是否存在
     */
    boolean existsByName(String name);
}
```

## 4. JWT工具类

### JwtTokenProvider.java
```java
package com.example.rbac.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

/**
 * JWT Token 提供者
 * 负责生成、解析和验证JWT令牌
 */
@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    // JWT密钥，从配置文件读取
    @Value("${app.jwt.secret:mySecretKey}")
    private String jwtSecret;
    
    // JWT过期时间（毫秒），默认24小时
    @Value("${app.jwt.expiration:86400000}")
    private long jwtExpiration;
    
    /**
     * 生成JWT令牌
     * @param authentication 认证信息
     * @return JWT令牌字符串
     */
    public String generateToken(Authentication authentication) {
        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        // 使用HMAC SHA算法签名
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        return Jwts.builder()
                .setSubject(userDetails.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }
    
    /**
     * 从JWT令牌中获取用户名
     * @param token JWT令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    /**
     * 验证JWT令牌
     * @param token JWT令牌
     * @return 是否有效
     */
    public boolean validateToken(String token) {
        try {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
            Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token);
            return true;
        } catch (SecurityException ex) {
            logger.error("Invalid JWT signature: {}", ex.getMessage());
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token: {}", ex.getMessage());
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token: {}", ex.getMessage());
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token: {}", ex.getMessage());
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty: {}", ex.getMessage());
        }
        return false;
    }
}
```

## 5. 自定义用户详情服务

### CustomUserDetailsService.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.User;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.Permission;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * 自定义用户详情服务
 * 实现Spring Security的UserDetailsService接口
 * 负责从数据库加载用户信息和权限信息
 */
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * 根据用户名加载用户详情
     * 这个方法在用户认证时被调用
     * @param username 用户名
     * @return UserDetails 用户详情对象
     * @throws UsernameNotFoundException 用户不存在异常
     */
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 从数据库查找用户，同时预加载角色和权限信息
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        // 构建用户权限列表
        List<GrantedAuthority> authorities = buildUserAuthorities(user.getRoles());
        
        // 创建Spring Security的User对象
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword())
                .authorities(authorities)
                .accountExpired(false)
                .accountLocked(false)
                .credentialsExpired(false)
                .disabled(!user.getEnabled())
                .build();
    }
    
    /**
     * 构建用户权限列表
     * 将角色和权限转换为Spring Security的GrantedAuthority
     * @param roles 用户角色集合
     * @return 权限列表
     */
    private List<GrantedAuthority> buildUserAuthorities(Set<Role> roles) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        for (Role role : roles) {
            // 添加角色权限，角色名前缀为ROLE_
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getName()));
            
            // 添加角色下的具体权限
            for (Permission permission : role.getPermissions()) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return authorities;
    }
}
```

## 6. JWT认证过滤器

### JwtAuthenticationFilter.java
```java
package com.example.rbac.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * JWT认证过滤器
 * 继承OncePerRequestFilter确保每个请求只执行一次
 * 负责从请求头中提取JWT令牌并验证用户身份
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    
    @Autowired
    private JwtTokenProvider jwtTokenProvider;
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    /**
     * 执行JWT认证过滤
     * @param request HTTP请求
     * @param response HTTP响应
     * @param filterChain 过滤器链
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response, 
                                   FilterChain filterChain) throws ServletException, IOException {
        try {
            // 从请求头中提取JWT令牌
            String jwt = getJwtFromRequest(request);
            
            // 验证令牌并设置认证信息
            if (StringUtils.hasText(jwt) && jwtTokenProvider.validateToken(jwt)) {
                String username = jwtTokenProvider.getUsernameFromToken(jwt);
                
                // 加载用户详情
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                // 创建认证令牌
                UsernamePasswordAuthenticationToken authentication = 
                    new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                
                // 设置到安全上下文中
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        } catch (Exception ex) {
            logger.error("Could not set user authentication in security context", ex);
        }
        
        // 继续执行过滤器链
        filterChain.doFilter(request, response);
    }
    
    /**
     * 从请求头中提取JWT令牌
     * @param request HTTP请求
     * @return JWT令牌字符串
     */
    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
```

## 7. 自定义权限数据源（重点）

### CustomSecurityMetadataSource.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.Permission;
import com.example.rbac.repository.PermissionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;

import javax.annotation.PostConstruct;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 自定义权限数据源（重点类）
 * 实现FilterInvocationSecurityMetadataSource接口
 * 
 * 核心作用：
 * 1. 根据请求的URL和HTTP方法，动态确定访问该资源所需的权限
 * 2. 从数据库动态加载权限配置，支持权限的动态更新
 * 3. 使用Redis缓存提高性能
 * 4. 为FilterSecurityInterceptor提供权限配置信息
 */
@Component
public class CustomSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomSecurityMetadataSource.class);
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    // 路径匹配器，用于匹配URL模式
    private final AntPathMatcher pathMatcher = new AntPathMatcher();
    
    // Redis缓存key前缀
    private static final String PERMISSION_CACHE_PREFIX = "permission:";
    private static final String ALL_PERMISSIONS_CACHE_KEY = "all_permissions";
    
    // 权限配置本地缓存
    private Map<String, List<String>> resourcePermissionMap = new HashMap<>();
    
    /**
     * 初始化权限数据源
     * 系统启动时加载所有权限配置到缓存
     */
    @PostConstruct
    public void init() {
        logger.info("初始化权限数据源...");
        loadAllPermissions();
        logger.info("权限数据源初始化完成，共加载{}个权限配置", resourcePermissionMap.size());
    }
    
    /**
     * 核心方法：根据请求获取所需权限
     * 这个方法在每次请求时被FilterSecurityInterceptor调用
     * 
     * @param object FilterInvocation对象，包含请求信息
     * @return 访问该资源所需的权限配置集合
     */
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String httpMethod = filterInvocation.getRequest().getMethod();
        
        logger.debug("获取资源权限配置: URL={}, Method={}", requestUrl, httpMethod);
        
        // 移除查询参数，只保留路径部分
        String path = requestUrl.split("\\?")[0];
        
        // 构建缓存key
        String cacheKey = PERMISSION_CACHE_PREFIX + httpMethod + ":" + path;
        
        // 1. 先从Redis缓存中查找
        List<String> cachedPermissions = (List<String>) redisTemplate.opsForValue().get(cacheKey);
        if (cachedPermissions != null) {
            logger.debug("从Redis缓存获取权限: {}", cachedPermissions);
            return createConfigAttributes(cachedPermissions);
        }
        
        // 2. 从本地缓存查找匹配的权限
        List<String> requiredPermissions = findMatchingPermissions(path, httpMethod);
        
        // 3. 如果没有找到匹配的权限，检查是否需要重新加载
        if (requiredPermissions.isEmpty()) {
            logger.debug("本地缓存中未找到匹配权限，尝试重新加载...");
            loadAllPermissions();
            requiredPermissions = findMatchingPermissions(path, httpMethod);
        }
        
        // 4. 缓存结果到Redis（TTL 10分钟）
        if (!requiredPermissions.isEmpty()) {
            redisTemplate.opsForValue().set(cacheKey, requiredPermissions, 10, TimeUnit.MINUTES);
            logger.debug("权限配置已缓存到Redis: {} -> {}", cacheKey, requiredPermissions);
        }
        
        // 5. 返回权限配置
        if (requiredPermissions.isEmpty()) {
            logger.debug("资源不需要特定权限: {}", path);
            return null; // 返回null表示该资源不需要特定权限
        }
        
        logger.debug("资源需要权限: {} -> {}", path, requiredPermissions);
        return createConfigAttributes(requiredPermissions);
    }
    
    /**
     * 查找匹配的权限
     * @param path 请求路径
     * @param httpMethod HTTP方法
     * @return 匹配的权限列表
     */
    private List<String> findMatchingPermissions(String path, String httpMethod) {
        List<String> matchedPermissions = new ArrayList<>();
        
        // 遍历所有权限配置，查找匹配的URL模式
        for (Map.Entry<String, List<String>> entry : resourcePermissionMap.entrySet()) {
            String resourcePattern = entry.getKey();
            List<String> permissions = entry.getValue();
            
            // 解析资源模式：METHOD:URL_PATTERN
            String[] parts = resourcePattern.split(":", 2);
            if (parts.length == 2) {
                String patternMethod = parts[0];
                String patternUrl = parts[1];
                
                // 匹配HTTP方法和URL模式
                if (patternMethod.equals(httpMethod) && pathMatcher.match(patternUrl, path)) {
                    matchedPermissions.addAll(permissions);
                    logger.debug("匹配到权限模式: {} -> {}", resourcePattern, permissions);
                }
            }
        }
        
        return matchedPermissions;
    }
    
    /**
     * 从数据库加载所有权限配置
     */
    private void loadAllPermissions() {
        try {
            // 清空本地缓存
            resourcePermissionMap.clear();
            
            // 从数据库查询所有权限配置
            List<Permission> permissions = permissionRepository.findAllResourcePermissions();
            
            for (Permission permission : permissions) {
                String resourceUrl = permission.getResourceUrl();
                String httpMethod = permission.getHttpMethod();
                String permissionName = permission.getName();
                
                if (resourceUrl != null && httpMethod != null) {
                    // 构建资源模式key：METHOD:URL_PATTERN
                    String resourceKey = httpMethod + ":" + resourceUrl;
                    
                    // 将权限添加到对应的资源模式中
                    resourcePermissionMap.computeIfAbsent(resourceKey, k -> new ArrayList<>())
                            .add(permissionName);
                }
            }
            
            // 更新Redis中的全量权限缓存
            redisTemplate.opsForValue().set(ALL_PERMISSIONS_CACHE_KEY, resourcePermissionMap, 30, TimeUnit.MINUTES);
            
            logger.info("权限配置加载完成，共{}个资源模式", resourcePermissionMap.size());
            
        } catch (Exception e) {
            logger.error("加载权限配置失败", e);
        }
    }
    
    /**
     * 创建权限配置属性集合
     * @param permissions 权限名称列表
     * @return ConfigAttribute集合
     */
    private Collection<ConfigAttribute> createConfigAttributes(List<String> permissions) {
        Collection<ConfigAttribute> configAttributes = new ArrayList<>();
        for (String permission : permissions) {
            configAttributes.add(new SecurityConfig(permission));
        }
        return configAttributes;
    }
    
    /**
     * 获取所有权限配置
     * FilterSecurityInterceptor在启动时会调用这个方法
     * @return 所有权限配置
     */
    @Override
    public Collection<ConfigAttribute> getAllConfigAttributes() {
        // 收集所有权限配置
        Set<ConfigAttribute> allAttributes = new HashSet<>();
        for (List<String> permissions : resourcePermissionMap.values()) {
            allAttributes.addAll(createConfigAttributes(permissions));
        }
        return allAttributes;
    }
    
    /**
     * 指示是否支持指定的类
     * @param clazz 类
     * @return 是否支持
     */
    @Override
    public boolean supports(Class<?> clazz) {
        return FilterInvocation.class.isAssignableFrom(clazz);
    }
    
    /**
     * 刷新权限配置
     * 当权限配置发生变化时可以调用此方法
     */
    public void refreshPermissions() {
        logger.info("刷新权限配置...");
        loadAllPermissions();
        // 清空Redis中的权限缓存
        Set<String> keys = redisTemplate.keys(PERMISSION_CACHE_PREFIX + "*");
        if (keys != null && !keys.isEmpty()) {
            redisTemplate.delete(keys);
        }
        logger.info("权限配置刷新完成");
    }
}
```

## 8. 自定义访问决策管理器（重点）

### CustomAccessDecisionManager.java
```java
package com.example.rbac.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.AccessDecisionManager;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.Collection;

/**
 * 自定义访问决策管理器（重点类）
 * 实现AccessDecisionManager接口
 * 
 * 核心作用：
 * 1. 决定用户是否有权限访问特定资源
 * 2. 比较用户拥有的权限与资源所需的权限
 * 3. 实现灵活的权限决策逻辑
 * 4. 支持多种决策策略：一票通过、一票否决、少数服从多数
 */
@Component
public class CustomAccessDecisionManager implements AccessDecisionManager {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomAccessDecisionManager.class);
    
    /**
     * 核心决策方法
     * 这个方法在每次权限验证时被调用
     * 
     * @param authentication 当前用户的认证信息
     * @param object 被访问的资源对象（通常是FilterInvocation）
     * @param configAttributes 访问该资源所需的权限配置
     * @throws AccessDeniedException 访问被拒绝异常
     * @throws InsufficientAuthenticationException 认证不足异常
     */
    @Override
    public void decide(Authentication authentication, Object object, Collection<ConfigAttribute> configAttributes)
            throws AccessDeniedException, InsufficientAuthenticationException {
        
        // 1. 如果没有配置权限要求，直接通过
        if (configAttributes == null || configAttributes.isEmpty()) {
            logger.debug("资源没有权限要求，直接通过访问");
            return;
        }
        
        // 2. 检查用户是否已认证
        if (authentication == null || !authentication.isAuthenticated()) {
            logger.warn("用户未认证，拒绝访问");
            throw new InsufficientAuthenticationException("用户未认证");
        }
        
        // 3. 获取用户的权限
        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        String username = authentication.getName();
        
        logger.debug("开始权限决策: 用户={}, 用户权限={}", username, authorities);
        
        // 4. 遍历资源所需的权限，检查用户是否具备
        for (ConfigAttribute configAttribute : configAttributes) {
            String needPermission = configAttribute.getAttribute();
            
            logger.debug("检查权限: 需要权限={}", needPermission);
            
            // 5. 检查用户是否拥有所需权限
            if (hasPermission(authorities, needPermission)) {
                logger.debug("权限验证通过: 用户={}, 权限={}", username, needPermission);
                return; // 一票通过策略：只要有一个权限匹配就通过
            }
        }
        
        // 6. 如果没有匹配的权限，拒绝访问
        logger.warn("权限验证失败: 用户={}, 需要权限={}, 用户权限={}", 
                   username, configAttributes, authorities);
        throw new AccessDeniedException("权限不足，访问被拒绝");
    }
    
    /**
     * 检查用户是否拥有指定权限
     * @param authorities 用户权限集合
     * @param needPermission 需要的权限
     * @return 是否拥有权限
     */
    private boolean hasPermission(Collection<? extends GrantedAuthority> authorities, String needPermission) {
        for (GrantedAuthority authority : authorities) {
            String userPermission = authority.getAuthority();
            
            // 精确匹配权限
            if (needPermission.equals(userPermission)) {
                logger.debug("权限精确匹配: {}", needPermission);
                return true;
            }
            
            // 支持超级管理员权限
            if ("ROLE_SUPER_ADMIN".equals(userPermission)) {
                logger.debug("超级管理员权限通过: {}", needPermission);
                return true;
            }
            
            // 可以在这里添加更多的权限匹配逻辑
            // 例如：层级权限、通配符权限等
        }
        return false;
    }
    
    /**
     * 指示是否支持指定的权限配置属性
     * @param attribute 权限配置属性
     * @return 是否支持
     */
    @Override
    public boolean supports(ConfigAttribute attribute) {
        return attribute.getAttribute() != null;
    }
    
    /**
     * 指示是否支持指定的类
     * @param clazz 类
     * @return 是否支持
     */
    @Override
    public boolean supports(Class<?> clazz) {
        return true;
    }
}
```

## 9. 自定义认证入口点

### CustomAuthenticationEntryPoint.java
```java
package com.example.rbac.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * 自定义认证入口点
 * 当用户未认证时的处理逻辑
 */
@Component
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomAuthenticationEntryPoint.class);
    
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException, ServletException {
        
        logger.error("认证失败: {}", authException.getMessage());
        
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        
        Map<String, Object> result = new HashMap<>();
        result.put("code", HttpServletResponse.SC_UNAUTHORIZED);
        result.put("message", "认证失败，请先登录");
        result.put("data", null);
        result.put("timestamp", System.currentTimeMillis());
        
        objectMapper.writeValue(response.getOutputStream(), result);
    }
}
```

## 10. 配置类

### SecurityConfig.java
```java
package com.example.rbac.config;

import com.example.rbac.security.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableGlobalMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.FilterSecurityInterceptor;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security核心配置类
 * 配置认证和授权的核心组件
 */
@Configuration
@EnableWebSecurity
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    @Autowired
    private CustomAuthenticationEntryPoint authenticationEntryPoint;
    
    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;
    
    @Autowired
    private CustomSecurityMetadataSource securityMetadataSource;
    
    @Autowired
    private CustomAccessDecisionManager accessDecisionManager;
    
    /**
     * 密码编码器
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    
    /**
     * 认证管理器
     */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
    
    /**
     * 自定义FilterSecurityInterceptor
     * 这是权限控制的核心过滤器
     */
    @Bean
    public FilterSecurityInterceptor filterSecurityInterceptor() {
        FilterSecurityInterceptor interceptor = new FilterSecurityInterceptor();
        
        // 设置自定义的权限数据源
        interceptor.setSecurityMetadataSource(securityMetadataSource);
        
        // 设置自定义的访问决策管理器
        interceptor.setAccessDecisionManager(accessDecisionManager);
        
        return interceptor;
    }
    
    /**
     * 安全过滤器链配置
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.cors().and().csrf().disable()
            .exceptionHandling()
                .authenticationEntryPoint(authenticationEntryPoint)
                .and()
            .sessionManagement()
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                .and()
            .authorizeHttpRequests(authz -> authz
                // 允许访问的公共端点
                .requestMatchers("/auth/login", "/auth/register").permitAll()
                .requestMatchers("/public/**").permitAll()
                // 其他所有请求都需要认证
                .anyRequest().authenticated()
            );
        
        // 添加JWT认证过滤器
        http.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        
        // 添加自定义的权限过滤器
        http.addFilterBefore(filterSecurityInterceptor(), FilterSecurityInterceptor.class);
        
        return http.build();
    }
}
```

### RedisConfig.java
```java
package com.example.rbac.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

/**
 * Redis配置类
 */
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

继续下一部分...
```

**RBAC权限控制系统 - 完整项目结构** ∙ Version 4

```java
# Spring Boot RBAC 权限控制系统完整Demo

## 项目结构
```
src/main/java/com/example/rbac/
├── RbacApplication.java                    # 主启动类
├── config/
│   ├── SecurityConfig.java                # Spring Security核心配置
│   ├── RedisConfig.java                   # Redis配置
│   └── DataSourceConfig.java             # 数据源配置
├── security/
│   ├── JwtTokenProvider.java              # JWT工具类
│   ├── JwtAuthenticationFilter.java       # JWT认证过滤器
│   ├── CustomUserDetailsService.java     # 自定义用户详情服务
│   ├── CustomSecurityMetadataSource.java # 自定义权限数据源（重点）
│   ├── CustomAccessDecisionManager.java  # 自定义访问决策管理器（重点）
│   └── CustomAuthenticationEntryPoint.java # 自定义认证入口点
├── entity/
│   ├── User.java                          # 用户实体
│   ├── Role.java                          # 角色实体
│   ├── Permission.java                    # 权限实体
│   └── UserRole.java                      # 用户角色关联实体
├── repository/
│   ├── UserRepository.java                # 用户仓库
│   ├── RoleRepository.java                # 角色仓库
│   └── PermissionRepository.java          # 权限仓库
├── service/
│   ├── UserService.java                   # 用户服务
│   ├── AuthService.java                   # 认证服务
│   └── PermissionService.java             # 权限服务
├── controller/
│   ├── AuthController.java                # 认证控制器
│   ├── UserController.java                # 用户控制器
│   └── AdminController.java               # 管理员控制器
└── dto/
    ├── LoginRequest.java                  # 登录请求DTO
    ├── LoginResponse.java                 # 登录响应DTO
    └── ApiResponse.java                   # 通用响应DTO
```

## 1. 主启动类

```java
package com.example.rbac;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@SpringBootApplication
@EnableCaching
@EnableTransactionManagement
public class RbacApplication {
    public static void main(String[] args) {
        SpringApplication.run(RbacApplication.class, args);
    }
}
```

## 2. 数据库实体类

### User.java
```java
package com.example.rbac.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @JsonIgnore
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private String email;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    // 多对多关系：用户-角色
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // 构造函数
    public User() {}
    
    public User(String username, String password, String email) {
        this.username = username;
        this.password = password;
        this.email = email;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "roles")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    // 多对多关系：角色-权限
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "role_permissions",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions = new HashSet<>();
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Role() {}
    
    public Role(String name, String description) {
        this.name = name;
        this.description = description;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java
```java
package com.example.rbac.entity;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "permissions")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @Column(name = "resource_url")
    private String resourceUrl; // 资源URL匹配模式
    
    @Column(name = "http_method")
    private String httpMethod; // HTTP方法：GET, POST, PUT, DELETE等
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String description, String resourceUrl, String httpMethod) {
        this.name = name;
        this.description = description;
        this.resourceUrl = resourceUrl;
        this.httpMethod = httpMethod;
    }
    
    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public String getResourceUrl() { return resourceUrl; }
    public void setResourceUrl(String resourceUrl) { this.resourceUrl = resourceUrl; }
    
    public String getHttpMethod() { return httpMethod; }
    public void setHttpMethod(String httpMethod) { this.httpMethod = httpMethod; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
```

## 3. 数据访问层

### UserRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * 根据用户名查找用户，同时预加载角色和权限信息
     * 使用左连接避免N+1查询问题
     */
    @Query("SELECT DISTINCT u FROM User u " +
           "LEFT JOIN FETCH u.roles r " +
           "LEFT JOIN FETCH r.permissions " +
           "WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
    
    /**
     * 根据用户名查找用户
     */
    Optional<User> findByUsername(String username);
    
    /**
     * 检查用户名是否存在
     */
    boolean existsByUsername(String username);
    
    /**
     * 检查邮箱是否存在
     */
    boolean existsByEmail(String email);
}
```

### RoleRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    
    /**
     * 根据角色名查找角色
     */
    Optional<Role> findByName(String name);
    
    /**
     * 查找所有角色并预加载权限信息
     */
    @Query("SELECT DISTINCT r FROM Role r LEFT JOIN FETCH r.permissions")
    List<Role> findAllWithPermissions();
    
    /**
     * 检查角色名是否存在
     */
    boolean existsByName(String name);
}
```

### PermissionRepository.java
```java
package com.example.rbac.repository;

import com.example.rbac.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    
    /**
     * 根据权限名查找权限
     */
    Optional<Permission> findByName(String name);
    
    /**
     * 根据资源URL和HTTP方法查找权限
     */
    Optional<Permission> findByResourceUrlAndHttpMethod(String resourceUrl, String httpMethod);
    
    /**
     * 查找所有权限资源配置，用于动态权限验证
     * 返回所有包含资源URL的权限
     */
    @Query("SELECT p FROM Permission p WHERE p.resourceUrl IS NOT NULL")
    List<Permission> findAllResourcePermissions();
    
    /**
     * 根据用户ID查找该用户拥有的所有权限
     * 通过用户->角色->权限的关联查询
     */
    @Query("SELECT DISTINCT p FROM Permission p " +
           "JOIN p.roles r " +
           "JOIN r.users u " +
           "WHERE u.id = :userId")
    List<Permission> findPermissionsByUserId(@Param("userId") Long userId);
    
    /**
     * 检查权限名是否存在
     */
    boolean existsByName(String name);
}
```

## 4. JWT工具类

### JwtTokenProvider.java
```java
package com.example.rbac.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;

/**
 * JWT Token 提供者
 * 负责生成、解析和验证JWT令牌
 */
@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    // JWT密钥，从配置文件读取
    @Value("${app.jwt.secret:mySecretKey}")
    private String jwtSecret;
    
    // JWT过期时间（毫秒），默认24小时
    @Value("${app.jwt.expiration:86400000}")
    private long jwtExpiration;
    
    /**
     * 生成JWT令牌
     * @param authentication 认证信息
     * @return JWT令牌字符串
     */
    public String generateToken(Authentication authentication) {
        UserDetails userDetails = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        // 使用HMAC SHA算法签名
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        return Jwts.builder()
                .setSubject(userDetails.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }
    
    /**
     * 从JWT令牌中获取用户名
     * @param token JWT令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    /**
     * 验证JWT令牌
     * @param token JWT令牌
     * @return 是否有效
     */
    public boolean validateToken(String token) {
        try {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
            Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token);
            return true;
        } catch (SecurityException ex) {
            logger.error("Invalid JWT signature: {}", ex.getMessage());
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token: {}", ex.getMessage());
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token: {}", ex.getMessage());
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token: {}", ex.getMessage());
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty: {}", ex.getMessage());
        }
        return false;
    }
}
```

## 5. 自定义用户详情服务

### CustomUserDetailsService.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.User;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.Permission;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * 自定义用户详情服务
 * 实现Spring Security的UserDetailsService接口
 * 负责从数据库加载用户信息和权限信息
 */
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    /**
     * 根据用户名加载用户详情
     * 这个方法在用户认证时被调用
     * @param username 用户名
     * @return UserDetails 用户详情对象
     * @throws UsernameNotFoundException 用户不存在异常
     */
    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 从数据库查找用户，同时预加载角色和权限信息
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        // 构建用户权限列表
        List<GrantedAuthority> authorities = buildUserAuthorities(user.getRoles());
        
        // 创建Spring Security的User对象
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword())
                .authorities(authorities)
                .accountExpired(false)
                .accountLocked(false)
                .credentialsExpired(false)
                .disabled(!user.getEnabled())
                .build();
    }
    
    /**
     * 构建用户权限列表
     * 将角色和权限转换为Spring Security的GrantedAuthority
     * @param roles 用户角色集合
     * @return 权限列表
     */
    private List<GrantedAuthority> buildUserAuthorities(Set<Role> roles) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        for (Role role : roles) {
            // 添加角色权限，角色名前缀为ROLE_
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getName()));
            
            // 添加角色下的具体权限
            for (Permission permission : role.getPermissions()) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return authorities;
    }
}
```

## 6. JWT认证过滤器

### JwtAuthenticationFilter.java
```java
package com.example.rbac.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * JWT认证过滤器
 * 继承OncePerRequestFilter确保每个请求只执行一次
 * 负责从请求头中提取JWT令牌并验证用户身份
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    
    @Autowired
    private JwtTokenProvider jwtTokenProvider;
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    /**
     * 执行JWT认证过滤
     * @param request HTTP请求
     * @param response HTTP响应
     * @param filterChain 过滤器链
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                   HttpServletResponse response, 
                                   FilterChain filterChain) throws ServletException, IOException {
        try {
            // 从请求头中提取JWT令牌
            String jwt = getJwtFromRequest(request);
            
            // 验证令牌并设置认证信息
            if (StringUtils.hasText(jwt) && jwtTokenProvider.validateToken(jwt)) {
                String username = jwtTokenProvider.getUsernameFromToken(jwt);
                
                // 加载用户详情
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                // 创建认证令牌
                UsernamePasswordAuthenticationToken authentication = 
                    new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                
                // 设置到安全上下文中
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        } catch (Exception ex) {
            logger.error("Could not set user authentication in security context", ex);
        }
        
        // 继续执行过滤器链
        filterChain.doFilter(request, response);
    }
    
    /**
     * 从请求头中提取JWT令牌
     * @param request HTTP请求
     * @return JWT令牌字符串
     */
    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
```

## 7. 自定义权限数据源（重点）

### CustomSecurityMetadataSource.java
```java
package com.example.rbac.security;

import com.example.rbac.entity.Permission;
import com.example.rbac.repository.PermissionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;

import javax.annotation.PostConstruct;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 自定义权限数据源（重点类）
 * 实现FilterInvocationSecurityMetadataSource接口
 * 
 * 核心作用：
 * 1. 根据请求的URL和HTTP方法，动态确定访问该资源所需的权限
 * 2. 从数据库动态加载权限配置，支持权限的动态更新
 * 3. 使用Redis缓存提高性能
 * 4. 为FilterSecurityInterceptor提供权限配置信息
 */
@Component
public class CustomSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomSecurityMetadataSource.class);
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    // 路径匹配器，用于匹配URL模式
    private final AntPathMatcher pathMatcher = new AntPathMatcher();
    
    // Redis缓存key前缀
    private static final String PERMISSION_CACHE_PREFIX = "permission:";
    private static final String ALL_PERMISSIONS_CACHE_KEY = "all_permissions";
    
    // 权限配置本地缓存
    private Map<String, List<String>> resourcePermissionMap = new HashMap<>();
    
    /**
     * 初始化权限数据源
     * 系统启动时加载所有权限配置到缓存
     */
    @PostConstruct
    public void init() {
        logger.info("初始化权限数据源...");
        loadAllPermissions();
        logger.info("权限数据源初始化完成，共加载{}个权限配置", resourcePermissionMap.size());
    }
    
    /**
     * 核心方法：根据请求获取所需权限
     * 这个方法在每次请求时被FilterSecurityInterceptor调用
     * 
     * @param object FilterInvocation对象，包含请求信息
     * @return 访问该资源所需的权限配置集合
     */
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String httpMethod = filterInvocation.getRequest().getMethod();
        
        logger.debug("获取资源权限配置: URL={}, Method={}", requestUrl, httpMethod);
        
        // 移除查询参数，只保留路径部分
        String path = requestUrl.split("\\?")[0];
        
        // 构建缓存key
        String cacheKey = PERMISSION_CACHE_PREFIX + httpMethod + ":" + path;
        
        // 1. 先从Redis缓存中查找
        List<String> cachedPermissions = (List<String>) redisTemplate.opsForValue().get(cacheKey);
        if (cachedPermissions != null) {
            logger.debug("从Redis缓存获取权限: {}", cachedPermissions);
            return createConfigAttributes(cachedPermissions);
        }
        
        // 2. 从本地缓存查找匹配的权限
        List<String> requiredPermissions = findMatchingPermissions(path, httpMethod);
        
        // 3. 如果没有找到匹配的权限，检查是否需要重新加载
        if (requiredPermissions.isEmpty()) {
            logger.debug("本地缓存中未找到匹配权限，尝试重新加载...");
            loadAllPermissions();
            requiredPermissions = findMatchingPermissions(path, httpMethod);
        }
        
        // 4. 缓存结果到Redis（TTL 10分钟）
        if (!requiredPermissions.isEmpty()) {
            redisTemplate.opsForValue().set(cacheKey, requiredPermissions, 10, TimeUnit.MINUTES);
            logger.debug("权限配置已缓存到Redis: {} -> {}", cacheKey, requiredPermissions);
        }
        
        // 5. 返回权限配置
        if (requiredPermissions.isEmpty()) {
            logger.debug("资源不需要特定权限: {}", path);
            return null; // 返回null表示该资源不需要特定权限
        }
        
        logger.debug("资源需要权限: {} -> {}", path, requiredPermissions);
        return createConfigAttributes(requiredPermissions);
    }
    
    /**
     * 查找匹配的权限
     * @param path 请求路径
     * @param httpMethod HTTP方法
     * @return 匹配的权限列表
     */
    private List<String> findMatchingPermissions(String path, String httpMethod) {
        List<String> matchedPermissions = new ArrayList<>();
        
        // 遍历所有权限配置，查找匹配的URL模式
        for (Map.Entry<String, List<String>> entry : resourcePermissionMap.entrySet()) {
            String resourcePattern = entry.getKey();
            List<String> permissions = entry.getValue();
            
            // 解析资源模式：METHOD:URL_PATTERN
            String[] parts = resourcePattern.split(":", 2);
            if (parts.length == 2) {
                String patternMethod = parts[0];
                String patternUrl = parts[1];
                
                // 匹配HTTP方法和URL模式
                if (patternMethod.equals(httpMethod) && pathMatcher.match(patternUrl, path)) {
                    matchedPermissions.addAll(permissions);
                    logger.debug("匹配到权限模式: {} -> {}", resourcePattern, permissions);
                }
            }
        }
        
        return matchedPermissions;
    }
    
    /**
     * 从数据库加载所有权限配置
     */
    private void loadAllPermissions() {
        try {
            // 清空本地缓存
            resourcePermissionMap.clear();
            
            // 从数据库查询所有权限配置
            List<Permission> permissions = permissionRepository.findAllResourcePermissions();
            
            for (Permission permission : permissions) {
                String resourceUrl = permission.getResourceUrl();
                String httpMethod = permission.getHttpMethod();
                String permissionName = permission.getName();
                
                if (resourceUrl != null && httpMethod != null) {
                    // 构建资源模式key：METHOD:URL_PATTERN
                    String resourceKey = httpMethod + ":" + resourceUrl;
                    
                    // 将权限添加到对应的资源模式中
                    resourcePermissionMap.computeIfAbsent(resourceKey, k -> new ArrayList<>())
                            .add(permissionName);
                }
            }
            
            // 更新Redis中的全量权限缓存
            redisTemplate.opsForValue().set(ALL_PERMISSIONS_CACHE_KEY, resourcePermissionMap, 30, TimeUnit.MINUTES);
            
            logger.info("权限配置加载完成，共{}个资源模式", resourcePermissionMap.size());
            
        } catch (Exception e) {
            logger.error("加载权限配置失败", e);
        }
    }
    
    /**
     * 创建权限配置属性集合
     * @param permissions 权限名称列表
     * @return ConfigAttribute集合
     */
    private Collection<ConfigAttribute> createConfigAttributes(List<String> permissions) {
        Collection<ConfigAttribute> configAttributes = new ArrayList<>();
        for (String permission : permissions) {
            configAttributes.add(new SecurityConfig(permission));
        }
        return configAttributes;
    }
    
    /**
     * 获取所有权限配置
     * FilterSecurityInterceptor在启动时会调用这个方法
     * @return 所有权限配置
     */
    @Override
    public Collection<ConfigAttribute> getAllConfigAttributes() {
        // 收集所有权限配置
        Set<ConfigAttribute> allAttributes = new HashSet<>();
        for (List<String> permissions : resourcePermissionMap.values()) {
            allAttributes.addAll(createConfigAttributes(permissions));
        }
        return allAttributes;
    }
    
    /**
     * 指示是否支持指定的类
     * @param clazz 类
     * @return 是否支持
     */
    @Override
    public boolean supports(Class<?> clazz) {
        return FilterInvocation.class.isAssignableFrom(clazz);
    }
    
    /**
     * 刷新权限配置
     * 当权限配置发生变化时可以调用此方法
     */
    public void refreshPermissions() {
        logger.info("刷新权限配置...");
        loadAllPermissions();
        // 清空Redis中的权限缓存
        Set<String> keys = redisTemplate.keys(PERMISSION_CACHE_PREFIX + "*");
        if (keys != null && !keys.isEmpty()) {
            redisTemplate.delete(keys);
        }
        logger.info("权限配置刷新完成");
    }
}
```

## 8. 自定义访问决策管理器（重点）

### CustomAccessDecisionManager.java
```java
package com.example.rbac.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.AccessDecisionManager;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.Collection;

/**
 * 自定义访问决策管理器（重点类）
 * 实现AccessDecisionManager接口
 * 
 * 核心作用：
 * 1. 决定用户是否有权限访问特定资源
 * 2. 比较用户拥有的权限与资源所需的权限
 * 3. 实现灵活的权限决策逻辑
 * 4. 支持多种决策策略：一票通过、一票否决、少数服从多数
 */
@Component
public class CustomAccessDecisionManager implements AccessDecisionManager {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomAccessDecisionManager.class);
    
    /**
     * 核心决策方法
     * 这个方法在每次权限验证时被调用
     * 
     * @param authentication 当前用户的认证信息
     * @param object 被访问的资源对象（通常是FilterInvocation）
     * @param configAttributes 访问该资源所需的权限配置
     * @throws AccessDeniedException 访问被拒绝异常
     * @throws InsufficientAuthenticationException 认证不足异常
     */
    @Override
    public void decide(Authentication authentication, Object object, Collection<ConfigAttribute> configAttributes)
            throws AccessDeniedException, InsufficientAuthenticationException {
        
        // 1. 如果没有配置权限要求，直接通过
        if (configAttributes == null || configAttributes.isEmpty()) {
            logger.debug("资源没有权限要求，直接通过访问");
            return;
        }
        
        // 2. 检查用户是否已认证
        if (authentication == null || !authentication.isAuthenticated()) {
            logger.warn("用户未认证，拒绝访问");
            throw new InsufficientAuthenticationException("用户未认证");
        }
        
        // 3. 获取用户的权限
        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        String username = authentication.getName();
        
        logger.debug("开始权限决策: 用户={}, 用户权限={}", username, authorities);
        
        // 4. 遍历资源所需的权限，检查用户是否具备
        for (ConfigAttribute configAttribute : configAttributes) {
            String needPermission = configAttribute.getAttribute();
            
            logger.debug("检查权限: 需要权限={}", needPermission);
            
            // 5. 检查用户是否拥有所需权限
            if (hasPermission(authorities, needPermission)) {
                logger.debug("权限验证通过: 用户={}, 权限={}", username, needPermission);
                return; // 一票通过策略：只要有一个权限匹配就通过
            }
        }
        
        // 6. 如果没有匹配的权限，拒绝访问
        logger.warn("权限验证失败: 用户={}, 需要权限={}, 用户权限={}", 
                   username, configAttributes, authorities);
        throw new AccessDeniedException("权限不足，访问被拒绝");
    }
    
    /**
     * 检查用户是否拥有指定权限
     * @param authorities 用户权限集合
     * @param needPermission 需要的权限
     * @return 是否拥有权限
     */
    private boolean hasPermission(Collection<? extends GrantedAuthority> authorities, String needPermission) {
        for (GrantedAuthority authority : authorities) {
            String userPermission = authority.getAuthority();
            
            // 精确匹配权限
            if (needPermission.equals(userPermission)) {
                logger.debug("权限精确匹配: {}", needPermission);
                return true;
            }
            
            // 支持超级管理员权限
            if ("ROLE_SUPER_ADMIN".equals(userPermission)) {
                logger.debug("超级管理员权限通过: {}", needPermission);
                return true;
            }
            
            // 可以在这里添加更多的权限匹配逻辑
            // 例如：层级权限、通配符权限等
        }
        return false;
    }
    
    /**
     * 指示是否支持指定的权限配置属性
     * @param attribute 权限配置属性
     * @return 是否支持
     */
    @Override
    public boolean supports(ConfigAttribute attribute) {
        return attribute.getAttribute() != null;
    }
    
    /**
     * 指示是否支持指定的类
     * @param clazz 类
     * @return 是否支持
     */
    @Override
    public boolean supports(Class<?> clazz) {
        return true;
    }
}
```

## 9. 自定义认证入口点

### CustomAuthenticationEntryPoint.java
```java
package com.example.rbac.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * 自定义认证入口点
 * 当用户未认证时的处理逻辑
 */
@Component
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomAuthenticationEntryPoint.class);
    
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException, ServletException {
        
        logger.error("认证失败: {}", authException.getMessage());
        
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        
        Map<String, Object> result = new HashMap<>();
        result.put("code", HttpServletResponse.SC_UNAUTHORIZED);
        result.put("message", "认证失败，请先登录");
        result.put("data", null);
        result.put("timestamp", System.currentTimeMillis());
        
        objectMapper.writeValue(response.getOutputStream(), result);
    }
}
```

## 10. 配置类

### SecurityConfig.java
```java
package com.example.rbac.config;

import com.example.rbac.security.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableGlobalMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.FilterSecurityInterceptor;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security核心配置类
 * 配置认证和授权的核心组件
 */
@Configuration
@EnableWebSecurity
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    @Autowired
    private CustomAuthenticationEntryPoint authenticationEntryPoint;
    
    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;
    
    @Autowired
    private CustomSecurityMetadataSource securityMetadataSource;
    
    @Autowired
    private CustomAccessDecisionManager accessDecisionManager;
    
    /**
     * 密码编码器
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    
    /**
     * 认证管理器
     */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
    
    /**
     * 自定义FilterSecurityInterceptor
     * 这是权限控制的核心过滤器
     */
    @Bean
    public FilterSecurityInterceptor filterSecurityInterceptor() {
        FilterSecurityInterceptor interceptor = new FilterSecurityInterceptor();
        
        // 设置自定义的权限数据源
        interceptor.setSecurityMetadataSource(securityMetadataSource);
        
        // 设置自定义的访问决策管理器
        interceptor.setAccessDecisionManager(accessDecisionManager);
        
        return interceptor;
    }
    
    /**
     * 安全过滤器链配置
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.cors().and().csrf().disable()
            .exceptionHandling()
                .authenticationEntryPoint(authenticationEntryPoint)
                .and()
            .sessionManagement()
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
                .and()
            .authorizeHttpRequests(authz -> authz
                // 允许访问的公共端点
                .requestMatchers("/auth/login", "/auth/register").permitAll()
                .requestMatchers("/public/**").permitAll()
                // 其他所有请求都需要认证
                .anyRequest().authenticated()
            );
        
        // 添加JWT认证过滤器
        http.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        
        // 添加自定义的权限过滤器
        http.addFilterBefore(filterSecurityInterceptor(), FilterSecurityInterceptor.class);
        
        return http.build();
    }
}
```

### RedisConfig.java
```java
package com.example.rbac.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

/**
 * Redis配置类
 */
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

继续下一部分...
```





---
Powered by [Claude Exporter](https://www.claudexporter.com)