## spring-authorization-server的配置

```java
//创建Authorization请求的过滤器链,
@Bean
public SecurityFilterChain authorizationServerSecurityFilterChain(HttpSecurity http) throws Exception {
    //OAuth2AuthorizationServerConfigurer的configure()方法中会循环调用一堆的配置器类的configure方法注册一堆过滤器
        //在http.build的时候将这些过滤添加到过滤器链中
	OAuth2AuthorizationServerConfigurer authorizationServerConfigurer =
			OAuth2AuthorizationServerConfigurer.authorizationServer();

	http
        //这段配置spring-authorization-server默认的授权端点,
        // AuthorizationServerSettings.Builder.build()方法配置的默认端点
		.securityMatcher(authorizationServerConfigurer.getEndpointsMatcher())
        //表示所有的端点都必须要被认证，只有这些端点的请求会被拦截,其他的请求不处理
         .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
        .exceptionHandling((exceptions) ->
                        exceptions
                         //按照条件匹配：当认证且请求的方式是Accept: text/html(浏览器网页),则重定向到/login
                         //如果请求路径是/jsonData/**则使用HttpStatusEntryPoint端点处理
                         //就是一种匹配到的条件来,使用那个端点的机制,可以根据请求的来源返回不同的数据格式,
                         // 比如是浏览器过来的请求就重定向到登录页面,是移动端过来的就返回json数据
                        .defaultAuthenticationEntryPointFor(new LoginUrlAuthenticationEntryPoint("/login"),new MediaTypeRequestMatcher(MediaType.TEXT_HTML))
                        .defaultAuthenticationEntryPointFor(new BearerTokenAuthenticationEntryPoint(),new MediaTypeRequestMatcher(MediaType.APPLICATION_JSON))
                        .defaultAuthenticationEntryPointFor(new HttpStatusEntryPoint(HttpStatus.OK),new AntPathRequestMatcher("/jsonData/**"))
                           //如果上面的都没匹配就按照这个处理,这个是兜底的端点
                        .authenticationEntryPoint(...)
        //这些都是对授权服务器的配置,包括使用什么注册客户端的存储方式registeredClientRepository(存内存,还是数据库等)
        //authorizationService处理授权服务,authorizationConsentService如何处理授权确认，authorizationServerSettings：授权服务器的配置设置,各个端点的配置
		.with(authorizationServerConfigurer, (authorizationServer) ->
			authorizationServer
				.registeredClientRepository(registeredClientRepository)	
				.authorizationService(authorizationService)	
				.authorizationConsentService(authorizationConsentService)	
				.authorizationServerSettings(authorizationServerSettings)	
				.tokenGenerator(tokenGenerator)	
				.clientAuthentication(clientAuthentication -> { })	
				.authorizationEndpoint(authorizationEndpoint -> { })	
				.pushedAuthorizationRequestEndpoint(pushedAuthorizationRequestEndpoint -> { })
				.deviceAuthorizationEndpoint(deviceAuthorizationEndpoint -> { })	
				.deviceVerificationEndpoint(deviceVerificationEndpoint -> { })	
				.tokenEndpoint(tokenEndpoint -> { })	
				.tokenIntrospectionEndpoint(tokenIntrospectionEndpoint -> { })	
				.tokenRevocationEndpoint(tokenRevocationEndpoint -> { })	
				.authorizationServerMetadataEndpoint(authorizationServerMetadataEndpoint -> { })	
				.oidc(oidc -> oidc
					.providerConfigurationEndpoint(providerConfigurationEndpoint -> { })	
					.logoutEndpoint(logoutEndpoint -> { })	
					.userInfoEndpoint(userInfoEndpoint -> { })	
					.clientRegistrationEndpoint(clientRegistrationEndpoint -> { })	
				)
		);

	return http.build();
}
```

```yaml
# 通常项目只需要配置registration下的内容(因为必须),其他使用默认即可，除非你要自定义这些内容配置
# 这样的配置仅在没有自定义RegisteredClientRepository时才生效，当你自定义Bean后框架会使用RegisteredClientRepository产生的配置,而yml文件的配置将失效。yml的配置也是在构建RegisteredClientRepository对象优先级低。
@Bean
public RegisteredClientRepository registeredClientRepository(){
RegisteredClient oidcClient = RegisteredClient.withId(UUID.randomUUID().toString())
				.clientId("oidc-client")
				.clientSecret("{noop}secret")
				.clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
				.authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
				.authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)
				.redirectUri("http://127.0.0.1:8080/login/oauth2/code/oidc-client")
				.postLogoutRedirectUri("http://127.0.0.1:8080/")
				.scope(OidcScopes.OPENID)
				.scope(OidcScopes.PROFILE)
				.clientSettings(ClientSettings.builder().requireAuthorizationConsent(true).build())
				.build();
}

spring:
  security:
    oauth2:
      authorizationserver:
        # ✅ 客户端注册（必须）
        registration:
          my-client-id: # 客户端ID（自定义名称）
            client-id: my-client-id
            client-secret: "{noop}my-secret" # 可使用 {noop} 明文，生产建议加密
            client-authentication-methods:
              - client_secret_basic
            authorization-grant-types:
              - authorization_code
              - refresh_token
              - client_credentials
            redirect-uris:
              - http://127.0.0.1:8080/login/oauth2/code/my-client-id
            scopes:
              - openid
              - profile
              - email
              - read
              - write
            require-authorization-consent: true # 是否需要授权确认页面

        # ✅ 客户端配置（可选，配置client管理器行为）
        client:
          require-proof-key: false        # 是否强制使用PKCE
          require-authorization-consent: true # 是否需要用户授权页面（同上，也可在registration中单独设）

        # ✅ Token 相关配置
        token:
          access-token-time-to-live: 30m         # access_token 有效期，默认 5 分钟
          reuse-refresh-tokens: false            # 是否复用 refresh_token
          refresh-token-time-to-live: 2h         # refresh_token 有效期
          id-token-signature-algorithm: RS256    # ID Token 签名算法

        # ✅ 自定义端点路径
        endpoint:
          authorization-endpoint: /oauth2/authorize
          token-endpoint: /oauth2/token
          token-revocation-endpoint: /oauth2/revoke
          token-introspection-endpoint: /oauth2/introspect
          device-authorization-endpoint: /oauth2/device_authorization
          device-verification-endpoint: /oauth2/device_verification
          jwk-set-endpoint: /oauth2/jwks

        # ✅ OIDC 开关（开启 OpenID Connect 支持）
        oidc:
          enabled: true

        # ✅ 自定义 OIDC 的相关端点（可选）
        oidc-endpoint:
          user-info-endpoint: /userinfo
          client-registration-endpoint: /connect/register
          logout-endpoint: /connect/logout

```

