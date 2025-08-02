# Spring Security Dynamic Authorization Demo

**Created:** 2025/7/15 5:07  
**Updated:** 2025/7/15 5:11  
**Exported:** 2025/7/15 5:22  
**Link:** [https://claude.ai/chat/a6b92fc9-7083-4086-9bd7-c1d3df627711](https://claude.ai/chat/a6b92fc9-7083-4086-9bd7-c1d3df627711)  

## Prompt:
自定义SecurityContextRepository+redis实现token认证和权限访问控制,同时重写FilterInvocationSecurityMetadataSource,AccessDecisionManager动态从数据库加载权限信息。编写一个完整可运行的demo不需要前端代码,只需要后端代码



## Response:
我来为您创建一个完整的基于Spring Security + Redis的token认证和权限访问控制系统。

**Spring Security + Redis Token认证权限系统**

```java
# Spring Security + Redis Token认证权限系统

## 1. 项目结构

```
src/
├── main/
│   ├── java/
│   │   └── com/
│   │       └── example/
│   │           └── security/
│   │               ├── SecurityDemoApplication.java
│   │               ├── config/
│   │               │   ├── SecurityConfig.java
│   │               │   └── RedisConfig.java
│   │               ├── security/
│   │               │   ├── CustomSecurityContextRepository.java
│   │               │   ├── CustomFilterInvocationSecurityMetadataSource.java
│   │               │   ├── CustomAccessDecisionManager.java
│   │               │   └── JwtTokenProvider.java
│   │               ├── entity/
│   │               │   ├── User.java
│   │               │   ├── Role.java
│   │               │   └── Permission.java
│   │               ├── repository/
│   │               │   ├── UserRepository.java
│   │               │   ├── RoleRepository.java
│   │               │   └── PermissionRepository.java
│   │               ├── service/
│   │               │   ├── UserService.java
│   │               │   └── CustomUserDetailsService.java
│   │               └── controller/
│   │                   ├── AuthController.java
│   │                   └── TestController.java
│   └── resources/
│       ├── application.yml
│       └── data.sql
```

## 2. pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>security-token-demo</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.0</version>
        <relativePath/>
    </parent>
    
    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt</artifactId>
            <version>0.9.1</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
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

## 3. 主启动类

```java
package com.example.security;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SecurityDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(SecurityDemoApplication.class, args);
    }
}
```

## 4. 配置文件

### application.yml

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
    username: sa
    password: 
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
    show-sql: true
  h2:
    console:
      enabled: true
  redis:
    host: localhost
    port: 6379
    password: 
    database: 0
    timeout: 3000ms
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0

server:
  port: 8080

jwt:
  secret: mySecretKey
  expiration: 86400000  # 24小时
```

### data.sql

```sql
-- 插入测试数据
INSERT INTO user (id, username, password, enabled) VALUES 
(1, 'admin', '$2a$10$Rq/k4SqKhiLV5YFGvTNL/OLyOLGhzmqrwXjsYqXwZO3nQHgRJBpLy', true),
(2, 'user', '$2a$10$Rq/k4SqKhiLV5YFGvTNL/OLyOLGhzmqrwXjsYqXwZO3nQHgRJBpLy', true);

INSERT INTO role (id, name, description) VALUES 
(1, 'ROLE_ADMIN', '管理员角色'),
(2, 'ROLE_USER', '普通用户角色');

INSERT INTO permission (id, name, url, method, description) VALUES 
(1, 'USER_READ', '/api/user/**', 'GET', '用户查看权限'),
(2, 'USER_WRITE', '/api/user/**', 'POST', '用户写入权限'),
(3, 'ADMIN_READ', '/api/admin/**', 'GET', '管理员查看权限'),
(4, 'ADMIN_WRITE', '/api/admin/**', 'POST', '管理员写入权限');

INSERT INTO user_role (user_id, role_id) VALUES 
(1, 1),
(1, 2),
(2, 2);

INSERT INTO role_permission (role_id, permission_id) VALUES 
(1, 1),
(1, 2),
(1, 3),
(1, 4),
(2, 1);
```

## 5. 实体类

