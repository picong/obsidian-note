```ad-abstract
SpringBoot的强大特性
- **约定大于配置**：Springboot对日常开发中比较常见的场景都提供了约定的默认配置，并基于自动装配机制，将场景中通常必需的组件都注册号，以此来达到少配置、甚至不配置都能正常启动项目的项目；
- **`starter`**：Springboot对常用的场景都进行了整合，将这些场景中需要的依赖都手机整理到一个依赖中，并在其中添加了默认的配置，使项目开发中只需要导入一个依赖，即可实现场景技术的整合；
- **自动装配**：基于模块装配 + 条件装配，可以在具体的场景下，自动引入需要的配置类并解析执行，并且它可以根据工程代码中已经配置的内容，动态注册缺少/必要的组件，以此实现约定大于配置的效果；
- **嵌入式Web容器**：使用内部嵌入式的Web容器支撑应用的运行。
- **生产级别的特性**：Springboot提供了一些很有用的生产运维型的功能特性，比如健康检查、监控指标、外部配置等。
```

`@SpringBootApplication`是组合注解，它等价于同时标注`@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan`。`@ComponentScan`默认扫描当前配置类所在包及子包下的所有组件，`exclude`属性会将启动类、自动配置类屏蔽掉。`@Configuration`可标注配置类，`@SpringBootConfiguration`并没有对其做实质性扩展。
## SpringBoot的自动装配
![[Pasted image 20240902135752.png]]
SpringBoot的自动配置完全由`@EnableAutoConfiguration`开启。
```java
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration
```
### `@AutoConfigurationPackage`注解上面标注了`@Import`，导入了一个`AutoConfigurationPackages.Register`,它的作用是把主配置所在根包保存起来一遍后期扫描使用。
### `@Import(AutoConfigurationImportSelector.class)`，导入的`AutoConfigurationImportSelector`实现了`DeferredImportSelector`，它的执行时机，是在`@Configuration`注解中的其他逻辑处理完毕之后再执行。其中最主要的逻辑其实是通过`SpringFactoriesLoader.loadFactoryNames`，加载所有jar包中`META-INF/spring.factories`文件，并加载文件中`@EnableAutoConfiguration`对应的自动配置类。
## WebMvc的自动装配
![[Pasted image 20240902140201.png]]
在引入`spring-boot-starter-web`的依赖后，SpringBoot会自动进行Web环境的装载。
![[Pasted image 20240902170517.png]]
- `WebMvcAutoConfiguration`必须在`DispatcherServletAutoConfiguration`、`TaskExecutionAutoConfigurtation`、`ValidationAutoConfiguration`执行完后再执行。
	- `DispatcherServletAutoConfiguration`的源码中又标注了`AutoConfigureAfter`，说明它又要在`ServletWebServerFactoryAutoConfiguration`之后再执行。
		- `ServletWebServerFactoryAutoConfiguration`导入了(`@Import`)几个组件：`EmbeddedTomcat`、`EmbeddedJetty`、`EmbeddedUndertow`、`BeanPostProcessorsRegister`。
	- `ServletWebServerFactoryAutoConfiguration`的自动配置执行完成后，开始执行`DispatcherServletAutoConfiguration`中的自动配置，这里面嵌套了两个内部类，分别注册`DispacherServlet`和`DispatcherServletRegistrationBean`。
	- `WebMvcAutoConfigurationAdapter`实现了Spring-boot2.X中定义的接口`WebMvcConfigurer`，并进行了默认的配置：
		- 配置`HttpMessageConverter`
		- `ViewResolver`的组件注册
		- 静态资源映射
		- 主页设置
		- 应用图标设置
	- `EnableWebMvcConfiguration`中配置了SpringMvc中最核心的两个组件：处理器适配器、处理器映射器。以及注册了Hibernate-Validator参数检验器和全局异常处理器。
### 小结
1. 自动配置类是有执行顺序的， `WebMvcAutoConfiguration` 的执行顺序在 `ServletWebServerFactoryAutoConfiguration` 、`DispatcherServletAutoConfiguration` 之后。
2. SpringBoot会根据当前classpath下的类来决定装配哪些组件，启动哪种类型的Web容器。
3. WebMvc的配置包括消息转换器、视图解析器、处理器映射器、处理器适配器、静态资源映射配置、主页设置、应用图标设置等。
4. 配置 SpringBoot 应用除了可以使用 properties、yml 之外，还可以使用 Customizer 来编程式配置。

