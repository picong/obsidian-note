## 循环依赖问题
Spring的做法是在BeanFactory中引入一个结构：earlySingletonObjects，这里面存放的就是早期的毛坯实例。创建Bean实例的时候，不用等到所有步骤完成，而是可以在属性还没有注入之前，就把早期的毛坯实例先保存起来，供属性注入时使用。
举个例子：
![[Pasted image 20240718142220.png]]
第一步，先实例化ABean，此时它是早期的不完整毛坯实例，好多属性还没被赋值，将实例放置到earlySingletonObjects中备用。然后给ABean注入属性，这个时候发现它还要依赖BBean。
第二步，实例化BBean，它也是早期的不完整毛坯实例，我们也将实例放到earlySingletonObjects中备用。然后再给BBean注入属性，又发现它依赖CBean。
第三步，实例化CBean，此时它仍然是早期的不完整的实例，同样将实例放置到earlySingletonObjects中备用，然后再给CBean属性赋值，这个时候又发现它反过来还要依赖ABean。
第四步，我们从earlySingletonObjects结构中找到ABean的早期毛坯实例，取出来给CBean注入属性，这意味着这时CBean所用的ABean实例是哪个早期的毛坯实例。这样就先创建好了CBean。
第五步，程序控制流回到第二步，完成BBean的属性注入。
第六步，程序控制流回到第一步，完成ABean的属性注入。至此，所有的Bean就都创建完了。
通过上述过程可以知道，这一系列的Bean是纠缠在一起创建的，我们不能简单地先独立创建它们，而是要作为一个整体来创建。
很多资料把这个过程叫做bean的"三级缓存"，这个术语来自于Spring源代码中的程序注释。实际上我们弄清楚了这个getBean()的过程后就会知道这段注释并不是很恰当。

`DefaultListableBeanFactory`,该类是Spring IoC的引擎。它成为引擎的秘诀在于**它继承了其他BeanFactory类实现Bean的创建管理功能。** 从代码可以看出它继承了AbstractAutowireCapableBeanFactory并实现了ConfigurableListableBeanFactory接口。
![[Pasted image 20240719172803.png]]
## 完整IOC容器
![[Pasted image 20240722105523.png]]
## IOC
IOC是面向对象编程里的一个重要原则，目的是从程序里移出原有的控制权，把控制权交给容器。IOC容器是一个中心化的地方，负责管理对象，也就是Bean的创建、销毁、依赖注入等操作，让程序变得更加灵活、可扩展、易于维护。
在使用IOC容器时，我们需要先配置容器，包括注册需要管理的对象、配置对象之间的依赖关系以及对象的生命周期等。然后，IOC容器会根据这些配置来动态地创建对象，并把它们注入到需要它们的位置上。当我们使用IOC容器时，需要将对象的配置信息告诉IOC容器，这个过程叫做依赖注入(DI)，而IOC容器就是实现依赖注入的工具。因此理解IOC容器就是理解它如何管理对象，如何实现DI的过程。
## MVC
当Servlet服务器如Tomcat启动的时候，要遵守下面的时序。
1. 在启动Web项目时，Tomcat会读取web.xml中的context-param节点，获取这个Web应用的全局参数。
2. Tomcat创建一个ServletContext实例，是全局有效的。
3. 将context-param的参数转换为键值对，存储在ServletContext里。
4. 创建listner中定义的监听类的实例，按照规定Listener要继承自ServletContextLisener。监听器初始化方法是contextInitialized(ServletContextEvent event)。初始化方法中可以通过event.getServletContext().getInitParamameter("name")方法获取上下文环境中的键值对。
5. 当Tomcat完成启动，也就是contextInitialized方法完成后，再对Filter过滤器进行初始化。
6. servlet初始化：有一个参数load-on-startup，它为正数的值越小优先级越高，会自动启动，如果为负数或未指定这个参数，会在servlet被调用时再进行初始化。init-param是一个servlet整个范围之内有效的参数，在servlet类的init()方法中通过this.getInitParameter("param1")方法获得。
### Listner初始化启动IoC容器
Tomcat启动过程中先拿context-param，初始化listener，在初始化过程中，创建IoC容器构建WAC(WebApplicationContext)，加载所管理的Bean对象，并把WAC关联到servlet context里。然后在DispatchServlet初始化的时候，从servletContext里获取属性拿WAC，放到Servlet的属性中，然后拿到Servlet的配置路径参数，之后再扫描路径下的包，调用refresh()方法加载Bean，最后配置url mapping。
我们之所以可以整合MVC和IOC容器，核心的原因是**Servlet规范中规定的时序**，从listener到filter再到servlet，每一个环节都预留了接口让我们有机会干预，写入我们需要的代码。

## 如何实现Spring MVC
利用Servlet机制，用一个单一的Servlet拦截所有请求，由它来分派任务，这样实现了原始MVC结构。然后把MVC和IoC结合再一起，在Servlet容器启动(监听器)的时候，给上下文环境里注入IoC容器，使得Servlet里可以访问到IoC容器里的Bean。
之后进一步解耦MVC结构，独立出请求处理器，还用一个简洁统一的注解方式，把Web请求方便地定位到后台处理的类和方法里，实现Spring的RequestHandler。
在前后台打通的时候，实现数据参数的自动转换，也就是说先把Web请求的传入参数，自动地从文本转换成对象，实现数据绑定功能。对于返回数据，也自动根据用户需求进行格式转换，这样实现了Spring里面的data binder和data conversion。最后回到前端View，如果有前端引擎，在Spring中引用，把数据自动渲染到前端。
## 动态代理
Java提供的动态代理可以对接口进行代理，在代理的过程中主要做三件事。
1. 实现InvocationHandler接口，重写接口内部唯一的方法invoke。
2. 使用Proxy类，通过newProxyInstance，初始化一个代理对象。
3. 通过代理对象，代理其他类，对该类进行增强处理。
## 拦截器
- Advice：表示这是一个增强操作。
- Interceptor：拦截器，它实现的是真正的增强逻辑。
- MethodInterceptor：调用方法上的拦截器，也就是它实现在某个方法上的增强。
对查找方法名的办法进行了扩展，让系统可以按照某个规则来匹配方法名，这样便于统一管理。这个概念叫做Pointcut，熟悉数据库操作的人，可以把这个概念类比为SQL语句中的where条件。其中有几个概念，需要梳理一下：
- Join Point：连接点的含义是指明切面可以插入的地方，这个点可以在函数调用时，或者正常流程中某一行等位置，加入切面的处理逻辑，来实现代码增强效果。
- Advice：通知，表示在特定的连接点采取的操作。
- Adivisor：通知者，它实现了Advice。
- Interceptor：拦截器，作用是拦截流程，方便处理。
- Pointcut：切点。

## Spring IOC
将获取对象的方式交给BeanFactory，这种将控制权交给别人的思想，就可以称作：控制反转(Inverse of Control, IOC)。而BeanFactory根据指定的beanName去获取和创建对象的过程，就可以称作：依赖查找(Dependency Lookup, DL)。
## 依赖查找与依赖注入的对比
- 作用目标不同
	- 依赖注入的作用目标通常是类成员
	- 依赖查找的作用目标可以是方法体内，也可以是方法体外
-  实现方式不同
	- 依赖注入通常借助一个上下文被动的接收
	- 依赖查找通常主动使用上下文搜索
## BeanFactory 与ApplicationContext的对比
BeanFactory接口提供了一个抽象的配置和对象的管理机制，ApplicationContext是BeanFactory的子接口，它简化了与AOP的整合、消息机制、事件机制，以及对Web环境的扩展(WebApplicationContext等)，BeanFactory是没有这些扩展的。
`ApplicationContext`主要扩展了以下功能：
- AOP的支持(`AnnotationAwareAspectJAutoProxyCreator`作用于Bean的初始化自后)
- 配置元信息(`BeanDefinition`、`Environment`、注解等)
- 资源管理(`Resource`抽象)
- 事件驱动机制(`ApplicationEvent`、`ApplicationListener`)
- `Environment`抽象(SpringFramework3.1以后)
## SpEL表达式
SpEL的语法统一用#{}表示，花括号内部编写表达式语言。
SpEL可以引用Bean属性，也可以调用方法。
```java
// 引用Bean的属性，在注入属性时通过SpEL表达式
@Component
public class Green {
    
    @Value("#{'copy of ' + blue.name}")
    private String name;
    
    @Value("#{blue.order + 1}")
    private Integer order;
```
---
```java
    @Component public class White { 
      @Value("#{blue.name.substring(0, 3)}") 
      private String name; 

      @Value("#{T(java.lang.Integer).MAX_VALUE}") 
      private Integer order;

```
	注意，直接引用类的属性(静态属性)，需要在类的全限定名外面使用T()包围。
## @Autowired注入的原理逻辑
先拿属性对应的类型，去IOC容器中找Bean，如果找到了一个，直接返回；如果找到多个类型一样的Bean，把属性名拿过去，跟这些Bean的id逐个比对，如果有一个相同的，直接返回；如果没有任何相同的id与要注入的属性名相同，则会抛出`NoUniqueBeanDefinitionException`异常。
## 依赖注入的目的和优点？
首先，一来注入作为IOC的实现方式之一，目的就是解耦，我们不再需要直接去new那些一来的类对象(直接依赖会导致对象的创建机制、初始化过程难以统一控制)；而且，如果组件存在多级依赖，一来注入可以将这些以来的关系简化，开发者只需要定义好谁依赖谁即可。
除此之外，依赖注入的另一个特点是依赖对象的可配置：通过xml或者注解声明，可以指定和调整组件注入的对象，借助Java的多态特性，可以不需要大批量的修改完成依赖注入的对象替换(面向接口编程与依赖注入配合近乎完美)。
## BeanFactory与FactoryBean的区别
`BeanFactory`：SpringFramework中实现IOC的最底层容器(此处的回答可以从两个角度出发：从类的继承结构上看，它是最顶级的皆苦，也就是最顶层的容器实现；从类的组合结构来看，它则是最深层次的容器，ApplicationContext在最底层组合了BeanFactory)
`FactoryBean`：创建对象的工厂Bean，可以使用它来直接创建一些初始化流程比较复杂的对象。
## SpringFramework中控制Bean声明周期的三种方式
![[Pasted image 20240726184002.png]]
`BeanFactory`提供了如下基础的特性：
- 基础的容器
- 定义了作用域的概念
- 集成环境配置
- 支持多种类型的配置元
- 层次性的设计
- 完整的生命周期控制机制
`HierarchicalBeanFactory`，它是层次性的`BeanFactory`。
`AutowireCapableBeanFactory`本身可以支持自动装配，而且还可以让现有的一些Bean也能支持自动装配。AutowireCapableBeanFactory一般不要让咱自己用，而是在与其他框架进行集成时才使用。AutowireCapableBeanFactory不由ApplicationContext实现但可获取。可以通过`getAutowireCapableBeanFactory()`方法进行访问。
![[Pasted image 20240729114107.png]]

普通的`BeanFactory`只有读操作，而`ConfigurableBeanFactory`具有写操作，一般以Configurable开头的BeanFactory或者ApplicationContext都具有写的操作。
## BeanFactory的实现类们
![[Pasted image 20240729114156.png]]
`AbstractBeanFactory`是最终`BeanFactory`的基础实现，它具有最基础的功能，并且它可以从配置源(xml、LDAP、RDBMS等)获取Bean的定义信息。
SPI:全称为Service Provider Interface，是jdk内置的一种服务提供发现机制。说白了，它可以加载预先在特定位置下配置的一些类。
## AbstractAutowireCapableBeanFactory提供Bean的创建逻辑实现
`AbstractAutowireCapableBeanFactory`继承了`AbstractBeanFactory`抽象类，还额外实现了`AutowireCapableBeanFactory`接口，实现这个接口就代表着，它可以实现自动注入的功能。除此之外，它还把`AbstractBeanFactory`的`createBean`方法给实现了，代表它还具有创建Bean的功能。
`AbstractAutowireCapableBeanFactory`还实现了属性赋值和组件注入。
`AbstractAutowireCapableBeanFactory`保留了`resolveDependency`模板方法，这个方法的作用是解析Bean的成员中定义的属性依赖关系。
`AbstractAutowireCapableBeanFactory`不负责BeanDefinition的注册
## DefaultListableBeanFactory
`DefaultListableBeanFactory`是BeanFactory最终的默认实现。
`DefaultListableBeanFactory`会先注册Bean定义信息再创建Bean。
`DefaultListableBeanFactory`不负责解析Bean定义文件。
`DefaultListableBeanFactory`的替代实现是`StaticListableBeanFactory`，它只能管理单例Bean，而且没有跟Bean定义等相关的操作，SpringFramework默认也不用它。
## XmlBeanFactory
`XmlBeanFactory`在springframework3.1之后，该类正式被标记为过时，替代方案是使用`DefaultListableBeanFactory` + `XmlBeanDefinitionReader`，这种设计更加符合组件的单一职责原则。

