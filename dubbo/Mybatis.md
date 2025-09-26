## 3.1.6 绑定Mapper接口
到此为止，解析映射文件的核心流程已经介绍完了。通过第2章对binding模块的介绍可知，每个映射配置文件的命名空间可以绑定一个Mapper接口，并注册到MapperRegistry中。MapperRegistry以及其他相关类的实现在分析binding模块时已经介绍过了，这里不再重复。在XMLMapperBuilder.bindMapperForNamespace() 方法中，完成了映射配置文件与对应Mapper接口的绑定，具体实现如下：

## 3.1.7 处理incomplete*集合


## 3.2.1 组合模式
组合模式是将对象组合树形结构，以表示“部分-整体”的层次结构（一般是树形结构），用户可以像处理一个简单对象一样来处理一个复杂对象，从而是的调用者无须了解复杂元素的内部结构。

1. 首先，通过skipRows() 方法定位到指定的记录行，前面已经分析，这里不再重复描述
2. 通过shouldProcessMoreRows() 方法检测是否能继续映射结果集中剩余的记录行，前面已经分析，这里不再重复描述。
3. 调用

```ad-note
Mybatis中通过动态代理来实现延迟加载
```
## cglib
cglib采用字节码技术实现动态代理功能，其原理是通过字节码技术为目标类生成一个子类，并在该子类中采用方法拦截的方式拦截所有父类方法的调用，从而实现代理的功能。因为cglib生成子类的方式实现动态代理，所以无法代理final关键字修饰的方法。cglib与JDK动态代理之间可以相互补充：在目标类实现接口时，使用JDK动态代理创建对象，但当目标类没有实现接口时，使用cglib实现动态代理的功能。在Spring、Mybatis等多种开源框架中，都可以看到JDK动态代理与cglib结合使用的场景。
## Javassist
Javassist是一个开源的生成Java字节码的类库，其主要优点在于简单、快速，直接使用Javassist提供的Java API就能动态修改类的结构，或是动态的生成类。

# 3.3.6 多结果集处理
parentMapping对象，该结果集映射得到的结果对象会设置到该parentMapping指定的属性上。在示例中，parentMapping就是下面的`<association>`节点产生的ResultMapping对象。

# 3.6.6 CachingExecutor
## 1.二级缓存简介
Mybatis中提供的二级缓存是应用级别的缓存，它的生命周期与应用程序的生命周期相同。与二级缓存相关的配置有三个，如下所示、
- 首先是mybatis-config.xml配置文件中的cacheEnabled配置，它是二级缓存的总开关。只有当该配置设置为true时，后面两项的配置才会有效果，cacheEnabled的默认值为true。
- 在前面介绍配置文件的解析流程时提到，映射配置文件中可以配置`<cache>`节点或`<cache-ref>`节点。如果配置了`<cache>`节点，在解析时会为该映射配置文件指定的命名空间创建相应的Cache对象作为其二级缓存，默认是PerpetualCache对象，用户可以通过`<cache>`节点的type属性指定自定义的Cache对象。`<cache-ref>`不会单独为当前映射配置文件创建Cache对象，而是认为它与 `<cache-ref>` 节点的namesapce属性指定的命名空间共享同一个Cache对象。
- 最后一个配置项是 `<select>` 节点中的useCache属性，该属性表示查询操作产生的结果对象是否要保护到二级缓存中。useCache属性的默认值是true。

## 访问者模式
访问者模式的主要目的是抽象处理某种数据结构中各元素的操作，可以在不改变数据结构的前提下，添加处理数据结构中指定元素的新操作。
![[Pasted image 20231023185343.png]]

1. SqlSessionFactoryBean
在前面介绍Mybatis初始化过程时提到，SqlSessionFactoryBuilder会通过XMLConfigBuilder等对象读取mybatis-config.xml配置文件以及映射配置信息，得到Configuration对象，然后创建SqlSessionFactory对象。而在sring集成时，Mybatis中的SqlSessionFactory对象则是由SqlSessionFactoryBean创建的。在上一小节的集成示例中，applicationContext.xml文件中配置了SqlSessionFactoryBean，其中指定了数据源对象、mybatis-config.xml配置文件的位置等信息。SqlSessionFactoryBean中定义了很多与Mybatis配置相关的字段，

# OgnlUtils工具类
通过前面几章对Mybatis原理和代码的分析可知，OGNL表达式主要应用在两个地方，一个是在动态SQL语句中，例如在 `<if>` 节点的test属性以及 `<bind>` 节点的value属性，Mybatis会通过OGNL计算这些表达式的值之后，再开始进行动态SQL的解析。另一个是在 `${}` 参数中，例如 `${name}` 表达式，Mybatis会通过OGNL解析表达式并进行替换。
笔者建议提供一个OgnlUtils类，其中提供多个用于条件检测的静态方法。下面是OgnlUtils工具类的简单实例，仅供参考，读者可以根据自己的实际业务，添加新静态方法，扩充OgnlUtils工具类。