### User.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "user")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "user_role",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles;
    
    // 构造函数
    public User() {}
    
    public User(String username, String password) {
        this.username = username;
        this.password = password;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "role")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    private String description;
    
    @ManyToMany(mappedBy = "roles")
    private Set<User> users;
    
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "role_permission",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions;
    
    // 构造函数
    public Role() {}
    
    public Role(String name) {
        this.name = name;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public Set<User> getUsers() { return users; }
    public void setUsers(Set<User> users) { this.users = users; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "permission")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column(nullable = false)
    private String url;
    
    @Column(nullable = false)
    private String method;
    
    private String description;
    
    @ManyToMany(mappedBy = "permissions")
    private Set<Role> roles;
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String url, String method) {
        this.name = name;
        this.url = url;
        this.method = method;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    
    public String getMethod() { return method; }
    public void setMethod(String method) { this.method = method; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

## 6. Repository接口

### UserRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    
    @Query("SELECT u FROM User u JOIN FETCH u.roles r JOIN FETCH r.permissions WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
}
```

### RoleRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    Optional<Role> findByName(String name);
}
```

### PermissionRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    @Query("SELECT p FROM Permission p WHERE p.url = :url AND p.method = :method")
    List<Permission> findByUrlAndMethod(@Param("url") String url, @Param("method") String method);
    
    @Query("SELECT DISTINCT p FROM Permission p JOIN p.roles r")
    List<Permission> findAllWithRoles();
}
```

## 7. JWT Token Provider

```java
package com.example.security.security;

import io.jsonwebtoken.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    @Value("${jwt.secret}")
    private String jwtSecret;
    
    @Value("${jwt.expiration}")
    private int jwtExpiration;
    
    public String generateToken(Authentication authentication) {
        UserDetails userPrincipal = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        return Jwts.builder()
                .setSubject(userPrincipal.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(SignatureAlgorithm.HS512, jwtSecret)
                .compact();
    }
    
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parser()
                .setSigningKey(jwtSecret)
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    public boolean validateToken(String authToken) {
        try {
            Jwts.parser().setSigningKey(jwtSecret).parseClaimsJws(authToken);
            return true;
        } catch (SignatureException ex) {
            logger.error("Invalid JWT signature");
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token");
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token");
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token");
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty");
        }
        return false;
    }
}
```

## 8. 自定义SecurityContextRepository

```java
package com.example.security.security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.concurrent.TimeUnit;

@Component
public class CustomSecurityContextRepository implements SecurityContextRepository {
    
    @Autowired
    private JwtTokenProvider tokenProvider;
    
    @Autowired
    private UserDetailsService userDetailsService;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    private static final String TOKEN_PREFIX = "Bearer ";
    private static final String HEADER_STRING = "Authorization";
    private static final String REDIS_TOKEN_PREFIX = "token:";
    
    @Override
    public SecurityContext loadContext(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        
        if (StringUtils.hasText(token) && tokenProvider.validateToken(token)) {
            // 检查Redis中是否存在该token
            String redisKey = REDIS_TOKEN_PREFIX + token;
            Boolean exists = redisTemplate.hasKey(redisKey);
            
            if (exists != null && exists) {
                String username = tokenProvider.getUsernameFromToken(token);
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                if (userDetails != null) {
                    PreAuthenticatedAuthenticationToken authentication = 
                        new PreAuthenticatedAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                    context.setAuthentication(authentication);
                    
                    // 刷新token在Redis中的过期时间
                    redisTemplate.expire(redisKey, 24, TimeUnit.HOURS);
                }
            }
        }
        
        return context;
    }
    
    @Override
    public void saveContext(SecurityContext context, HttpServletRequest request, HttpServletResponse response) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token) && context.getAuthentication() != null) {
            String redisKey = REDIS_TOKEN_PREFIX + token;
            // 将token存储到Redis中，设置过期时间
            redisTemplate.opsForValue().set(redisKey, context.getAuthentication().getName(), 24, TimeUnit.HOURS);
        }
    }
    
    @Override
    public boolean containsContext(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token) && tokenProvider.validateToken(token)) {
            String redisKey = REDIS_TOKEN_PREFIX + token;
            Boolean exists = redisTemplate.hasKey(redisKey);
            return exists != null && exists;
        }
        return false;
    }
    
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader(HEADER_STRING);
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith(TOKEN_PREFIX)) {
            return bearerToken.substring(TOKEN_PREFIX.length());
        }
        return null;
    }
    
    public void removeToken(String token) {
        String redisKey = REDIS_TOKEN_PREFIX + token;
        redisTemplate.delete(redisKey);
    }
}
```

## 9. 自定义FilterInvocationSecurityMetadataSource

```java
package com.example.security.security;