## SpringBoot准备IOC容器
![[Pasted image 20240903094931.png]]
- SrpingApplication.run方法首先会new一个SpringApplicaiton对象，构造函数内会填充SpringApplication的一些属性，如下所示：
```java
@SuppressWarnings({ "unchecked", "rawtypes" })
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
    // resourceLoader为null
    this.resourceLoader = resourceLoader;
    Assert.notNull(primarySources, "PrimarySources must not be null");
    // 将传入的DemoApplication启动类放入primarySources中，这样应用就知道主启动类在哪里，叫什么了
    // SpringBoot一般称呼这种主启动类叫primarySource（主配置资源来源）
    this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));
    // 3.1 判断当前应用环境
    this.webApplicationType = WebApplicationType.deduceFromClasspath();
    // 3.2 设置初始化器
    setInitializers((Collection) getSpringFactoriesInstances(ApplicationContextInitializer.class));
    // 3.3 设置监听器
    setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class));
    // 3.4 确定主配置类
    this.mainApplicationClass = deduceMainApplicationClass();
}
```
-  WebApplicationType.deduceFromClassPath:判断当前应用环境
-  setInitializers: 设置初始化器，这些初始化器类型为`ApplicationContextInitializer`。而这组`ApplicationContextInitializer`是在构造方法中，通过getSpringFactories得到的。`ApplicationContextInitializer`是在IOC容器刷新之前进行回调。SpringBoot一共配置了6个`ApplicationContextInitializer`:
	-  ConfigurationWarningsApplicationContextInitializer：报告IOC容器的一些常见的错误配置
	- ContextIdApplicationContextInitializer：设置Spring应用上下文的ID
	- DelegatingApplicationContextInitializer：加载 `application.properties` 中 `context.initializer.classes` 配置的类
	- ServerPortInfoApplicationContextInitializer：将内置servlet容器实际使用的监听端口写入到 `Environment` 环境属性中
	- SharedMetadataReaderFactoryContextInitializer：创建一个 SpringBoot 和 `ConfigurationClassPostProcessor` 共用的 `CachingMetadataReaderFactory` 对象
	- ConditionEvaluationReportLoggingListener：将 `ConditionEvaluationReport` 写入日志
- `setListeners`：设置监听器，该监听器用于监听IOC容器中发布的各种事件。默认配置的监听器如下所示：
	- ClearCachesApplicationListener：应用上下文加载完成后对缓存做清除工作
	- ParentContextCloserApplicationListener：监听双亲应用上下文的关闭事件并往自己的子应用上下文中传播
	- FileEncodingApplicationListener：检测系统文件编码与应用环境编码是否一致，如果系统文件编码和应用环境的编码不同则终止应用启动
	- AnsiOutputApplicationListener：根据 `spring.output.ansi.enabled` 参数配置 AnsiOutput
	- ConfigFileApplicationListener：从常见的那些约定的位置读取配置文件
	- DelegatingApplicationListener：监听到事件后转发给 `application.properties` 中配置的 `context.listener.classes` 的监听器
	- ClasspathLoggingApplicationListener：对环境就绪事件 `ApplicationEnvironmentPreparedEvent` 和应用失败事件 `ApplicationFailedEvent` 做出响应
	- LoggingApplicationListener：配置 `LoggingSystem`。使用 `logging.config` 环境变量指定的配置或者缺省配置
	- LiquibaseServiceLocatorApplicationListener：使用一个可以和 SpringBoot 可执行jar包配合工作的版本替换 LiquibaseServiceLocator
	- BackgroundPreinitializer：使用一个后台线程尽早触发一些耗时的初始化任务
