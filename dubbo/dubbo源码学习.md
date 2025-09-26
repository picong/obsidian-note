## Dubbo架构简介
![[Pasted image 20241024181356.png]]
![image-20241204152838973](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241204152838973.png)
Dubbo核心架构图中的各个角色：
- **Registry：注册中心**。负责服务地址的注册与查找，服务的Provider和Consumer只在启动时与注册中心交互。注册中心通过长连接感知Provider的存在，在Provider出现宕机的时候，注册中心会立即推送相关事件通知Consumer.
- **Provider：服务提供者。** 在它启动的时候，会向Registry进行注册操作，将自己服务的地址和相关配置信息封装成URL添加到ZooKeeper中。
- **Consumer：服务消费者。** 在它启动的时候，会向Registry进行订阅操作。订阅操作会从ZooKeeper中获取Provider注册的URL，并在ZooKeeper中添加相应的监听器。获取到Provider URL之后，Consumer会根据负载均衡算法从多个Provider中选择一个Provider并与其建立连接，最后发起对Provider的RPC调用。如果Provider URL发生变更，Consumer将会通过之前订阅过程中的注册中心添加的监听器，获取到最新的Provider URL信息，进行相应的调整，比如断开与宕机Provider的连接，并与新的Provider建立连接。Consumer与Provider建立的是长连接，且Consumer会缓存Provider信息，所以一旦连接建立，即使注册中心宕机，也不会影响已运行的Provider和Consumer。
- **Monitor：监控中心。** 用于统计服务的调用次数和调用时间。Provider和Consumer在运行过程中，会在内存中统计调用次数和调用时间，定时每分钟发送一次统计数据到监控中心。监控中心在上面的架构图中并不是必要角色，监控中心宕机不会影响Provider、Consumer以及Registry的功能，只会丢失监控数据而已。

Dubbo 3.x的提供者是接口级注册和应用级注册同时支持。
![image-20241204154405487](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241204154405487.png)
我们可以通过在提供方设置`dubbo.application.register-mode`属性来自由控制，设置得值有3中：
- `interface`：只接口级注册
- `instance`：只应用级注册
- all：接口级注册、应用级注册都会存在，同时也是默认值