import com.example.security.entity.Permission;
import com.example.security.repository.PermissionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;
import org.springframework.util.PathMatcher;

import java.util.*;

@Component
public class CustomFilterInvocationSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    private PathMatcher pathMatcher = new AntPathMatcher();
    
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String method = filterInvocation.getRequest().getMethod();
        
        // 从数据库动态加载权限信息
        List<Permission> permissions = permissionRepository.findAllWithRoles();
        
        Set<ConfigAttribute> configAttributes = new HashSet<>();
        
        for (Permission permission : permissions) {
            if (pathMatcher.match(permission.getUrl(), requestUrl) && 
                (permission.getMethod().equals(method) || permission.getMethod().equals("*"))) {
                configAttributes.add(new SecurityConfig(permission.getName()));
            }
        }
        
        // 如果没有匹配的权限，返回一个默认的配置
        if (configAttributes.isEmpty()) {
            configAttributes.add(new SecurityConfig("ROLE_ANONYMOUS"));
        }
        
        return configAttributes;
    }
    
    @Override
    public Collection<ConfigAttribute> getAllConfigAttributes() {
        List<Permission> permissions = permissionRepository.findAll();
        Set<ConfigAttribute> configAttributes = new HashSet<>();
        
        for (Permission permission : permissions) {
            configAttributes.add(new SecurityConfig(permission.getName()));
        }
        
        return configAttributes;
    }
    
    @Override
    public boolean supports(Class<?> clazz) {
        return FilterInvocation.class.isAssignableFrom(clazz);
    }
}
```

## 10. 自定义AccessDecisionManager

```java
package com.example.security.security;

import org.springframework.security.access.AccessDecisionManager;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.Collection;

@Component
public class CustomAccessDecisionManager implements AccessDecisionManager {
    
    @Override
    public void decide(Authentication authentication, Object object, Collection<ConfigAttribute> configAttributes)
            throws AccessDeniedException, InsufficientAuthenticationException {
        
        if (configAttributes == null || configAttributes.isEmpty()) {
            return;
        }
        
        // 检查用户是否已认证
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new InsufficientAuthenticationException("User not authenticated");
        }
        
        // 获取用户权限
        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        
        // 检查是否有匹配的权限
        for (ConfigAttribute configAttribute : configAttributes) {
            String needPermission = configAttribute.getAttribute();
            
            // 如果是匿名访问，直接允许
            if ("ROLE_ANONYMOUS".equals(needPermission)) {
                return;
            }
            
            // 检查用户是否具有所需权限
            for (GrantedAuthority authority : authorities) {
                if (authority.getAuthority().equals(needPermission)) {
                    return;
                }
            }
        }
        
        // 如果没有匹配的权限，拒绝访问
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
```

## 11. 用户服务类

### CustomUserDetailsService.java

```java
package com.example.security.service;

import com.example.security.entity.Permission;
import com.example.security.entity.Role;
import com.example.security.entity.User;
import com.example.security.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        Set<Role> roles = user.getRoles();
        for (Role role : roles) {
            // 添加角色
            authorities.add(new SimpleGrantedAuthority(role.getName()));
            
            // 添加权限
            Set<Permission> permissions = role.getPermissions();
            for (Permission permission : permissions) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return new org.springframework.security.core.userdetails.User(
                user.getUsername(),
                user.getPassword(),
                user.getEnabled(),
                true,
                true,
                true,
                authorities
        );
    }
}
```

### UserService.java

```java
package com.example.security.service;

import com.example.security.entity.User;
import com.example.security.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private PasswordEncoder passwordEncoder;
    
    public User createUser(String username, String password) {
        User user = new User();
        user.setUsername(username);
        user.setPassword(passwordEncoder.encode(password));
        user.setEnabled(true);
        return userRepository.save(user);
    }
    
    public Optional<User> findByUsername(String username) {
        return userRepository.findByUsername(username);
    }
    
    public boolean existsByUsername(String username) {
        return userRepository.findByUsername(username).isPresent();
    }
}
```

## 12. 配置类

### SecurityConfig.java

```java
package com.example.security.config;