- `deduceMainApplicationClass`：确定主配置类
## 准备运行时环境->创建IOC容器(注册主启动类到BeanFactory中)->刷新IOC容器
![[Pasted image 20240903140934.png]]
IOC容器刷新方法：
```java
	public void refresh() throws BeansException, IllegalStateException {
		synchronized (this.startupShutdownMonitor) {
			// Prepare this context for refreshing.
			prepareRefresh();

			// Tell the subclass to refresh the internal bean factory.
			ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

			// Prepare the bean factory for use in this context.
			prepareBeanFactory(beanFactory);

			try {
				// Allows post-processing of the bean factory in context subclasses.
				postProcessBeanFactory(beanFactory);

				// Invoke factory processors registered as beans in the context.
				invokeBeanFactoryPostProcessors(beanFactory);

				// Register bean processors that intercept bean creation.
				registerBeanPostProcessors(beanFactory);

				// Initialize message source for this context.
				initMessageSource();

				// Initialize event multicaster for this context.
				initApplicationEventMulticaster();

				// Initialize other special beans in specific context subclasses.
				onRefresh();

				// Check for listener beans and register them.
				registerListeners();

				// Instantiate all remaining (non-lazy-init) singletons.
				finishBeanFactoryInitialization(beanFactory);

				// Last step: publish corresponding event.
				finishRefresh();
			}
...
```
#### 如下所示为包扫描的过程：
![[Pasted image 20240904142158.png]]
### `invokeBeanFactoryPostProcessors(beanFactory)`
![[Pasted image 20240904142559.png]]
上述方法中在获取`BeanDefinitionRegistryPostProcessor`进行回调时，会发现有一个后置处理器：`ConfigurationClassPostProcessor`，这个处理器用来进行注解组件的解析。
`org.springframework.context.annotation.ClassPathBeanDefinitionScanner#doScan`，解析到`@ComponentScan`后会去扫描basePackages下面的所有@Component标注了的类，注册到BeanDefinitionRegistry中。
`org.springframework.context.annotation.ConfigurationClassBeanDefinitionReader#loadBeanDefinitionsForConfigurationClass`，该方法会去加载配置类`@Configuration`中通过`@Bean`注解声明的BeanDefinition。
### 后置处理器和监听器的注册
1. 注册`BeanPostProcessor`的时机是`BeanFactory`已经初始化完毕，监听器还没有注册之前。
2. 注册`ApplicationListener`的时机是`BeanPostProcessor`注册完，但还没有初始化单实例Bean。
3. IOC容器使用`ApplicationEventMulticaster`广播事件。
### `finishBeanFactoryInitialization` -> `preInstantiateSingletons` -> `getBean`实例化并初始化bean
1. IOC容器初始化单例Bean使用`getBean`方法
2. 真正创建Bean的步骤是`doCreateBean`
3. 创建Bean的过程：
	1. 实例化Bean
	2. 属性赋值&自动注入
	3. 执行初始化方法
4. `BeanPostProcessor`中before方法真正的执行时机是在注入之后，初始化方法调用之前。

### @Autowired解决循环依赖的核心思路
整个IOC容器解决循环依赖，用到`DefaultSingletonBeanRegistry`中的几个重要成员：
- `singletonObjects`：一级缓存，存放完全初始化好的Bean的集合，从这个集合中取出来的Bean可以立马返回
- `earlySingletonObjects`：二级缓存，存放创建好但没有初始化属性的Bean的集合，它用来解决循环依赖
- `singletonFactories`：三级缓存，存放但实例Bean工厂的集合
- `singletonCurrentlyIncreation`：存放正在被创建的Bean的集合
IOC容器解决循环依赖的思路：
1. 初始化Bean之前，将bean的name存放三级缓存
2. 创建Bean将准备创建的Bean放入singletonsCurrentyIncreation
3. `doCreateBean`方法中会执行`addSingletonFactory`，将这个实例化但没有属性赋值的Bean放入三级缓存，并从二级缓存中移除（一般初次创建的bean不会存在于二级缓存）
4. 属性赋值&自动注入时，引发关联创建
5. 关联创建时：
	1. 检查"正在被创建的Bean"中是否有即将注入的Bean
	2. 如果有，检查二级缓存中是否有当前创建好但没有赋值初始化的Bean
	3. 如果没有，检查三级缓存中是否有正在创建中的Bean
	4. 至此一般会有，将这个Bean放入二级缓存，并从三级缓存中移除
