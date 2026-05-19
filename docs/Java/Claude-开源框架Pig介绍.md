# 开源框架Pig介绍

**Created:** 5/13/2026 14:48:13  
**Updated:** 5/13/2026 15:02:11  
**Exported:** 5/13/2026 22:02:42  
**Link:** [https://claude.ai/chat/d62d64e1-1d32-4b69-985b-67bb7dc4758c](https://claude.ai/chat/d62d64e1-1d32-4b69-985b-67bb7dc4758c)  

## Prompt:
2026/5/13 14:48:14

你了解开源框架pig吗



## Response:
2026/5/13 14:48:24

了解！**PIG** 是一个基于 Spring Boot + Spring Cloud 的微服务开发框架，在国内开源社区很有名气。

## 核心定位

PIG 是一个**企业级微服务权限管理系统**，主打"开箱即用"的后台管理脚手架，适合快速搭建中后台项目。

## 技术栈

- **后端**：Spring Boot 3.x、Spring Cloud、Spring Security OAuth2（或 Spring Authorization Server）
- **注册/配置中心**：Nacos
- **网关**：Spring Cloud Gateway
- **缓存**：Redis
- **数据库**：MySQL + MyBatis-Plus
- **前端**：Vue 3 + Element Plus（配套项目 pig-ui）

## 主要特性

- **基于 OAuth2 的统一认证授权**，支持多种登录方式（密码、短信、社交登录等）
- **RBAC 权限模型**，角色/菜单/数据权限细粒度控制
- **多租户支持**（商业版更完善）
- **日志追踪**，基于 SkyWalking 或 Skylog
- **代码生成器**，根据表结构自动生成前后端代码
- **Docker / K8s** 友好，支持容器化部署

## 版本情况

| 版本 | 说明 |
|------|------|
| 开源版 | 核心功能免费，GitHub/Gitee 可获取 |
| 商业版（pigX） | 更多企业特性，如工作流、多租户增强等 |

## 适用场景

适合需要快速交付的**中后台管理系统**、**微服务入门学习**，以及有权限管理需求的企业项目。

---

你是想用 PIG 做项目开发、学习源码，还是有具体的技术问题？可以告诉我方向，我来针对性地帮你。



## Prompt:
2026/5/13 14:50:44

spring security cloud oauth2 在分布式微服务系统是怎么应用的？spring security负责认证，然后认证完了之后oauth2在负责授权吗？oauth2需要获取什么东西，spring security负责提供什么东西，这个完整的流程是怎么样的？



## Response:
2026/5/13 14:51:41

很好的问题！你的理解方向是对的，但细节上需要纠正一下——Spring Security 和 OAuth2 的关系不是"先后"关系，而是**包含关系**。让我画一张完整的流程图来解释。

````plaintext
Tool: read_me
````

````plaintext
Tool: show_widget
````

好，结合这张图，我来详细解释每个阶段。

---

## 纠正一个误解：不是"先后"关系

你说的"Spring Security 负责认证，OAuth2 负责授权"这个方向是对的，但**不是两个独立系统先后工作**。正确的理解是：

> **OAuth2 是一套协议规范，Spring Security 是实现它的框架。** OAuth2 运行在 Spring Security 之上，就像 HTTPS 运行在 TCP 之上一样。

---

## 完整流程拆解

### ① 认证阶段（Spring Security 的工作）

用户提交用户名+密码，Spring Security 内部做这些事：

- `UsernamePasswordAuthenticationFilter` 拦截请求
- 调用你实现的 `UserDetailsService.loadUserByUsername()` 查数据库
- 用 `BCryptPasswordEncoder` 比对密码
- 认证通过后，构建 `Authentication` 对象（包含用户信息和权限列表）

### ② OAuth2 颁发 Token

认证成功后，Spring Authorization Server（OAuth2 实现）做这些事：

- 按照 OAuth2 协议，将用户信息 + 权限（roles/scopes）打包进 **JWT**
- JWT Payload 大概长这样：
  ```json
  { "sub": "user123", "roles": ["ROLE_ADMIN"], "scope": "order:read", "exp": 1700000000 }
  ```
- 用私钥签名，返回给客户端

### ③ 网关层校验（Gateway 的工作）

之后每次请求，客户端都带着这个 Token。网关负责：

- 用**公钥**验证签名是否合法
- 检查是否过期
- 解析出用户信息，注入到请求 Header（`X-User-Id`、`X-User-Roles`）
- **转发给后端微服务**——所以各微服务不需要再去联系认证服务器

### ④ 各微服务做授权（Resource Server）

每个微服务配置为 **OAuth2 Resource Server**，只需：

- 从 Header 或 Token 中拿到 roles/scopes
- 用 `@PreAuthorize("hasRole('ADMIN')")` 等注解做方法级权限校验

---

## Spring Security 提供什么，OAuth2 需要什么

| 组件 | 提供方 | 作用 |
|---|---|---|
| 认证过滤器链 | Spring Security | 拦截登录请求，验证用户名密码 |
| UserDetails / UserDetailsService | Spring Security（你实现） | 从数据库加载用户信息 |
| PasswordEncoder | Spring Security | 密码加密比对 |
| Token 颁发 | Spring Authorization Server（OAuth2） | 生成 JWT，包含用户权限 |
| Token 校验 | Spring Security Resource Server | 各微服务验签、解析权限 |
| `@PreAuthorize` | Spring Security | 方法级权限拦截 |

---

点击图中各节点可以继续深入了解某个具体组件。有哪一块想深入说说？比如 JWT 的结构、网关怎么配，还是 `@PreAuthorize` 怎么用？



## Prompt:
2026/5/13 14:52:09

我在使用开源项目pig的时候，我的登录认证流程是 使用用户名和密码请求一次后台，然后后台会给我返回一个token，我不知道这个token是不是aceess token 还是什么token。但是后面我调用微服务接口的时候会带上这个toekn，bearar token：返回来的token，去返回接口就能调用了。请问这个流程是什么？



## Response:
2026/5/13 14:53:03

你描述的就是标准的 **OAuth2 密码模式（Password Grant）** 流程，而且那个 token **就是 Access Token**，格式是 JWT。让我结合 PIG 的具体实现来解释。

````plaintext
Tool: read_me
````

````plaintext
Tool: show_widget
````

结合你的具体场景，逐步解释。

---

## 你拿到的那个 Token 是什么

就是 **OAuth2 Access Token**，PIG 里用的是 JWT 格式。你可以把它粘贴到 [jwt.io](https://jwt.io) 解码，能看到里面的内容大概是：

```json
{
  "sub": "admin",
  "userId": 1,
  "username": "admin",
  "authorities": ["ROLE_ADMIN", "order:read"],
  "client_id": "pig",
  "exp": 1700000000
}
```

---

## 你登录时请求的接口是什么

PIG 登录接口遵循 OAuth2 标准，实际上你 POST 的是：

```
POST /auth/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&username=admin
&password=admin123
&scope=server
```

Header 里还要带 `Authorization: Basic cGlnOnBpZw==`（这是 client_id:client_secret 的 Base64，pig 默认是 `pig:pig`）。

返回的数据结构是：

```json
{
  "access_token": "eyJhbGci...",
  "token_type": "Bearer",
  "refresh_token": "eyJhbGci...",
  "expires_in": 43199
}
```

你用的就是 `access_token`。

---

## 为什么 `Bearer <token>` 就能调通接口

流程是：

1. 你带着 `Authorization: Bearer eyJ...` 发请求到 Gateway
2. Gateway 里的 `TokenAuthenticationFilter` 用**公钥**验证 JWT 签名，解析出用户信息
3. 把用户 id、用户名注入请求 Header（`X-User-Id`、`X-Username`）
4. 转发给具体微服务
5. 微服务作为 **Resource Server**，读取 Header 或 Token 里的 roles，执行 `@PreAuthorize` 校验

全程**不需要再联系 Auth Server**，因为 JWT 是自包含的，签名验证本地就能完成。

---

## 还有个 Refresh Token，是干什么的

Access Token 有过期时间（PIG 默认 12 小时）。过期之后不需要重新登录，而是用 `refresh_token` 换一个新的 `access_token`：

```
POST /auth/oauth2/token
grant_type=refresh_token
&refresh_token=eyJ...（refresh_token 的值）
```

---

需要深入某个环节吗？比如 PIG 里怎么自定义登录逻辑、怎么加自定义字段到 Token、或者权限注解怎么配？



## Prompt:
2026/5/13 14:54:17

pig的pig-auth模块内部认证逻辑是什么？



## Response:
2026/5/13 14:55:11

好，我来详细拆解 PIG 的 `pig-auth` 模块内部认证逻辑。PIG 使用的是 **Spring Authorization Server**（简称 SAS），在它的标准流程上做了大量定制扩展。

````plaintext
Tool: show_widget
````

下面按层次逐一解释每个关键节点。

---

## 第一层：过滤器链入口（SAS 原生）

请求进来后先经过两个 Spring Authorization Server 的标准过滤器：

`OAuth2TokenEndpointFilter` 负责拦截所有 `/oauth2/token` 请求，把 HTTP 表单参数（`grant_type`、`username`、`password` 等）提取出来，交给后续的 Converter 处理。

`ClientSecretAuthenticationFilter` 验证客户端身份，也就是校验你请求 Header 里的 `Authorization: Basic cGlnOnBpZw==`，解码后确认 `client_id=pig`、`client_secret=pig` 在数据库 `sys_oauth_client_details` 表中是否存在且合法。

---

## 第二层：PIG 的核心扩展（最重要）

这是 PIG 相比标准 SAS 做定制的地方：

### `PasswordAuthenticationConverter`

SAS 原生只支持授权码模式，不支持用户名密码直接登录。PIG 自己实现了这个 Converter，从请求里解析出 `username`、`password`，还有 PIG 特有的**图形验证码**（`code` + `randomStr`）参数，组装成 `PasswordAuthenticationToken` 传给 Provider。

### `PasswordAuthenticationProvider`

这是整个认证的核心，内部串联了三步：

**第一步 — `PigUserDetailsServiceImpl` 加载用户**

不是查本地数据库，而是通过 Feign 远程调用 `pig-upms-biz`（用户权限管理服务），根据用户名查回完整的用户信息，包括角色列表、权限列表、部门、租户 ID 等，封装成 `PigUser`（继承自 `UserDetails`）。

**第二步 — `BCryptPasswordEncoder` 比对密码**

拿用户输入的明文密码和数据库里存的 BCrypt 密文做比对。PIG 还在这一步前加了验证码校验（查 Redis，验证图形验证码是否正确）。

**第三步 — `PigOAuth2TokenCustomizer` 定制 JWT**

密码比对通过后，在生成 JWT 之前，`PigOAuth2TokenCustomizer` 会把额外信息写进 JWT 的 Payload：

```json
{
  "sub": "admin",
  "userId": 1,
  "username": "admin",
  "deptId": 1,
  "tenantId": "000000",
  "authorities": ["ROLE_ADMIN", "sys_user_add"],
  "exp": 1700000000
}
```

这就是为什么后续微服务里能直接从 Token 里拿到 `userId` 和 `deptId`，不用再查数据库。

---

## 第三层：JWT 签发（SAS 原生）

`OAuth2TokenGenerator` 调用内部的 `JwtGenerator`，用 **RSA 私钥**对 Payload 签名，生成最终的 JWT 字符串。同时生成一个 `refresh_token` 存入 Redis（或数据库），用于后续无感刷新。

---

## 整体关键点总结

| 扩展点 | 作用 | PIG 特有？ |
|---|---|---|
| `PasswordAuthenticationConverter` | 支持用户名密码登录模式 | 是 |
| `PasswordAuthenticationProvider` | 串联验证码+用户加载+密码比对 | 是 |
| `PigUserDetailsServiceImpl` | 通过 Feign 远程加载用户 | 是 |
| `PigOAuth2TokenCustomizer` | 向 JWT 注入业务字段 | 是 |
| `BCryptPasswordEncoder` | 密码加密比对 | 否（Spring Security 原生） |
| `JwtGenerator` | RSA 签名生成 JWT | 否（SAS 原生） |

---

想继续深入哪个点？比如验证码校验的具体实现、`PigUserDetailsServiceImpl` 怎么扩展自定义登录方式（手机号登录、第三方登录），还是 JWT 的 RSA 公私钥是怎么配置的？



## Prompt:
2026/5/13 15:01:07

我想知道pig用的Spring Authorization Server 具体是哪一个项目？是spring security吗还是单独的一个项目通过maven单独引用？它和spring security是怎么配合的？两个框架spring security和Spring Authorization Server分别在那个阶段发挥作用的，都被集成在pig-auth这个模块吗？具体的代码帮我罗列出来



## Response:
2026/5/13 15:02:11

很好的问题！先直接回答核心疑问，再看代码。

````plaintext
Tool: show_widget
````

**Spring Authorization Server 是完全独立的项目**，不是 Spring Security 的子模块，通过 Maven 单独引入。两者关系是：SAS 构建在 Spring Security 之上，大量复用其过滤器链和认证体系，但 OAuth2 协议逻辑（Token 端点、客户端管理、JWT 签发）全由 SAS 自己实现。pig-auth 模块同时引入两者并做扩展。

下面逐层看代码。

---

## 一、Maven 依赖（最直接的证明）

`pig-auth/pom.xml`：

```xml
<dependencies>
    <!-- Spring Authorization Server：独立坐标，不是 spring-security-* 子模块 -->
    <dependency>
        <groupId>org.springframework.security</groupId>
        <artifactId>spring-security-oauth2-authorization-server</artifactId>
        <!-- 版本由 Spring Boot 父 pom 统一管理，pig 用 1.1.x / 1.2.x -->
    </dependency>

    <!-- Spring Security Web（过滤器链、密码加密等基础能力） -->
    <!-- 不需要显式写，SAS 已经传递依赖了它 -->

    <!-- pig 自己封装的 security 公共模块（给各微服务用的 Resource Server 配置） -->
    <dependency>
        <groupId>com.pig4cloud</groupId>
        <artifactId>pig-common-security</artifactId>
    </dependency>

    <!-- upms feign 客户端，用于远程查用户 -->
    <dependency>
        <groupId>com.pig4cloud</groupId>
        <artifactId>pig-upms-api</artifactId>
    </dependency>
</dependencies>
```

---

## 二、Spring Security 在 pig-auth 里做什么

Spring Security 提供最底层的安全基础设施，pig-auth 里直接用到的主要是这几块：

### 1. SecurityFilterChain 配置（两条链并存）

`AuthorizationServerConfiguration.java`：

```java
@Configuration
@RequiredArgsConstructor
public class AuthorizationServerConfiguration {

    // ① 这条链专门服务 OAuth2 端点（/oauth2/token、/oauth2/authorize 等）
    //    由 SAS 提供，内部挂了一堆 OAuth2 专用 Filter
    @Bean
    @Order(Ordered.HIGHEST_PRECEDENCE)
    public SecurityFilterChain authorizationServerSecurityFilterChain(HttpSecurity http) throws Exception {

        // 这一行是 SAS 的入口：把所有 OAuth2 端点的 Filter 注册进来
        OAuth2AuthorizationServerConfigurer authorizationServerConfigurer =
                new OAuth2AuthorizationServerConfigurer();

        // PIG 在这里注册自定义的 Converter 和 Provider（用户名密码模式）
        authorizationServerConfigurer
            .tokenEndpoint(tokenEndpoint -> tokenEndpoint
                .accessTokenRequestConverter(new PasswordAuthenticationConverter())   // 解析参数
                .authenticationProvider(new PasswordAuthenticationProvider(...))      // 核心认证
            );

        http.apply(authorizationServerConfigurer);
        return http.build();
    }

    // ② 这条链服务普通接口（如 /actuator），Spring Security 原生管
    @Bean
    public SecurityFilterChain defaultSecurityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .formLogin(Customizer.withDefaults());
        return http.build();
    }
}
```

### 2. UserDetailsService（Spring Security 接口，pig 自己实现）

`PigUserDetailsServiceImpl.java`：

```java
@Service
@RequiredArgsConstructor
public class PigUserDetailsServiceImpl implements UserDetailsService {

    private final RemoteUserService remoteUserService; // Feign 客户端

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // 注意：这里不查本地库，通过 Feign 调用 pig-upms-biz 微服务
        R<UserInfo> result = remoteUserService.info(username, SecurityConstants.FROM_IN);

        return getUserDetails(result); // 封装成 PigUser（UserDetails 实现类）
    }

    private UserDetails getUserDetails(R<UserInfo> result) {
        UserInfo info = result.getData();

        // 把角色列表转成 Spring Security 的 GrantedAuthority
        Set<String> dbAuthsSet = new HashSet<>();
        if (ArrayUtil.isNotEmpty(info.getRoles())) {
            Arrays.stream(info.getRoles()).forEach(role -> dbAuthsSet.add(SecurityConstants.ROLE + role));
        }
        // 细粒度权限（菜单权限标识，如 sys_user_add）
        if (ArrayUtil.isNotEmpty(info.getPermissions())) {
            Arrays.stream(info.getPermissions()).forEach(dbAuthsSet::add);
        }

        Collection<GrantedAuthority> authorities =
            AuthorityUtils.createAuthorityList(dbAuthsSet.toArray(new String[0]));

        SysUser user = info.getSysUser();
        // PigUser 继承 Spring Security 的 User，额外携带 deptId、tenantId 等业务字段
        return new PigUser(user.getUserId(), user.getDeptId(), user.getTenantId(),
                user.getUsername(), user.getPassword(),
                true, true, true, !LOCK_FLAG.equals(user.getLockFlag()),
                authorities);
    }
}
```

### 3. PasswordEncoder（Spring Security 提供）

```java
@Bean
public PasswordEncoder passwordEncoder() {
    // Spring Security 原生的 BCrypt 实现，SAS 和 pig 都直接用
    return new BCryptPasswordEncoder();
}
```

---

## 三、Spring Authorization Server 在 pig-auth 里做什么

SAS 提供 OAuth2 协议层，pig 在它的扩展点上做定制。

### 1. pig 自定义的 PasswordAuthenticationConverter

SAS 原生不支持 password grant（OAuth 2.1 已废弃），pig 自己补上：

```java
// 作用：从 HttpServletRequest 里解析参数，组装成 Token 对象交给 Provider
public class PasswordAuthenticationConverter implements AuthenticationConverter {

    @Override
    public Authentication convert(HttpServletRequest request) {
        // 只处理 grant_type=password 的请求
        String grantType = request.getParameter(OAuth2ParameterNames.GRANT_TYPE);
        if (!AuthorizationGrantType.PASSWORD.getValue().equals(grantType)) {
            return null;
        }

        String username = request.getParameter(OAuth2ParameterNames.USERNAME);
        String password = request.getParameter(OAuth2ParameterNames.PASSWORD);

        // 组装成 pig 自定义的 Token 对象（SAS 的 AbstractAuthenticationToken 子类）
        return new PasswordAuthenticationToken(
            getGrantType(),
            clientPrincipal,   // 已验证的客户端信息（来自前一个 Filter）
            username, password,
            requestedScopes
        );
    }
}
```

### 2. pig 自定义的 PasswordAuthenticationProvider

```java
// 作用：拿到 Converter 组装的 Token，执行真正的认证逻辑
public class PasswordAuthenticationProvider implements AuthenticationProvider {

    private final UserDetailsService userDetailsService;
    private final PasswordEncoder passwordEncoder;
    private final OAuth2TokenGenerator<?> tokenGenerator; // SAS 提供的 Token 生成器

    @Override
    public Authentication authenticate(Authentication authentication) {
        PasswordAuthenticationToken authToken = (PasswordAuthenticationToken) authentication;

        // ① 调用 UserDetailsService 加载用户（走 Feign 查 upms）
        UserDetails userDetails = userDetailsService.loadUserByUsername(
            authToken.getUsername()
        );

        // ② Spring Security 的 BCrypt 比对密码
        if (!passwordEncoder.matches(authToken.getPassword(), userDetails.getPassword())) {
            throw new OAuth2AuthenticationException("用户名或密码错误");
        }

        // ③ 构造 principal，传给 SAS 的 tokenGenerator 生成 JWT
        UsernamePasswordAuthenticationToken principal =
            new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());

        // ④ 调用 SAS 的标准流程生成 access_token + refresh_token
        OAuth2TokenContext tokenContext = buildTokenContext(authToken, principal);
        OAuth2AccessToken accessToken = tokenGenerator.generate(tokenContext); // SAS 负责签名

        return new OAuth2AccessTokenAuthenticationToken(
            registeredClient, principal, accessToken, refreshToken
        );
    }
}
```

### 3. pig 的 JWT 自定义字段注入（SAS 的扩展点）

```java
// 作用：在 JWT Payload 里塞入业务字段，SAS 原生只放标准字段
@Bean
public OAuth2TokenCustomizer<JwtEncodingContext> tokenCustomizer() {
    return context -> {
        // 只在生成 access_token 时扩展
        if (OAuth2TokenType.ACCESS_TOKEN.equals(context.getTokenType())) {
            OAuth2Authentication auth2Authentication = context.getPrincipal();
            Collection<? extends GrantedAuthority> authorities = auth2Authentication.getAuthorities();

            // 把权限列表写进 JWT
            context.getClaims().claim(SecurityConstants.AUTHORITIES_KEY,
                authorities.stream().map(GrantedAuthority::getAuthority).collect(Collectors.toSet())
            );

            // 把 PigUser 里的业务字段写进 JWT
            if (auth2Authentication.getPrincipal() instanceof PigUser pigUser) {
                context.getClaims().claim(SecurityConstants.USER_ID_KEY, pigUser.getId());
                context.getClaims().claim(SecurityConstants.DEPT_ID_KEY, pigUser.getDeptId());
                context.getClaims().claim(SecurityConstants.USERNAME, pigUser.getUsername());
                context.getClaims().claim(SecurityConstants.TENANT_ID, pigUser.getTenantId());
            }
        }
    };
}
```

---

## 四、两个框架分工总结

| 阶段 | 谁负责 | 具体类 |
|---|---|---|
| 过滤器链基础设施 | Spring Security | `SecurityFilterChain`、`HttpSecurity` |
| 客户端身份验证 | SAS | `ClientSecretAuthenticationFilter` |
| 请求参数解析 | pig 扩展 SAS | `PasswordAuthenticationConverter` |
| 用户加载 | pig 实现 SS 接口 | `PigUserDetailsServiceImpl` → Feign |
| 密码比对 | Spring Security | `BCryptPasswordEncoder` |
| 认证编排 | pig 扩展 SAS | `PasswordAuthenticationProvider` |
| JWT 签发（RSA 签名） | SAS | `JwtGenerator`、`NimbusJwtEncoder` |
| JWT 字段扩展 | pig 扩展 SAS | `PigOAuth2TokenCustomizer` |
| 微服务侧 Token 解析 | SAS + SS | `BearerTokenAuthenticationFilter` |
| 方法级权限 `@PreAuthorize` | Spring Security | `MethodSecurityInterceptor` |

一句话总结：**Spring Security 是地基，SAS 是盖在上面的 OAuth2 协议楼，pig-auth 是在这栋楼里做的装修定制**。两者都在 pig-auth 模块里，缺一不可。





---
Powered by [Claude Exporter](https://www.ai-chat-exporter.net)