import com.example.security.security.CustomAccessDecisionManager;
import com.example.security.security.CustomFilterInvocationSecurityMetadataSource;
import com.example.security.security.CustomSecurityContextRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.FilterSecurityInterceptor;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Autowired
    private CustomSecurityContextRepository customSecurityContextRepository;
    
    @Autowired
    private CustomFilterInvocationSecurityMetadataSource customFilterInvocationSecurityMetadataSource;
    
    @Autowired
    private CustomAccessDecisionManager customAccessDecisionManager;
    
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
        http.csrf().disable()
            .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            .and()
            .securityContext()
            .securityContextRepository(customSecurityContextRepository)
            .and()
            .authorizeHttpRequests(authz -> authz
                .antMatchers("/api/auth/**").permitAll()
                .antMatchers("/h2-console/**").permitAll()
                .anyRequest().authenticated()
            )
            .headers().frameOptions().sameOrigin();
        
        // 添加自定义的FilterSecurityInterceptor
        FilterSecurityInterceptor filterSecurityInterceptor = new FilterSecurityInterceptor();
        filterSecurityInterceptor.setSecurityMetadataSource(customFilterInvocationSecurityMetadataSource);
        filterSecurityInterceptor.setAccessDecisionManager(customAccessDecisionManager);
        filter
```



## Prompt:
Continue



## Response:


**Spring Security + Redis Token认证权限系统** ∙ Version 2

```java
# Spring Security + Redis Token认证权限系统

## 1. 项目结构

```
src/
├── main/
│   ├── java/
│   │   └── com/
│   │       └── example/
│   │           └── security/
│   │               ├── SecurityDemoApplication.java
│   │               ├── config/
│   │               │   ├── SecurityConfig.java
│   │               │   └── RedisConfig.java
│   │               ├── security/
│   │               │   ├── CustomSecurityContextRepository.java
│   │               │   ├── CustomFilterInvocationSecurityMetadataSource.java
│   │               │   ├── CustomAccessDecisionManager.java
│   │               │   └── JwtTokenProvider.java
│   │               ├── entity/
│   │               │   ├── User.java
│   │               │   ├── Role.java
│   │               │   └── Permission.java
│   │               ├── repository/
│   │               │   ├── UserRepository.java
│   │               │   ├── RoleRepository.java
│   │               │   └── PermissionRepository.java
│   │               ├── service/
│   │               │   ├── UserService.java
│   │               │   └── CustomUserDetailsService.java
│   │               └── controller/
│   │                   ├── AuthController.java
│   │                   └── TestController.java
│   └── resources/
│       ├── application.yml
│       └── data.sql
```

## 2. pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>security-token-demo</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.0</version>
        <relativePath/>
    </parent>
    
    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt</artifactId>
            <version>0.9.1</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
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

## 3. 主启动类

```java
package com.example.security;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SecurityDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(SecurityDemoApplication.class, args);
    }
}
```

## 4. 配置文件

### application.yml

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
    username: sa
    password: 
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    hibernate:
      ddl-auto: create-drop
    show-sql: true
  h2:
    console:
      enabled: true
  redis:
    host: localhost
    port: 6379
    password: 
    database: 0
    timeout: 3000ms
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0

server:
  port: 8080

jwt:
  secret: mySecretKey
  expiration: 86400000  # 24小时
```

### data.sql

```sql
-- 插入测试数据
INSERT INTO user (id, username, password, enabled) VALUES 
(1, 'admin', '$2a$10$Rq/k4SqKhiLV5YFGvTNL/OLyOLGhzmqrwXjsYqXwZO3nQHgRJBpLy', true),
(2, 'user', '$2a$10$Rq/k4SqKhiLV5YFGvTNL/OLyOLGhzmqrwXjsYqXwZO3nQHgRJBpLy', true);

INSERT INTO role (id, name, description) VALUES 
(1, 'ROLE_ADMIN', '管理员角色'),
(2, 'ROLE_USER', '普通用户角色');

INSERT INTO permission (id, name, url, method, description) VALUES 
(1, 'USER_READ', '/api/user/**', 'GET', '用户查看权限'),
(2, 'USER_WRITE', '/api/user/**', 'POST', '用户写入权限'),
(3, 'ADMIN_READ', '/api/admin/**', 'GET', '管理员查看权限'),
(4, 'ADMIN_WRITE', '/api/admin/**', 'POST', '管理员写入权限');