# ApplicationContext
| Feature                                                                   | BeanFactory | ApplicationContext |
| ------------------------------------------------------------------------- | ----------- | ------------------ |
| Bean instantiation/wiring --- Bean的实例化和属性注入                               | Yes         | Yes                |
| Integrated lifecycle management --- 生命周期管理                                | No          | Yes                |
| Automitic `BeanPostProcessor` registration --- Bean后置处理器的支持               | No          | Yes                |
| Automatic `BeanFactoryPostProcessor` registration --- BeanFactory后置处理器的支持 | No          | Yes                |
| Convenient `MessageSource` access(for internalization) --- 消息转换服务(国际化)    | No          | Yes                |
| Built-in `ApplicationEvent ` publication mechanism --- 事件发布机制(事件驱动)       | No          | Yes                |

![[Pasted image 20240729145019.png]]
**AplicationContext是SpringFramework的最最核心。**
## ConfigurableApplicationContext
与`ConfigurableBeanFactory`类似，它也给`ApplicationContext`提供了"可写"的功能。
`ConfigurableApplicationContext`提供了可配置的可能，该接口中扩展了`setParent`、`setEnvironment`、`addBeanFactoryPostProcessor`、`addApplicaitonListener`等方法，都是可以改变`ApplicaitonContext`本身的方法。
`ConfigurableApplicationContext`只希望被调用启动和关闭，该类扩展了一些方法，但是它一般情况不希望让咱开发者调用，而是只调用启动(refresh)和关闭(close)方法。
## ApplicationContext的实现类们
![[Pasted image 20240729154219.png]]
## AbstractApplicationContext
**这个类是`ApplicatonContext`最最最核心的实现类，没有之一。**
- `AbstractApplicaitonContext`中定义和实现了绝大部分应用上下文的特性和功能。
- `AbstractApplicaitonContext`只构建够能抽象，主要规范功能(借助模板方法)，实际的动作它不管，让子类自行实现。
- `AbstractApplicaitonContext`可以处理特殊类型的Bean，ApplicationContext比BeanFactory强大的地方是支持更多的机制，这里面就包括**后置处理器、监听器**等，而这些器，说白了也都是一个一个的Bean，BeanFactory不会把它们区别对待，但是`ApplicaitonContext`就可以区分出来，并且赋予他们发挥特殊能力的机会。
- `AbstractApplicaitonContext`可以转换为多种类型，ApplicationContext实现了国际化的接口`MessageSource`、事件广播器的接口`ApplicationEventMulticaster`，那作为容器，它会把自己看成一个Bean，以支持不同类型的组件注入需要。
- `AbstractApplicaitonContext`提供默认的加载资源文件策略，默认情况下- - 
- `AbstractApplicaitonContext`加载资源文件的策略是直接继承了`DefaultResourceLoader`的策略，从类路径下加载；但在Web项目中，可能策略就不一样了，它可以从`ServletContext`中加载(扩展的子类`ServletContextResourceLoader等)。
## GenericAppliaitonContext
- `GenericAppliaitonContext`中组合了一个`DefaultListableBeanFactory`,由此可以得到一个非常重要的信息：`ApplicaitonContext`并不是继承了`BeanFactory`的容器，而是组合了`BeanFactory`。
- `GenericAppliaitonContext`借助BeanDefinitionRegistry处理特殊Bean。BeanDefinitionRegistry(Bean定义的注册器)，`GenericAppliaitonContext`实现了它，但是其中实现的定义注册方法`registerBeanDefiniton`，在底层还是调用的`DefaultListableBeanFactory`执行`registerBeanDefinition`方法，说明它也没有对此做什么扩展。
- `GenericAppliaitonContext`只能刷新一次
- `GenericAppliaitonContext`的替代方案是用xml
- `GenericAppliaitonContext`不支持特殊Bean定义的可刷新读取
## AbstractRefreshableApplicationContext
- `AbstractRefreshableApplicationContext`支持多次刷新
- `AbstractRefreshableApplicationContext`刷新的核心是加载Bean定义信息
- `AbstractRefreshableApplicationContext`额外提供了Web环境的功能
- ......
## ClassPathXmlApplicationContext
- `ClassPathXmlApplicationContext`是一个最终落地实现，它支持的配置文件加载位置都是classpath下取，这种方式的一个好处是：如果工程中依赖了一些其他的jar包，而工程启动时需要同时传入这些jar包中的配置文件，那`ClassPathXmlApplicationContext`就可以加载它们。
- `ClassPathXmlApplicationContext`使用Ant模式声明配置文件路径。
- `ClassPathXmlApplicationContext`解析的配置文件有先后之分，通常情况下，如果一个jar包的xml配置文件中声明了一个Bean，并且又在工程的resources目录下又声明了同样的Bean，则jar包中声明的Bean会被覆盖，这也就是陪孩子文件加载优先级的设定。
## AnnotationConfigApplicationContext(注解驱动的IOC容器)
注解驱动，除了`@Component`及其衍生出来的几个注解，更重要的是`@Configuration`注解，一个被`@Configuration`标注的类相当于一个xml配置文件。`AnnotationConfigApplicationContext`解析的配置类也有先后之分。
## 事件机制&监听器
SpringFramework的事件驱动核心概念：事件源、事件、广播器、监听器。
- 事件源：发布事件的对象
- 事件：事件源发布的信息/作出的动作
- 广播器：事件真正广播给监听器的对象【即ApplicationContext】
	- `ApplicationContext` 接口有实现`ApplicaitonEventPublisher`接口，具备事件广播器的发布事件的能力
	- `ApplicaitonEventMulticaster`组合了所有的监听器，具备事件广播器的广播时间的能力
- 监听器：监听事件的对象
Spring内置四个事件， ContextRefreshedEvent&ContextClosedEvent ， ContextStartedEvent&ContextStoppedEvent。
# 模块装配
什么是模块？
通常理解下，模块可以理解成一个一个的可以分解、组合、更换的单元，模块与模块之间可能存在一定的依赖，模块的内部通常是高内聚的，一个模块通常都是解决一个独立的问题(如引入事务模块是为了解决数据库操作的最终一致性)。其实按照这个理解来看，我们平时的一个一个功能，也可以看成一个个的模块；封装的一个个组件，可以看做是模块。
什么是模块装配?
既然模块是功能单元，那模块装配，就可以理解为**把一个模块需要的核心功能组件都装配好，** 当然如果有尽可能简便的方式那最好。
## SpringFramework中的模块装配
在3.1之后引入大量`@EnableXXX`注解，来快速整合激活相对应的模块。
- `@EnableTransactionManagement`：开启注解事务驱动
- `@EnableWebMvc`：激活SpringWebMvc
- `@EnableAspectJAutoProxy`：开启注解AOP编程
- `@EnableScheduling`：开启调度功能(定时任务)
模块装配的核心原则：自定义注解 + `@Import`导入组件，自定义注解的内容如下所示：
```java
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE})
@Documented
@Import({DelegatingWebMvcConfiguration.class})
public @interface EnableWebMvc {
}
```
模块装配需要一个最核心的注解`@Import`，它要标注在我们自定义的注解上面，`@Import`需要传入value值，这个值可以是导入配置类、`ImportSelector`的实现类，`ImportBeanDefinitionRegister`的实现类，或者普通类。`@Configuration`标注的配置类也会被注册到IOC容器称为一个Bean，但是ImportSelector的实现类不会被注册到IOC容器中。ImportBeanDefinitionRegisterar的实现类也不会注入到IOC容器里面。
模块装配说白了就是这四种方式的综合使用。
## 条件装配
### @Profile
@Profile注解可以标注在一组组件上，当一个配置属性(并不是文件)激活时，它才会起作用，而激活这个属性的方式有很多种(启动参数、环境变量、web.xml配置等)，但是需要在refresh执行之前，annotation...ApplicaitonContext只会refresh一次。
### @Conditional
@Conditional注解可以指定匹配条件，而被@Conditional注解标注的 组件类/配置类/组件工厂方法必须满足@Conditonal中指定的条件，才会被创建/解析。
## 组件扫描
### @ComponentScan
### 包扫描的过滤
在实际开发的场景中，我们用包扫描拿到的组件不一定全部都需要，也或者只有一部分需要，这个时候就需要用到包扫描的过滤了。
- **按注解过滤包含** : 如下所示，通过在`@ComponentScan`注解中声明`includeFilters`属性，让它把含有`@Animal`注解的类扫描进来。`@ComponentScan`注解中还有一个属性：useDefaultFilters，它代表的是"是否启用默认的规则",默认是true。而默认规则就是扫描那些以`@Component`注解为基准的模式注解。
```java
@Configuration
@ComponentScan(basePackages = "com.linkedbear.spring.annotation.f_typefilter",
               includeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, value = Animal.class))
public class TypeFilterConfiguration {
    
}
```
- **按注解排除** : 通过excludeFilters属性来进行排除。
```java
@Configuration @ComponentScan(basePackages = "com.linkedbear.spring.annotation.f_typefilter", excludeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, value = Animal.class)) public class TypeFilterConfiguration { }
```
**排除型过滤器会排除掉其他过滤规则已经包含进来的Bean。**
- **按类型过滤** : Filter中的type类型为FilterType.ASSIGNABLE_TYPE时可以按类型进行顾虑。
```java
@Configuration @ComponentScan(basePackages = "com.linkedbear.spring.annotation.f_typefilter", includeFilters = {@ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, value = Color.class)}, excludeFilters = {@ComponentScan.Filter(type = FilterType.ANNOTATION, value = Animal.class)}) public class TypeFilterConfiguration { }
```
- **正则表达式过滤**：内置的模式还有两种表达式的过滤规则，分别是"切入点表达式顾虑"和"正则表达式过滤"。如下所示可以通过正则表达式过滤包含Demo开头的bean。
```java
@Configuration
@ComponentScan(basePackages = "com.linkedbear.spring.annotation.f_typefilter",
               includeFilters = {
                       @ComponentScan.Filter(type = FilterType.REGEX, pattern = "com.linkedbear.spring.annotation.f_typefilter.+Demo.+")
               },
               excludeFilters = {
                       @ComponentScan.Filter(type = FilterType.ANNOTATION, value = Animal.class),
                       @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, value = Color.class)
               })
public class TypeFilterConfiguration {
    
}
```
- **自定义过滤**：如果预设的几种模式都不能满足要求，那就要用编程式过滤方式了，也就是自定义过滤规则。需要实现`TypeFilter`接口，如下所示GreenTypeFilter为自定义的过滤规则。
```java
@Configuration
@ComponentScan(basePackages = "com.linkedbear.spring.annotation.f_typefilter",
               includeFilters = {
                       @ComponentScan.Filter(type = FilterType.REGEX, pattern = "com.linkedbear.spring.annotation.f_typefilter.+Demo.+")
               },
               excludeFilters = {
                       @ComponentScan.Filter(type = FilterType.ANNOTATION, value = Animal.class),
                       @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, value = Color.class),
                       @ComponentScan.Filter(type = FilterType.CUSTOM, value = GreenTypeFilter.class)
               })
public class TypeFilterConfiguration {
    
}
```
## 资源管理
![[Pasted image 20240730153132.png]]
### Java原生资源加载方式，Java原生能加载到哪些地方资源？
- 借助ClassLoader加载类路径下的资源
- 借助File加载文件系统中的资源
- 借助URL和不同的协议加载本地/网络上的资源
### SpringFramework的实现
- ClassLoader -> `ClassPathResource` [classpath:/]
- File -> `FileSystemResource` [file:/]
- URL -> `UrlResource` [xxxx:/]
除了这三种实现，还有对应于 `ContextResource`的实现：`ServletContextResource`，它意味着资源是去ServletContext域中寻找。
### SpringFramework加载资源的方式
`AbstractApplicationContext`中，通过类继承关系可以得知它继承了`DefaultResourceLoader`，也就是说，`ApplicationContext`具有加载资源的能力。
## @PropertySource的使用
### 1. @PropertySource引入properties文件
### 2. @PropertySource引入xml文件
### 3. @PropertySource引入yaml文件
```java
public @interface PropertySource {
    // ......