6. 之后Bean被成功注入，最后执行`addSingleton`，将这个完全创建好的Bean放入一级缓存，从二级和三级缓存移除，并记录已经创建了的单实例Bean
![[Pasted image 20240905165438.png]]
###  多种后置处理器
- BeanPostProcessor：Bean实例化后，初始化的前后触发
- BeanDefinitionRegistryPostProcessor：所有Bean的定义信息即将全部被加载但未实例化时触发
- BeanFactoryPostProcessor：所有的BeanDefinition已经被加载，但没有Bean被实例化时触发
- InstantiationAwareBeanPostProcessor：Bean的实例化对象的前后过程、以及实例的属性设置(AOP)
- InitDestroyAnnotationBeanPostProcessor：触发执行Bean中标注@PostConstruct、@PreDestroy注解的方法
- ConfigurationClassPostProcessor：解析加了@Configuration的配置类，解析@ComponentScan注解扫描包，以及解析@Import、@ImportResource等注解
- AutowiredAnnotationBeanPostProcessor：负责处理@Autowired、@Value等注解
### 嵌入式Web容器的创建
SpringBoot扩展的ServletWebServerApplicationContext会在IOC容器的模板方法onRefresh方法中创建嵌入式Web容器。
## AOP中 @EnableAspectJAutoProxy的作用
`@EnableAspectJAutoProxy`主要是往BeanDefinitionRegistry中注册`AnnotationAwareAspectJAutoProxyCreator`的BeanDefinition。
![[Pasted image 20240906153302.png]]
这个creator的主要作用：
- 实现了`SmartInstantiationAwareBeanPostProcessor`，可以做组件的**创建前后、初始化前后的后置处理工作。** `SmartInstantiationAwareBeanPostProcessor`扩展了`InstantiationAwareBeanPostProcessor`接口，它用于组件的创建前后做后置处理，恰好AOP的核心是用代理对象代替普通对象，用这种后置处理器刚好可以满足需求。`AbstractApplicationContext#registerBeanPostProcessors`中会将该PostProcessor注册到IOC容器中。
- 实现了`BeanFactoryAware`，可以将`BeanFactory`注入到组件中。
### Spring AOP创建代理对象的流程
![[Pasted image 20240906172247.png]]
1. `AbstractAutoProxyCreator`的`postProcessBeforeInstantiation`方法并没有创建代理对象，而是通过`postProcessAfterInitialization`创建。
2. AOP创建的核心方法在`AbstractAutoProxyCreator`的`wrapIfNecessary`方法。
3. AOP增强方法的核心是增强器，而增强器的创建在创建目标对象之前。

