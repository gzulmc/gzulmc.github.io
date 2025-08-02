# Spring Security SMS Login Implementation

**Created:** 2025/7/8 1:56  
**Updated:** 2025/7/8 1:58  
**Exported:** 2025/7/8 1:59  
**Link:** [https://claude.ai/chat/036e3dc2-565e-404f-8120-d8519632db84](https://claude.ai/chat/036e3dc2-565e-404f-8120-d8519632db84)  

## Prompt:
请帮我写一个基于spring security实现手机短信验证码登录某系统的代码，并解释每一个步骤和要继承或实现的接口，即为什么要实现某个接口或某个类他们的背后逻辑，说明整个执行流程。不需要前端代码只需要实现后端代码



## Response:
我来帮您实现一个基于Spring Security的手机短信验证码登录系统。这是一个完整的实现，包括所有必要的组件和详细的执行流程说明。

**Spring Security 手机短信验证码登录系统**

```java
// 1. 短信验证码实体类
public class SmsCode {
    private String code;
    private LocalDateTime expireTime;
    
    public SmsCode(String code, int expireIn) {
        this.code = code;
        this.expireTime = LocalDateTime.now().plusSeconds(expireIn);
    }
    
    public SmsCode(String code, LocalDateTime expireTime) {
        this.code = code;
        this.expireTime = expireTime;
    }
    
    public boolean isExpired() {
        return LocalDateTime.now().isAfter(expireTime);
    }
    
    // getters and setters
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public LocalDateTime getExpireTime() { return expireTime; }
    public void setExpireTime(LocalDateTime expireTime) { this.expireTime = expireTime; }
}

// 2. 短信验证码异常类
public class SmsCodeException extends AuthenticationException {
    public SmsCodeException(String message) {
        super(message);
    }
}

// 3. 短信验证码服务接口
public interface SmsCodeService {
    void sendSmsCode(String mobile);
    void validateSmsCode(String mobile, String code);
}

// 4. 短信验证码服务实现类
@Service
public class SmsCodeServiceImpl implements SmsCodeService {
    
    // 使用Redis存储验证码，这里用Map模拟
    private final Map<String, SmsCode> smsCodeStore = new ConcurrentHashMap<>();
    
    @Override
    public void sendSmsCode(String mobile) {
        // 生成6位数字验证码
        String code = String.valueOf((int)((Math.random() * 9 + 1) * 100000));
        
        // 验证码有效期5分钟
        SmsCode smsCode = new SmsCode(code, 300);
        smsCodeStore.put(mobile, smsCode);
        
        // 这里应该调用短信服务商API发送短信
        System.out.println("发送短信验证码到手机号: " + mobile + ", 验证码: " + code);
    }
    
    @Override
    public void validateSmsCode(String mobile, String code) {
        SmsCode smsCode = smsCodeStore.get(mobile);
        
        if (smsCode == null) {
            throw new SmsCodeException("验证码不存在");
        }
        
        if (smsCode.isExpired()) {
            smsCodeStore.remove(mobile);
            throw new SmsCodeException("验证码已过期");
        }
        
        if (!smsCode.getCode().equals(code)) {
            throw new SmsCodeException("验证码错误");
        }
        
        // 验证通过后删除验证码
        smsCodeStore.remove(mobile);
    }
}

// 5. 短信验证码认证Token
// 继承AbstractAuthenticationToken是因为它实现了Authentication接口
// 并提供了基础的认证信息存储功能
public class SmsCodeAuthenticationToken extends AbstractAuthenticationToken {
    
    private final Object principal; // 存储手机号
    private Object credentials; // 存储验证码
    
    // 未认证的构造函数
    public SmsCodeAuthenticationToken(String mobile, String smsCode) {
        super(null);
        this.principal = mobile;
        this.credentials = smsCode;
        setAuthenticated(false);
    }
    
    // 已认证的构造函数
    public SmsCodeAuthenticationToken(Object principal, Object credentials, 
                                     Collection<? extends GrantedAuthority> authorities) {
        super(authorities);
        this.principal = principal;
        this.credentials = credentials;
        super.setAuthenticated(true);
    }
    
    @Override
    public Object getCredentials() {
        return this.credentials;
    }
    
    @Override
    public Object getPrincipal() {
        return this.principal;
    }
    
    @Override
    public void setAuthenticated(boolean isAuthenticated) throws IllegalArgumentException {
        if (isAuthenticated) {
            throw new IllegalArgumentException(
                "Cannot set this token to trusted - use constructor which takes a GrantedAuthority list instead");
        }
        super.setAuthenticated(false);
    }
    
    @Override
    public void eraseCredentials() {
        super.eraseCredentials();
        credentials = null;
    }
}

// 6. 短信验证码认证过滤器
// 继承AbstractAuthenticationProcessingFilter是因为它提供了认证处理的基础框架
// 包括认证成功/失败处理、会话管理等
public class SmsCodeAuthenticationFilter extends AbstractAuthenticationProcessingFilter {
    
    public static final String SPRING_SECURITY_FORM_MOBILE_KEY = "mobile";
    public static final String SPRING_SECURITY_FORM_SMSCODE_KEY = "smsCode";
    
    private String mobileParameter = SPRING_SECURITY_FORM_MOBILE_KEY;
    private String smsCodeParameter = SPRING_SECURITY_FORM_SMSCODE_KEY;
    private boolean postOnly = true;
    
    public SmsCodeAuthenticationFilter() {
        super(new AntPathRequestMatcher("/login/sms", "POST"));
    }
    
    @Override
    public Authentication attemptAuthentication(HttpServletRequest request, 
                                              HttpServletResponse response) 
            throws AuthenticationException, IOException, ServletException {
        
        if (postOnly && !request.getMethod().equals("POST")) {
            throw new AuthenticationServiceException("Authentication method not supported: " + request.getMethod());
        }
        
        String mobile = obtainMobile(request);
        String smsCode = obtainSmsCode(request);
        
        if (mobile == null) {
            mobile = "";
        }
        
        if (smsCode == null) {
            smsCode = "";
        }
        
        mobile = mobile.trim();
        
        SmsCodeAuthenticationToken authRequest = new SmsCodeAuthenticationToken(mobile, smsCode);
        
        // 设置详细信息
        setDetails(request, authRequest);
        
        return this.getAuthenticationManager().authenticate(authRequest);
    }
    
    protected String obtainMobile(HttpServletRequest request) {
        return request.getParameter(mobileParameter);
    }
    
    protected String obtainSmsCode(HttpServletRequest request) {
        return request.getParameter(smsCodeParameter);
    }
    
    protected void setDetails(HttpServletRequest request, SmsCodeAuthenticationToken authRequest) {
        authRequest.setDetails(authenticationDetailsSource.buildDetails(request));
    }
    
    // getters and setters
    public void setMobileParameter(String mobileParameter) {
        this.mobileParameter = mobileParameter;
    }
    
    public void setSmsCodeParameter(String smsCodeParameter) {
        this.smsCodeParameter = smsCodeParameter;
    }
    
    public void setPostOnly(boolean postOnly) {
        this.postOnly = postOnly;
    }
}

// 7. 短信验证码认证提供者
// 实现AuthenticationProvider接口是因为它定义了认证逻辑的核心方法
// Spring Security会遍历所有的AuthenticationProvider来处理不同类型的认证
public class SmsCodeAuthenticationProvider implements AuthenticationProvider {
    
    private UserDetailsService userDetailsService;
    private SmsCodeService smsCodeService;
    
    @Override
    public Authentication authenticate(Authentication authentication) throws AuthenticationException {
        SmsCodeAuthenticationToken authenticationToken = (SmsCodeAuthenticationToken) authentication;
        
        String mobile = (String) authenticationToken.getPrincipal();
        String smsCode = (String) authenticationToken.getCredentials();
        
        // 验证短信验证码
        smsCodeService.validateSmsCode(mobile, smsCode);
        
        // 根据手机号获取用户信息
        UserDetails userDetails = userDetailsService.loadUserByUsername(mobile);
        
        // 创建已认证的token
        SmsCodeAuthenticationToken authenticationResult = 
            new SmsCodeAuthenticationToken(userDetails, smsCode, userDetails.getAuthorities());
        
        authenticationResult.setDetails(authenticationToken.getDetails());
        
        return authenticationResult;
    }
    
    @Override
    public boolean supports(Class<?> authentication) {
        // 指定该Provider支持的认证类型
        return SmsCodeAuthenticationToken.class.isAssignableFrom(authentication);
    }
    
    // getters and setters
    public void setUserDetailsService(UserDetailsService userDetailsService) {
        this.userDetailsService = userDetailsService;
    }
    
    public void setSmsCodeService(SmsCodeService smsCodeService) {
        this.smsCodeService = smsCodeService;
    }
}

// 8. 用户详情服务实现
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    // 这里模拟数据库查询，实际应该注入UserRepository
    private final Map<String, User> users = new HashMap<>();
    
    @PostConstruct
    public void init() {
        // 初始化一些测试用户
        users.put("13800138000", User.builder()
            .username("13800138000")
            .password("{noop}password") // {noop}表示不加密
            .authorities("ROLE_USER")
            .build());
    }
    
    @Override
    public UserDetails loadUserByUsername(String mobile) throws UsernameNotFoundException {
        User user = users.get(mobile);
        if (user == null) {
            throw new UsernameNotFoundException("手机号不存在: " + mobile);
        }
        return user;
    }
}

// 9. 短信验证码配置类
@Component
public class SmsCodeAuthenticationSecurityConfig extends SecurityConfigurerAdapter<DefaultSecurityFilterChain, HttpSecurity> {
    
    @Autowired
    private AuthenticationSuccessHandler authenticationSuccessHandler;
    
    @Autowired
    private AuthenticationFailureHandler authenticationFailureHandler;
    
    @Autowired
    private UserDetailsService userDetailsService;
    
    @Autowired
    private SmsCodeService smsCodeService;
    
    @Override
    public void configure(HttpSecurity http) throws Exception {
        // 创建过滤器
        SmsCodeAuthenticationFilter smsCodeAuthenticationFilter = new SmsCodeAuthenticationFilter();
        smsCodeAuthenticationFilter.setAuthenticationManager(http.getSharedObject(AuthenticationManager.class));
        smsCodeAuthenticationFilter.setAuthenticationSuccessHandler(authenticationSuccessHandler);
        smsCodeAuthenticationFilter.setAuthenticationFailureHandler(authenticationFailureHandler);
        
        // 创建认证提供者
        SmsCodeAuthenticationProvider smsCodeAuthenticationProvider = new SmsCodeAuthenticationProvider();
        smsCodeAuthenticationProvider.setUserDetailsService(userDetailsService);
        smsCodeAuthenticationProvider.setSmsCodeService(smsCodeService);
        
        // 将认证提供者添加到系统中
        http.authenticationProvider(smsCodeAuthenticationProvider)
            .addFilterAfter(smsCodeAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
    }
}

// 10. 短信验证码控制器
@RestController
@RequestMapping("/sms")
public class SmsCodeController {
    
    @Autowired
    private SmsCodeService smsCodeService;
    
    @PostMapping("/send")
    public ResponseEntity<String> sendSmsCode(@RequestParam String mobile) {
        try {
            smsCodeService.sendSmsCode(mobile);
            return ResponseEntity.ok("短信验证码发送成功");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("短信验证码发送失败: " + e.getMessage());
        }
    }
}

// 11. 认证成功处理器
@Component
public class CustomAuthenticationSuccessHandler implements AuthenticationSuccessHandler {
    
    private ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, 
                                      HttpServletResponse response, 
                                      Authentication authentication) throws IOException, ServletException {
        
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpStatus.OK.value());
        
        Map<String, Object> result = new HashMap<>();
        result.put("code", 200);
        result.put("message", "登录成功");
        result.put("data", authentication.getPrincipal());
        
        response.getWriter().write(objectMapper.writeValueAsString(result));
    }
}

// 12. 认证失败处理器
@Component
public class CustomAuthenticationFailureHandler implements AuthenticationFailureHandler {
    
    private ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void onAuthenticationFailure(HttpServletRequest request, 
                                      HttpServletResponse response, 
                                      AuthenticationException exception) throws IOException, ServletException {
        
        response.setContentType("application/json;charset=UTF-8");
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        
        Map<String, Object> result = new HashMap<>();
        result.put("code", 401);
        result.put("message", "登录失败: " + exception.getMessage());
        
        response.getWriter().write(objectMapper.writeValueAsString(result));
    }
}

// 13. Spring Security配置
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    
    @Autowired
    private SmsCodeAuthenticationSecurityConfig smsCodeAuthenticationSecurityConfig;
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/sms/send", "/login/sms").permitAll()
                .anyRequest().authenticated()
            )
            .csrf().disable()
            .apply(smsCodeAuthenticationSecurityConfig); // 应用短信验证码配置
            
        return http.build();
    }
}

// 14. 主要的依赖项（pom.xml中需要添加）
/*
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>
*/
```

现在让我详细解释整个系统的设计思路和执行流程：

## 核心接口和类的设计原理

### 1. **SmsCodeAuthenticationToken 继承 AbstractAuthenticationToken**
- **原因**: `AbstractAuthenticationToken` 实现了 `Authentication` 接口，提供了认证信息的基础存储功能
- **作用**: 存储手机号(principal)和验证码(credentials)，以及认证状态
- **设计**: 提供两个构造函数，一个用于未认证状态，一个用于已认证状态

### 2. **SmsCodeAuthenticationFilter 继承 AbstractAuthenticationProcessingFilter**
- **原因**: `AbstractAuthenticationProcessingFilter` 提供了认证处理的完整框架
- **作用**: 拦截 `/login/sms` 请求，提取手机号和验证码，创建认证Token
- **核心方法**: `attemptAuthentication()` 方法负责从请求中提取认证信息

### 3. **SmsCodeAuthenticationProvider 实现 AuthenticationProvider**
- **原因**: Spring Security 通过 `AuthenticationProvider` 接口实现认证逻辑的插件化
- **作用**: 处理短信验证码的认证逻辑，包括验证码校验和用户信息加载
- **核心方法**: 
  - `authenticate()`: 执行认证逻辑
  - `supports()`: 指定支持的认证类型

### 4. **CustomUserDetailsService 实现 UserDetailsService**
- **原因**: Spring Security 需要通过此接口获取用户详细信息
- **作用**: 根据手机号查询用户信息，返回 `UserDetails` 对象

## 完整的执行流程

### 阶段1: 发送验证码
1. 用户调用 `/sms/send` 接口，传入手机号
2. `SmsCodeController.sendSmsCode()` 方法被调用
3. `SmsCodeService.sendSmsCode()` 生成验证码并存储（这里用Map模拟，实际应该用Redis）
4. 调用短信服务商API发送验证码到用户手机

### 阶段2: 验证码登录
1. 用户提交手机号和验证码到 `/login/sms` 接口
2. `SmsCodeAuthenticationFilter` 拦截请求：
   - 检查是否为POST请求
   - 提取手机号和验证码参数
   - 创建未认证的 `SmsCodeAuthenticationToken`
   - 调用 `AuthenticationManager.authenticate()`

3. `AuthenticationManager` 遍历所有 `AuthenticationProvider`：
   - 找到支持 `SmsCodeAuthenticationToken` 的Provider
   - 调用 `SmsCodeAuthenticationProvider.authenticate()`

4. `SmsCodeAuthenticationProvider` 执行认证：
   - 调用 `SmsCodeService.validateSmsCode()` 验证验证码
   - 调用 `UserDetailsService.loadUserByUsername()` 获取用户信息
   - 创建已认证的 `SmsCodeAuthenticationToken`

5. 认证成功/失败处理：
   - 成功：调用 `AuthenticationSuccessHandler`
   - 失败：调用 `AuthenticationFailureHandler`

## 关键设计模式

### 1. **策略模式**
- 不同的认证方式（用户名密码、短信验证码）通过不同的 `AuthenticationProvider` 实现
- Spring Security 在运行时选择合适的Provider

### 2. **责任链模式**
- 过滤器链：请求依次经过多个过滤器处理
- AuthenticationProvider链：多个Provider按顺序尝试认证

### 3. **工厂模式**
- `AbstractAuthenticationProcessingFilter` 作为模板，具体的认证方式继承并实现特定逻辑

## 测试使用方法

1. **发送验证码**：
```bash
POST /sms/send
Content-Type: application/x-www-form-urlencoded

mobile=13800138000
```

2. **验证码登录**：
```bash
POST /login/sms
Content-Type: application/x-www-form-urlencoded

mobile=13800138000&smsCode=123456
```

这个实现提供了完整的短信验证码登录功能，包括验证码生成、存储、校验，以及与Spring Security的完美集成。代码结构清晰，易于扩展和维护。





---
Powered by [Claude Exporter](https://www.claudexporter.com)