	/**
	 * Specify a custom {@link PropertySourceFactory}, if any.
	 * <p>By default, a default factory for standard resource files will be used.
	 * @since 4.3
	 */
	Class<? extends PropertySourceFactory> factory() default PropertySourceFactory.class;
}
```
如果需要@PropertySource可以解析Yaml文件，需要实现PropertySourceFactory去解析yaml文件。并将自己实现的这个factory设置到@PropertySource中的factory属性上去。
## 配置源&配置元信息
### SpringFramework中的配置元信息
1. SpringFramework中定义的Bean也会封装为一个个的Bean的元信息，也就是`BeanDefinition`。它包含了一个Bean所需要的几乎所有维度的定义：
- Bean的全限定名 className
- Bean的作用域 scope
- Bean是否延迟加载lazy
- Bean的工厂Bean名称factoryBean
- Bean的构造方法参数列表constructorArgumentValues
- Bean的属性值propertyValues
- .....
2. IOC容器的配置原信息
	1. beans的配置元信息
	2. context的配置元信息
3. beans的其他配置元信息：`<alias />`、`<import />`
4. properties等配置元信息
## Environment抽象
### 如何概述Environment
`Environment`是SpringFramework3.1引入的抽象概念，它包含profiles和properties的信息，可以实现统一的配置存储和注入、配置属性的解析等。其中profiles实现了一种基于模式的环境配置，properties则应用与外部配置。
## Bean和BeanDefinition
### 如何概述BeanDefinition
`BeanDefinition`描述了SpringFramework中bean的元信息，它包含bean的类信息、属性、行为、一来关系、配置信息等。`BeanDefition`具有层次性，并且可以在IOC容器初始化阶段被`BeanDefinitionRegistryPostProcessor`构造和注册，被`BeanFactoryPostProcessor`拦截修改等。
![[Pasted image 20240731105427.png]]
`BeanDefiniton`的特征： `BeanDefinition`继承了`AttributeAccessor`接口，具有配置bean属性的功能。(配置bean就包含了访问、修改、移除在内的操作)
`AbstractBeanDefinition`作为`BeanDefinition`的抽象实现，它里面已经定义好了一些属性和功能(大部分都有了)。
`GenericBeanDefinition`仅比`AbstractBeanDefition`多了一个parentName属性而已。
`RootBeanDefition`与`ChildBeanDefition`，其中`ChildBeanDefinition`没有无参构造器，必须要传入`parentName`才可以。`RootBeanDefinition`不能继承其他`BeanDefinition`。我们发现，`RootBeanDefinition`在`AbstractBeanDefinition`的基础上，又扩展除了下面的Bean的信息：
- Bean的id和别名
- Bean的注解信息
- Bean的工厂相关信息(是否为工厂Bean、工厂类、工厂方法等)
### BeanDefinition是如何生成的
1. 通过xml加载`BeanDefinition`，它的读取工具是`XmlBeanDefinitonReader`，它会解析xml配置文件，最终来到`DefaultBeanDefinitionDocumentReader`的`doRegisterBeanDefinitions`方法，根据xml配置文件中的bean定义构造`BeanDefinition`，最底层创建`BeanDefiniton`的位置在`org.springframework.beans.factory.support.BeanDefinitionReaderUtils#createBeanDefinition`。
2. 通过模式注解 + 组件扫描的方式构造的`BeanDefinition`，它的扫描工具是`ClassPathBeanDefinitionScanner`，它会扫描指定包路径下包含特定模式注解的类，核心工作方法是`doScan`方法，它会调用到父类`ClassPathScanningCandidateComponentProvider`的`findCandidateComponents`方法，创建`ScannedGenericBeanDefinition`并返回。
3. 通过配置类 + `@Bean`注解的方式构造的`BeanDefinition`最复杂，它涉及到配置类的解析。配置类的解析要追踪到`ConfiguratinClassPostProcessor`的`processConfigBeanDefinitions`方法，它会处理配置类，并交给`ConfigurationClassParser`来解析配置类，取出所有标注了`@Bean`的方法。随后，这些方法又被`ConfigurationClassBeanDefinitionReader`解析，最终在底层创建`ConfigurationClassBeanDefinition`并返回。
## BeanDefinition与BeanDefinitionRegistry
`BeanDefinitionRegistry`是BeanDefinition的仓库，所有`BeanDefinition`都存储在该仓库中。
`BeanDefinitionRegistry`中有增删改查`BeanDefinition`的方法：
```java
void registerBeanDefinition(String beanName, BeanDefinition beanDefinition) throws BeanDefinitionStoreException; void removeBeanDefinition(String beanName) throws NoSuchBeanDefinitionException; BeanDefinition getBeanDefinition(String beanName) throws NoSuchBeanDefinitionException;
```
### BeanDefinitionRegistry的主要实现是DefaultListableBeanFactory
### 如何概述BeanDefinitionRegistry
`BeanDefinitionRegitry`是维护`BeanDefinition`的注册中心，它内部存放了IOC容器中bean的定义信息，同时`BeanDefinitionRegistry`也是支撑其他组件和动态注册Bean的重要组件。在SpringFramework中，`BeanDefinitionRegistry`的实现是DefaultListableBeanFactory。
### 概述BeanPostProcessor
`BeanPostProcessor`是一个容器的扩展点，它可以在bean的生命周期过程中，初始化阶段前后添加自定义处理逻辑，并且不同IOC容器间的BeanPostProcessor不会相互干预。
### Bean的初始化阶段的全流程：
`BeanPostProcessor#postProcessBeforeInitialization → @PostConstruct → InitializingBean → init-method → BeanPostProcessor#postProcessAfterInitialization`
如下图所示：
![[Pasted image 20240731181632.png]]
![[Pasted image 20240731182203.png]]
### Spring中的MergeDefinitionProcessor
在SpringFramework中，一个非常重要的`MergeDefinitionPostProcessor`的实现，就是`AutowiredAnnotationBeanPostProcessor` ，它负责给bean实现注解的自动注入，而注入的依据就是`postProcessMergedBeanDefinition` 后整理的标记。
`postProcessMergedBeanDefinition`方法发生在bean的实例化之后，自动注入之前。而这个设计，就是为了在属性赋值和自动注入之前，把要注入的属性都收集好，这样才能顺利的想下执行注入的逻辑。
## BeanFactoryPostProcessor
`BeanFactoryPostProcessor`可以在Bean实例的初始化之前修改定义信息，换句话说，它可以对原有的`BeanDefinition`进行修改。
![[Pasted image 20240801095738.png]]
### 概述BeanFactoryPostProcessor
`BeanFactoryPostProcessor`是容器的扩展点，它用于IOC容器的生命周期中，所有`BeanDefinition`都注册到`BeanFactory`后回调触发，用于访问/修改已经存在的`BeanDefinition`。与`BeanPostProcessor`相同，它们都是容器隔离的，不同容器中的`BeanFactoryPostProcessor`不会相互起作用。
### 对比BeanPostProcessor与BeanFactoryPostProcessor
|        | BeanPostProcessor         | BeanFactoryPostProcessor                           |
| ------ | ------------------------- | -------------------------------------------------- |
| 处理目标   | bean实例                    | `BeanDefinition`                                   |
| 执行时机   | bean的初始化阶段前后(已经创建出bean对象) | `BeanDefinition`解析完毕，注册进`BeanFactory`的阶段(bean未实例化) |
| 可操作的空间 | 给bean的属性赋值、创建代理对象等        | 给`BeanDefinition`中增删属性、移除`BeanDefinition`等         |
### `BeanDefinitionRegistryPostProcessor`
![[Pasted image 20240801101147.png]]
由于实现了`BeanDefinitionRegistryPostProcessor`的类同时也实现了`BeanFactoryPostProcessor`的`postProcessBeanFactory`方法，所以在执行完所有`BeanDefinitionRegistryPostProcessor`的接口方法后，会**立即执行**这些类的`postProcessBeanFactory`方法，之后才是执行那些普通的只实现了`BeanFactoryPostProcessor`的`postProcessBeanFactory`方法。
### 概述BeanDefiniitionRegistryPostProcessor
`BeanDefinitionRegistryPostProcessor`是容器的扩展点，它用于IOC容器的生命周期中，所有`BeanDefinition`都准备好，即将加载到`BeanFactory`实回调触发，用于给`BeanFactory`中添加新的`BeanDefinition`。`BeanDefinitionRegistryPostProcessor`也是容器隔离的，不同容器中的`BeanDefinitionRegistryPostProcessor`不会相互起作用。
### `BeanDefinitionRegistryPostProcessor`中方法的执行时机
所有的`BeanDefinitionRegistryPostProcessor`的`postProcessorBeanDefinitionRegistry`方法执行完毕后，然后回先执行它们的`postProcessBeanFactory`，然后才能轮到普通的`BeanFactoryPostProcessor`执行。
### `BeanDefinitionRegistryPostProcessor`中还可以在`postProcessBeanDefinitionRegistry`方法中，动态的注册`BeanPostProcessor`。
```java
@Component public class AnimalProcessorRegisterPostProcessor implements BeanDefinitionRegistryPostProcessor { @Override public void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException { registry.registerBeanDefinition("animalNameSetterPostProcessor", new RootBeanDefinition(AnimalNameSetterPostProcessor.class)); } @Override public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException { } }
```
### 三种后置处理器的对比
|        | **BeanPostProcessor**       | **BeanFactoryPostProcessor**                             | **BeanDefinitionRegistryPostProcessor**                              |
| ------ | --------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------- |
| 处理目标   | bean 实例                     | `BeanDefinition`                                         | `BeanDefinition` 、`.class` 文件等                                       |
| 执行时机   | bean 的初始化阶段前后（已创建出 bean 对象） | `BeanDefinition` 解析完毕并注册进 `BeanFactory` 之后（此时 bean 未实例化） | 配置文件、配置类已解析完毕并注册进 `BeanFactory` ，但还没有被 `BeanFactoryPostProcessor` 处理 |
| 可操作的空间 | 给 bean 的属性赋值、创建代理对象等        | 给 `BeanDefinition` 中增删属性、移除 `BeanDefinition` 等           | 向 `BeanFactory` 中注册新的 `BeanDefinition`                               |
## SPI概述
SPI全称叫`Service Provider Interface`服务提供接口，它可以通过一个指定的接口/抽象类，寻找到预先配置好的实现类(并创建实现类对象)。jdk1.6中有SPI的具体实现，SpringFramework3.2也引入了SPI的实现，而且比jdk的实现更加强大。
一个接口可以有多个实现类，通过SPI机制，可以将一个接口需要创建实现类的对象都罗列在一个特殊的文件中，SPI机制会将这些实现都实例化出对象并返回。
### JDK的SPI实现
jdk的SPI是需要遵循规范的：**所有定义的SPI文件都必须放在工程`META-INF/services`目录下，且文件名必须命名为接口/抽象类的全限定名，文件内容为接口/抽象类的具体实现类的全限定名，如果出现多个具体实现类，则每行声明一个类的全限定名，没有分隔符。**
### SpringFramework3.2中的SPI
SpringFramework中的SPI相比较于jdk原生的，那可就高级多了，因为它不仅仅局限于接口/抽象类，它可以是任何一个类、接口、注解。也正是因为可以支持注解的SPI，这个特性在Springboot中被疯狂利用(大名鼎鼎的`@EnableAutoConfiguration`)。
### spring声明SPI文件
SpringFramework的SPI文件也是有规矩的，它需要放在工程META-INF下，且文件名必须为spring.factories。而文件的内容，其实就是一个properties：
```java
com.linkedbear.spring.configuration.z_spi.bean.DemoDao=\ com.linkedbear.spring.configuration.z_spi.bean.DemoMySQLDaoImpl,\ com.linkedbear.spring.configuration.z_spi.bean.DemoOracleDaoImpl
```
## 事件&监听机制
### PayloadApplicationEvent
`PayLoadApplicaitonEvent`本身是有泛型的，如果不指定具体的泛型，则会监听所有`PayloadApplicationEvent`事件。如果指定了泛型，就只会监听指定泛型的payload事件了。使用该事件，我们只需要定义并注册监听器即可。
### SpringFramework中的实践模型
`ApplicationEventPublisher` 和 `ApplicationEventMulticaster`，它们分别代表事件发不起和事件广播器。事件发不起用来接受事件，并交给事件广播器处理；事件广播器拿到事件发不起的事件，并广播给监听器。`ApplicationContext`接口继承了`ApplicationEventPublisher`,拥有事件发布功能；`ApplicationContext`的抽象实现类`AbstractApplicationContext`组合了一个`ApplicationEventMulticaster`，拥有事件广播的能力。
## Bean完整的生命周期
### BeanDefinition的后置处理
![[Pasted image 20240802144812.png]]
### Bean的实例阶段
- BeanDefinition的合并
- bean的实例化
- 属性赋值 + 依赖注入，在这个环节，最重要的是如何处理`<bean>`中的`<property>`标签、bean中的`@Value`、`@Autowired`等自动注入的注解。`InstantiationAwareBeanPostProcessor`可以在bean的实例化之后、初始化之前执行`postProcessAfterInstantiation`方法，以及`postProcessProperties`方法完成属性赋值。`AutowiredAnnotationBeanPostProcessor`就是实现了`InstantiationAwareBeanPostProcessor`接口，从而完成了`@Autowired`的属性注入。
- bean的初始化
- bean的启动，`org.springframework.context.support.AbstractApplicationContext#refresh`会调用`finishRefresh`，而该方法里面会找出所有实现了`Lifecycle`接口的bean，并调用它们的`start`方法。一般实现`Lifecycle`的`start`方法多用于建立连接、加载资源等等操作，以备程序运行期使用。
### bean销毁阶段的内容
关闭`ApplicationContext`会顺序执行以下几步：
1. 广播关闭时间(ContextClosedEvent事件)
2. 通知所有实现了`Lifecyble`的bean回调`close`方法
3. 销毁所有bean
4. 关闭BeanFactory
5. 标记本身为不可用
实现了`Lifecyble`接口的bean的close方法的执行时机在销毁阶段是最靠前的，一般用来关闭连接、释放资源等操作，因为程序终止了，这些资源也就没有必要持有了。
bean的销毁回调：`BeanPostProcessor`的回调包含bean的初始化之前和初始化之后，但`DestructionAwareBeanPostProcessor`只包含bean销毁回调之前的动作，没有之后。
## BeanDefinition阶段
### 加载xml配置文件的流程
**首先`ClassPathXmlApplicationContext`在`refesh`之前，会指定传入的xml配置文件的路径，执行`refresh`方法时，会初始化`BeanFactory`，触发xml配置文件的读取、加载和解析。其中xml的读取需要借助`XmlBeanDefinitionReader`，解析xml配置文件则使用`DefaultBeanDefinitionDocumentReder`，最终解析xml中的元素，封装出`BeanDefinition`，最后注册到`BeanDefinitionRegistry`。**
![[Pasted image 20240812113034.png]]
## 加载注解配置类
相比较于xml配置文件，注解配置类的加载时机会晚一些，它用到了一个至关重要的`BeanDefinitionRegistryPostProcessor`，而且无论如何，这个后置处理器都是最优先执行的，它就是`ConfigurationClassPostProcessor`。
用简单的语言概括，这个方法(`org.springframework.context.support.PostProcessorRegistrationDelegate#invokeBeanFactoryPostProcessors`)的执行机制如下：
1. 执行`BeanDefinitionRegistryPostProcessor`的`postProcessBeanDefinitionRegistry`方法
	1. 执行实现了`PiorityOrdered`接口的`BeanDefinitionRegistryPostProcessor`
	2. 执行实现了`Ordered`接口的`BeanDefinitionRegistryPostProcessor`
	3. 执行普通的`BeanDefinitionRegistryPostProcessor`