### JDK动态代理流程
![[Pasted image 20240906185646.png]]
### cglib的intercept方法 - CglibAopProxy.DynamicAdvisedInterceptor 最终调用的拦截器链的逻辑和JDK动态代理一致
### 小结
1. jdk动态代理借助接口实现，并且在创建代理对象之前还注入了额外的接口。
2. cglib动态代理的实现机制与jdk动态dialing几乎完全一致。
3. 两种动态代理的核心思想都是获取增强器调用链，然后链式执行增强器(拦截器)。
4. 执行拦截器链时，为保证拦截器链能有序执行，会引入下标索引机制。
## 声明式事务：生效原理
通过`@EnableTransactionManagement`注解来启动注解事务。该注解通过`@Import`导入了`TransactionManagementConfigurationSelector`，如下所示：
```java
public class TransactionManagementConfigurationSelector extends AdviceModeImportSelector<EnableTransactionManagement> {

	@Override
	protected String[] selectImports(AdviceMode adviceMode) {
		switch (adviceMode) {
			case PROXY:
				return new String[] {AutoProxyRegistrar.class.getName(), ProxyTransactionManagementConfiguration.class.getName()};
			case ASPECTJ:
				return new String[] {TransactionManagementConfigUtils.TRANSACTION_ASPECT_CONFIGURATION_CLASS_NAME};
			default:
				return null;
		}
	}

}
```
`@EnableTransactionManagement`注解默认使用`PROXY`来增强事务，那这个switch结构中就应该返回两个类的全限定类名：`AutoProxyRegister`、`ProxyTransactionMangementConfiguration`。
`AutoProxyRegistrar`通过调用`AopUtils.registerAutoProxyCreatorIfNecessary`注册`InfrastructureAdvisorAutoProxyCreator`的`BeanDefinition`到`BeanDefinitionRegistry`中。该`Creator`的主要作用是用来自动的创建事务增强的动态代理。
![[Pasted image 20240909142417.png]]
然后在`ProxyTransactionManagementConfiguration`配置类中，注册了`BeanFactoryTransactionAttributeSourceAdvisor`、`AnnotationTransactionAttributeSource`、`TransactionInterceptor`、`TransactionalEventListenerFactory`组件。
### 小结
1. Spring的注解事务底层是借助AOP的机制，创建了一个`InfrastructureAdvisorAutoProxyCreator`组件来创建代理对象。
2. 注解事务要想生效，需要**事务增强器、事务切入点解析器、事务配置源、事务拦截器**等组件。
### 声明式事务：工作原理
事务动态代理对象会获取增强链，或获取到`TransactionInterceptor`然后通过调用`TransactionInterceptor#invoke`然后回调用到`TransactionAspectSupport#invokeWithinTransaction`方法中，在这里面使用**环绕通知**，来完成事务创建，事务提交，事务回滚等操作的增强，如果没有使用三方的数据池，底层就是通过调用jdbc的API来进行提交和回滚。
## 声明式事务：事务传播行为原理
开启注解事务时，触发自动配置，而自动配置中注入了一个`InfrastructureAdvisorAutoProxyCreator`，它配合`BeanFactoryTransactionAttributeSourceAdvisor`(事务增强器)来完成事务织入，在第一次事务织入时要获取所有切入点，之后它会搜索所有切入点，判断创建的Bean是否可以被织入事务通知，在搜索时刚好来到这里要解析事务定义信息，所以会触发解析和缓存动作。--- `TransactionAttribute`会在织入事务增强时解析并缓存。
**事务传播行为的核心控制点在`AbstractPlatformTransactionManager#getTransaction`和`AbstractPlatformTransactionManager#handleExistingTransaction`方法中**。
## 自动装配与DispatcherServlet组件
### `SpringBootServletInitializer`的作用和原理
`SpringBoot`应用打包启动的两种方式：
- 打jar包启动时，先创建IOC容器，在创建过程中创建了嵌入式Web容器。
- 打war包启动时，要先启动外部的Web服务器，Web服务器再去启动`SpringBoot`应用，然后才是创建IOC容器。
### 外置Web容器时如何成功引导`SpringBoot`应用启动的：
1. 外部Web容器启动，开始加载SpringBoot的war包并解压。
2. 去`SpringBoot`应用中的每一个依赖的jar中寻找`META-INF/services/javax.servlet.ServletContainerInitializer`的文件。
3. 根据文件中标注的全限定类名，去找这个类(`SpringServletContainerInitializer`)。
```java
@HandlesTypes(WebApplicationInitializer.class)
public class SpringServletContainerInitializer implements ServletContainerInitializer {
    @Override
    public void onStartup(Set<Class<?>> webAppInitializerClasses, ServletContext servletContext)
            throws ServletException {
        // SpringServletContainerInitializer会加载所有的WebApplicationInitializer类型的普通实现类
        
        List<WebApplicationInitializer> initializers = new LinkedList<WebApplicationInitializer>();

        if (webAppInitializerClasses != null) {
            for (Class<?> waiClass : webAppInitializerClasses) {
                // 如果不是接口，不是抽象类
                if (!waiClass.isInterface() && !Modifier.isAbstract(waiClass.getModifiers()) &&
                        WebApplicationInitializer.class.isAssignableFrom(waiClass)) {
                    try {
                        // 创建该类的实例
                        initializers.add((WebApplicationInitializer) waiClass.newInstance());
                    }
                    catch (Throwable ex) {
                        throw new ServletException("Failed to instantiate WebApplicationInitializer class", ex);
                    }
                }
            }
        }

        if (initializers.isEmpty()) {
            servletContext.log("No Spring WebApplicationInitializer types detected on classpath");
            return;
        }

        servletContext.log(initializers.size() + " Spring WebApplicationInitializers detected on classpath");
        AnnotationAwareOrderComparator.sort(initializers);
        // 调用各自的onStartup方法
        for (WebApplicationInitializer initializer : initializers) {
            initializer.onStartup(servletContext);
        }
    }
}
```
5. 因为打war包的`SpringBoot`工程会在启动类的同包下创建ServletInitializer，并且必须继承`SpringBootServletInitializer`，所以会被服务器创建对象。
6. `SpringBootServletInitializer`中重写了`onStartup`方法。
	1. `WebApplicationContext rootAppContext = createRootApplicationContext(servletContext)`，创建父IOC容器。使用Builder机制构建SpringBoot启动的一些配置，并启动SpringBoot应用。
### 小结
1. Servlet3.0规范中取消了`web.xml`，改用`ServletContainerInitializer`来接管应用启动。
2. `SpringBootServletInitializer`实现了`WebApplicationInitializer`，用于被`ServletContainerInitializer`引导SpringBoot应用启动。
3. Controller中的`@RequestMapping`标注的方法装载时机是`RequestMappingHandlerMapping`的初始化阶段(实现了InitializationBean接口的afterProperties方法)。
4. `SpringBoot`中SpringMVC不存在父子容器的隔离情况，只会refresh一次容器。
![[Pasted image 20240911184347.png]]
## 嵌入式容器：tomcat的创建过程
Tomcat的内部核心结构包含如下组件：
- Service：一个Tomcat-Server可以有多个Service，Service中包含下面的所有组件
- Connector：用于与客户端交互，接收客户端的请求，并将结果相应给客户端
- Engine：负责处理来自Service中的Connector的所有请求
- Host：可理解为主机，一个主机绑定一个端口号
- Context：可理解为应用，一个主机下有多个应用。

