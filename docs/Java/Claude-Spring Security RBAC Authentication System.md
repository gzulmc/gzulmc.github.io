# Spring Security RBAC Authentication System

**Created:** 2025/7/15 5:35  
**Updated:** 2025/7/15 5:39  
**Exported:** 2025/7/15 5:40  
**Link:** [https://claude.ai/chat/bfddca8a-20f9-4859-bb22-4e092c26f5c2](https://claude.ai/chat/bfddca8a-20f9-4859-bb22-4e092c26f5c2)  

## Prompt:
使用springboot和spring security技术，基于RBAC模型和mysql数据库和redis，实现一个基于token的动态认证和权限访问控制，动态从数据库加载权限信息。编写一个完整可运行的demo，不需要前端代码,只需要后端代码



## Response:
我将为您创建一个完整的基于Spring Boot和Spring Security的RBAC权限管理系统。这个系统包含用户管理、角色管理、权限管理以及基于JWT token的认证和授权。

**pom.xml - Maven配置文件**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>rbac-security-demo</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <name>RBAC Security Demo</name>
    <description>基于Spring Boot和Spring Security的RBAC权限管理系统</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.5</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>17</java.version>
        <jwt.version>0.11.5</jwt.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web Starter -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Security Starter -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>

        <!-- Spring Boot Data JPA -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- Spring Boot Data Redis -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>

        <!-- MySQL Driver -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <version>8.0.33</version>
        </dependency>

        <!-- JWT -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>${jwt.version}</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>${jwt.version}</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>${jwt.version}</version>
            <scope>runtime</scope>
        </dependency>

        <!-- Validation -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>

        <!-- JSON Processing -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>

        <!-- Spring Boot DevTools -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-devtools</artifactId>
            <scope>runtime</scope>
            <optional>true</optional>
        </dependency>

        <!-- Test Dependencies -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.security</groupId>
            <artifactId>spring-security-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

**application.properties - 应用配置**

```properties
# 应用配置
server.port=8080
server.servlet.context-path=/api

# 数据库配置
spring.datasource.url=jdbc:mysql://localhost:3306/rbac_demo?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=GMT%2B8
spring.datasource.username=root
spring.datasource.password=123456
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# JPA配置
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.MySQL8Dialect
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

# Redis配置
spring.data.redis.host=localhost
spring.data.redis.port=6379
spring.data.redis.password=
spring.data.redis.database=0
spring.data.redis.timeout=10000ms
spring.data.redis.lettuce.pool.max-active=8
spring.data.redis.lettuce.pool.max-wait=-1ms
spring.data.redis.lettuce.pool.max-idle=8
spring.data.redis.lettuce.pool.min-idle=0

# JWT配置
jwt.secret=mySecretKey123456789012345678901234567890
jwt.expiration=86400000
jwt.refresh-expiration=604800000

# 日志配置
logging.level.com.example.rbac=DEBUG
logging.level.org.springframework.security=DEBUG
```

**RbacSecurityDemoApplication.java - 主启动类**

```java
package com.example.rbac;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class RbacSecurityDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(RbacSecurityDemoApplication.class, args);
    }
}
```

**User.java - 用户实体类**

```java
package com.example.rbac.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "sys_user")
@Data
@EqualsAndHashCode(exclude = "roles")
@ToString(exclude = "roles")
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @NotBlank(message = "用户名不能为空")
    @Size(min = 3, max = 20, message = "用户名长度必须在3-20之间")
    @Column(unique = true, nullable = false)
    private String username;
    
    @NotBlank(message = "密码不能为空")
    @Size(min = 6, message = "密码长度至少6位")
    @Column(nullable = false)
    private String password;
    
    @Column(name = "email")
    private String email;
    
    @Column(name = "phone")
    private String phone;
    
    @Column(name = "enabled")
    private Boolean enabled = true;
    
    @Column(name = "account_non_expired")
    private Boolean accountNonExpired = true;
    
    @Column(name = "account_non_locked")
    private Boolean accountNonLocked = true;
    
    @Column(name = "credentials_non_expired")
    private Boolean credentialsNonExpired = true;
    
    @Column(name = "create_time")
    private LocalDateTime createTime;
    
    @Column(name = "update_time")
    private LocalDateTime updateTime;
    
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "sys_user_role",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    public void prePersist() {
        this.createTime = LocalDateTime.now();
        this.updateTime = LocalDateTime.now();
    }
    
    @PreUpdate
    public void preUpdate() {
        this.updateTime = LocalDateTime.now();
    }
}
```

**Role.java - 角色实体类**

```java
package com.example.rbac.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "sys_role")
@Data
@EqualsAndHashCode(exclude = {"users", "permissions"})
@ToString(exclude = {"users", "permissions"})
public class Role {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @NotBlank(message = "角色名不能为空")
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column(name = "description")
    private String description;
    
    @Column(name = "enabled")
    private Boolean enabled = true;
    
    @Column(name = "create_time")
    private LocalDateTime createTime;
    
    @Column(name = "update_time")
    private LocalDateTime updateTime;
    
    @ManyToMany(mappedBy = "roles", fetch = FetchType.LAZY)
    private Set<User> users = new HashSet<>();
    
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "sys_role_permission",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions = new HashSet<>();
    
    @PrePersist
    public void prePersist() {
        this.createTime = LocalDateTime.now();
        this.updateTime = LocalDateTime.now();
    }
    
    @PreUpdate
    public void preUpdate() {
        this.updateTime = LocalDateTime.now();
    }
}
```

**Permission.java - 权限实体类**

```java
package com.example.rbac.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "sys_permission")
@Data
@EqualsAndHashCode(exclude = "roles")
@ToString(exclude = "roles")
public class Permission {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @NotBlank(message = "权限名不能为空")
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column(name = "description")
    private String description;
    
    @Column(name = "resource_url")
    private String resourceUrl;
    
    @Column(name = "resource_method")
    private String resourceMethod;
    
    @Column(name = "enabled")
    private Boolean enabled = true;
    
    @Column(name = "create_time")
    private LocalDateTime createTime;
    
    @Column(name = "update_time")
    private LocalDateTime updateTime;
    
    @ManyToMany(mappedBy = "permissions", fetch = FetchType.LAZY)
    private Set<Role> roles = new HashSet<>();
    
    @PrePersist
    public void prePersist() {
        this.createTime = LocalDateTime.now();
        this.updateTime = LocalDateTime.now();
    }
    
    @PreUpdate
    public void preUpdate() {
        this.updateTime = LocalDateTime.now();
    }
}
```

**Repository接口 - 数据访问层**

```java
package com.example.rbac.repository;

import com.example.rbac.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    Optional<User> findByUsername(String username);
    
    @Query("SELECT u FROM User u LEFT JOIN FETCH u.roles r LEFT JOIN FETCH r.permissions WHERE u.username = ?1")
    Optional<User> findByUsernameWithRolesAndPermissions(String username);
    
    boolean existsByUsername(String username);
    
    boolean existsByEmail(String email);
}

// RoleRepository.java
package com.example.rbac.repository;

import com.example.rbac.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    
    Optional<Role> findByName(String name);
    
    @Query("SELECT r FROM Role r LEFT JOIN FETCH r.permissions WHERE r.name = ?1")
    Optional<Role> findByNameWithPermissions(String name);
    
    List<Role> findByEnabledTrue();
    
    boolean existsByName(String name);
}

// PermissionRepository.java
package com.example.rbac.repository;

import com.example.rbac.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    
    Optional<Permission> findByName(String name);
    
    List<Permission> findByEnabledTrue();
    
    List<Permission> findByResourceUrlAndResourceMethod(String resourceUrl, String resourceMethod);
    
    boolean existsByName(String name);
}
```

**JwtUtil.java - JWT工具类**

```java
package com.example.rbac.util;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

@Component
public class JwtUtil {
    
    @Value("${jwt.secret}")
    private String secret;
    
    @Value("${jwt.expiration}")
    private Long expiration;
    
    @Value("${jwt.refresh-expiration}")
    private Long refreshExpiration;
    
    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secret.getBytes());
    }
    
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }
    
    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }
    
    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }
    
    private Claims extractAllClaims(String token) {
        try {
            return Jwts.parserBuilder()
                    .setSigningKey(getSigningKey())
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
        } catch (Exception e) {
            throw new RuntimeException("Invalid JWT token", e);
        }
    }
    
    private Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }
    
    public String generateToken(UserDetails userDetails) {
        Map<String, Object> claims = new HashMap<>();
        return createToken(claims, userDetails.getUsername(), expiration);
    }
    
    public String generateRefreshToken(UserDetails userDetails) {
        Map<String, Object> claims = new HashMap<>();
        return createToken(claims, userDetails.getUsername(), refreshExpiration);
    }
    
    private String createToken(Map<String, Object> claims, String subject, Long expiration) {
        return Jwts.builder()
                .setClaims(claims)
                .setSubject(subject)
                .setIssuedAt(new Date(System.currentTimeMillis()))
                .setExpiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(getSigningKey(), SignatureAlgorithm.HS512)
                .compact();
    }
    
    public Boolean validateToken(String token, UserDetails userDetails) {
        final String username = extractUsername(token);
        return (username.equals(userDetails.getUsername()) && !isTokenExpired(token));
    }
    
    public Boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(getSigningKey())
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
    
    public Long getExpirationTime() {
        return expiration;
    }
    
    public Long getRefreshExpirationTime() {
        return refreshExpiration;
    }
}
```

**CustomUserDetailsService.java - 用户详情服务**

```java
package com.example.rbac.service;

import com.example.rbac.entity.User;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        return new CustomUserDetails(user);
    }
}

// CustomUserDetails.java
package com.example.rbac.service;

import com.example.rbac.entity.Permission;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.User;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

public class CustomUserDetails implements UserDetails {
    
    private User user;
    
    public CustomUserDetails(User user) {
        this.user = user;
    }
    
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        // 添加角色权限
        for (Role role : user.getRoles()) {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getName()));
            
            // 添加权限
            for (Permission permission : role.getPermissions()) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return authorities;
    }
    
    @Override
    public String getPassword() {
        return user.getPassword();
    }
    
    @Override
    public String getUsername() {
        return user.getUsername();
    }
    
    @Override
    public boolean isAccountNonExpired() {
        return user.getAccountNonExpired();
    }
    
    @Override
    public boolean isAccountNonLocked() {
        return user.getAccountNonLocked();
    }
    
    @Override
    public boolean isCredentialsNonExpired() {
        return user.getCredentialsNonExpired();
    }
    
    @Override
    public boolean isEnabled() {
        return user.getEnabled();
    }
    
    public User getUser() {
        return user;
    }
}
```

**JwtAuthenticationFilter.java - JWT认证过滤器**

```java
package com.example.rbac.filter;

import com.example.rbac.service.CustomUserDetailsService;
import com.example.rbac.util.JwtUtil;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.UnsupportedJwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    @Autowired
    private RedisTemplate<String, String> redisTemplate;
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                    HttpServletResponse response, 
                                    FilterChain filterChain) throws ServletException, IOException {
        
        String jwt = getTokenFromRequest(request);
        
        if (StringUtils.hasText(jwt) && SecurityContextHolder.getContext().getAuthentication() == null) {
            try {
                // 检查token是否在黑名单中
                if (isTokenBlacklisted(jwt)) {
                    response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                    response.getWriter().write("Token has been revoked");
                    return;
                }
                
                String username = jwtUtil.extractUsername(jwt);
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                if (jwtUtil.validateToken(jwt, userDetails)) {
                    UsernamePasswordAuthenticationToken authToken = 
                            new UsernamePasswordAuthenticationToken(
                                    userDetails, null, userDetails.getAuthorities());
                    authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            } catch (ExpiredJwtException e) {
                logger.error("JWT token is expired: {}", e);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("JWT token is expired");
                return;
            } catch (UnsupportedJwtException e) {
                logger.error("JWT token is unsupported: {}", e);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("JWT token is unsupported");
                return;
            } catch (MalformedJwtException e) {
                logger.error("Invalid JWT token: {}", e);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("Invalid JWT token");
                return;
            } catch (IllegalArgumentException e) {
                logger.error("JWT claims string is empty: {}", e);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("JWT claims string is empty");
                return;
            } catch (Exception e) {
                logger.error("Cannot set user authentication: {}", e);
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.getWriter().write("Authentication failed");
                return;
            }
        }
        
        filterChain.doFilter(request, response);
    }
    
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
    
    private boolean isTokenBlacklisted(String token) {
        return Boolean.TRUE.equals(redisTemplate.hasKey("blacklist:" + token));
    }
    
    public void blacklistToken(String token) {
        // 将token加入黑名单，过期时间设置为token的剩余有效期
        long expiration = jwtUtil.getExpirationTime();
        redisTemplate.opsForValue().set("blacklist:" + token, "true", expiration, TimeUnit.MILLISECONDS);
    }
}
```

**artifacts**

*Request*

```javascript
{
  "id": "security_config",
  "type": "application/vnd.ant.code",
  "title": "SecurityConfig.java - Spring Security配置",
  "command": "create",
  "version_uuid": "dbf723d3-5d8a-48f1-a36d-3e7a9cde5552"
}
```



## Prompt:
Continue



## Response:


**SecurityConfig.java - Spring Security配置**

```java
package com.example.rbac.config;

import com.example.rbac.filter.JwtAuthenticationFilter;
import com.example.rbac.service.CustomUserDetailsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    
    @Autowired
    private CustomUserDetailsService userDetailsService;
    
    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;
    
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
    
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration authConfig) throws Exception {
        return authConfig.getAuthenticationManager();
    }
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/auth/**").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .requestMatchers("/user/**").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        
        return http.build();
    }
}
```

**DynamicAccessDecisionManager.java - 动态权限访问控制**

```java
package com.example.rbac.security;

import com.example.rbac.entity.Permission;
import com.example.rbac.service.PermissionService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.AccessDecisionManager;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.List;

@Component
public class DynamicAccessDecisionManager implements AccessDecisionManager {
    
    @Autowired
    private PermissionService permissionService;
    
    @Override
    public void decide(Authentication authentication, Object object, Collection<ConfigAttribute> configAttributes) 
            throws AccessDeniedException, InsufficientAuthenticationException {
        
        if (authentication == null) {
            throw new AccessDeniedException("Access denied");
        }
        
        if (configAttributes == null || configAttributes.isEmpty()) {
            return;
        }
        
        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        
        for (ConfigAttribute configAttribute : configAttributes) {
            String needRole = configAttribute.getAttribute();
            
            for (GrantedAuthority authority : authorities) {
                if (needRole.equals(authority.getAuthority())) {
                    return;
                }
            }
        }
        
        throw new AccessDeniedException("Access denied");
    }
    
    @Override
    public boolean supports(ConfigAttribute attribute) {
        return true;
    }
    
    @Override
    public boolean supports(Class<?> clazz) {
        return true;
    }
}

// DynamicFilterInvocationSecurityMetadataSource.java
package com.example.rbac.security;

import com.example.rbac.entity.Permission;
import com.example.rbac.service.PermissionService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;

import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Component
public class DynamicFilterInvocationSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    @Autowired
    private PermissionService permissionService;
    
    private AntPathMatcher antPathMatcher = new AntPathMatcher();
    
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String method = filterInvocation.getHttpRequest().getMethod();
        
        List<Permission> permissions = permissionService.findAllEnabledPermissions();
        Set<ConfigAttribute> attributes = new HashSet<>();
        
        for (Permission permission : permissions) {
            if (permission.getResourceUrl() != null && 
                antPathMatcher.match(permission.getResourceUrl(), requestUrl) &&
                (permission.getResourceMethod() == null || permission.getResourceMethod().equals(method))) {
                attributes.add(new SecurityConfig(permission.getName()));
            }
        }
        
        return attributes;
    }
    
    @Override
    public Collection<ConfigAttribute> getAllConfigAttributes() {
        return null;
    }
    
    @Override
    public boolean supports(Class<?> clazz) {
        return FilterInvocation.class.isAssignableFrom(clazz);
    }
}
```

**Service层 - 业务逻辑服务**

```java
package com.example.rbac.service;

import com.example.rbac.entity.User;
import com.example.rbac.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private PasswordEncoder passwordEncoder;
    
    public List<User> findAll() {
        return userRepository.findAll();
    }
    
    public Optional<User> findById(Long id) {
        return userRepository.findById(id);
    }
    
    public Optional<User> findByUsername(String username) {
        return userRepository.findByUsername(username);
    }
    
    public User save(User user) {
        if (user.getId() == null) {
            user.setPassword(passwordEncoder.encode(user.getPassword()));
        }
        return userRepository.save(user);
    }
    
    public User update(User user) {
        return userRepository.save(user);
    }
    
    public void deleteById(Long id) {
        userRepository.deleteById(id);
    }
    
    public boolean existsByUsername(String username) {
        return userRepository.existsByUsername(username);
    }
    
    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }
    
    public User changePassword(String username, String newPassword) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setPassword(passwordEncoder.encode(newPassword));
        return userRepository.save(user);
    }
}

// RoleService.java
package com.example.rbac.service;

import com.example.rbac.entity.Role;
import com.example.rbac.repository.RoleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class RoleService {
    
    @Autowired
    private RoleRepository roleRepository;
    
    public List<Role> findAll() {
        return roleRepository.findAll();
    }
    
    public Optional<Role> findById(Long id) {
        return roleRepository.findById(id);
    }
    
    public Optional<Role> findByName(String name) {
        return roleRepository.findByName(name);
    }
    
    public Role save(Role role) {
        return roleRepository.save(role);
    }
    
    public Role update(Role role) {
        return roleRepository.save(role);
    }
    
    public void deleteById(Long id) {
        roleRepository.deleteById(id);
    }
    
    public boolean existsByName(String name) {
        return roleRepository.existsByName(name);
    }
    
    public List<Role> findEnabledRoles() {
        return roleRepository.findByEnabledTrue();
    }
}

// PermissionService.java
package com.example.rbac.service;

import com.example.rbac.entity.Permission;
import com.example.rbac.repository.PermissionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

@Service
@Transactional
public class PermissionService {
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    private static final String PERMISSION_CACHE_KEY = "permissions:all";
    
    public List<Permission> findAll() {
        return permissionRepository.findAll();
    }
    
    public Optional<Permission> findById(Long id) {
        return permissionRepository.findById(id);
    }
    
    public Optional<Permission> findByName(String name) {
        return permissionRepository.findByName(name);
    }
    
    public Permission save(Permission permission) {
        Permission savedPermission = permissionRepository.save(permission);
        clearPermissionCache();
        return savedPermission;
    }
    
    public Permission update(Permission permission) {
        Permission updatedPermission = permissionRepository.save(permission);
        clearPermissionCache();
        return updatedPermission;
    }
    
    public void deleteById(Long id) {
        permissionRepository.deleteById(id);
        clearPermissionCache();
    }
    
    public boolean existsByName(String name) {
        return permissionRepository.existsByName(name);
    }
    
    @SuppressWarnings("unchecked")
    public List<Permission> findAllEnabledPermissions() {
        // 先从缓存获取
        List<Permission> permissions = (List<Permission>) redisTemplate.opsForValue().get(PERMISSION_CACHE_KEY);
        
        if (permissions == null) {
            // 缓存未命中，从数据库获取
            permissions = permissionRepository.findByEnabledTrue();
            // 存入缓存，30分钟过期
            redisTemplate.opsForValue().set(PERMISSION_CACHE_KEY, permissions, 30, TimeUnit.MINUTES);
        }
        
        return permissions;
    }
    
    private void clearPermissionCache() {
        redisTemplate.delete(PERMISSION_CACHE_KEY);
    }
}
```

**DTO类 - 数据传输对象**

```java
package com.example.rbac.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class LoginRequest {
    
    @NotBlank(message = "用户名不能为空")
    private String username;
    
    @NotBlank(message = "密码不能为空")
    private String password;
}

// LoginResponse.java
package com.example.rbac.dto;

import lombok.Data;

@Data
public class LoginResponse {
    private String token;
    private String refreshToken;
    private String tokenType = "Bearer";
    private Long expiresIn;
    private UserInfoDTO userInfo;
    
    public LoginResponse(String token, String refreshToken, Long expiresIn, UserInfoDTO userInfo) {
        this.token = token;
        this.refreshToken = refreshToken;
        this.expiresIn = expiresIn;
        this.userInfo = userInfo;
    }
}

// UserInfoDTO.java
package com.example.rbac.dto;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class UserInfoDTO {
    private Long id;
    private String username;
    private String email;
    private String phone;
    private Boolean enabled;
    private LocalDateTime createTime;
    private List<String> roles;
    private List<String> permissions;
}

// RegisterRequest.java
package com.example.rbac.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {
    
    @NotBlank(message = "用户名不能为空")
    @Size(min = 3, max = 20, message = "用户名长度必须在3-20之间")
    private String username;
    
    @NotBlank(message = "密码不能为空")
    @Size(min = 6, message = "密码长度至少6位")
    private String password;
    
    @Email(message = "邮箱格式不正确")
    private String email;
    
    private String phone;
}

// ChangePasswordRequest.java
package com.example.rbac.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ChangePasswordRequest {
    
    @NotBlank(message = "原密码不能为空")
    private String oldPassword;
    
    @NotBlank(message = "新密码不能为空")
    @Size(min = 6, message = "新密码长度至少6位")
    private String newPassword;
}

// ApiResponse.java
package com.example.rbac.dto;

import lombok.Data;

@Data
public class ApiResponse<T> {
    private int code;
    private String message;
    private T data;
    
    public ApiResponse() {}
    
    public ApiResponse(int code, String message) {
        this.code = code;
        this.message = message;
    }
    
    public ApiResponse(int code, String message, T data) {
        this.code = code;
        this.message = message;
        this.data = data;
    }
    
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(200, "Success", data);
    }
    
    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(200, message, data);
    }
    
    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(400, message);
    }
    
    public static <T> ApiResponse<T> error(int code, String message) {
        return new ApiResponse<>(code, message);
    }
}
```

**Controller层 - 控制器**

```java
package com.example.rbac.controller;

import com.example.rbac.dto.*;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.User;
import com.example.rbac.filter.JwtAuthenticationFilter;
import com.example.rbac.service.CustomUserDetails;
import com.example.rbac.service.RoleService;
import com.example.rbac.service.UserService;
import com.example.rbac.util.JwtUtil;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/auth")
public class AuthController {
    
    @Autowired
    private AuthenticationManager authenticationManager;
    
    @Autowired
    private UserService userService;
    
    @Autowired
    private RoleService roleService;
    
    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private PasswordEncoder passwordEncoder;
    
    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;
    
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@Valid @RequestBody LoginRequest request) {
        try {
            Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
            );
            
            CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
            String token = jwtUtil.generateToken(userDetails);
            String refreshToken = jwtUtil.generateRefreshToken(userDetails);
            
            UserInfoDTO userInfo = convertToUserInfoDTO(userDetails.getUser());
            
            LoginResponse response = new LoginResponse(
                token, 
                refreshToken, 
                jwtUtil.getExpirationTime(), 
                userInfo
            );
            
            return ResponseEntity.ok(ApiResponse.success("登录成功", response));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("用户名或密码错误"));
        }
    }
    
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<String>> register(@Valid @RequestBody RegisterRequest request) {
        if (userService.existsByUsername(request.getUsername())) {
            return ResponseEntity.badRequest().body(ApiResponse.error("用户名已存在"));
        }
        
        if (request.getEmail() != null && userService.existsByEmail(request.getEmail())) {
            return ResponseEntity.badRequest().body(ApiResponse.error("邮箱已存在"));
        }
        
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(request.getPassword());
        user.setEmail(request.getEmail());
        user.setPhone(request.getPhone());
        
        // 默认分配USER角色
        Role userRole = roleService.findByName("USER").orElse(null);
        if (userRole != null) {
            Set<Role> roles = new HashSet<>();
            roles.add(userRole);
            user.setRoles(roles);
        }
        
        userService.save(user);
        
        return ResponseEntity.ok(ApiResponse.success("注册成功"));
    }
    
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<String>> logout(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token)) {
            jwtAuthenticationFilter.blacklistToken(token);
        }
        return ResponseEntity.ok(ApiResponse.success("退出成功"));
    }
    
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<LoginResponse>> refreshToken(@RequestBody String refreshToken) {
        try {
            if (jwtUtil.validateToken(refreshToken)) {
                String username = jwtUtil.extractUsername(refreshToken);
                User user = userService.findByUsername(username).orElseThrow();
                
                // 生成新的token
                CustomUserDetails userDetails = new CustomUserDetails(user);
                String newToken = jwtUtil.generateToken(userDetails);
                String newRefreshToken = jwtUtil.generateRefreshToken(userDetails);
                
                UserInfoDTO userInfo = convertToUserInfoDTO(user);
                
                LoginResponse response = new LoginResponse(
                    newToken, 
                    newRefreshToken, 
                    jwtUtil.getExpirationTime(), 
                    userInfo
                );
                
                return ResponseEntity.ok(ApiResponse.success("Token刷新成功", response));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("刷新token失败"));
        }
        
        return ResponseEntity.badRequest().body(ApiResponse.error("无效的刷新token"));
    }
    
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<UserInfoDTO>> getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof CustomUserDetails) {
            CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
            UserInfoDTO userInfo = convertToUserInfoDTO(userDetails.getUser());
            return ResponseEntity.ok(ApiResponse.success(userInfo));
        }
        return ResponseEntity.badRequest().body(ApiResponse.error("用户未登录"));
    }
    
    @PostMapping("/change-password")
    public ResponseEntity<ApiResponse<String>> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof CustomUserDetails) {
            CustomUserDetails userDetails = (CustomUserDetails) authentication.getPrincipal();
            
            // 验证原密码
            if (!passwordEncoder.matches(request.getOldPassword(), userDetails.getPassword())) {
                return ResponseEntity.badRequest().body(ApiResponse.error("原密码错误"));
            }
            
            userService.changePassword(userDetails.getUsername(), request.getNewPassword());
            return ResponseEntity.ok(ApiResponse.success("密码修改成功"));
        }
        return ResponseEntity.badRequest().body(ApiResponse.error("用户未登录"));
    }
    
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
    
    private UserInfoDTO convertToUserInfoDTO(User user) {
        UserInfoDTO dto = new UserInfoDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setPhone(user.getPhone());
        dto.setEnabled(user.getEnabled());
        dto.setCreateTime(user.getCreateTime());
        
        List<String> roles = user.getRoles().stream()
            .map(Role::getName)
            .collect(Collectors.toList());
        dto.setRoles(roles);
        
        List<String> permissions = user.getRoles().stream()
            .flatMap(role -> role.getPermissions().stream())
            .map(permission -> permission.getName())
            .distinct()
            .collect(Collectors.toList());
        dto.setPermissions(permissions);
        
        return dto;
    }
}

// UserController.java
package com.example.rbac.controller;

import com.example.rbac.dto.ApiResponse;
import com.example.rbac.entity.User;
import com.example.rbac.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/user")
public class UserController {
    
    @Autowired
    private UserService userService;
    
    @GetMapping("/profile")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<ApiResponse<String>> getUserProfile() {
        return ResponseEntity.ok(ApiResponse.success("用户个人信息"));
    }
    
    @GetMapping("/list")
    @PreAuthorize("hasAuthority('user:read')")
    public ResponseEntity<ApiResponse<List<User>>> getUserList() {
        List<User> users = userService.findAll();
        return ResponseEntity.ok(ApiResponse.success("获取用户列表成功", users));
    }
}

// AdminController.java
package com.example.rbac.controller;

import com.example.rbac.dto.ApiResponse;
import com.example.rbac.entity.Permission;
import com.example.rbac.entity.Role;
import com.example.rbac.entity.User;
import com.example.rbac.service.PermissionService;
import com.example.rbac.service.RoleService;
import com.example.rbac.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/admin")
public class AdminController {
    
    @Autowired
    private UserService userService;
    
    @Autowired
    private RoleService roleService;
    
    @Autowired
    private PermissionService permissionService;
    
    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<String>> getAdminDashboard() {
        return ResponseEntity.ok(ApiResponse.success("管理员仪表板"));
    }
    
    @GetMapping("/users")
    @PreAuthorize("hasAuthority('user:read')")
    public ResponseEntity<ApiResponse<List<User>>> getAllUsers() {
        List<User> users = userService.findAll();
        return ResponseEntity.ok(ApiResponse.success("获取所有用户成功", users));
    }
    
    @DeleteMapping("/users/{id}")
    @PreAuthorize("hasAuthority('user:delete')")
    public ResponseEntity<ApiResponse<String>> deleteUser(@PathVariable Long id) {
        userService.deleteById(id);
        return ResponseEntity.ok(ApiResponse.success("删除用户成功"));
    }
    
    @GetMapping("/roles")
    @PreAuthorize("hasAuthority('role:read')")
    public ResponseEntity<ApiResponse<List<Role>>> getAllRoles() {
        List<Role> roles = roleService.findAll();
        return ResponseEntity.ok(ApiResponse.success("获取所有角色成功", roles));
    }
    
    @PostMapping("/roles")
    @PreAuthorize("hasAuthority('role:create')")
    public ResponseEntity<ApiResponse<Role>> createRole(@RequestBody Role role) {
        Role savedRole = roleService.save(role);
        return ResponseEntity.ok(ApiResponse.success("创建角色成功", savedRole));
    }
    
    @GetMapping("/permissions")
    @PreAuthorize("hasAuthority('permission:read')")
    public ResponseEntity<ApiResponse<List<Permission>>> getAllPermissions() {
        List<Permission> permissions = permissionService.findAll();
        return ResponseEntity.ok(ApiResponse.success("获取所有权限成功", permissions));
    }
    
    @PostMapping("/permissions")
    @PreAuthorize("hasAuthority('permission:create')")
    public ResponseEntity<ApiResponse<Permission>> createPermission(@RequestBody Permission permission) {
        Permission savedPermission = permissionService.save(permission);
        return ResponseEntity.ok(ApiResponse.success("创建权限成功", savedPermission));
    }
}
```

**RedisConfig.java - Redis配置类**

```java
package com.example.rbac.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.
```





---
Powered by [Claude Exporter](https://www.claudexporter.com)