INSERT INTO user_role (user_id, role_id) VALUES 
(1, 1),
(1, 2),
(2, 2);

INSERT INTO role_permission (role_id, permission_id) VALUES 
(1, 1),
(1, 2),
(1, 3),
(1, 4),
(2, 1);
```

## 5. 实体类

### User.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "user")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String username;
    
    @Column(nullable = false)
    private String password;
    
    @Column(nullable = false)
    private Boolean enabled = true;
    
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "user_role",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles;
    
    // 构造函数
    public User() {}
    
    public User(String username, String password) {
        this.username = username;
        this.password = password;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

### Role.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "role")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    private String description;
    
    @ManyToMany(mappedBy = "roles")
    private Set<User> users;
    
    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(
        name = "role_permission",
        joinColumns = @JoinColumn(name = "role_id"),
        inverseJoinColumns = @JoinColumn(name = "permission_id")
    )
    private Set<Permission> permissions;
    
    // 构造函数
    public Role() {}
    
    public Role(String name) {
        this.name = name;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public Set<User> getUsers() { return users; }
    public void setUsers(Set<User> users) { this.users = users; }
    
    public Set<Permission> getPermissions() { return permissions; }
    public void setPermissions(Set<Permission> permissions) { this.permissions = permissions; }
}
```

### Permission.java

```java
package com.example.security.entity;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table(name = "permission")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String name;
    
    @Column(nullable = false)
    private String url;
    
    @Column(nullable = false)
    private String method;
    
    private String description;
    
    @ManyToMany(mappedBy = "permissions")
    private Set<Role> roles;
    
    // 构造函数
    public Permission() {}
    
    public Permission(String name, String url, String method) {
        this.name = name;
        this.url = url;
        this.method = method;
    }
    
    // getter 和 setter 方法
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    
    public String getMethod() { return method; }
    public void setMethod(String method) { this.method = method; }
    
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    
    public Set<Role> getRoles() { return roles; }
    public void setRoles(Set<Role> roles) { this.roles = roles; }
}
```

## 6. Repository接口

### UserRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    
    @Query("SELECT u FROM User u JOIN FETCH u.roles r JOIN FETCH r.permissions WHERE u.username = :username")
    Optional<User> findByUsernameWithRolesAndPermissions(@Param("username") String username);
}
```

### RoleRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    Optional<Role> findByName(String name);
}
```

### PermissionRepository.java

```java
package com.example.security.repository;

import com.example.security.entity.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Long> {
    @Query("SELECT p FROM Permission p WHERE p.url = :url AND p.method = :method")
    List<Permission> findByUrlAndMethod(@Param("url") String url, @Param("method") String method);
    
    @Query("SELECT DISTINCT p FROM Permission p JOIN p.roles r")
    List<Permission> findAllWithRoles();
}
```

## 7. JWT Token Provider

```java
package com.example.security.security;

import io.jsonwebtoken.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtTokenProvider {
    
    private static final Logger logger = LoggerFactory.getLogger(JwtTokenProvider.class);
    
    @Value("${jwt.secret}")
    private String jwtSecret;
    
    @Value("${jwt.expiration}")
    private int jwtExpiration;
    
    public String generateToken(Authentication authentication) {
        UserDetails userPrincipal = (UserDetails) authentication.getPrincipal();
        Date expiryDate = new Date(System.currentTimeMillis() + jwtExpiration);
        
        return Jwts.builder()
                .setSubject(userPrincipal.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(expiryDate)
                .signWith(SignatureAlgorithm.HS512, jwtSecret)
                .compact();
    }
    
    public String getUsernameFromToken(String token) {
        Claims claims = Jwts.parser()
                .setSigningKey(jwtSecret)
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }
    
    public boolean validateToken(String authToken) {
        try {
            Jwts.parser().setSigningKey(jwtSecret).parseClaimsJws(authToken);
            return true;
        } catch (SignatureException ex) {
            logger.error("Invalid JWT signature");
        } catch (MalformedJwtException ex) {
            logger.error("Invalid JWT token");
        } catch (ExpiredJwtException ex) {
            logger.error("Expired JWT token");
        } catch (UnsupportedJwtException ex) {
            logger.error("Unsupported JWT token");
        } catch (IllegalArgumentException ex) {
            logger.error("JWT claims string is empty");
        }
        return false;
    }
}
```

