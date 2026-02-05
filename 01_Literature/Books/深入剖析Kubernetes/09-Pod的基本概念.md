---
tags: [k8s, pod, 配置]
created: 2026-01-29
---

# 深入理解K8s-09-Pod的基本概念

## 💡 核心观点
> Pod是Kubernetes最小编排单位，管理整体的网络、存储、调度和安全策略，而Container只负责运行逻辑。理解Pod级别和Container级别的字段划分是掌握K8s的关键。

## 📝 详细笔记

### 1. Kubernetes的关键理念与核心抽象

#### 1.1 Pod是最小编排单位

- Kubernetes的核心设计：Pod，而非容器，是调度、网络、存储和安全策略管理的对象。
- Pod在语义上接近"轻量虚拟机"：
  * 容器在Pod内共享环境(特别是Linux Namespace与资源视图)。
  * Pod承担"机器角色"，容器是"程序"。

#### 1.2 Pod与Container的关系

- container是Pod.spec中的普通字段。
- Pod管的是整体(网络、存储、调度、安全)，Container管运行逻辑(镜像、命令、挂载)。

### 2. Pod的关键字段与语义

#### 2.1 调度相关字段(Pod 级别)

| 字段 | 作用 |
| -------------- | --------------- |
| nodeSelect | 指定Pod必须调度到具备特定label的节点。 |
| nodeName | 指定目标节点(跳过调度器)，常用于调试。 |
| affinity/anti-affinity | 更细粒度的调度约束。 |

#### 2.2 网络/存储/安全(Pod级别)

- Pod整体的"机身配置":
  * hostNetwork/hostPID/hostIPC：共享宿主机Namespace。
  * volumes：定义存储卷。
  * securityContext(Pod级别)：定义整体安全策略。

#### 2.3 /etc/hosts控制(Pod级别)

- hostAliases:
  * 以声明方式修改hosts文件。
  * Pod重建后由Kubelet重写；不可直接手动修改。

### 3. Pod内多容器协作机制

#### 3.1 Linux Namespace 共享

- Pod设计核心目标：让同一个Pod内的容器尽可能共享Namespace，类似进程在同一台机器上运行。
- 常见共享模式：
  * shareProcessNamespace: true -> 容器共享PID Namespace，可互相看到对方进程(含pause容器)。
  * hostNetwork/HostPID/hostIPC -> 直接使用宿主机的Namespace

#### 3.2 Init Container

- 与普通容器等价定义，但执行顺序严格控制：
  * 顺序必定为initContainer1 -> 2 -> ... -> containers。
  * 用于依赖准备、环境检查等场景。

### 4. Container(容器)级别的关键字

- **ImgagePullPolicy**:
  * 如果镜像标签是latest或者没有指定tag，则默认ImagePullPolicy=Always。-- 总是拉去像，至于底层CRI是否会根据layer进行hash的判断，这里不谈。
  * 如果镜像标签是其他具体标签(如nginx:1.21)
  * IfNotPresent:宿主机没有才拉取(推荐生产环境配合使用具体版本号并配合此项)。
  * Never：只使用本地镜像。

- **Lifecycle(生命周期钩子)**：
  * postStart：容器启动后立即执行。注意：它与ENTRYPOINT异步执行，不保证先后顺序。
  * preStop：容器被杀死前执行。它是同步阻塞的，常用于应用的"优雅退出"(如关闭数据库连接)。

### 4. Pod的生命周期与状态机

Pod的status.phase是判断应用健康状况的第一窗口：

1. Pending：资源请求已提交，但尚未调度成功或镜像正在下载。
2. Running：至少一个容器正在运行。
3. Succeeded：所有容器正常退出(状态码0)，多见于Job任务。
4. Failed：至少一个容器非正常退出。
5. Unknown：Kubelet失去联系(通常是网络插件或节点宕机问题)。

注：Running不等于Ready：Running仅代表进程在运行，而Ready(属于Conditions)才代表Pod已经通过了健康检查，可以对外接收流量。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-10-深入解析Pod对象(二)使用进阶]]
- 最佳实践：Pod配置的常见陷阱和优化技巧

## 📚 系列导航
- 上一篇：[[深入理解K8s-08-为什么需要Pod]]
- 下一篇：[[深入理解K8s-10-深入解析Pod对象(二)使用进阶]]