消费方通过设置`dubbo.applicaiton.service-discovery.migration`属性来兼容新老订阅方案，设置得值也有3总：
- FORCE_INTERFACE：只订阅消费接口级信息。
- APPLICATION_FIRST：注册中心有应用级注册信息则订阅应用级信息，否则订阅接口级信息，起到智能决策来兼容过渡的方案。
- FORCE_APPLICATION：只订阅应用级信息。
dubbo框架为了尽可能保障与运行，除了有failover故障转移策略，还有许多的容错策略：
![[Pasted image 20241204162509.png]]
![image-20241204162919920](file://C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241204162919920.png?lastModify=1733300980)

![image-20241204162929856](file://C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241204162929856.png?lastModify=1733300980)

![image-20241204162941523](file://C:/Users/cong.pi/AppData/Roaming/Typora/typora-user-images/image-20241204162941523.png?lastModify=1733300980)

### Dubbo核心源码模块
- **dubbo-common模块：** Dubbo的一个公共模块，其中有很多种工具类以及公用逻辑。
![[Pasted image 20241024182733.png]]
- **dubbo-remoting模块：** Dubbo的远程通信，其中的子模块依赖各个开源组件实现远程通信。在dubbo-remoting-api模块中定义该模块的抽象概念，在其他子模块中依赖其他开源组件进行实现，例如,dubboe-remoting-netty4子模块依赖Netty4实现远程通信，dubbot-remoting-zookeeper通过Apache Curator实现与ZooKeeper集群的交互。
- **dubbo-cluster模块：** Dubbo中负责管理集群的模块，提供了负载均衡、容错、路由等一系列集群相关的功能。
- **dubbo-registry模块：** Dubbo中负责与多种开源注册中心进行交互的模块，提供注册中心的能力。
- **dubbo-monitor模块：** Dubbo的监控模块。
- **dubbo-config模块：** Dubbo对外暴露的配置都由该模块进行解析的。
- **dubbo-metadata模块：** Dubbo的元数据。
- **dubbo-configcenter模块：** Dubbo的动态配置模块，主要负责外部化配置以及服务治理规则的存储于通知，提供了多个子模块来接入多种开源的服务发现组件。
## Dubbo配置总线：URL
```shell
```sql
dubbo://172.17.32.91:20880/org.apache.dubbo.demo.DemoService?anyhost=true&application=dubbo-demo-api-provider&dubbo=2.0.2&interface=org.apache.dubbo.demo.DemoService&methods=sayHello,sayHelloAsync&pid=32508&release=&side=provider&timestamp=1593253404714dubbo://172.17.32.91:20880/org.apache.dubbo.demo.DemoService?anyhost=true&application=dubbo-demo-api-provider&dubbo=2.0.2&interface=org.apache.dubbo.demo.DemoService&methods=sayHello,sayHelloAsync&pid=32508&release=&side=provider&timestamp=1593253404714
```
这个URL的各个部分：
- **protocol：** dubbo协议。
- **username/password：** 没有用户名和密码。
- **host/port**：172.17.32.91:20880
- **path**：org.apache.dubbo.demo.DemoService
- **parameters**：参数键值对，这里是问号后面的参数
在dubbo-common包中还提供了URL的辅助类：
- **URLBuilder，辅助构造URL**
- **URLStrParser，将字符串解析成URL**
### 1. URL在SPI中的应用
Dubbo SPI中有一个依赖URL的重要场景---适配器方法，是被@Adaptive注解标注的，URL一个很重要的作用是与@Adaptive注解一起选择合适的扩展实现类。
例如，在dubbo-registry-api模块中我们可以看到RegistryFactory这个接口，其中的getRegistry()方法上有@Adaptive({"protocol"})注解，说明这是一个适配器方法，Dubbo在运行时会为其动态生成相应的"$Adaptive"类型：
```java
public class RegistryFactory$Adaptive

              implements RegistryFactory { 

    public Registry getRegistry(org.apache.dubbo.common.URL arg0) { 

        if (arg0 == null) throw new IllegalArgumentException("..."); 

        org.apache.dubbo.common.URL url = arg0; 

        // 尝试获取URL的Protocol，如果Protocol为空，则使用默认值"dubbo" 

        String extName = (url.getProtocol() == null ? "dubbo" : 

             url.getProtocol()); 

        if (extName == null) 

            throw new IllegalStateException("..."); 

        // 根据扩展名选择相应的扩展实现，Dubbo SPI的核心原理在下一课时深入分析 

        RegistryFactory extension = (RegistryFactory) ExtensionLoader 

          .getExtensionLoader(RegistryFactory.class) 

                .getExtension(extName); 

        return extension.getRegistry(arg0); 

    } 

}
```
![[Pasted image 20241025110157.png]]
此次使用的Registry扩展实现类就是`ZookeeperRegistryFactory`。
### 2. URL在服务暴露中的引用
Provider在启动时会将自身暴露的服务注册到Zookeeper上，具体是通过`ZookeeperRegistry.doRegister()`方法进行注册的：
![[Pasted image 20241025110446.png]]
### 3. URL在服务订阅中的应用
在`ZookeeperRegistry#doSubsrive`方法中实现订阅的功能。
![[Pasted image 20241025110750.png]]
通过URL中的上述参数，ZookeeperRegistry会在toCategoriesPath()方法中奖其整理成一个Zookepper路径，然后调用zkClient在其上添加监听。

## Dubbo SPI 精析
### 1. JDK SPI机制
当服务的提供者提供了一种接口的实现之后，需要在Classpath下的META-INF/services/目录里创建一个以服务接口命名的文件，此文件记录了该jar包提供的服务接口的具体实现类。当某个应用引入了该jar包且需要使用该服务时，JDK SPI机制就可以通过查找这个jar包的META/INF/services/中的配置文件来获得具体的实现类名，进行实现类的加载和实例化，最终使用该实现类完成业务功能。
### 2. JDK SPI源码分析
JDK SPI的入口方法是ServiceLoader.load()方法，ServiceLoader.load()方法中，首先会尝试获取当前使用的ClassLoader(获取当前线程绑定的ClassLoader，查找失败后使用SystemClassLoader)，然后调用reload方法：
![[Pasted image 20241025172735.png]]
以下为reload方法源码：
```java
// 缓存，用来缓存 ServiceLoader创建的实现对象 
private LinkedHashMap<String,S> providers = new LinkedHashMap<>(); 
public void reload() {
	providers.clear(); // 清空缓存 
	lookupIterator = new LazyIterator(service, loader); // 迭代器 
}
```
真正去`META/INF/services`目录下面遍历扩展实现的代码在`LazyIterator`里面。
### Dubbo SPI
- **扩展点**：通过SPI机制查找并加载实现的接口。例如：JDBC中的`java.sql.Driver`接口。
- **扩展点实现**: 实现了扩展接口的实现类。例如：mysql驱动中的`com.mysql.cj.jdbc.Driver`。
**Dubbo SPI 不仅解决了上述资源浪费的问题，还对SPI配置文件进行了扩展和修改。**
首先，Dubbo按照SPI配置文件的用途，将其分成了三类目录。
- META-INF/services/ 目录：该目录下的 SPI 配置文件用来兼容 JDK SPI 。
- META-INF/dubbo/ 目录：该目录用于存放用户自定义 SPI 配置文件。
- META-INF/dubbo/internal/ 目录：该目录用于存放 Dubbo 内部使用的 SPI 配置文件。
然后，Dubbo将SPI配置文件改成了KV格式，例如：
```shell
dubbo=org.apache.dubbo.rpc.protocol.dubbo.DubboProtocol
```
### Spring 中SPI
Spring中的SPI相比于JDK原生的SPI，功能也很强大，主要是通过`org.springframework.core.io.support.SpringFactoriesLoader#loadFactories`方法读取所有jar包的`META-INF/spring.factories`资源文件，并从文件中读取一堆的类似`EnableAutoConfiguration`标识的类路径，将这些类创建对应的Spring Bean对象注入到容器中，就完成了SpringBoot的自动装配底层核心原理。

**使用步骤:**
- 首先，定义一个类，该类可加Spring的相关注解，也可以不加，完全看时机业务诉求。
- 然后，将该类的类路径添加到`META-INF/spring.factories`文件中，举个样例如下：
```yaml
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
com.hmilyylimh.cloud.HmilyRegistryAutoConfiguration
```
spring.factories除了可以`EnableAutoConfiguration`类型的类之外，还可以处理一些其他类型的类，如下所示：
1. `ApplicationContextInitializer`
2. `ApplicationListener`
3. `AutoConfigurationImportListener`
4. `AutoConfigurationImportFilter`
5. `EnableAutoConfiguration`
6. `FailureAnalyzer`
7. `TemplateAvailabilityProvider`

### 1. @SPI注解
Dubbo中某个接口被@SPI注解修饰时，就表示该接口是扩展接口，例如`org.apache.dubbo.rpc.Protocol`就是一个扩展接口：
`ExtensionLoader`位于dubbo-common模块中的extension包中，功能类似JDK SPI中的`java.util.ServiceLoader`。
```java
Protocol protocol = ExtensionLoader.getExtensionLoader(Protocol.class).getExtension("dubbo");
```
这里首先来了解一下 ExtensionLoader 中三个核心的静态字段。

- **strategies（LoadingStrategy[]类型）:** LoadingStrategy 接口有三个实现（通过 JDK SPI 方式加载的），如下图所示，分别对应前面介绍的三个 Dubbo SPI 配置文件所在的目录，且都继承了 Prioritized 这个优先级接口，默认优先级是

```shell
 DubboInternalLoadingStrategy > DubboLoadingStrategy > ServicesLoadingStrateg
```

![Drawing 2.png](https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/Dubbo%e6%ba%90%e7%a0%81%e8%a7%a3%e8%af%bb%e4%b8%8e%e5%ae%9e%e6%88%98-%e5%ae%8c/assets/Ciqc1F8s95mANXYKAADUVwBlgxs297.png)

- **EXTENSION_LOADERS（ConcurrentMap类型）** ：Dubbo 中一个扩展接口对应一个 ExtensionLoader 实例，该集合缓存了全部 ExtensionLoader 实例，其中的 Key 为扩展接口，Value 为加载其扩展实现的 ExtensionLoader 实例。
- **EXTENSION_INSTANCES（ConcurrentMap, Object>类型）**：该集合缓存了扩展实现类与其实例对象的映射关系。在前文示例中，Key 为 Class，Value 为 DubboProtocol 对象。

下面我们再来关注一下 ExtensionLoader 的实例字段。

- **type（`Class<?>`类型）** ：当前 ExtensionLoader 实例负责加载扩展接口。
- **cachedDefaultName（String类型）**：记录了 type 这个扩展接口上 @SPI 注解的 value 值，也就是默认扩展名。
- **cachedNames（ConcurrentMap, String>类型）**：缓存了该 ExtensionLoader 加载的扩展实现类与扩展名之间的映射关系。
- **cachedClasses（Holder>>类型）**：缓存了该 ExtensionLoader 加载的扩展名与扩展实现类之间的映射关系。cachedNames 集合的反向关系缓存。
- **cachedInstances（ConcurrentMap>类型）**：缓存了该 ExtensionLoader 加载的扩展名与扩展实现对象之间的映射关系。

在`ExtensionLoader#createExtensin`方法中完成了SPI配置文件的查找以及相应扩展实现类的实例化，同时还实现了自动装配以及自动Wrapper包装等功能。其核心流程是这样的：
1. 根据扩展名从cachedClasses中获取扩展类实现。如果未初始化，则扫描前面三个spi的目录获取相应SPI配置文件，进行加载。
2. 根据扩展实现类从EXTENSION_INSTANCES缓存中查找相应的实力。如果查找失败，会通过反射创建扩展实现对象。
3. **自动装配** 扩展实现对象中的属性(即调用其setter)。
4. **自动包装** 扩展实现对象。
5. 如果扩展实现类实现了Lifecycle接口，在initExtension方法中会调用initialize方法进行初始化。
```java
private T createExtension(String name) { 

    Class<?> clazz = getExtensionClasses().get(name); // --- 1 

    if (clazz == null) { 

        throw findException(name); 

    } 

    try { 

        T instance = (T) EXTENSION_INSTANCES.get(clazz); // --- 2.

        if (instance == null) { 

            EXTENSION_INSTANCES.putIfAbsent(clazz, clazz.newInstance()); 

            instance = (T) EXTENSION_INSTANCES.get(clazz); 

        } 

        injectExtension(instance); // --- 3 

        Set<Class<?>> wrapperClasses = cachedWrapperClasses; // --- 4 

        if (CollectionUtils.isNotEmpty(wrapperClasses)) { 

            for (Class<?> wrapperClass : wrapperClasses) { 

                instance = injectExtension((T) wrapperClass.getConstructor(type).newInstance(instance)); 

            } 

        } 

        initExtension(instance); // ---5

        return instance; 

    } catch (Throwable t) { 

        throw new IllegalStateException("Extension instance (name: " + name + ", class: " + 

                type + ") couldn't be instantiated: " + t.getMessage(), t); 

    } 

}

```
### 2. @Adaptive注解与适配器
`@Adaptive`注解用来实现dubbo的适配器功能，如下图所示，ExtensionFactory接口上有@SPI注解，AdaptiveExtensinFactory实现类上有@Adaptive注解。
![[Pasted image 20241025180826.png]]
AdaptiveExtensionFactory 不实现任何具体的功能，而是用来适配 ExtensionFactory 的 SpiExtensionFactory 和 SpringExtensionFactory 这两种实现。AdaptiveExtensionFactory 会根据运行时的一些状态来选择具体调用 ExtensionFactory 的哪个实现。

@Adaptive 注解还可以加到接口方法之上，Dubbo 会动态生成适配器类。例如，Transporter接口有两个被 @Adaptive 注解修饰的方法：
```java
@SPI("netty") 

public interface Transporter { 

    @Adaptive({Constants.SERVER_KEY, Constants.TRANSPORTER_KEY}) 

    RemotingServer bind(URL url, ChannelHandler handler) throws RemotingException; 

    @Adaptive({Constants.CLIENT_KEY, Constants.TRANSPORTER_KEY}) 

    Client connect(URL url, ChannelHandler handler) throws RemotingException; 
}
```
Dubbo 会生成一个 Transporter$Adaptive 适配器类，该类继承了 Transporter 接口。

我们可以通过 ExtensionLoader.getAdaptiveExtension() 方法获取适配器实例，并将该实例缓存到 cachedAdaptiveInstance 字段（Holder类型）中，核心流程如下：

- 首先，检查 cachedAdaptiveInstance 字段中是否已缓存了适配器实例，如果已缓存，则直接返回该实例即可。
- 然后，调用 getExtensionClasses() 方法，其中就会触发前文介绍的 loadClass() 方法，完成 cachedAdaptiveClass 字段的填充。
- 如果存在 @Adaptive 注解修饰的扩展实现类，该类就是适配器类，通过 newInstance() 将其实例化即可。如果不存在 @Adaptive 注解修饰的扩展实现类，就需要通过 createAdaptiveExtensionClass() 方法扫描扩展接口中方法上的 @Adaptive 注解，动态生成适配器类，然后实例化。
- 接下来，调用 injectExtension() 方法进行自动装配，就能得到一个完整的适配器实例。
- 最后，将适配器实例缓存到 cachedAdaptiveInstance 字段，然后返回适配器实例。
### 3. 自适应包装特性
Dubbo中的一个扩展接口可能有多个扩展类，这些扩展类可能会包含一些相同的逻辑，Dubbo提供的自动包装特性，Dubbo将多个扩展实现类的公共累计，抽象到Wrapper类中，Wrapper类与普通扩展实现类一样，也实现了扩展皆苦，在获取真正的扩展实现对象时，在其外面包装一层Wrapper对象，可以理解为一层装饰器。
### 4. 自动装配
在createExtension方法中我们看到，Dubbo SPI在拿到扩展实现类的对象以及Wapper对象之后，还会调用injectExtension方法扫描其全部setter方法，并根据setter方法的名称以及参数的类型，加载相应的扩展实现，然后调用相应的setter方法填充属性。
### 5. @Activate注解与自动激活特性
这里以Dubbo中的Filter为例说明自动激活特性的含义，`org.apache.dubbo.rpc.Filter`接口有非常多的扩展实现类，在一个场景中可能需要某几个Filter扩展实现类协同工作，而另一个场景中可能需要另外几个实现类一起工作。这种场景就需要使用@Activate注解来进行分别激活。
Activate 注解标注在扩展实现类上，有 group、value 以及 order 三个属性。
- group 属性：修饰的实现类是在 Provider 端被激活还是在 Consumer 端被激活。
- value 属性：修饰的实现类只在 URL 参数中出现指定的 key 时才会被激活。
- order 属性：用来确定扩展实现类的排序。

### transport相关实现
正如前文介绍Netty线程模型的时候提到，我们不能在Netty的I/O线程中执行耗时的业务逻辑。在Demo RPC框架的Server端接收到请求时，首先会通过上面介绍的DemoRpcDecoder反序列化得到请求消息，之后我们会通过一个自定义的ChannelHandler将响应返回给DemoRpcDecoder反序列化得到响应消息，之后通过一个自定义的ChannelHandler将响应返回给上层业务。

- 首先，Dubbo注册中心以应用粒度聚合实例数据，消费者按消费需求精准订阅，避免了大多数开源框架如Istio、Spring Cloud等全量订阅带来的性能瓶颈。
- 其次，Dubbo SDK在实现上对消费端地址列表处理过程做了大量优化，地址通知增加异步、缓存、bitmap等多种解析优化，避免了地址更新常出现的消费端进程资源波动。
- 最后，在功能丰富度和易用性上，服务发现除了同步ip、port等端点基本信息到消费者外，Dubbo还将服务端的RPC/HTTP服务及其配置的元数据信息同步到消费端，这让消费者、提供者两端的更细粒度的协作成为可能，Dubbo基于此机制提供了很多差异化的治理能力。

## Dubbo异步化实践
开启异步化的核心步骤：
1. 定义线程池对象，通过RpcContext.startAsync方法开启异步模式；
2. 在异步线程中通过asyncContext.signalContextSwitch同步父线程的上下文信息；
3. 在异步线程中将异步结果通过asyncContext.write写入到异步线程的上下文信息中。

```java
@DubboService
@Component
public class AsyncOrderFacadeImpl implements AsyncOrderFacade {

    private final ExecutorService cachedThreadPool = Executors.newCachedThreadPool();
    @Override
    public OrderInfo queryOrderById(String id) {
        // 创建线程池对象

        // 开启异步化操作模式，标识异步化模式开始
        AsyncContext asyncContext = RpcContext.startAsync();

        // 利用线程池来处理 queryOrderById 的核心业务逻辑
        cachedThreadPool.execute(new Runnable() {
            @Override
            public void run() {
                // 将 queryOrderById 所在线程的上下文信息同步到该子线程中
                asyncContext.signalContextSwitch();

                // 这里模拟执行一段耗时的业务逻辑
                sleepInner(5000);
                OrderInfo resultInfo = new OrderInfo(
                        "GeekDubbo",
                        "服务方异步方式之RpcContext.startAsync#" + id,
                        new BigDecimal(129));
                System.out.println(resultInfo);

                // 利用 asyncContext 将 resultInfo 返回回去
                asyncContext.write(resultInfo);
            }
        });
        return null;
    }
}
```
### Dubbo异步实现原理
1. startAsync方法最终通过CAS原子性的方式创建了一个`java.util.concurrent.CompletableFuture`对象，这个对象就存储在当前的上下文`org.apache.dubbo.rpc.RpcContextAttachment`对象中。
![image-20241204171058957](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241204171058957.png)

2. 通过asyncContext.signalContextSwitch同步不同线程间的信息，也就是信息的拷贝，只不过这个拷贝需要利用到一步模式开启之后的返回对象asyncContext。因为asyncContext富含上下文信息，**只需要把这个所谓的asyncContext对象传入到子线程中，然后将asyncContext中的上下文信息充分拷贝到子线程中，** 这样，子线程处理所需要的任何信息就不会因为开启了异步化处理而确实。
![[Pasted image 20241204171924.png]]

3. 最后第三步就是在异步线程中，将异步结果写入到异步线程的上线文信息中：
```java
// org.apache.dubbo.rpc.AsyncContextImpl#write
public void write(Object value) {
    if (isAsyncStarted() && stop()) {
        if (value instanceof Throwable) {
            Throwable bizExe = (Throwable) value;
            future.completeExceptionally(bizExe);
        } else {
            future.complete(value);
        }
    } else {
        throw new IllegalStateException("The async response has probably been wrote back by another thread, or the asyncContext has been closed.");
    }
}
```

## 通过自定义过滤器隐式传参的步骤：
- 首先，创建一个自定义的类，并实现 org.apache.dubbo.rpc.Filter 接口；

- 其次，在自定义类上通过 @Activate 注解标识是提供方维度的过滤器，还是消费方维度的过滤器；

- 然后，在自定义类中的 invoke 方法中实现传递逻辑，提供方过滤器从 invocation 取出 traceId 并设置到 ClientAttachment、MDC 中，消费方过滤器从 ClientAttachment 取出 traceId 并设置到 invocation 中；

- 最后，将自定义的类路径添加到 META-INF/dubbo/org.apache.dubbo.rpc.Filter 文件中，并取个别名。
在Dubbo3中，RpcContext被拆分为四大模块(ServerContext、ClientAttachment、ServerAttachment和ServiceContext)。
它们分别承担了不同的职责：
- ServiceContext：在Dubbo内部使用，用于传递调用连路上的参数信息，如invoker对象等。
- ClientAttachment：在Client端使用，往ClientAttachment中写入的参数将被传递到Server端
- ServerAttachment：在Server端使用，从ServerAttachment中读取的参数是从Client中传递过来的
- ServerContext：在Client端和Server端使用，用于从Server端回传参数给Client端，Server端写入的ServerContext的参数在调用结束后可以在Client端的ServerContext中获取到。
### 泛化调用三部曲：
- 接口类名、接口方法名、接口参数类名、业务请求参数，四个维度的数据不能少。
- 根据接口类名创建ReferenceConfig对象，设置generic = true属性，调用referenceConfig.get拿到genericeService泛化对象。
- 传入接口方法名、接口方法参数类名、业务请求参数，调用genericeService.$invoke方法拿到响应对象，并通过Ognl表达式语言判断响应成功或失败，然后完成数据最终返回。
```java
@RestController
public class CommonController {
    // 响应码为成功时的值
    public static final String SUCC = "000000";

    // 定义URL地址
    @PostMapping("/gateway/{className}/{mtdName}/{parameterTypeName}/request")
    public String commonRequest(@PathVariable String className,
                                @PathVariable String mtdName,
                                @PathVariable String parameterTypeName,
                                @RequestBody String reqBody){
        // 将入参的req转为下游方法的入参对象，并发起远程调用
        return commonInvoke(className, parameterTypeName, mtdName, reqBody);
    }

    /**
     * <h2>模拟公共的远程调用方法.</h2>
     *
     * @param className：下游的接口归属方法的全类名。
     * @param mtdName：下游接口的方法名。
     * @param parameterTypeName：下游接口的方法入参的全类名。
     * @param reqParamsStr：需要请求到下游的数据。
     * @return 直接返回下游的整个对象。
     * @throws InvocationTargetException
     * @throws IllegalAccessException
     */
    public static String commonInvoke(String className,
                                      String mtdName,
                                      String parameterTypeName,
                                      String reqParamsStr) {
        // 然后试图通过类信息对象想办法获取到该类对应的实例对象
        ReferenceConfig<GenericService> referenceConfig = createReferenceConfig(className);

        // 远程调用
        GenericService genericService = referenceConfig.get();
        Object resp = genericService.$invoke(
                mtdName,
                new String[]{parameterTypeName},
                new Object[]{JSON.parseObject(reqParamsStr, Map.class)});

        // 判断响应对象的响应码，不是成功的话，则组装失败响应
        if(!SUCC.equals(OgnlUtils.getValue(resp, "respCode"))){
            return RespUtils.fail(resp);
        }

        // 如果响应码为成功的话，则组装成功响应
        return RespUtils.ok(resp);
    }

    private static ReferenceConfig<GenericService> createReferenceConfig(String className) {
        DubboBootstrap dubboBootstrap = DubboBootstrap.getInstance();

        // 设置应用服务名称
        ApplicationConfig applicationConfig = new ApplicationConfig();
        applicationConfig.setName(dubboBootstrap.getApplicationModel().getApplicationName());

        // 设置注册中心的地址
        String address = dubboBootstrap.getConfigManager().getRegistries().iterator().next().getAddress();
        RegistryConfig registryConfig = new RegistryConfig(address);
        ReferenceConfig<GenericService> referenceConfig = new ReferenceConfig<>();
        referenceConfig.setApplication(applicationConfig);
        referenceConfig.setRegistry(registryConfig);
        referenceConfig.setInterface(className);

        // 设置泛化调用形式
        referenceConfig.setGeneric("true");
        // 设置默认超时时间5秒
        referenceConfig.setTimeout(5 * 1000);
        return referenceConfig;
    }
}
```
### 点点直连
这里总结一下通过直连进行泛化调用的三部曲：

- 接口类名、接口方法名、接口方法参数类名、业务请求参数，四个维度的数据不能少。
- 根据接口类名创建 ReferenceConfig 对象，设置 generic = true 、url =协议+IP+PORT 两个重要属性，调用 referenceConfig.get 拿到 genericService 泛化对象。
- 传入接口方法名、接口方法参数类名、业务请求参数，调用genericService.$invoke 方法拿到响应对象，并通过 Ognl 表达式语言判断响应成功或失败，然后完成数据最终返回。

最后总结一下Groovy+Spring完成动态编译调用的三部曲：

- 首先，将Java代码利用Groovy插件的groovyClassLoader加载器编译为Class对象。
- 其次，将Class信息创建Bean定义对象后，移交给Spring容器去创建单例Bean对象。
- 最后，调用单例Bean对象的run方法，完成动态代码调用。
![[Pasted image 20241205145141.png]]
点点直连，在进行泛化调用的时候可以通过ReferenceConfig#setUrl()设置提供方所在的机器。

## Dubbo调用 超时时间的计算规则
在DubboInvoker#calculateTimeout方法中获取超时时间。该方法的流程整体分为三大块，**先取方法级别的参数，再取服务级别的参数，最后取实例级别的参数；** 在每一块的内部**按照先取 消费方，再取提供房的顺序读取参数。**
不管是在消费方，还是在提供方，各自都按照下图所示的层级覆盖关系，然后在calculateTimeout方法中就能从消费方、提供方取到精准的超时时间。
![[Pasted image 20241125110539.png]]
主要有四个层级关系：
System Properties，最高优先级，我们一般会在启动命令中通过JVM的-D参数进行指定，图中通过-D参数从指定的磁盘路径加载配置，也可以从公共的NAS路径加载配置。
Externalized Configuration，优先级次之，外部化配置，我们可以直接从统一的配置中心加载配置，上图中就是从Nacos配置中心加载配置。
API / XML / 注解，优先级再次降低。
Local File，优先级最低，一般是项目中默认的一份基础配置，当什么都不配置的时候会读取。

## Dubbo十层模块的作用
![[Pasted image 20241126214551.png]]
- **Service**：服务层，泛指应用系统中提供的Dubbo接口服务的代码层，或向dubbo接口发起调用的代码层。
- **Config**：配置层，主要围绕ServiceConfig和ReferenceConfig展开的配置读与写的处理，既可以通过代码直接初始化配置，也可以通过Spring解析生成配置。
- **Proxy**：服务代理层，将各种发起远程调用的接口包装为代理对象实现统一的远程调用。
- **Registry**：注册中心层，封装服务地址的注册与发现，来做到动态感知服务的上下线，以此提供一份准实时的最新地址注册列表。
- **Cluster**：路由层，持有注册中心提供的多个提供者，并进行路由过滤和负载均衡。
- **Monitor**：监控层，RPC远程调用次数和调用时间的监控，来较实时的感知各接口的调用健康状态。
- **Protocol**：远程调用层，封装一次RPC的调用细节，让上层感觉调用远程是一件很简单的事。
- **Exchange**：信息交换层，将上层发送的业务对象转换为统一的Request、Response对象，并且屏蔽掉了因同步异步模式带来额转换困难的差异。
- **Transport**：网络传输层，负责与网络打交道，让上层放心的把Request、Response对象交给该层进行远程发送。
- **Serialize**：数据序列化层，将统一的Request、Response对象最终转成物理层能识别的二进制数据。

## Wrapper机制
### 生成代理类的流程
![[Pasted image 20241127170547.png]]
生成代理类的流程总结起来有3点：
1. 以源对象的类属性为维度，与生成的代理类建立缓存映射关系，避免频繁创建代理类影响性能。
2. 生成一个继承Wrapper的动态类，并且暴露了一个公有invokeMethod方法来调用源对象的方法。
3. 在invokeMethod方法中，通过生成if...else逻辑代码来识别调用源对象的不同方法。
### Compiler编译方式的适用场景
- **JavaCompiler**: 是JDK提供的一个工具包，我们熟知的Javac编译器其实就是JavaCompiler的实现，不过JDK的版本迭代速度快，变化大，我们升级JDK的时候，本来在低版本JDK能正常编译的功能，跑到高版本就失效了。
- **Groovy**: 属于第三方插件，功能很多很强大，几乎是开发小白的首选框架，不需要考虑过多API和字节码指令，会构建源代码字符串，交给Groovy插件后就能拿到类信息，拿起来就可以直接使用，单同时也是比较重量级的插件。
- **Javassist**: 封装了各种API来创建类，相对于稍微偏底层的风格，可以动态针对已有类的字节码，调用相关的API直接增删改查，非常灵活，只要熟练使用API就可以达到很高的境界。
- **ASM**: 是一个通用的字节码操作的框架，属于非常底层的插件了，操作该插件的技术难度相当高，需要对字节码指令有一定的了解，但它体现出来的性能却是最高的，并且插件本身就是定位为一款轻量级的高性能字节码插件。
如果需要开发一些底层插件，可以使用Javassist或者ASM。使用Javassist是因为用API简单而且方便后人维护，使用ASM是在一些高度频繁调用的场景出于对性能的极致追求。如果开发应用系统的业务功能，对性能没有太强的追求，而且便于加载和卸载，推荐使用Groovy的插件。
### 使用Javassist编译的三大基本步骤
- 首先，设计一个代码模板
- 然后，使用Javassist的相关API，通过`ClassPool.makeClass`得到一个操控类`CtClass`对象，然后针对`CtClass`进行`addField`添加字段、`addMethod`添加方法、`addConstructor`添加构造方法等等。
- 最后，调用`CtClass.toClass`方法并编译得到一个类信息，有了类信息，就可以实例化对象处理业务逻辑了。
### 使用ASM的四大基本步骤
- 首先，还是设计一个代码模板。
- 其次，通过IDEA的协助得到代码模板的字节码指令内容。
- 然后，使用Asm的相关API依次将字节码指令翻译为Asm对应的语法，比如创建`ClassWriter`相当于创建了一个类，继续调用`ClassWriter.visitMethod`方法相当于创建了一个方法等等，对于生僻的字节码指令是在找不到对应的官方文档的话，可以通过`MethodVistor + 字节码`来快速查找对应的Asm API。
- 最后，调用`ClassWriter.toByteArray`得到字节码的字节数组，传递到`ClassLoader.defineClass`交给JVM虚拟机得出一个Class类信息。
## Adaptive适配
通过阅读ExtensionLoader#getAdaptiveExtension方法的源码，紧抓主干，直接找没有缓存的逻辑，最后得出@Adaptive注解其实是生成了一个自适应的代理类，每个SPI接口都有且仅有一个自适应扩展点。
然后阅读了加载SPI资源文件的loadDirectory方法的源码，发现@Adaptive注解不仅可以写在SPI接口的方法上，还可以写在SPI接口实现类上，并且在使用自适应扩展的时候，若实现类有@Adaptive注解，则优先使用该实现类作为自适应扩展点。

### 自定义接口使用@Adaptive注解的步骤
- 首先，定义一个SPI接口。
- 然后，为SPI接口中的某个方法添加@Adaptive注解，同时，关注该方法入参中是否与URL参数，若想使某个SPI接口的实现类称为自适应扩展点，直接在这个实现类上添加@Adaptive注解即可。
- 最后，在`META-INF/dubbo`目录中，添加实现类的类路径，key为扩展名，文件名为接口全限定名。
## Dubbo实例注入
从学过的获取自适应扩展点实例开始，反思既然有特殊的实例化操作，想必也有普通的实例化操作，为后续的源码反向跟踪撕开了一道口子，找到了createExtension创建普通扩展点的核心源码。
总结下例注入的5个关键结论：
- 每个合法的扩展点名称都会对应一个Class类信息，并且都是以线程安全的形式创建了一个与之对应的实例对象。
- 通过反射创建出来的原始实例类对象，最终都会经过初始化前置处理、实例注入、初始化后置处理，再叠加层层包装套娃处理后，变成了一个有血有肉的复杂对象。
- 实现类可以设置@Wrapper注解，注解中的order属性值越小则越先执行，mismatches属性值包含入参给定的扩展点名称时，那么该扩展点的方法不会触发执行。
- 通过setter方式可以进行实例注入，通过构造方法且构造方法入参是SPI接口，可以将实现类变成包装类，而且包装类能提供轻量级的切面编程的能力。
- 资源目录中的SPI文件内容，包装类不需要设置别名，就可以被Dubbo框架只能识别为包装类。
![[Pasted image 20241129115505.png]]
## Provider发布流程
发布的大致流程就3个环节: **配置 -> 导出 -> 注册**。
### 配置流程
![[Pasted image 20241129184249.png]]
### 导出流程
```java
// 单个接口服务的导出方法，比如 DemoFacadeImpl 服务的导出，就会进入到这里来
org.apache.dubbo.config.ServiceConfig#doExport
                  ↓
// 因为存在多协议的缘故，所以这里就会将单个接口服务按照不同的协议进行导出
org.apache.dubbo.config.ServiceConfig#doExportUrls
                  ↓
// 将单个接口服务按照单个协议进行导出
// 其实是 doExportUrls 方法中循环调用了 doExportUrlsFor1Protocol 方法
org.apache.dubbo.config.ServiceConfig#doExportUrlsFor1Protocol
                  ↓
// 将单个接口服务按照单协议导出到多个注册中心上
org.apache.dubbo.config.ServiceConfig#exportUrl
// exportUrl 方法的实现体逻辑如下：
private void exportUrl(URL url, List<URL> registryURLs) {
    String scope = url.getParameter("scope");
    // don't export when none is configured
    if (!"none".equalsIgnoreCase(scope)) {
        // export to local if the config is not remote (export to remote only when config is remote)
        if (!"remote".equalsIgnoreCase(scope)) {
            // 本地导出
            exportLocal(url);
        }
        // export to remote if the config is not local (export to local only when config is local)
        if (!"local".equalsIgnoreCase(scope)) {
            // 远程导出
            url = exportRemote(url, registryURLs);
            if (!isGeneric(generic) && !getScopeModel().isInternal()) {
                MetadataUtils.publishServiceDefinition(url, providerModel.getServiceModel(), getApplicationModel());
            }
        }
    }
    this.urls.add(url);
}
```
- procolSPI.export
![[Pasted image 20241129184605.png]]
- exportRemote远程导出
![[Pasted image 20241129184648.png]]
启动netty服务：
![[Pasted image 20241129184748.png]]
注册：往注册中心写入服务接口信息
![[Pasted image 20241129184914.png]]
## 小结
![[Pasted image 20241129185104.png]]
看源码的12字方针：**不沾细节：只看流程；不看过程：只看结论；再看细节：再看过程。**
## 订阅流程
通过查看@DubboReference的引用代码，得知泛化调用需要通过ReferenceConfig的get方法来活动代理引用。
ReferenceConfig的get方法中，以线程安全的方式来创建ref引用对象；ReferenceConfig的init方法中，除了构建引用服务所需的参数，还有个创建代理(createProxy)的方法，并且将创建代理方法的返回值赋值给了ref对象。
创建代理的内部逻辑中，有条件地进行本地引用(createInvokerForLocal)和远程引用(createInovkerForRemote)，并将引用之后的结果invoker对象再次包装为代理对象，以供消费方调用远程使用。

![image-20241212104126114](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241212104126114.png)

![image-20241202140913121](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241202140913121.png)

结果发现 NettyClient 中有个 doConnect 方法，见名知意，这大概率就是连接服务端的核心方法，于是我们就在消费方 NettyClient 这里打个断点，先启动提供方，再 Debug 启动消费方，静静等候断点的到来：
![image-20241202112050548](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241202112050548.png)
![image-20241202112122242](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241202112122242.png)

![image-20241202113334330](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241202113334330.png)

## 事件通知
Dubbo框架中设置事件通知的简单三部曲：
- 首先，创建一个服务类，在该类中添加onInvoke、onReturn、onThrow三个方法。
- 其次，在三个方法中按照源码FutureFilter的规则定义好方法入参。
- 最后，@DubboReference注解中或者dubbo:reference/标签中给需要关注时间的Dubbo的方法添加配置即可。
```java
@DubboService
@Component
public class PayFacadeImpl implements PayFacade {
    @Autowired
    @DubboReference(
            /** 为 DemoRemoteFacade 的 sayHello 方法设置事件通知机制 **/
            methods = {@Method(
                    name = "sayHello",
                    oninvoke = "eventNotifyService.onInvoke",
                    onreturn = "eventNotifyService.onReturn",
                    onthrow = "eventNotifyService.onThrow")}
    )
    private DemoRemoteFacade demoRemoteFacade;

    // 商品支付功能：一个大方法
    @Override
    public PayResp recvPay(PayReq req){
        // 支付核心业务逻辑处理
        method1();
        // 返回支付结果
        return buildSuccResp();
    }
    private void method1() {
        // 省略其他一些支付核心业务逻辑处理代码
        demoRemoteFacade.sayHello(buildSayHelloReq());
    }
}

// 专门为 demoRemoteFacade.sayHello 该Dubbo接口准备的事件通知处理类
@Component("eventNotifyService")
public class EventNotifyServiceImpl implements EventNotifyService {
    // 调用之前
    @Override
    public void onInvoke(String name) {
        System.out.println("[事件通知][调用之前] onInvoke 执行.");
    }
    // 调用之后
    @Override
    public void onReturn(String result, String name) {
        System.out.println("[事件通知][调用之后] onReturn 执行.");
        // 埋点已支付的商品信息
        method2();
        // 发送支付成功短信给用户
        method3();
        // 通知物流派件
        method4();
    }
    // 调用异常
    @Override
    public void onThrow(Throwable ex, String name) {
        System.out.println("[事件通知][调用异常] onThrow 执行.");
    }
}
```
## Dubbo中参数验证
从源码中我们发现Dubbo参数校验有两种方式：

- 一般方式，设置 validation 为 jvalidation、jvalidationNew 两种框架提供的值。
- 特殊方式，设置 validation 为自定义校验器的类路径，并将自定义的类路径添加到 META-INF 文件夹下面的 org.apache.dubbo.validation.Validation 文件中。

如何进行参数校验改造，也有通用三部曲：

- 首先，寻找具有拦截机制的接口，且该接口具有读取请求对象数据的能力。
- 其次，寻找一套注解来定义校验的标准规则，并将该注解修饰到请求对象的字段上。
- 最后，寻找一套校验逻辑来根据注解的标准规则来校验字段值，提供通用的校验能力。

参数校验的应用场景主要有3类，单值简单规则判断、降低无谓的脏请求、通用网关校验领域。
```java
///////////////////////////////////////////////////
// 统一验证：下游 validateUser 的方法入参对象
///////////////////////////////////////////////////
@Setter
@Getter
public class ValidateUserInfo implements Serializable {
    private static final long serialVersionUID = 1558193327511325424L;
    // 添加了 @NotBlank 注解
    @NotBlank(message = "id 不能为空")
    private String id;
    // 添加了 @Length 注解
    @Length(min = 5, max = 10, message = "name 必须在 5~10 个长度之间")
    private String name;
    // 无注解修饰
    private String sex;
}

///////////////////////////////////////////////////
// 统一验证：消费方的一段调用下游 validateUser 的代码
///////////////////////////////////////////////////
@Component
public class InvokeDemoFacade {

    // 注意，@DubboReference 这里添加了 validation 属性
    @DubboReference(validation ＝ "jvalidation")
    private ValidationFacade validationFacade;

    // 一个简单的触发调用下游 ValidationFacade.validateUser 的方法
    public String invokeValidate(String id, String name, String sex) {
        return validationFacade.validateUser(new ValidateUserInfo(id, name, sex));
    }
}

///////////////////////////////////////////////////
// 统一验证：提供方的一段接收 validateUser 请求的代码
///////////////////////////////////////////////////
// 注意，@DubboService 这里添加了 validation 属性
@DubboService(validation ＝ "jvalidation")
@Component
public class ValidationFacadeImpl implements ValidationFacade {
    @Override
    public String validateUser(ValidateUserInfo userInfo) {
        // 这里就象征性的模拟下业务逻辑
        String retMsg = "Ret: "
                + userInfo.getId()
                + "," + userInfo.getName()
                + "," + userInfo.getSex();
        System.out.println(retMsg);
        return retMsg;
    }
}
```
总结：通过在@DubboReference注解中添加validation ＝ "jvalidation"属性，表示在消费端开启参数校验选项，通过在@DubboService注解中添加该属性代表在提供端开启参数校验选项。
### 自定义校验注解示例
```java
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER, ElementType.TYPE})
@Constraint(validatedBy = UserValidation.NotMaleValidator.class)
public @interface NotMale {

    String message() default "性别不能为男";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

}

// 这里抽象出一个父类UserValidation，子类就不用再重复实现isValid方法
public class UserValidation<T extends Annotation> implements
        ConstraintValidator<T, String> {

    protected Predicate<String> predicate = c -> true;
    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        return predicate.test(value);
    }

    public static class NotMaleValidator extends UserValidation<NotMale> {

        @Override
        public void initialize(NotMale constraintAnnotation) {
            predicate = sex -> !"m".equals(sex);
        }
    }


}
```
但是Dubbo接口是通过代理调用的，所以在方法里面加注解是没法触发bean validation校验的，需要将自定义注解加到参数对象的属性上才能生效。
## Dubbo缓存
Dubbo缓存设置的主要有两步：

- 第一步，找到 [dubbo:service/](dubbo:service/)、[dubbo:method/](dubbo:method/)、[dubbo:provider/](dubbo:provider/)、[dubbo:consumer/](dubbo:consumer/)、@DubboReference、@DubboService 这些可以设置缓存的标签或注解。
- 第二步，添加 cache 属性，并填充属性值，属性值有 lru、threadlocal、jcache、expiring 四种缓存策略。
四中缓存策略的介绍：
- lru，使用的是LruCacheFactory，其存储数据的结构LRU2Cache是实现LinkedHashMap，重写其中的`removeEldestEntry`方法来达到缓存满时淘汰最老的元素。
- threadlocal，使用的是 ThreadLocalCacheFactory 工厂类，类名中 ThreadLocal 是本地线程的意思，而 ThreadLocal 最终还是使用的是 JVM 内存。
- jcache，使用的是 JCacheFactory 工厂类，是提供 javax-spi 缓存实例的工厂类，既然是一种 spi 机制，可以接入很多自制的开源框架。
- expiring，使用的是 ExpiringCacheFactory 工厂类，内部的 ExpiringCache 中还是使用的 Map 数据结构来存储数据，仍然使用的是 JVM 内存。

通过引入cache-api、redisson来使用redis作为jcache的实现。
```xml
<dependency>
  <groupId>javax.cache</groupId>
  <artifactId>cache-api</artifactId>
</dependency>

<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson</artifactId>
    <version>3.18.0</version>
</dependency>
```
但是通过监控redis的命令执行情况，发现redisson会启动一些定时任务在redis上执行一些lua脚本来达到统计的目的，但是可能对redis的压力比较大。所以需要看看怎么配置关闭这些统计相关的。还有dubbo默认的失效实现是60秒，可以通过`cache.write.expire`进行设置，单位是"毫秒"。
### 自定义过滤器的通用三部曲：
- 首先，自定义过滤器继承`org.apache.dubbo.rpc.Filter`接口，并实现`invoke`方法，同时在过滤器的`@Activate`注解中声明是提供方或消费方，还是两者都是。
- 其次，可以在@Method的parameters字段中为方法自定义一些属性，以辅助过滤器的通用逻辑处理。
- 最后，将自定义过滤器的类路径一定要记得添加到META-INF文件夹下面的`org.apache.dubbo.rpc.Filter`文件中。

## Wrapper机制
一下是Dubbo生成Wrapper代理类的核心代码：
```java
// org.apache.dubbo.rpc.proxy.javassist.JavassistProxyFactory#getInvoker
// 创建一个 Invoker 的包装类
@Override
public <T> Invoker<T> getInvoker(T proxy, Class<T> type, URL url) {
    // 这里就是生成 Wrapper 代理对象的核心一行代码
    final Wrapper wrapper = Wrapper.getWrapper(proxy.getClass().getName().indexOf('$') < 0 ? proxy.getClass() : type);
    // 包装一个 Invoker 对象
    return new AbstractProxyInvoker<T>(proxy, type, url) {
        @Override
        protected Object doInvoke(T proxy, String methodName,
                                  Class<?>[] parameterTypes,
                                  Object[] arguments) throws Throwable {
            // 使用 wrapper 代理对象调用自己的 invokeMethod 方法
            // 以此来避免反射调用引起的性能开销
            // 通过强转来实现统一方法调用
            return wrapper.invokeMethod(proxy, methodName, parameterTypes, arguments);
        }
    };
}
```
调用流程如下：
![image-20241209175152795](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241209175152795.png)
生成代理类的流程总结起来有3点：
1. 以源对象的类属性为维度，与生成的代理类建立缓存映射关系，避免频繁创建代理类影响性能。
2. 生成一个继承Wrapper的动态类，并且暴露一个公有`invokeMethod`方法来调用源对象的方法。
3. 在`invokeMethod`方法中，通过生成if...else逻辑代码来识别调用源对象的不同方法。

## 集群拓展的应用
Cluster作为路由层，封装多个提供方的路由及负载均衡，并桥接注册中心以Invoker为中心发起调用，那那些应用场景可以考虑集群扩展呢？
第一，同机房请求无法连通时，可以考虑转发HTTP请求至可用提供者。
第二，内网本机访问测试环境无法联通时，可以转发请求至HTTP协议的接口，然后在接口中泛化调用各种Dubbo服务。
第三，如果针对接口的多个提供者需要做适应当前公司业务的筛选、踢除、负载均衡之类的诉求时，也是可以考虑集群扩展的。
### 集群扩展四部曲
- 首先定义一个TransferClusterInvoker集群扩展处理器来处理核心的调用转发逻辑。
- 其次定义一个TransferCluster集群扩展器来封装集群扩展处理器。
- 然后在META-INF/dubbo/org.apache.dubbo.rpc.cluster.Cluster文件中定义TransferCluster的类路径并取个别名。
- 最后再dubbo.properties配置文件通过一个别名来指定消费者需要使用的集群扩展器。
```java
public class TransferClusterInvoker<T> extends FailoverClusterInvoker<T> {
    // 按照父类 FailoverClusterInvoker 要求创建的构造方法
    public TransferClusterInvoker(Directory<T> directory) {
        super(directory);
    }
    // 重写父类 doInvoke 发起远程调用的接口
    @Override
    public Result doInvoke(Invocation invocation, List<Invoker<T>> invokers, LoadBalance loadbalance) throws RpcException {
        try {
            // 先完全按照父类的业务逻辑调用处理，无异常则直接将结果返回
            return super.doInvoke(invocation, invokers, loadbalance);
        } catch (RpcException e) {
            // 这里就进入了 RpcException 处理逻辑

            // 当调用发现无提供者异常描述信息时则向转发服务发起调用
            if (e.getMessage().toLowerCase().contains("no provider available")){
                // TODO 从 invocation 中拿到所有的参数，然后再处理调用转发服务的逻辑
                return doTransferInvoke(invocation);
            }
            // 如果不是无提供者异常，则不做任何处理，异常该怎么抛就怎么抛
            throw e;
        }
    }
}

public class TransferCluster implements Cluster {
    // 返回自定义的 Invoker 调用器
    @Override
    public <T> Invoker<T> join(Directory<T> directory, boolean buildFilterChain) throws RpcException {
        return new TransferClusterInvoker<T>(directory);
    }
}
```

META-INF/dubbo/org.apache.dubbo.rpc.cluster.Cluster 文件中新增的配置：
```properties
transfer＝com.hmilyylimh.cloud.TransferCluster
```

dubbo.properties:
```properties
dubbo.consumer.cluster=transfer
```
## 线程池扩展
普通线程池执行的流程
![image-20241203143904621](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241203143904621.png)
### Dubbo中存在的四种线程池
1. **FixedThreadPool**：固定线程数量的线程池，也就是说，核心线程与最大线程数量相等，该线程池的拒绝策略是抛异常，不过这个拒绝策略是经过框架特殊包装处理的，发现拒绝任务时，这个策略有导出线程堆栈的能力，特别适合开发人员分析线程池满时的一些实时状况。
2. **LimitedThreadPool**：该线程池默认情况下没有核心线程，非核心线程数量最大也不能超过200。并且非核心线程的keepAliveTime存活时间为Long类型的最大值，也就是说永不过期。
3. **CachedThreadPool**：对比LimitedThreadPool，CachedThreadPool最大的变化就在于创建线程池对象的时候，支持alive属性来赋值非核心线程的空闲时的存活时间，默认存活时间是1分钟，也就是说，一旦非核心线程自带了销毁功能，也就变成了缓存线程池了。
4. **EagerThreadPool**：核心线程数由一个单独的corethreads属性来赋值，默认值是0.最大线程数是由threads属性来赋值，默认值是200，非核心线程的存活时间是由alive属性来赋值的。任务阻塞队列，既不是SynchronousQueue，也不是LinkedblockingQueue，而是重新设计了一款新的阻塞队列TaskQueue放到了线程池中。新的阻塞队列TaskQueue，主要作用在于**重写了LinkedBlockingQueue的offer方法，只要活跃的工作线程数量小于最大线程数量，就优先创建工作线程来处理任务。**
EagerThreadPool的设计精髓：
![image-20241203150218676](C:\Users\cong.pi\AppData\Roaming\Typora\typora-user-images\image-20241203150218676.png)