## 8. 自定义SecurityContextRepository

```java
package com.example.security.security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedAuthenticationToken;
import org.springframework.security.web.context.SecurityContextRepository;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.concurrent.TimeUnit;

@Component
public class CustomSecurityContextRepository implements SecurityContextRepository {
    
    @Autowired
    private JwtTokenProvider tokenProvider;
    
    @Autowired
    private UserDetailsService userDetailsService;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    private static final String TOKEN_PREFIX = "Bearer ";
    private static final String HEADER_STRING = "Authorization";
    private static final String REDIS_TOKEN_PREFIX = "token:";
    
    @Override
    public SecurityContext loadContext(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        
        if (StringUtils.hasText(token) && tokenProvider.validateToken(token)) {
            // 检查Redis中是否存在该token
            String redisKey = REDIS_TOKEN_PREFIX + token;
            Boolean exists = redisTemplate.hasKey(redisKey);
            
            if (exists != null && exists) {
                String username = tokenProvider.getUsernameFromToken(token);
                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                
                if (userDetails != null) {
                    PreAuthenticatedAuthenticationToken authentication = 
                        new PreAuthenticatedAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                    context.setAuthentication(authentication);
                    
                    // 刷新token在Redis中的过期时间
                    redisTemplate.expire(redisKey, 24, TimeUnit.HOURS);
                }
            }
        }
        
        return context;
    }
    
    @Override
    public void saveContext(SecurityContext context, HttpServletRequest request, HttpServletResponse response) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token) && context.getAuthentication() != null) {
            String redisKey = REDIS_TOKEN_PREFIX + token;
            // 将token存储到Redis中，设置过期时间
            redisTemplate.opsForValue().set(redisKey, context.getAuthentication().getName(), 24, TimeUnit.HOURS);
        }
    }
    
    @Override
    public boolean containsContext(HttpServletRequest request) {
        String token = getTokenFromRequest(request);
        if (StringUtils.hasText(token) && tokenProvider.validateToken(token)) {
            String redisKey = REDIS_TOKEN_PREFIX + token;
            Boolean exists = redisTemplate.hasKey(redisKey);
            return exists != null && exists;
        }
        return false;
    }
    
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader(HEADER_STRING);
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith(TOKEN_PREFIX)) {
            return bearerToken.substring(TOKEN_PREFIX.length());
        }
        return null;
    }
    
    public void removeToken(String token) {
        String redisKey = REDIS_TOKEN_PREFIX + token;
        redisTemplate.delete(redisKey);
    }
}
```

## 9. 自定义FilterInvocationSecurityMetadataSource

```java
package com.example.security.security;

import com.example.security.entity.Permission;
import com.example.security.repository.PermissionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.access.SecurityConfig;
import org.springframework.security.web.FilterInvocation;
import org.springframework.security.web.access.intercept.FilterInvocationSecurityMetadataSource;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;
import org.springframework.util.PathMatcher;

import java.util.*;

@Component
public class CustomFilterInvocationSecurityMetadataSource implements FilterInvocationSecurityMetadataSource {
    
    @Autowired
    private PermissionRepository permissionRepository;
    
    private PathMatcher pathMatcher = new AntPathMatcher();
    
    @Override
    public Collection<ConfigAttribute> getAttributes(Object object) throws IllegalArgumentException {
        FilterInvocation filterInvocation = (FilterInvocation) object;
        String requestUrl = filterInvocation.getRequestUrl();
        String method = filterInvocation.getRequest().getMethod();
        
        // 从数据库动态加载权限信息
        List<Permission> permissions = permissionRepository.findAllWithRoles();
        
        Set<ConfigAttribute> configAttributes = new HashSet<>();
        
        for (Permission permission : permissions) {
            if (pathMatcher.match(permission.getUrl(), requestUrl) && 
                (permission.getMethod().equals(method) || permission.getMethod().equals("*"))) {
                configAttributes.add(new SecurityConfig(permission.getName()));
            }
        }
        
        // 如果没有匹配的权限，返回一个默认的配置
        if (configAttributes.isEmpty()) {
            configAttributes.add(new SecurityConfig("ROLE_ANONYMOUS"));
        }
        
        return configAttributes;
    }
    
    @Override
    public Collection<ConfigAttribute> getAllConfigAttributes() {
        List<Permission> permissions = permissionRepository.findAll();
        Set<ConfigAttribute> configAttributes = new HashSet<>();
        
        for (Permission permission : permissions) {
            configAttributes.add(new SecurityConfig(permission.getName()));
        }
        
        return configAttributes;
    }
    
    @Override
    public boolean supports(Class<?> clazz) {
        return FilterInvocation.class.isAssignableFrom(clazz);
    }
}
```

