## Spring Cloud Gateway 的 GlobalFilter
> GlobalFilter 是所有被Gateway拦截的http请求都要做的处理；GatewayFilter是根据路由配置匹配predicate的http请求才会做的处理。


## @RefreshScope解析
### 注解的作用：
@Refresh注解是Spring Cloud中的一个注解，用来实现Bean中属性的动态刷新。
### 原理：
1. 让Spring容器重新加载Environment环境变量
2. Spring Bean重新创建生成
`@RefreshScope`注解上面加了`@Scope`注解，加了`@RefreshScope`注解的类，在被Bean工厂创建后会加入自己的refresh scope这个缓存中，后续会优先从Bean缓存中获取，当配置中心发生了变更，会把变更的配置更新到spring容器的Environment中，并且清空refresh scope中的所有缓存，从而下次调用的时候会重新创建该bean实例，而这次创建bean实例的时候就会继续经历这个bean的声明周期，是的@Value属性能够从Environment中获取到最新的属性值，这样整个过程就达到了动态刷新的效果，当然首先要确保项目中是支持配置中心配置动态刷新的。
![[RefreshScope动态加载配置的原理.png]]
### debug查看源码时需要关注的几个相关地方
1. 因为Class被加上`@RefreshScope`注解，那么这个BeanDefinition信息中的scope为refresh，在getBean的时候会有单独的处理逻辑，如下所示：
```java
public abstract class AbstractBeanFactory extends FactoryBeanRegistrySupport implements ConfigurableBeanFactory {

protected <T> T doGetBean(
			String name, @Nullable Class<T> requiredType, @Nullable Object[] args, boolean typeCheckOnly)
			throws BeansException {

				// 如果scope是单例的情况, 这里不进行分析
				if (mbd.isSingleton()) {
				 .....
				}
                // 如果scope是prototype的情况, 这里不进行分析
				else if (mbd.isPrototype()) {
					......
				}
                // 如果scope是其他的情况，本例中是reresh
				else {
					String scopeName = mbd.getScope();
					if (!StringUtils.hasLength(scopeName)) {
						throw new IllegalStateException("No scope name defined for bean '" + beanName + "'");
					}
                    // 获取refresh scope的实现类RefreshScope，这个类在哪里注入，我们后面讲
					Scope scope = this.scopes.get(scopeName);
					if (scope == null) {
						throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
					}
					try {
                        // 这边是获取bean,调用的是RefreshScope中的的方法
						Object scopedInstance = scope.get(beanName, () -> {
							beforePrototypeCreation(beanName);
							try {
								return createBean(beanName, mbd, args);
							}
							finally {
								afterPrototypeCreation(beanName);
							}
						});
						beanInstance = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
					}
					catch (IllegalStateException ex) {
						throw new ScopeNotActiveException(beanName, scopeName, ex);
					}
				}
			}
			catch (BeansException ex) {
				beanCreation.tag("exception", ex.getClass().toString());
				beanCreation.tag("message", String.valueOf(ex.getMessage()));
				cleanupAfterBeanCreationFailure(beanName);
				throw ex;
			}
			finally {
				beanCreation.end();
			}
		}

		return adaptBeanInstance(name, beanInstance, requiredType);
	}
    
}

```
2. `RefreshScope`继承了`GenericScope`类，最终调用的是`GenericScope#get()`方法
3. `RefreshScope`是在`RefreshAutoConfiguration`中通过`@Bean`注入到spring容器中的。
4. 配置中心配置变更提交后，`RefreshEventListner`会收到`RefreshEven`事件，最终会调用到`GenericScope#destroy()`方法，清空之前缓存的bean，后续对该对象方法的调用会重新触发初始化，从而达到动态更新配置的目的。