2. 执行`BeanDefinitionRegistryPostProcessor`的`postProcessBeanFactory`方法
	1. 同上
3. 执行`BeanFactoryPostProcessor`的`postProcessBeanFactory`方法
	1. 同上
### ImportSelector的扩展
在SpringFramework4.0中，`ImportSelector`多了一个子接口：`DeferredImportSelector`，它的执行时机比`ImportSelector`更晚，他会在注解配置类的所有解析工作完成后才执行。一般情况下，`DeferredImportSelector`会跟`@Conditinal`的注解配合使用，完成**条件装配**。
### 加载注解配置类流程总结
**直接配置类的解析发生在`BeanDefinitionRegistryPostProcessor`的执行阶段，它对应的核心后置处理器是`ConfigurationClassPostProcessor`，它主要负责两个步骤三件事情：解析配置类、注册`BeanDefinition`。三件事情包括：1)解析`@ComponentScan`并进行包扫描，实际进行包扫描的组件是`ClassPathBeandefinitionScanner`；2)解析配置类中的注解 (如`@Import`、`@ImportResource`、`@PropertySource`等)并处理，工作的核心组件是`ConfigurationClassParser`；3)解析配置类中的`@Bean`并封装`BeanDefinition`，实际解析的组件是`ConfigurationClassBeanDefinitionReader`。**
![[Pasted image 20240812113000.png]]
## BeanDefinition的后置处理
执行完`ConfigurationClassPostProcessor`之后，在xml和配置类中定义的BeanDefinition就都解析和准备好了，并且已经加载进`BeanDefinitionRegistry`中。下面还会有`BeanDefinitionRegistryPostProcessor`和`BeanFactoryPostProcessor`的执行。
## 怎么描述BeanDefinition部分的声明周期
首先，bean的生命周期分为`BeanDefinition`阶段和bean实例阶段。
1. **加载xml配置文件** 发生在基于xml配置文件的`ApplicationContext`中`refresh`方法的`BeanFactory`初始化阶段，此时`BeanFactory`刚刚构建完成，它会借助`XmlBeanDefinitionReader`来加载xml配置文件，并使用`DefaultBeanDefinitionDocumentReader`解析xml配置文件，封装声明的`<bean>`标签内的内容并转换为`BeanDefinition`。
2. **解析注解配置类** 发生在`ApplicationContext`中refresh方法的`BeanDefinitionRegistryPostProcessor`执行阶段，该阶段首先会执行`ConfigurationClassPostProcessor`的`postProcessBeanDefinitionRegistry`方法。`ConfigurationClassPostProcessor`中会找出所有的配置类，排序后依次解析，并借助`ClassPathBeanDefinitionScanner`实现包扫描的`BeanDefinition`封装，借助`ConfigurationClassBeanDefinitionReader`实现`@Bean`注解方法的`BeanDefinitin`解析和封装。
3. **编程式构造** `BeanDefinition` 也是发生在`ApplicationContext`中`refresh`方法的`BeanDefinitionRegistryPostProcessor`执行阶段，由于`BeanDefinitionRegistryPostProcessor`中包含`ConfigurationClassPostProcessor`，而`ConfigurationClassPostProcessor`会执行`ImportBeanDefinitionRegistrar`的逻辑，从而达到编程式构造`BeanDefinition`并注入到`BeanDefinitionRegistry`的目的；另外，实现了`BeanDefiniitonRegistryPostProcessor`的类也可以编程式构造`BeanDefinition`，注入`BeanDefinitionRegistry`。

## IOC原理-Bean的生命周期-Bean的实例化阶段
为什么不能在循环中顺便初始化除PriorityOrdered的`BeanPostProcessor`：
**如果`BeanPostProcessor`的初始化逻辑是一边循环一边初始化，则可能会导致优先级低的`BeanPostProcessor`干预了优先级高的`BeanPostProcessor`，从而引发程序的运行情况异常。而正确的做法就只是初始化最高优先级的`BeanPostProcessor`，其余的都只是记录下全限定名，等所有高优先级的`BeanPostProcessor`都初始化完成后，再一次初始化低优先级的`BeanPostProcessor`(优先级低的`BeanPostProcessor`可能也需要被优先级高的`BeanPostProcessor`处理)**。

### bean实例化部分的生命周期：
1. bean的实例化
2. 属性赋值 + 依赖注入
3. bean的初始化生命周期回调
4. bean实例的销毁
在所有非延迟加载的单实例bean初始化之前，会先初始化所有的BeanPostProcessor。
在`ApplicationContext`的`refresh`方法中，`finishBeanFactoryInitialization`步骤会初始化所有的非延迟加载的单例bean。实例化bean的入口是`getBean` --> `doGetBean`，该阶段会合并`BeanDefinition`，并根据bean的scope选择实例化bean的策略。
创建bean的逻辑会走`createBean`方法，该方法中会先执行所有`InstantiationAwareBeanPostProcessor`的`postProcessBeforeInstantiation`方法尝试创建bean实例，如果成功创建，则会直接调用`postProcessAfterInitialization`方法初始化bean后返回；如果`InstantiationAwareBeanPostProcessor`没有创建bean实例，则会调用`doCreateBean`方法创建bean实例。在`doCreateBean`方法中，会先根据bean的`Class`中的构造器定义，决定如何实例化bean，如果没有定义构造器，则会使用无参构造器，反射创建bean对象。
![[Pasted image 20240813095736.png]]
## Bean的生命周期-Bean的初始化阶段
- `InitDestroyAnnotationBeanPostProcessor`负责收集跟JSR-250相关的初始化和销毁注解对应的元数据，即`@PostConstruct`和`PreDestroy`注解的后置处理器。
- `CommonAnnotationBeanPostProcessor`还能支持JAVA EE规范中的`@WebServiceRef`、`@EJB`、`@Resource`注解，并封装对应的注解信息。
- `AutowiredAnnotationBeanPostProcessor`负责收集自动注入的注解信息，在构造方法中，就已经指定好了默认支持`@Autowired`注解、`@Value`注解，如果classpath下有来自JSR 330的`@Inject`注解，也会一并支持。
**注解后置处理器小结：** 从这几个后置处理器中，我们就发现，可以支持bean中标注的注解的后置处理器，它们的处理方式都是先收集注解标注的信息，保存到缓存中，随后再处理时，只需要从缓存中取就可以了。

### `AutowiredAnnotationBeanPostProcessor#postProcessProperties`
在 `BeanFactoryPostProcessor` 或者 `BeanDefinitionRegistryPostProcessor` 中无法直接使用 `@Autowired` 直接注入 `SpringFramework` 中的内部组件（如 `Environment` ）？现在是否明白这个问题的答案了吗？当 `BeanDefinitionRegistryPostProcessor` 在初始化的阶段，还不存在 `BeanPostProcessor` 呢，所以那些用于支持依赖注入的后置处理器（ `AutowiredAnnotationBeanPostProcessor` ）还没有被初始化，自然也就没办法支持注入了。正确的做法是借助 Aware 接口的回调注入。
### bean初始化部分的生命周期：
**bean对象创建完成后，会进行属性赋值、组件依赖注入，以及初始化阶段的方法回调。在`populateBean`属性赋值阶段，会实现收集好bean中标注了依赖注入的注解(`@Autowired`、`@Value`、`@Resource`、`@Inject`)，之后会借助后置处理器，回调`postProcessProperties`方法实现依赖注入。**
**属性赋值和依赖注入之后，会回调执行bean的初始化方法，以及后置处理器的逻辑：首先会执行Aware相关的回调注入，之后执行后置处理器的前置回调，在后置处理器的前置方法中，会回调bean中标注了`@PostConstruct`注解的方法，所有的后置处理器前置回调后，会执行`InitializingBean`的`afterPropertiesSet`方法，随后是`init-method`指定的方法，等这些bean的初始化方法都回调完毕后，最后执行后置处理器的后置回调。**

**全部的bean初始化结束后，`ApplicaitonContext`的`start`方法触发时，会触发实现了`Lifecycle`的接口的bean的`start`方法。**
![[Pasted image 20240813160837.png]]
## Bean的生命周期-Bean的销毁阶段
### bean销毁阶段的生命周期
**bean对象在销毁时，由`ApplicationContext`发起关闭动作。销毁bean的阶段，由`BeanFactory`去除所有单实例bean，并逐个销毁。**
**销毁动作会先将当前bean依赖的所有bean都销毁，随后回调自定义的bean的销毁方法，之后如果bean中有定义内部bean则会一并销毁，最后销毁那些依赖了当前bean的bean。**

## IOC容器的生命周期概述
### `AbstractApplicationContext#refresh`
```java
public void refresh() throws BeansException, IllegalStateException {
    synchronized (this.startupShutdownMonitor) {
        // Prepare this context for refreshing.
        // 1. 初始化前的预处理
        prepareRefresh();

        // Tell the subclass to refresh the internal bean factory.
        // 2. 获取BeanFactory，加载所有bean的定义信息（未实例化）
        ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

        // Prepare the bean factory for use in this context.
        // 3. BeanFactory的预处理配置
        prepareBeanFactory(beanFactory);

        try {
            // Allows post-processing of the bean factory in context subclasses.
            // 4. 准备BeanFactory完成后进行的后置处理
            postProcessBeanFactory(beanFactory);

            // Invoke factory processors registered as beans in the context.
            // 5. 执行BeanFactory创建后的后置处理器
            invokeBeanFactoryPostProcessors(beanFactory);

            // Register bean processors that intercept bean creation.
            // 6. 注册Bean的后置处理器
            registerBeanPostProcessors(beanFactory);

            // Initialize message source for this context.
            // 7. 初始化MessageSource
            initMessageSource();

            // Initialize event multicaster for this context.
            // 8. 初始化事件派发器
            initApplicationEventMulticaster();

            // Initialize other special beans in specific context subclasses.
            // 9. 子类的多态onRefresh
            onRefresh();

            // Check for listener beans and register them.
            // 10. 注册监听器
            registerListeners();
          
            //到此为止，BeanFactory已创建完成

            // Instantiate all remaining (non-lazy-init) singletons.
            // 11. 初始化所有剩下的单例Bean
            finishBeanFactoryInitialization(beanFactory);

            // Last step: publish corresponding event.
            // 12. 完成容器的创建工作
            finishRefresh();
        } // catch ......

        finally {
            // Reset common introspection caches in Spring's core, since we
            // might not ever need metadata for singleton beans anymore...
            // 13. 清除缓存
            resetCommonCaches();
        }
    }
}
```
纵观整个`refesh`方法，每个动作的职责都很清晰，而且非常的有条理性。这个过程中，有对`BeanFactory`的处理，有对`ApplicationContext`的处理，有处理`BeanPostProcessor`的逻辑，有准备`ApplicationListener`的逻辑，最后它会初始化那些非延迟加载的单实例bean。整个`refresh`方法走下来，`ApplicaitonContext`也就全部初始化完毕了。
### ApplicationContext初始化中的扩展带你
- `invokeBeanFactoryPostProcessors`方法中的切入点
	- `ImportSelector & ImportBeanDefinitionRegistrar`，在`ConfigurationClassPostProcessor`的执行过程中，会解析`@Import`注解，取出里面的`ImportBeanDefinitionRegistrar`并执行，所以第一个扩展点是`ImportSelector`和`ImportBeanDefinitionRegistrar`了。