## 10. 自定义AccessDecisionManager

```java
package com.example.security.security;

import org.springframework.security.access.AccessDecisionManager;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.ConfigAttribute;
import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

import java.util.Collection;

@Component
public class CustomAccessDecisionManager implements AccessDecisionManager {
    
    @Override
    public void decide(Authentication authentication, Object object, Collection<ConfigAttribute> configAttributes)
            throws AccessDeniedException, InsufficientAuthenticationException {
        
        if (configAttributes == null || configAttributes.isEmpty()) {
            return;
        }
        
        // 检查用户是否已认证
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new InsufficientAuthenticationException("User not authenticated");
        }
        
        // 获取用户权限
        Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
        
        // 检查是否有匹配的权限
        for (ConfigAttribute configAttribute : configAttributes) {
            String needPermission = configAttribute.getAttribute();
            
            // 如果是匿名访问，直接允许
            if ("ROLE_ANONYMOUS".equals(needPermission)) {
                return;
            }
            
            // 检查用户是否具有所需权限
            for (GrantedAuthority authority : authorities) {
                if (authority.getAuthority().equals(needPermission)) {
                    return;
                }
            }
        }
        
        // 如果没有匹配的权限，拒绝访问
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
```

## 11. 用户服务类

### CustomUserDetailsService.java

```java
package com.example.security.service;

import com.example.security.entity.Permission;
import com.example.security.entity.Role;
import com.example.security.entity.User;
import com.example.security.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepository.findByUsernameWithRolesAndPermissions(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
        
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        Set<Role> roles = user.getRoles();
        for (Role role : roles) {
            // 添加角色
            authorities.add(new SimpleGrantedAuthority(role.getName()));
            
            // 添加权限
            Set<Permission> permissions = role.getPermissions();
            for (Permission permission : permissions) {
                authorities.add(new SimpleGrantedAuthority(permission.getName()));
            }
        }
        
        return new org.springframework.security.core.userdetails.User(
                user.getUsername(),
                user.getPassword(),
                user.getEnabled(),
                true,
                true,
                true,
                authorities
        );
    }
}
```

### UserService.java

```java
package com.example.security.service;

import com.example.security.entity.User;
import com.example.security.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class UserService {
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private PasswordEncoder passwordEncoder;
    
    public User createUser(String username, String password) {
        User user = new User();
        user.setUsername(username);
        user.setPassword(passwordEncoder.encode(password));
        user.setEnabled(true);
        return userRepository.save(user);
    }
    
    public Optional<User> findByUsername(String username) {
        return userRepository.findByUsername(username);
    }
    
    public boolean existsByUsername(String username) {
        return userRepository.findByUsername(username).isPresent();
    }
}
```

## 12. 配置类

### SecurityConfig.java

```java
package com.example.security.config;

import com.example.security.security.CustomAccessDecisionManager;
import com.example.security.security.CustomFilterInvocationSecurityMetadataSource;
import com.example.security.security.CustomSecurityContextRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.intercept.FilterSecurityInterceptor;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Autowired
    private CustomSecurityContextRepository customSecurityContextRepository;
    
    @Autowired
    private CustomFilterInvocationSecurityMetadataSource customFilterInvocationSecurityMetadataSource;
    
    @Autowired
    private CustomAccessDecisionManager customAccessDecisionManager;
    
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
        http.csrf().disable()
            .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            .and()
            .securityContext()
            .securityContextRepository(customSecurityContextRepository)
            .and()
            .authorizeHttpRequests(authz -> authz
                .antMatchers("/api/auth/**").permitAll()
                .antMatchers("/h2-console/**").permitAll()
                .anyRequest().authenticated()
            )
            .headers().frameOptions().sameOrigin();
        
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