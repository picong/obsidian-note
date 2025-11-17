## 基本架构
![[Pasted image 20230912153509.png]]
Dubbo从架构图上分为数据面和控制面。在数据面，使用Dubbo开发的微服务进程间基于RPC协议通信。DubboAdmin控制面作为服务治理的抽象入口，由一系列可选的服务治理组件构成，负责Dubbo集群的服务发现、流量管控策略、可视化监控。

### Dubbo 服务治理
- 地址发现
默认提供Nacos、Zookeeper、Consul等多种注册中心适配，与Spring Cloud、Kubernets Service模型打通，支持自定义扩展。
- 负载均衡
Dubbo默认提供加权随机、加权轮询、最少活跃请求数优先、最短响应时间优先、一致性哈希和自适应负载等策略
- 流量路由
Dubbo支持通过一系列流量规则控制服务调用的流量分布与行为，基于这些规则可以实现基于权重的比例流量分发、灰度验证、金丝雀发布、按请求参数的路由、同区域优先、超时配置、重试、限流降级等能力。
- 链路追踪
官方通过适配OpenTelemetry提供了对Tracing全链路追踪的支持， 用户可以接入支持OpenTelemetry标准的产品如Skywalking、Zipkin等。
- 可观测性
Dubbo实例通过Prometheus等上报QPS、RT、请求次数、成功率、异常次数等多维度的可观测指标帮助了解服务运行状态，通过接入Grafana、Admin控制台帮助实现数据指标可视化展示。

## 构建可伸缩的微服务集群
业务增长带来了集群规模的快速增长，而集群规模的增长会对服务治理架构带来挑战：
- 注册中心的存储容量瓶颈
- 节点动态变化带来的地址推送与解析效率下降
- 消费端存储大量网路地址的资源开销
- 复杂的网络链接管理
- 高峰期的流量无损上下线
- 异常节点的自动节点管理

## 服务发现
Dubbo提供的是一种Client-Based的服务发现机制：
![[Pasted image 20230912163655.png]]

## 异步调用
Dubbo异步调用分为Provider端异步和Consumer端异步调用。Provider端异步执行将阻塞的业务从Dubbo线程池切换到业务自定义线程，避免Dubbo线程池的过度占用，有助于避免不同服务间的互相影响。异步执行无异于节省资源或提升RPC响应性能。

### Provider异步
1、使用CompletableFuture实现异步
接口定义：
```java
public interface AsyncService {
	/**
	*同步调用方法
	 */
	String invoke(String param);
	
	/**
	*异步调用方法
	 */
	CompletableFuture<String> asyncInvoke(String param);
}
```
服务实现：
```java
@DubboService
public class AsyncServiceImpl implements AsyncService {
	@Override
	public String invoke(String param) {
		try {
			long time = ThreadLocalRandom.current().nextLong(1000);
			Thread.sleep(time);
			StringBuilder s = new StringBuilder();
			s.append("AsyncService invoke param:").append(param).append(",sleep:").append(time);
			return s.toString();
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
		}
		return null;
	}

	@Override
	public CompletableFuture<String> asyncInvoke(String param) {
		// 建议为supplyAsync提供自定义线程池	
		return CompletableFuture.supplyAsync(() -> {
			try {
				// Do something
				long time = ThreadLocalRandom.current().nextLong(1000);
				Thread.sleep(time);
				StringBuilder s = new StringBuilder();
                s.append("AsyncService asyncInvoke param:").append(param).append(",sleep:").append(time);
                return s.toString();
			} catch (InterruptedException e) {
				Thread.currentThread().interrupt();
			}
			return null;
		});
	}
}
```
通过return CompletableFuture.supplyAsync(), 业务执行已从Dubbo线程切换到业务线程，避免了对Dubbo线程池的阻塞。

2、使用AsyncContext实现异步
Dubbo提供了一个类似Sevlet3.0的异步接口AsyncContext，在没有CompletableFuture签名的情况下，也可以实现Provider端的异步执行。
```java
pulic interface AsyncService {
	String sayHello(String name)j;
}
```
服务实现：
```java
public class AsyncServiceImpl implements AsyncService {
	public String sayHello(String name) {
		final AnyncContext asyncContext = RpcContext.startAsync();
		new Thread(() {
			// 如果要使用上下文，则必须要放在第一句执行
			asyncContext.signalContextSwitch();
			try {
                Thread.sleep(500);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            // 写回响应
			asyncContext.write("Hello " + name + ", response from provider.");
		}).start;
		return null;
	}
}
```

### Consumer异步
```java
@DubboReference
private AsyncService asyncService;

@Override
public void run(String... args) throws Exception {
    //调用异步接口
    CompletableFuture<String> future1 = asyncService.asyncInvoke("async call request1");
    future1.whenComplete((v, t) -> {
        if (t != null) {
            t.printStackTrace();
        } else {
            System.out.println("AsyncTask Response-1: " + v);
        }
    });
    //两次调用并非顺序返回
    CompletableFuture<String> future2 = asyncService.asyncInvoke("async call request2");
    future2.whenComplete((v, t) -> {
        if (t != null) {
            t.printStackTrace();
        } else {
            System.out.println("AsyncTask Response-2: " + v);
        }
    });
    //consumer异步调用
    CompletableFuture<String> future3 =  CompletableFuture.supplyAsync(() -> {
        return asyncService.invoke("invoke call request3");
    });
    future3.whenComplete((v, t) -> {
        if (t != null) {
            t.printStackTrace();
        } else {
            System.out.println("AsyncTask Response-3: " + v);
        }
    });

    System.out.println("AsyncTask Executed before response return.");
}
```