- `BeanDefinitionRegistryPostProcessor`，其可以拿到`BeanDefinitionRegistry`的API，直接向IOC容器中注册新的`BeanDefinition`。
- `BeanFactoryPostProcessor`，该阶段的回调，可以拿到的参数是`ConfigurableListableBeanFactory`，拿到它就意味着，我们在这个阶段按理来讲不应该再向`BeanFactory`中注册新的`BeanDefinition`了，只能获取和修改现有的`BeanDefinition`。这个阶段可以提早初始化bean对象，但是需要注意这个阶段初始化的bean有一个共同的特点：能使用`Aware`回调注入，但无法使用`@Autowired`等自动注入的注解进行依赖注入，且不会产生任何代理对象。
- `registerBeanPostProcessors`
- `finishBeanFactoryInitialization`
	- `InstantiationAwareBeanPostProcessor#postProcessBeforeInstantiation`，从bean的创建阶段之前，就有`InstantiationAwareBeanPostProcessor`来代替创建，如果没有任何`InstantiationAwareBeanPostProcessor`可以拦截创建，则会走真正的bean对象实例化流程。
	- `SmartInstantiationAwareBeanPostProcessor#determineCandidateConstructor`
	- `MergedBeanDefinitionPostProcessor#postProcessMergedBeanDefinition`，在`createBeanInstance`方法执行完毕之后，此时bean对象已经创建出来了，只是没有任何属性值的注入而已。此时`doCreateBean`方法会走到`applyMergedBeanDefinitionPostProcessors`方法，让这些`MergedBeanDefinitionPostProcessor`去手机bean所属的Class中的注解信息，一下列举三个关键的`MergedBeanDefinitionPostProcessor`，它们分别是`InitDestroyAnnotationBeanPostProcessor`(收集`@PostConstruct`与`@PreDestroy`注解)、`CommonAnnotationBeanPostProcessor`(收集JSR 250的其他注解)、`AutowiredAnnotationBeanPostProcessor`(收集自动注入相关的注解)。
- `InstantiationAwareBeanPostProcessor#postProcessAfterInstantiation`,它要负责控制是否继续走接下来的`populateBean`和`initializeBean`方法初始化bean。所以如果在这里切入扩展的话，只能起到流程控制的作用。
- `InstantiationAwareBeanPostProcessor#postProcessProperties`,这个步骤会将bean对象对应的`PropertyValues`中封装赋值和注入的数据应用给bean实例。在该阶段SpringFramework内部起作用的后置处理器`AutowiredAnnotationBeanPostProcessor `，它会搜集bean所属的Class中标注了`@Autowired`、`@Value`、`@Resource`等注解的属性和方法，并反射赋值/调用。在此处扩展逻辑的话，相当于扩展了后置处理器的属性赋值+依赖注入的自定义逻辑。当这个动作执行完毕之后，就不会再与属性赋值和组件注入的回调了。
- `BeanPostProcessor`,它的前后两个执行动作`postProcessBeforeInitialization`和`postProcessAfterInitialization`都发生在`initializeBean`方法中。在此处扩展逻辑，相当于针对一个接近完善的bean去扩展/包装。当后置处理器执行完`postProcessAfterInitialization`方法后，基本上就代表bean的初始化结束了。
- `SmartInitializingSingleton`
### 如何对比BeanFactory与ApplicationContext
`BeanFactory`接口提供了一个抽象的配置和对象的管理机制，`ApplicationContext`是`BeanFactory`的子接口，它简化了与AOP的整合、消息机制、事件机制，以及对Web环境的扩展(WebApplicaitonContext等)，`BeanFactory`是没有这些扩展的。
### ApplicationContext的类型
基于xml配置文件的`ApplicationContext`有`ClassPathXmlApplicationContext`和`FileSystemXmlApplicationContext`两种，它们的区别是加载xml配置文件的基准路径不同；基于注解驱动配置类的`ApplicationContext`只有`AnnotationConfigApplicationContext`，它可以基于配置类驱动，也可以基于包扫描路径驱动。
### 如何理解BeanDefinitionRegistry
`BeanDefinitionRegistry`是维护`BeanDefinition`的注册中心，它内部存放了IOC容器中的bean的定义信息，同时`BeanDefinitionRegistry`也是支撑其他组件和动态注册Bean的重要组件。在SpringFramework中，`BeanDefinitionRegistry`的实现是`DefaultListableBeanFactory`。
### 后置处理器的比较
 ![[Pasted image 20240814150059.png]]
  ### Bean初始化/销毁的三种生命周期控制方法对比
  ![[Pasted image 20240814152740.png]]
 
  ### SPI
  SPI是通过一种"服务寻找"的机制，动态的加载接口/抽象类对应的具体实现类，它把接口具体实现类的定义和声明权交给了外部化的配置文件中。
  jdk的SPI是需要遵循规范的：所有定义的SPI文件必须放在工程的`META-INF/services`目录下，且文件名必须命名为接口/抽象类的全限定名，文件内容为接口/抽象类的具体实现类的全限定名，如果出现多个具体实现类，则每行声明一个类的全限定名，灭有分隔符。
  SpringFramework中的SPI在要求上比较宽松，它不止可以基于接口/抽象类，还可以是任何一个类、接口、注解，并且这种机制被大量用于Springboot的自动装配中。
### 概述AOP
**AOP面向切面编程，全程Aspect Oriented Programming，它是OOP的补充。OOP关注的核心是对象，AOP的核心是切面(Aspect)。AOP可以在不修改功能代码本身的前提下，使用运行时动态代理的技术对已有代码逻辑增强。AOP可以实现组件化、可插拔式的功能扩展，通过简单配置即可将功能增强到指定的切入点。**
### AOP中的术语
- **Target：目标对象**，目标对象就是被代理的对象。
- **Proxy：代理对象**，jdk自带的动态代理实现如右边所示：`Proxy.newProxyInstance`返回的结果。
- **JoinPoint：连接点**，目标对象的所属类中，定义的所有方法。
- **Pointcut：切入点**，那些被拦截/被增强的连接点。注意，**切入点一定是连接点，连接点不一定是切入点。**
- **Advice：通知**，增强的逻辑，也就是增强的代码。**Proxy代理对象 = Target目标对象 + Advice通知**。
- **Aspect：切面**，Aspect 切面 = Pointcut 切入点 + Advice通知。
- **Weaving：织入**，织入就是将Advice通知应用到Target目标对象，进而生成Proxy代理对象的过程。
- **Introduction：引介**，可以在不修改原有类的代码的前提下，在运行期为原始类动态添加新的属性/方法。
- **通知类型：**
	- Before前置通知
	- After后置通知
	- AfterReturning返回通知
	- AfterThrowing异常通知
	- Around环绕通知
	
### 切入点表达式
```java
// 表示切入的方式是在FinanceService类型的public修饰，参数只有一个，并且类型是double类型的任意方法名
execution(public * com.linkedbear.spring.aop.a_xmlaspect.service.FinanceService.*(double))
```

```java
// 表示切入的方式是在FinanceService类型的public修饰，参数只有一个，类型无所谓的任意方法名
execution(public * com.linkedbear.spring.aop.a_xmlaspect.service.FinanceService.*(*))
```

```java
// 表示切入的方式是在FinanceService类型的public修饰，**参数个数和类型不受限制**的任意方法名
execution(public * com.linkedbear.spring.aop.a_xmlaspect.service.FinanceService.*(..))
```

```java
// 这个切入点表达式就代表 `com.linkedbear.spring` 包下的所有类的所有方法都会被切入
execution(* com.linkedbear.spring..*.*(..))
```

```java
// 如果要切入声明了异常的方法，可以使用异常通知来切入这部分方法
execution(public * com.linkedbear.spring.aop.a_xmlaspect.service.FinanceService.*(..) throws java.lang.Exception)
```

**如果切入点表达式覆盖到了接口，那么如果这个接口有实现类，则实现类上的接口方法也会被切入增强。**

### 基于AspectJ实现AOP
只有环绕切入(即@Around)，才支持参数传ProceedingJoinPoint类型，其他切入时机，只支持传递Joinpoint参数。**同一个切面类中，环绕通知的执行时机比单个通知要早。**
### AspectJ注解抽取切入点表达式
```java
@Pointcut("execution(* com.linkedbear.spring.aop.b_aspectj.service.*.*(String)))")
public void defaultPointcut() {

}
@After("defaultPointcut()")
public void afterPrint() {
    System.out.println("Logger afterPrint run ......");
}

@AfterReturning("defaultPointcut()")
public void afterReturningPrint() {
    System.out.println("Logger afterReturningPrint run ......");
}
```
xml配置抽取的例子：
```java
<aop:config>
    <aop:aspect id="loggerAspect" ref="logger">
        <aop:pointcut id="defaultPointcut" 
                      expression="execution(public * com.linkedbear.spring.aop.a_xmlaspect.service.*.*(..))"/>
        <!-- ... -->
        <aop:after-returning method="afterReturningPrint"
                             pointcut-ref="defaultPointcut"/>
    </aop:aspect>
</aop:config>
```
### 注解切入点表达式
```java
@annotation(com.linkedbear.spring.aop.b_aspectj.component.Log)
```
### 如果需要调用在代理类的方法中调用代理类自己的方法，除了通过依赖自己来走代理外，还可以通过下面的方法来走代理调用。
```java
@Service
public class UserService {
    
//    @Autowired
//    UserService userService;
    
    public void update(String id, String name) {
//        this.get(id);
//        userService.get(id);
        ((UserService) AopContext.currentProxy()).get(id);
        System.out.println("修改指定id的name。。。");
    }
    
    public void get(String id) {
        System.out.println("获取指定id的user。。。");
    }
}
```
但是需要显示开启`exposeProxy`属性：
```java
@Configuration
@ComponentScan("com.linkedbear.spring.aop.e_aopcontext")
@EnableAspectJAutoProxy(exposeProxy = true) // 暴露代理对象
public class AopContextConfiguration {
    
}
```
### AOP增强的时机
- **字节码编译织入**：在javac的动作中，使用特殊的编译器，将通知直接织入到Java类的字节码文件中;
- **类加载时期织入**：在类加载时期，使用特殊的类加载器，在目标类的字节码加载到JVM的时机中，将通知织入进去；
- **运行时创建对象织入**：在目标对象的创建时机，使用动态代理技术将通知织入到目标对象中，形成代理对象。
### AspectJ对于增强的时机
- 对于字节码的编译期织入，它可以利用它自己定义的AspectJ语言编写好切面，并借助Maven等项目管理工具，在工程的编译期使用特殊的编译器(ajc等)，将切面类中定义的通知织入到Java类中；
- 对于类加载时期的织入，它的机制就是LoadTimeWeaving；
- 对于运行时创建对象的织入，它在早期有整合一个叫AspectWerkz框架，也是在运行时动态代理产生代理对象，在Spirng中整合AspectJ后，最终用的是基于SpringFramework底层的动态代理搞定的。
## AOP原理
### `AnnotationAwareAspectJAutoProxyCreator`
![[Pasted image 20240816111752.png]]
它实现了几个重要的接口：
- `BeanPostProcessor`：用于在`postProcessAfterInitialization`方法中生成代理对象
- `InstantiationAwareBeanPostProcessor`：拦截bean的正常`doCreateBean`创建流程
- `SmartInstantiationAwareBeanPostProcessor`：提前预测bean的类型、暴露bean的引用(AOP、循环依赖等)
- `AopInfrastructureBean`：实现了该接口的bean永远不会被代理(防止套娃)
### `AnnotationAwareAspectJAutoProxyCreator`的作用时机
`createBean`到`doCreateBean`这个动作中还有一个`InstantiationAwareBeanPostProcessor`的拦截初始化动作：`AnnotationAwareAspectJAutoProxyCreator#postProcessBeforeInstantiation`，前面的拦截判断结束后，初始化之后的后置拦截方法`AnnotationAwareAspectJAutoProxyCreator#postProcessAfterInitialization`，**`postProcessAfterInitialization`是真正生成代理对象的地方。**
创建代理对象的核心动作其实就三个步骤：
1. 判断决定是否是不会被增强的bean
2. 根据当前正在创建的bean去匹配增强器
3. 如果有增强器，创建bean的代理对象
## AOP收集切面类并封装的过程
- `org.springframework.aop.aspectj.annotation.BeanFactoryAspectJAdvisorsBuilder#buildAspectJAdvisors`：这里会去构建AspectJ相关的增强对象，Spring原生的切面在这个方法调用的上方，但是由于比较复杂，现在很少有人使用Spring原生的切面相关的代码进行AOP编程。
- 决定是否跳过bean的增强步骤:**让AOP代理`TargetSource`的好处，是可以每次方法调用时作用的具体对象实例，从而让方法的调用更加灵活。**
	- **SpringFramework中提供的TargetSource**:
		- - `SingletonTargetSource` ：每次 `getTarget` 都返回同一个目标对象 bean （与直接代理 target 无任何区别）
		- `PrototypeTargetSource` ：每次 `getTarget` 都会从 `BeanFactory` 中创建一个全新的 bean （被它包装的 bean 必须为原型 bean ）
		- `CommonsPool2TargetSource` ：内部维护了一个对象池，每次 `getTarget` 时从对象池中取（底层使用 apache 的 `ObjectPool` ）
		- `ThreadLocalTargetSource` ：每次 `getTarget` 都会从它所处的线程中取目标对象（由于每个线程都有一个 `TargetSource` ，所以被它包装的 bean 也必须是原型 bean ）
		- `HotSwappableTargetSource` ：内部维护了一个可以热替换的目标对象引用，每次 `getTarget` 的时候都返回它（它提供了一个线程安全的 `swap` 方法，以热替换 `TargetSource` 中被代理的目标对象）
