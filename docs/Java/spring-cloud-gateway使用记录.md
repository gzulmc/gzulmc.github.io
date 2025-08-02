```java
请求处理流程：
| 场景                                      | 处理组件                           |
| --------------------------------------- | ------------------------------ |
| Spring Cloud Gateway 匹配 `/api/**` 后转发请求 | `RoutePredicateHandlerMapping` |
| 用 `@RestController` 编写业务接口              | `RequestMappingHandlerMapping` |
| 用函数式 `RouterFunction` 定义路由              | `RouterFunctionMapping`        |
| 请求静态资源、WebSocket、favicon                | `SimpleUrlHandlerMapping`      |


```

```
	@Nullable
	private List<HandlerMapping> handlerMappings;
	@Nullable
	private List<HandlerAdapter> handlerAdapters;
	@Nullable
	private List<HandlerResultHandler> resultHandlers;
```

HandlerMapping:

| 场景                                           |           处理组件           |
| :--------------------------------------------- | :--------------------------: |
| Spring Cloud Gateway 匹配 `/api/**` 后转发请求 | RoutePredicateHandlerMapping |
| 用 @RequestController编写业务接口              | RequestMappingHandlerMapping |
| 用函数式 RouteFunction 定义的路由              |    RouterFunctionMapping     |
| 请求静态资源、WebSocket、favicon               |   SimpleUrlHandlerMapping    |

```yaml
1.gateway中的两种过滤器：全局过滤器GlobalFilter和路由绑定过滤器GatewayFilter
2.WebFlux应用的过滤器：WebFilter和servlet中普通过滤器一样，是与springsecurityfilterchain同级的过滤器
3.WebFilter会在GlobalFilter和GatewayFilter之前执行,无论是否匹配到路由，他的执行和路由无关
4.GlobalFilter和GatewayFilter都是围绕路由执行的过滤器，不同的是GlobalFilter会在GatewayFilter之前执行，且GlobalFilter只需要匹配到至少一个路由后就会被调用,而GatewayFilter是绑定到具体路由的过滤器，只有具体的某一个路由被匹配后这个绑定的gatewayfilter才会被调用。
5.默认的predicates是AND逻辑,即所有的谓词都被匹配后这个路由才会被生效，然后执行具体的动作。当请求匹配到当前路由（即所有 predicates 条件都满足）时，Spring Cloud Gateway 会将这个请求 转发到 https://example.org 这个地址。
6.uri 可以是：
        http://...（普通 HTTP 服务）
        https://...（SSL 服务）
        lb://...（注册中心中的服务名，使用负载均衡）
        forward:/local/path（本地控制器转发）转发到当前服务内部的 Controller（不发出 HTTP 请求）
        ws://localhost:3001 
7.Spring Cloud Gateway 的路由不是“多个路由都可以生效”的概念，而是：
	🧠 "路由是单一匹配模式，匹配成功一个即停止"，按照他们的顺序进行匹配
    gateway:
      server:
        webflux:
          routes:
            - id: after_route
              uri: https://example.org
              predicates:
                # 默认是AND与逻辑
                - After=2017-01-20T17:42:47.789-07:00[America/Denver]
                - Header=X-Request-Id, \d+
                - Host=**.somehost.org,**.anotherhost.org
                # 或逻辑
                - OR=
                    - HOST=**.abc.com
                    - HOST=**.xyz.com
                # 非逻辑
                - NOT=HOST=**.forbidden.com
                - NOT=Method=PUT
```

## 路由定位器：

当 Gateway 启动时，需要“加载所有的路由配置”，比如：

- 配置文件中的 `spring.cloud.gateway.routes`

- 数据库中动态加载的路由

- Nacos、Consul、Apollo 等注册中心

- Java 代码中手动注册的路由

- ```java
  @Component
  public class MyDbRouteDefinitionLocator implements RouteDefinitionLocator {
  
      @Override
      public Flux<RouteDefinition> getRouteDefinitions() {
          // 查询数据库返回 List<RouteDefinition>
          List<RouteDefinition> routes = myRouteService.loadFromDb();
          return Flux.fromIterable(routes);
      }
  }
  
  ```

| 实现类                                  | 来源                                                      | 用途                         |
| --------------------------------------- | --------------------------------------------------------- | ---------------------------- |
| `PropertiesRouteDefinitionLocator`      | `application.yml` 中的 `spring.cloud.gateway.routes` 配置 | 这是你最常用的               |
| `DiscoveryClientRouteDefinitionLocator` | 微服务注册中心（Nacos、Eureka 等）                        | 自动为每个服务创建一条路由   |
| `InMemoryRouteDefinitionRepository`     | 内存中的定义，可动态添加                                  | 通常配合 API 添加/删除路由用 |
| `CompositeRouteDefinitionLocator`       | 组合所有 Locator，返回聚合结果                            | 内部用于合并上述结果         |
| 自定义实现                              | 你可以从数据库或第三方系统动态加载                        | 常见于后台路由动态配置平台   |

```java
启动时：
   所有 RouteDefinitionLocator → getRouteDefinitions()
       ↓
   加载成 RouteDefinition 对象
       ↓
   RouteDefinitionRouteLocator → 转换为 Route（带谓词 + 过滤器）
       ↓
   保存到 InMemory 中，后续请求匹配就靠它了
```

## 动态路由：

| 类                      | 用途                                          |
| ----------------------- | --------------------------------------------- |
| `RouteDefinitionWriter` | 用于写入/修改/删除路由定义                    |
| `RouteLocator`          | 把 RouteDefinition 转换为 Route（真正可用的） |
| `CachingRouteLocator`   | 缓存路由结果，提高性能                        |
| `RefreshRoutesEvent`    | 发布事件，触发 Gateway 重新加载路由           |

### 在日常开发中，**Spring Cloud Gateway** 主要用于作为**API 网关（API Gateway）**，它在微服务架构中扮演“请求入口”的角色，主要用于**请求路由、权限校验、限流、服务熔断、监控、统一处理跨域等功能**。以下是它在实际开发中解决的几个核心问题：

### 🔧 **1. 请求路由和转发**

**最核心的作用**：将外部请求路由到内部对应的微服务上。

- 例如，客户端请求 `https://api.example.com/user/123`，Gateway 会根据配置把它路由到 `user-service` 的对应接口，如 `http://user-service/api/users/123`。
- 支持多种路由方式：基于路径、主机名、Header、Query 参数等。

------

### 🔐 **2. 统一的安全认证与鉴权**

- 在请求进入后端服务前，先经过 Gateway 统一校验，如：
  - **Token 校验**（JWT、OAuth2）；
  - **IP 黑白名单**；
  - **权限控制**（比如与 Spring Security 集成）；
- 一旦认证失败就可以在 Gateway 层拦截并返回，保护后端服务不暴露给非法访问者。

------

### 📈 **3. 限流、防刷、熔断降级**

- **限流**：控制访问频率，防止接口被恶意刷爆。
- **熔断**：某个服务不稳定时，快速失败，防止拖垮系统。
- **降级**：目标服务不可用时返回默认响应，提升用户体验。
- Spring Cloud Gateway 可以通过集成如 Resilience4j、Sentinel 实现这些功能。

------

### 🌍 **4. 统一处理跨域（CORS）**

- Gateway 可统一设置跨域策略，避免每个服务单独配置。

------

### 📊 **5. 日志记录与请求追踪**

- 可统一在 Gateway 层记录访问日志、请求链路信息（TraceId）等；
- 为后续监控、排查、统计提供基础数据。

------

### 🎨 **6. 请求/响应统一处理**

- 统一修改请求头、添加参数；
- 统一修改响应格式、响应头；
- 统一返回结构，比如将所有接口返回封装为 `{ code, msg, data }` 结构。

------

### ☁️ **7. 隐藏微服务细节**

- 客户端只接触 Gateway，不知道后端微服务部署在哪，防止直接访问，提高安全性；
- 便于版本管理，例如 `/api/v1/user` 和 `/api/v2/user` 分别路由到不同版本的服务。

------

## ✅ 总结：Spring Cloud Gateway 的主要作用

| 功能              | 说明                           |
| ----------------- | ------------------------------ |
| 请求路由          | 根据规则将请求转发到具体微服务 |
| 权限认证与校验    | JWT、OAuth2 鉴权               |
| 限流熔断降级      | 提高系统稳定性                 |
| 日志与监控        | 请求日志、链路追踪、指标统计   |
| CORS 统一处理     | 解决浏览器跨域问题             |
| 请求/响应统一改写 | 统一数据结构和参数             |
| 微服务隐藏        | 提高安全性和解耦性             |

### 1.请求的路由和转发

```

```