### 嵌入式tomcat初始化启动的入口：`ServletWebServerApplicationContext#onRefresh`,主要的启动流程在`TomcatWebServer#initialize`中处理。嵌入式Tomcat的组件初始化步骤顺序如下：
1. Server
2. Service
3. Engine
4. Executor
5. MapperListener
6. Connector
7. Protocol
8. EndPoint
初始化之后会调用`Tomcat#start`依次启动如下组件：`Engine`、`Executor`、`MapperListener`、`Connector`。
注意：创建嵌入式Tomcat的时机是`onRefresh`方法，此时还有很多单实例Bean没有被创建，此时如果直接初始化所有组件后，Connector也被初始化，此时客户端就可以与Tomcat进行交互，但这个时候单实例Bean还没有初始化完毕(尤其是`DispatcerServlet`)，就会导致传入的请求Tomcat无法处理，出现异常。
所以SpringBoot为了避免这个问题，会在嵌入式Tomcat发布事件时检测此时的`Context`状态是否为`START_EVENT`，如果是则将这些`Connector`先移除掉。
`ServletWebServerApplicationContext#finishRefresh`中会恢复`Connector`并启动。
## WebFlux
### Reactive中的核心概念
- Publisher，作为数据发布者，它只有一个方法：subscribe，该方法会接收一个`Subsriber`，构成"订阅"关系。
- Subscriber作为数据接收者，包含四个方法：
```java
public void onSubscribe(Subscription s); 
public void onNext(T t); 
public void onError(Throwable t); 
public void onComplete();
```
- Subscription可以看做一个订阅"关系"，它归属于一个发布者和一个接收者。它有两个方法:
```java
public void request(long n); // 请求/拉取数据
public void cancel(); // 放弃/停止拉取
```
- Processor，它同时继承了Subscriber和Publisher接口，一般用于数据的中间处理。
### Reactor中常用组件
- Flux，可以简单理解为**非阻塞的Stream**，它实现了Publisher接口
- Mono可以简单理解为**非阻塞的Optional**，它也实现了Publisher接口
- Scheduler可以简单理解为**线程池**，如果需要使用它，应该通过Schedulers工具类来产生(Scheduler不是public类型)。它有几种类型：
	- immediate：与主线程一直
	- single：只有一个线程的线程池
	- elastic：弹性线程池，线程池中的线程数量原则上没有上限。
	- parallel：并行线程池，线程池中的线程数量等于CPU处理器的数量。
### WebFlux：DispatcherHandler工作原理-传统方式
![[Pasted image 20240913111906.png]]
1. `DispatcherHandler`与`DispatcherServlet`的处理思路几乎完全相同，包括寻找`HandlerMapping`、`HandlerAdapter`、执行目标方法等。
2. `DispatcherHandler`相比较`DispatcherServlet`最大的不同点，是里面的实现绝大部分都采用响应式流变成。
### 函数式端点
```java

```
![[Pasted image 20240913115322.png]]
### WebMvc和WebFlux的区别
![[Pasted image 20240913112322.png]]
### 小结
1. `RouterFunctionMapping`用于在函数式端点的映射中寻找对应的目标方法，而且它的优先级高于`RequestMappingHandlerMaping`。
2. 函数式端点变成在真正调用Controller/Handler方法时，相较于传统WebMvc方式，不需要走反射，而是直接强转为`HandlerFunction`后直接调用目标方法。
### Springboot通过jar包引导启动，其实是通过在`META-INF`下的`MINIFEST.MF`文件中定义的Main-Class来引导启动的，Start-Class属性注明了SpringBoot的主启动类。
```properties
Manifest-Version: 1.0 
Implementation-Title: demo 
Implementation-Version: 0.0.1-SNAPSHOT 
Start-Class: com.example.demo.DemoApplication 
Spring-Boot-Classes: BOOT-INF/classes/ 
Spring-Boot-Lib: BOOT-INF/lib/ Build-Jdk-Spec: 1.8 
Spring-Boot-Version: 2.1.9.RELEASE 
Created-By: Maven Archiver 3.4.0 
Main-Class:org.springframework.boot.loader.JarLauncher
```