## Bean是如何被AOP代理的
bean的初始化会被`BeanPostProcessor`的`postProcessAfterInitialization`处理，进入到`AnnontationAwareAspectJAutoProxyCreator`的`postProcessAfterInitialization`方法中，它又要调用`wrapIfNecessary`方法来尝试创建代理。
`wrapIfNecessary`中首先调用`getAdvicesAndAdvisorsForBean`方法获取增强对象，然后调用`createProxy`来创建代理对象。

## AOP原理-代理对象的底层执行逻辑
Cglib的动态代理实现的调用：
- 首先调用`CglibAopProxy`的内部类`DynamicAdvisedInterceptor`中的`intercept`方法。(**核心步骤：获取增强器链、执行增强器**)。
- `CglibMethodInvocation#proceed`的执行逻辑：**利用一个全局索引值，决定每次执行的拦截器，当所有拦截器都执行完时，索引值刚好等一`size() - 1`，此时就可以执行真正的目标方法了。** 下图所示：
![[Pasted image 20240819113354.png]]
- `JdkDynamicAopProxy#invoke`
![[Pasted image 20240819113913.png]]
### AOP的设计原理
**AOP的底层设计是由运行时动态代理支撑，在bean的初始化流程中，借助BeanPostProcessor将原始的目标对象织入通知，生成代理对象。**
**AOP的设计原理是对原有业务逻辑的横切增强，使用不同的通知织入方式，他有不同的底层支撑(编译器、类加载、对象创建期)**。
### jdk动态代理和Cglib动态代理的对比
- jdk动态代理要求被代理的对象所属类至少实现一个接口，它是jdk内置的机制
- Cglib动态代理无此限制，使用字节码增强技术实现，需要依赖第三方Cglib包
- jdk动态代理对象创建速度快，执行速度慢；Cglib动态代理对象创建速度慢，执行速度快
### AOP的失效场景
- **代理对象调用自身方法**时，AOP通知会失效
	- 即在代理对象中直接调用`this.xxx`方法
	- 正确做法是借助`AopContext`取到当前代理对象并强转，之后调用，这样AOP通知依然会执行
- **代理对象在后置处理器还没有初始化的时候，提前创建了，** 则AOP通知不会织入
	- 由于AOP是借助`BeanPostProcessor`实现，如果`BeanPostProcessor`还没有初始化好，目标对象已经创建了，则不可能再生成代理对象
- WeMvc：原始的SSM工程架构中，**AOP配置的切入点表达式，切入的是一些Controller**，导致通知失效
	- 传统的SSM项目中，SpringFramework容器与SpringWebMvc容器时父子容器，如果在父容器中定义切面类，则MVC的子容器无法感知到父容器中的通知，也就没办法织入通知了
	- 正确做法是将切面注册到spring-mvc.xml中，并开启AspectJ注解AOP
- WebMvc:**Controller依赖的Service同时被父容器和子容器扫描，** 则Service的通知会失效
	- 如果父容器和子容器都扫描到Service，则父容器和子容器中都会有一个Service的bean对象，这样在Controller依赖注入时，会直接拿MVC子容器中没有经过AOP代理的Service，而不会去父容器拿经过AOP代理的Service
	- 正确做法是避免两个包扫描的部分产生交集
### AOP的底层原理机制
Aop底层，借助`AnnotationAwareAspectJAutoProxyCreator`在bean的初始化流程，`postProcessAfterInitialization`方法中将目标对象包装为代理对象。这里面设计到几个核心步骤：
1. 检查当前初始化的bean是否可以被AOP代理(检查是否有匹配的增强器)
2. 如果存在，则根据当前初始化的bean所属类有无实现接口，以及AOP的全局配置，决定使用哪种代理方案
3. 将目标对象包装为`TargetSource`，并一次为原型生成代理对象
### 代理对象的通知逻辑是如何执行的
代理对象被构造后，执行方法会进行`JdkDynamicAopProxy`/`CglibAopProxy`中，并构造`ReflectiveMethodInvocation`并依次执行这些织入的通知。执行通知的逻辑是靠一个`currentInterceptorIndex`下标控制，并以此下标为依据顺序执行增强器的通知逻辑。
## Dao编程基础
### 事务保存点
或许咱在日常开发中会遇到一些特殊的场景，它可能需要分段执行，如果出现异常后不需要全部回滚，这种情况就需要jdbc事务中的保存点了。当程序出现异常时，可以控制事务只回滚到某个保存点上，这样保存点之前的SQL还是会照常执行。
```java
{
        ClassPathXmlApplicationContext ctx = new ClassPathXmlApplicationContext("jdbc/spring-jdbc.xml");
        DataSource dataSource = ctx.getBean(DataSource.class);
        Connection connection = null;
        Savepoint savepoint = null;
        try {
            connection = dataSource.getConnection();
            connection.setAutoCommit(false);
    
            PreparedStatement statement = connection
                    .prepareStatement("insert into tbl_user (name, tel) values ('hahaha', '12345')");
            statement.executeUpdate();
    
            savepoint = connection.setSavepoint();
            
            statement = connection.prepareStatement("insert into tbl_account (user_id, money) values (2, 123)");
            statement.executeUpdate();
    
            int i = 1 / 0;
    
            statement = connection.prepareStatement("delete from tbl_user where id = 1");
            statement.executeUpdate();
    
            connection.commit();
        } catch (Exception e) {
            if (savepoint != null) {
                connection.rollback(savepoint);
                connection.commit();
            } else {
                connection.rollback();
            }
        } finally {
            if (connection != null) {
                connection.close();
            }
        }
    }
```
当除零异常发生时，由于上面设置了保存点，所以在catch中就可以指定回滚到保存点而不是全部回滚。但是！如果只是回滚到指定的回滚点，此时事务还是存在的，还需要再手动提交一次，不然保存点之前的SQL执行是不会生效的。
```ad-note
`<aop:aspect>`针对的是一个Aspect切面类的多个通知方法配置，而`<aop:advisor>`针对的是一个通知方法配置。这种配置是为了兼顾SpringFramework原生的AOP通知写法，由于我们日常开发中已经几乎不用该方法。
```

## 声明式事务
### 基于xml配置的声明式事务：
```xml
    <context:component-scan base-package="com.linkedbear.spring.transaction.c_declarativexml"/>
    <context:annotation-config/>

    <bean id="transactionManager" class="org.springframework.jdbc.datasource.DataSourceTransactionManager">
        <property name="dataSource" ref="dataSource"/>
    </bean>

    <tx:advice id="transactionAdvice" transaction-manager="transactionManager">
        <tx:attributes>
            <tx:method name="saveAndQuery"/>
            <tx:method name="addMoney"/>
            <tx:method name="subtractMoney"/>
        </tx:attributes>
    </tx:advice>

    <aop:config>
        <aop:advisor advice-ref="transactionAdvice"
                     pointcut="execution(* com.linkedbear.spring.transaction.c_declarativexml.service.*.*(..))"/>
    </aop:config>
```

### 基于注解配置的声明式事务
```java
@Configuration
@ComponentScan("com.linkedbear.spring.transaction.d_declarativeanno")
@EnableTransactionManagement
public class DeclarativeTransactionConfiguration {
    
    @Bean
    public DataSource dataSource() {
        DriverManagerDataSource dataSource = new DriverManagerDataSource();
        dataSource.setDriverClassName("com.mysql.jdbc.Driver");
        dataSource.setUrl("jdbc:mysql://localhost:3306/spring-dao?characterEncoding=utf8");
        dataSource.setUsername("root");
        dataSource.setPassword("123456");
        return dataSource;
    }
    
    @Bean
    public JdbcTemplate jdbcTemplate() {
        return new JdbcTemplate(dataSource());
    }
    
    @Bean
    public TransactionManager transactionManager() {
        return new DataSourceTransactionManager(dataSource());
    }
}
```
### 如果xml与注解驱动混用
需要在xml中添加以下配置，跟`<context:annotation-config/>`(开启annotation-driven类似)，下面的配置与`@EnableTransactionManagement`注解具有相同的作用
```xml
<tx:annotation-driven transaction-manager="transactionManager"/>
```
### @Transactional的其他属性
`@Transactional`注解中的属性，与`<tx:method>`标签中的属性几乎完全一致：
- `isolation`：事务隔离级别。默认是**DEFAULT**，即依据数据库默认的事务隔离级别来定
- `timeout`：事务超时时间，当事务执行超过指定时间后，事务会自动终止并回滚，单位**秒**。默认值-1，代表永不超时
- `read-only`：设置是否为只读事务。默认值**false**，代表读写型事务。
	- 当设置为true时，当前事务为只读事务，通常用于查询操作(此时不会有`setAutoCommit(false)`等操作，可以加快查询速度)
- `rollback-for`：当方法触发指定异常时，事务回滚，需要传入异常类的全限定名。
	- 默认只为空，代表**捕捉所有`RuntimeException`和`Error`的子类**
	- 一般情况下，在日常开发中，我们都会显示声明其为`Exception`，目的是一起捕捉非运行时异常
- `no-rollback-for`：当方法触发指定异常时，事务不会滚继续执行，需要传入异常类的全限定名。默认值为空，代表不忽略异常
- `propagation`：**事务传播行为**
### 声明式事务的核心组件为**TransactionManager**
### 事务传播行为
**外层事务传播到内层的事务后，内层的事务做出的行为**，这就是事务传播行为。
### 事务传播的7种策略
- **REQUIRED：必须要的【默认值】**：如果当前没有事务运行，则会开启一个新的事务；如果当前已经有事务运行，则方法会运行在当前事务中。
- **REQUIRES_NEW：新事务**：如果当前没有事务运行，则会开启一个新的事务；如果当前已经有事务运行，则会将原事务挂起(暂停)，重新开启一个新的事务。当新的事务运行完毕后，再将原来的事务释放。
- **SUPPORTS:支持**：如果当前有事务运行，则方法会运行在当前事务中；如果当前没有事务运行，则不会创建新的事物(即不运行在事务中)。
- **NOT_SUPPORTED：不支持**：如果当前有事务运行，则会将该事务挂起(暂停)；如果当前没有事务运行，则它不会运行在事务中。
- **MANDATORY：强制**：当前方法必须运行在事务中，如果没有事务，则抛出异常。
- **NEVER：不允许**：当前方法不允许运行在事务中，如果当前已经有事务运行，则抛出异常。
- **NESTED：嵌套**：如果当前没有事务运行，则开启一个新的事务；如果当前已经有事务运行，则会记录一个保存点，并继续运行在当前事务中。如果子事务中运行出现异常，则不会全部回滚，而是回滚到上一个保存点。
由于NESTED的执行需要依赖关系型数据库的SavePoint机制，所以这种传播行为只适用于`DataSourceTransactionManager`(即基于数据源的事务管理器)。
**利用`TransactionSynchronizationManager#getCurrentTransactionName()`，可以获取到当前事务的名称，而当前事务的名称就是开启事务时触发的方法。**
## Spring中的事务控制模型
### Spring事务的三大核心
- `PlatformTransactionManager`：平台事务管理器
- `TransactionDefinition`：事务定义
- `TransactionStatus`：事务状态
简单的说，SpringFramework对于事务的控制，可以理解为**事务管理器，可以根据事务的定义，获取/控制事务的状态。**
![[Pasted image 20240820104231.png]]

![[Pasted image 20240820104920.png]]

![[Pasted image 20240820105427.png]]
## Spring中的全局事务控制
`JTATransationManger`事务管理器，主要是用来控制下图中第三种场景：
![[Pasted image 20240820113927.png]]
基于数据源的事务管理器`DatasourceTransactionManager`是一个数据源对应一个事务管理器，事务管理器之间无法相互干预。所以，SpringFramework提供了JTA全局事务，来同时控制多个数据源的事务。
### 2PC(全局事务解决方案)
2PC即两阶段提交协议，它将一个事务的提交动作拆解为两个阶段：准备阶段(prepare)和提交阶段(commit)。准备阶段下，全局事务管理器会给每个分支事务对应的资源管理器，发送一个prepare的消息，资源服务器收到消息会在本地执行，但是此时不会提交。如果所有分支prepare阶段都执行成功，并且全局事务管理器接收到了所有分支的执行成功的消息，此时全局事务管理器就会向所有分支管理器发送commit消息示意所有分支事务提交；如果有任何一个分支prepare阶段执行失败或者连接超时，全局事务管理器也会感知到失败的消息，并且发送rollback消息，通知所有资源管理器回滚事务。
### XA与JTA事务
XA协议是2PC全局事务的落地方案，它是依赖传荣的关系型数据库实现的，MYSQL、ORACLE等数据库都支持基于XA方案的2PC协议。
**XA指代的是全局事务管理器与资源管理器之间的交互接口规范。**
**JTA其实就是XA方案的java实现，JTA全程Java Transaction Api。**
使用JTA，目前来看有两种可实现的方式：借助外部Web容器，或者借助第三方JTA库。对于前者，目前还能支持的有JBOSS等；后者的话，在目前来看，比较流行的框架有Atomikos、JOTM等。
### Spring使用JTA的两种方式
无论使用哪种方案，必备的角色一样也不能少，它们分别有：
- 全局事务管理器
- JTA资源管理器
- 资源服务器(关系型数据库等)
而在SpringFramework中，能提供的只有事务管理器，以及资源服务器(`Datasource`)，至于JTA资源管理器，要么Web容器提供，要么第三方框架提供。
**如果JTA资源管理器由Web容器提供，整体的分布式事务架构图就应该是这样的：**
![[Pasted image 20240820142304.png]]
在这种方案下，当外部资源调用触发事务时，由SpringFramework的事务管理接收，并由`JTATransactionManager`接管落地实现，由于此时的JTA资源管理器是外部的Web容器提供，所以此处会调用到外部的JTA资源管理器，并由外部的JTA资源管理器负责控制具体的资源(数据源)完成与数据库的交互。

**如果使用第三方框架提供JTA资源管理器，则架构会变为如下形式：**
![[Pasted image 20240820142734.png]]
可见这种方案下，Atomikos是作为SpringFramework的IOC容器中的一部分，SpringFramework的`JTATransactionManager`在调用具体的JTA资源管理器时，是直接从IOC容器中找对应的bean即可，整体事务控制的思路不变。
## Spring事务的生效原理
### 1. 基于xml的声明式事务生效原理
`<tx:advice>`标签的底层，其实是注册了一个`TransactionInterceptor`.
### 2.基于注解的声明式事务生效原理
在配置类上标注`@EnableTransactionManagement`注解，然后注册一个事务管理器就OK了。
### 2.1 `@EnableTransactionManagement`的属性
- **proxyTargetClass**：如果`proxyTargetClass`属性声明为true，则所有被事务增强的类全部使用Cglib代理类的方式，默认情况下为false，这种情况有接口就用jdk动态代理，没有接口就用Cglib动态代理。
- **mode**：PRXOY代表是运行期增强，ASPECTJ代表的是类加载期增强(类似于load-time-weaving)。
	- **PROXY** - AutoProxyRegistrar + ProxyTransactionManagementConfiguration
	- **ASPECTJ** - TRANSACTION_ASPECT_CONFIGURATION_CLASS_NAME
- **order** #TODO

## 声明式事务的控制原理
**由于事务通知的织入需要对每个正在创建的bean进行匹配，而匹配的时候需要用到`TransactionAttributeSource`去检查方法上，或者方法所在的类上是否标注有`@Transactional`注解，以此来判断是否需要对当前正在创建的bean织入事务通知。而不管最终事务通知是否织入进去，`TransactionAttributeSource`中都会留下这些方法的判断痕迹。**
如果没有JTA或者EJB的依赖，则只会存在`SpringTransactionAnnotationParser`，用此解析器来解析`Transactional`注解。解析完`@Transactional`注解的信息后，返回`RuleBasedTransactionAttribute`的对象，这个类实现了`TransactionAttribute`接口，自然也实现了`TransactionDefinition`接口。
### 小结
这个阶段的工作内容：**当应用启动的时候，由于声明了`@EnableTransactionManagement`注解，它会向IOC容器中注册事务通知增强器，这个增强器会参与到bean初始化的AOP后置处理逻辑中，检查被创建的bean中是否可以织入事务通知(标注`@Transactional`注解)。而这个检查的动作顺便保存到了`AbstractFallbackTransactionAttributeSource`的本地缓存中，所以在真正触发事务拦截器的逻辑，需要去除事务定义信息时，就可以直接从缓存中取出，而不需要重新解析了。**
### 获取事务管理器
获取到事务定义信息之后，接下来要做的是获取事务管理器，执行`determinTransactionManager`方法。最终其实是从`BeanFactory`中获取到的事务管理器，也就是说需要往容器中提前注册事务管理器，关系型数据库提前注册的一般是`DataSourceTransactionManger`。
### 响应式事务管理器的处理
### 事务控制核心
通过下面事务处理的核心代码，可以看出来其实就是环绕通知：
```java
PlatformTransactionManager ptm = asPlatformTransactionManager(tm);
    final String joinpointIdentification = methodIdentification(method, targetClass, txAttr);

    if (txAttr == null || !(ptm instanceof CallbackPreferringPlatformTransactionManager)) {
        // Standard transaction demarcation with getTransaction and commit/rollback calls.
        // 1. 开启事务
        TransactionInfo txInfo = createTransactionIfNecessary(ptm, txAttr, joinpointIdentification);

        Object retVal;
        try {
            // This is an around advice: Invoke the next interceptor in the chain.
            // This will normally result in a target object being invoked.
            // 2. 环绕通知执行Service方法
            retVal = invocation.proceedWithInvocation();
        }
        catch (Throwable ex) {
            // target invocation exception
            // 3. 捕捉到异常，回滚事务
            completeTransactionAfterThrowing(txInfo, ex);
            throw ex;
        }
        finally {
            cleanupTransactionInfo(txInfo);
        }

        if (retVal != null && vavrPresent && VavrDelegate.isVavrTry(retVal)) {
            // Set rollback-only in case of Vavr failure matching our rollback rules...
            TransactionStatus status = txInfo.getTransactionStatus();
            if (status != null && txAttr != null) {
                retVal = VavrDelegate.evaluateTryFailure(retVal, txAttr, status);
            }
        }

        // 4. Service方法执行成功，提交事务
        commitTransactionAfterReturning(txInfo);
        return retVal;
    }
    // 下面的逻辑基本一致，不再展开 ......
```
核心动作就4步：**开启事务、执行Service方法、遇到异常就回滚事务、没有异常就提交事务。**
## 声明式事务的事务传播行为原理
`TransactionAspectSupport#invokeWithinTransaction`方法中会调用`createTransactionIfNecessary`方法来创建事务，而这个方法找那个会包含事务传播机制的一些判断。
`org.springframework.transaction.PlatformTransactionManager#getTransaction`事务传播逻辑在该方法中，
如果当前存在事务，则会走到下面代码的逻辑中去处理事务传播机制的逻辑:
```java
    // ......
    if (isExistingTransaction(transaction)) {
        // Existing transaction found -> check propagation behavior to find out how to behave.
        return handleExistingTransaction(def, transaction, debugEnabled);
    }
    // ......

```
如果当前线程中存在活跃事务：
1. **NEVER处理**：要求线程中不能有事务，所以这里检测到有事务就会抛出异常。
2. **NOT_SUPPRTED的处理**：要求方法执行不在事务中，所以这里会把当前事务挂起，并执行自己的方法。
3. **REQUIRES_NEW的处理**：开启一个新的事务，不过在此之前它还要挂起已有的外部事务。如果新事务抛出异常后，会恢复之前的外部事务。
4. **NESTED的处理**：首先需要允许嵌套事务在程序的使用，然后还需要连接的数据库支持基于保存点的嵌套事务。如果这些条件成立，则会创建保存点，否则会开启一个新的事务。
5. **REQUIRED & SUPPORTS的处理**：这里什么也不做，直接在当前事务中执行。


如果当前线程中没有绑定事务，则会走到下面的传播行为处理：
```java
 // ......
    // No existing transaction found -> check propagation behavior to find out how to proceed.
    if (def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_MANDATORY) {
        throw new IllegalTransactionStateException(
                "No existing transaction found for transaction marked with propagation 'mandatory'");
    }
    else if (def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRED ||
            def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_REQUIRES_NEW ||
            def.getPropagationBehavior() == TransactionDefinition.PROPAGATION_NESTED) {
        SuspendedResourcesHolder suspendedResources = suspend(null);
        // logger ......
        try {
            return startTransaction(def, transaction, debugEnabled, suspendedResources);
        } // catch ......
    }
    else {
        // logger ......
        boolean newSynchronization = (getTransactionSynchronization() == SYNCHRONIZATION_ALWAYS);
        return prepareTransactionStatus(def, null, true, newSynchronization, debugEnabled, null);
    }
```
首先，如果方法的事务定义信息配置的传播行为是**MANDATORY**，则直接抛出异常，也就是调用该方法之前必须已经存在事务。
接着，如果传播行为配置为**REQUIRED、REQUIRES_NEW、NESTED**，那就很简单了，直接开启一个新的事务即可。
去除上面的4中事务传播行为，还剩下**SUPPORTS、NOT_SUPPORTED、NEVER**，它们都可以在没有事务的情况下运行，所以这几种事务传播级别，在当前线程中没有活跃事务是就啥也不用干，只需继续执行方法即可，也就是不加事务。
## Spring整合Web与三层架构
### MVC
![[Pasted image 20240827155231.png]]
### 三层架构
![[Pasted image 20240827155256.png]]

**怎么让web.xml把Spring的配置文件加载上来呢？什么时候加载？加载完成后应该放在哪呢？**
**在Web容器启动时，借助Listner加载配置文件。IOC容器加载完成后，放到application域中任何位置都能拿到。**
下面是通过web.xml配置的例子：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
                             http://xmlns.jcp.org/xml/ns/javaee/web-app_3_1.xsd"
         version="3.1">
    <listener>
        <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
    </listener>

    <context-param>
        <param-name>contextConfigLocation</param-name>
		<!-- 可以指定通配匹配一批文件spring-*.xml -->
        <param-value>classpath:spring-web.xml</param-value>
    </context-param>
</web-app>
```
### 基于Servlet3.0规范的web整合
Servlet3.0规范文档中的8.2.4节，介绍的是**Shared libraries / runtimes pluggability**，这里面讲了一个`ServletContainerInitializer`的东西，借助Java的SPI技术，可以从项目或者项目依赖的jar包中，找到一个`/META-INF/services/javax.servlet.ServletContainerInitializer`的文件，并加载项目中所有它的实现类。它就是为了替代`web.xml`的，所以它的加载时机也是在项目的初始化阶段就出发的。
`ServletContainerInitializer`这个接口通常会配合@HandlesTypes注解一起使用，这个注解可以传入一些我们所需要的接口/抽象类，支持Servlet3.0规范的Web容器会在容器启动项目初始化时，把这些接口/抽象类的实现类全部都找出来，整合为一个Set，传入`ServletContainerInitializer`的`onStartUp`方法参数中，这样我们就可以在onStartUp中拿到这些实现类，随机反射创建调用等等的动作。
### Spring支持Servlet3.0规范
`spring-web`的jar包中，就可以找到这个`/META/services/javax.servlet.ServletContainerInitializer`的文件：
![[Pasted image 20240827162714.png]]
```java
@HandlesTypes(WebApplicationInitializer.class) public class SpringServletContainerInitializer implements ServletContainerInitializer
```
## SpringWebMvc
对于基于注解驱动的话，都是一配置类的方式，所以这里只需要定义好两组不同的配置类，返回出去，`AbstractAnnotationConfigDispatcherServletInitializer`就会自动的将这些配置类分别注册进两个IOC容器中。实现示例如下：
```java
public class SpringWebMvcInitializer extends AbstractAnnotationConfigDispatcherServletInitializer {
    
    @Override
    protected Class<?>[] getRootConfigClasses() {
        return new Class[] {RootConfiguration.class};
    }
    
    @Override
    protected Class<?>[] getServletConfigClasses() {
        return new Class[] {WebMvcConfiguration.class};
    }
    
    @Override
    protected String[] getServletMappings() {
        return new String[] {"/"};
    }
}
```
### 根容器与Servlet子容器
![[Pasted image 20240827170343.png]]
这种父子容器的设计，好处有两个：第一，形成层级关系后，Controller可以拿到Service，而Service拿不到Controller，可以以此形成一道隔离；第二，如果真的出现特殊情况，需要注册多个`DispatcherServlet`的时候，不必注册多套Service和Dao，每个Servlet子容器都从这个根容器找那个取Service和Dao即可。
但是这种分级也会有些小坑：在进行包扫描的时候，Servlet子容器只能扫描`@Controller`注解，而不能扫描`@Service`、`@Responsitory`等注解，否则会导致子容器中存在Service而不会去父容器中寻找，从而引发一些问题(如事务失效、AOP增强失效等)。
### 拦截器和过滤器对比
拦截器是springwebmvc框架里的概念，而过滤器是Servlet的概念。
过滤器可以拦截几乎所有请求，而拦截器只能拦截到被`DispatcherServlet`接收处理的请求。
拦截器可以借助依赖注入获取所需要的bean，而过滤器无法使用正常手段获取。
过滤器的调用是一层层的函数回调，而拦截器是SpringWebMvc在底层借助反射调用的。
### 拦截器的执行机制
![[Pasted image 20240828113255.png]]
`preHandle`方法是顺序执行，`postHandle`和`afterCompletion`方法均是逆序执行。
- **只有`preHandle`方法返回true时，`afterCompletion`方法才会调用**
- **只有所有`preHandle`方法的返回值全部为true时，Controller方法和`postHandler`方法才会调用**
### @CrossOrigin做的工作
其实解决跨域就是添加如下响应头信息：
```java
`Access-Control-Allow-Origin: *`
```
所以`@CrossOrigin`干的事，其实就是相当于我们用`HttpServletResponse`执行了这么一句代码：
```java
response.addHeader("Access-Control-Allow-Origin", "*");
```

## WebMVC的架构与组件功能解析
![[Pasted image 20240828152810.png]]
### HandlerMapping
`HandlerMapping`是处理映射器，使用它，可以根据请求的uri，找到能处理该请求的一个Handler，并组合可能匹配的拦截器，包装为一个`HandlerExecutionChian`对象返回出去。它有如下几个主要的实现：
- `RequestMappingHandlerMapping`：支持`@RequestMapping`注解的处理器映射器。
- `BeanNameUrlHandlerMapping`：使用bean的名称作为Handler接收请求路径的处理映射器，使用该方式，需要我们编写Controller类实现`Controller`接口。因为使用该方式编写Controller，一个类只能接收一个请求路径，已经被淘汰。
- `SimpleUrlHandlerMapping`：集中配置请求路径与Controller的对应关系的处理器映射器。
```xml
<bean class="org.springframework.web.servlet.handler.SimpleUrlHandlerMapping"> <property name="mappings"> <props> <prop key="/department/list">departmentListController</prop> <prop key="/department/save">departmentSaveController</prop> </props> </property> </bean>
```
**从springframework升级到3.0后，全面支持注解驱动开发之后，只需要记住处理@RequestMapping注解映射的实现类`RequestMappingHandlerMapping`即可。**
### WebMvc中HandlerAdapter的实现
- `RequestMappingHandlerAdapter`：基于`@RequestMapping`的处理器适配器，底层使用反射调用Handler的方法
- `SimpleControllerHandlerAdapter`：基于`Controller`接口处理器适配器，底层会将Handler强转为`Controller`，调用其`handleRequest`方法
- `SimpleServletHandlerAdapter`：基于`Servlet`的处理器适配器，底层会将Handler强转为`Servlet`，调用其`service`方法
### ViewResolver
- 视图响应，`InternalResourceViewResolver`这个类继承自`UrlBasedViewResolver`，它可以方便的声明页面路径的前后缀，以方便我们在返回视图(jsp)的时候编写视图名称。
- json响应，当Handler执行完毕后，SpringWebMvc会根据当前Handler以及返回值，决定使用何种方式响应。如果我们在编写的Controller方法中没有标注`@ResponseBody`注解，而且返回`String`，则SpringWebMvc会认为要跳转页面，于是就去让`ViewResolver`处理去了；而如果方法上，或者整个Controller类上标注了`@RestController`或者`@ResponseBody`，则SpringWebMvc就不会再去找`ViewResolver`，而是转头去找jackson了，这个时候`ViewResolver`直接是不工作的。
## WebMvc的异步请求
### Servlet3.0的异步请求支持
Servlet3.0规范提出了**异步请求**的概念。借助`HttpServletRequest`，可以从中拿到一个`AsyncContext`，使用这个`AsyncContext`，就可以实现异步请求处理。
```java
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        System.out.println("AsyncServlet doGet ......" + Thread.currentThread().getName());
        PrintWriter writer = resp.getWriter();
        
        AsyncContext asyncContext = req.startAsync();
        asyncContext.start(() -> {
            System.out.println("AsyncServlet asyncContext ......" + Thread.currentThread().getName());
            
            try {
                TimeUnit.SECONDS.sleep(2);
            } catch (InterruptedException ignore) { }
            asyncContext.complete();
            
            writer.println("success");
            System.out.println("AsyncServlet asyncContext end ......" + Thread.currentThread().getName());
        });
        
        System.out.println("AsyncServlet doGet end ......" + Thread.currentThread().getName());
    }
```
start方法区执行业务逻辑，然后外层doGet方法就顺势执行完毕了，里面耗时的操作对应的线程，跟doGet方法执行的线程肯定不是同一个。
### SpringWebMvc的异步请求支持
- **基于Callable的异步请求支持**：SpringWebMvc规定了，如果返回值是`Callable`类型，则认定该Handler采用异步请求支持。
```java
@RestController
public class AsyncController {
    
    @GetMapping("/async")
    public Callable<String> async() {
        return () -> {
            TimeUnit.SECONDS.sleep(5);
            return "AsyncController async ......";
        };
    }
}
```
默认情况下我们没有配置TaskExecutor，所以WebMvc内部会使用`SimpleAsyncTaskExecutor`来执行异步handler，但是该默认的TaskExecutor每次执行会new一个全新的线程，所以会警告用户注册一个线程池的实现类。SpringFramework给我们提供了一个`ThreadPoolExecutor`，它就是基于线程池的`TaskExecutor`，向IOC容器中注册一个，就可以消除告警，主要是可以提高线程的利用率。
- **基于DeferredResult的异步请求支持**：只要返回值是`DeferredResult`，SpringWebMvc就不会立即响应结果，而是等待数据填充。当`DeferredResult`的`setResult`方法被调用时，才会触发响应处理，客户端也才能收到响应结果。

## DispatcherServlet的初始化原理
### 1.基于Web.xml的DispatcherServlet初始化
- Servlet的生命周期，从`init`方法开始 ->
- DispatchServlet的直接父类`FramworkServlet`中的`initServletBean` ->
- `DispatcherServlet`中的`initWebApplicationContext`(这个步骤里面会先获取通过ContextLoaderListener初始化的IOC容器) ->
- `createWebApplicationContext(rootContext)`实例化IOC容器、设置配置文件路径配置->
- `configureAndRefreshWebApplicationContext(wac)`刷新容器 - refresh(注意此时`WebApplicationContext`中是没有`DispatcherServlet`的，所以这里需要添加`ContextRefreshListener`事件监听容器初始化完成之后再初始化DispatcherServlet)->
- `ContextRefreshListener#onApplicationEvent`->
- `FrameworkServlet.this.onApplicationEvent(event)`->
- `DispatcherServlet#onRefresh`->
- `DispatcherServlet#initStrategies`->
```java
//`DispatcherServlet#initStrategies`方法的方法体
initMultipartResolver(context); // 文件上传 
initLocaleResolver(context); // 国际化 
initThemeResolver(context); // 前端主题 
initHandlerMappings(context); // 处理器映射器 
initHandlerAdapters(context); // 处理器适配器 initHandlerExceptionResolvers(context); // 异常处理器 initRequestToViewNameTranslator(context); 
initViewResolvers(context); // 视图解析器
initFlashMapManager(context);
```
**spring-webmvc包下面有一个名为DispatcherServlet.properties的配置文件，里面包含了一些组件的默认实现。**
![[Pasted image 20240829110401.png]]

### 使用`web.xml`配置`DispatcherServlet`的时候，即便我们不配置任何内置组件，SpringWebMvc可以通过预先定义好的内置组件，在IOC容器已经初始化接近完毕的时候，记住事件监听器，回调`DispatcherServlet`使其初始化默认组件的实现，从而达到兜底配置。

### 基于`Servlet3.0`规范的`DispatcherServlet`初始化
- `AbstractDispatcherServletInitializer#onStartup`->
		- `AbstractContextLoaderInitializer#onStartup`(初始化根容器)
- `AbstractDispatcherServletInitializer#registerDispatcherServlet`->
	- `AbstractDispatcherServletInitializer#createServletApplicationContext()` (创建WebMvc子容器)
	- `createDispatcherServlet(servletAppContext)`（初始化DispatcherServlet)
- ... 后面的逻辑就是Servlet的生命周期走init方法，然后刷新容器之后回调监听器调DispatcherServlet初始化组件策略的方法。
```java
protected WebApplicationContext initWebApplicationContext() {
    // 先获取根容器（通过ContextLoaderListener初始化的IOC容器）
    WebApplicationContext rootContext =
            WebApplicationContextUtils.getWebApplicationContext(getServletContext());
    WebApplicationContext wac = null;

    // 该分支通过Servlet3.0规范初始化时会进来
    if (this.webApplicationContext != null) {
        // A context instance was injected at construction time -> use it
        wac = this.webApplicationContext;
        if (wac instanceof ConfigurableWebApplicationContext) {
            ConfigurableWebApplicationContext cwac = (ConfigurableWebApplicationContext) wac;
            if (!cwac.isActive()) {
                if (cwac.getParent() == null) {
                    cwac.setParent(rootContext);
                }
                configureAndRefreshWebApplicationContext(cwac);
            }
        }
    }
    // ......
    // 如果没有WebApplicationContext，则会创建一个全新的WebApplicationContext(该分支是通过web.xml方式初始化时会进入)
    if (wac == null) {
        wac = createWebApplicationContext(rootContext);
    }
    // ......
    // 将该WebApplicationContext放入ServletContext中
    if (this.publishContext) {
        // Publish the context as a servlet context attribute.
        String attrName = getServletContextAttributeName();
        getServletContext().setAttribute(attrName, wac);
    }
    return wac;
}
```
### 基于Servlet3.0规范的方式，通过编写继承`AbstractAnnotationConfigDispatcherServletInitializer`的子类，分别提供根容器与WebMvc子容器的配置类，底层会帮我们初始化对应的容器，并且借助ServletContext注册DispatcherServlet。后续逻辑与基于web.xml的配置方式一致。
## DispatcherServlet的核心工作原理
- `DispatcherServlet#service`(父类中的方法)->
- `DispatcherServlet#doDispatch`->
	- `DispatcherServlet#checkMultipart`(文件上传解析)
	- `DispatcherServlet#getHandler`(获取一个可用的Handler)->
		- `AbstractHandlerMapping#getHandler`(循环调用初始化时候加载的HandlerMapping的getHandler方法获取`HandlerExecutionChain`)
			- `AbstractHandlerMethodMapping#getHandlerInternal`(根据请求uri匹配`HandlerMethod`)
			- `AbstractHandlerMethodMapping#getHandlerEcecutionChain`(构造handlerExecutionChian)
	- `DispatcherServlet#getHandlerAdapter`(获取HandlerAdapter)
	- `HandlerExecutionChain#applyPreHandle`(回调拦截器的preHandle)
	- `HandlerAdapter#handle`(执行Handler的逻辑)->
		- `RequestMappingHandlerAdapter#invokeHandlerMethod`(如果是通过@RequestMapping注解配置的controller会进到这里)->
			- `ServletInvocableHandlerMethod#invokeAndHandle`(通过反射来执行Controller中的方法)
			- `HandlerMethodReturnValueHandlerComposite#handleReturnValue`(处理方法返回值，代理给适合的xxxReturnValueHandler来进行底层处理)
		- `RequestMappingHandlerAdapter#getModelAndView`(将`ModelAndViewContainer`转换为实际的`ModelAndView`)
	- `HandlerExecutionChain#applyPostHandle`(继续调用拦截器的`postHandle`)
	- `DispatcherServlet#processDispatchResult`(处理异常、渲染视图、回到拦截器的afterCompletion)
### SpringWebMvc中的核心组件：
- DispatcherServlet：**核心中央处理器**，负责接收请求、分发、并给予客户端响应
- HandlerMapping：**处理器映射器**，根据uri，去匹配查找能处理的Handler，并会将请求涉及到的拦截器，和Handler一起级封装
- HandlerAdapter：**处理器适配器**，根据`HandlerMapping`找到的Handler，适配执行对应的Handler
- ViewResolver：**视图解析器**，根据Handler返回的逻辑视图/视图，解析并渲染真正的视图，并传递给`DispatcherServlet`响应客户端
- Handler：处理实际请求的处理器
