---
tags: [k8s, statefulset, mysql, 实战]
created: 2026-01-29
---

# 深入理解K8s-15-深入理解StatefulSet之实践部署Mysql一主多从集群

## 💡 核心观点
> 通过StatefulSet部署Mysql集群的实战案例，展示了如何利用InitContainer处理配置差异和数据同步，利用Sidecar容器处理集群初始化，这是容器化复杂有状态应用的通用模式。

## 📝 详细笔记

### 1. 文章核心内容概括

文章的核心是一个实战案例：如何使用Kubernetes的`StatefulSet`控制器，将一个传统的、非云原生的Mysql主从集群成功"搬进"容器世界。

深入剖析了在Kubernetes中处理有状态应用的通用模式，包括：

- 拓扑状态的管理：如何保证Master是0号，Slave是1,2...号。
- 存储状态的管理：如何保证Pod重启后依然能挂载到原有的数据。
- 复杂初始化逻辑的容器化：利用InitContainer和Sidercar处理数据备份与同步。

### 2. 为什么选Mysql？为什么要用StatefulSet？

**为什么选Mysql举例？**

因为Mysql是典型的**非原生分布式系统**。它对主从切换、数据同步、配置差异有严格的要求，比Etcd或Cassandra更难容器化。攻克了Mysql，就意味着掌握了绝大多数复杂有状态应用的方法。

**为什么必须用Statefulset而不是Deployment？**

- 身份唯一性：Mysql集群需要固定的编号(如mysql-0必须是Master)。
- 持久化绑定：数据库的数据不能因为Pod漂移而丢失，必须实现Pod与物理存储(PV)的"一对一固定绑定"。
- 有序启动与缩容：Slave节点在启动时需要从前一个节点拷贝数据，这要求Pod必须按顺序启动。

### 3. 具体实现步骤

**Statefulset对象的大致框架**：
![整体Statefulset框架](251231-164331.png))

**第一步：解决配置差异(利用ConfigMap + InitContainer)**

- **问题**：Master需要开启二进制日志(log-bin)，Slave需要只读(super-read-only)。
- **解决**：
  * 将两份配置文件存在一个ConfigMap中。
  * 增加一个InitContainer(init-mysql),它读取Pod的序号(index):
    + 如果是0号，拷贝Master配置。
    + 如果非0号，拷贝Slave配置。
    + 同时生成唯一的`server-id`写入配置文件。

**第二步：解决数据同步(利用PVC + InitContainer)**

- **问题**：新启动的Slave必须先拥有Master基础数据。
- **解决**：
  * 使用`volumeClaimTemplates`自动为每个Pod分配独立的存储卷(PVC)。
  * 增加第二个InitContainer(clone-mysql)：
    + 通过`ncat`指令从"前一个Pod"(如mysql-0)跨网络拷贝数据。
    + 使用`xtrabackup`工具进行数据恢复，确保数据一致性。

**解决集群初始化(利用Sidecar容器)**

- **问题**：Mysql容器启动后，需要执行`CHANGE MASTER TO`等SQL语句才能建立主从关系。
- **解决**：
  * 引入一个Sidecar容器(`xtrabackup`)，它与Mysql容器共享网络和存储。
  * sidercar负责监听Mysql是否启动成功，然后自动执行拼接好的初始化SQL。
  * 常驻职责：它还会开启3307端口，专门负责给后续新加入的Slave节点提供备份数据传输服务。

**最终StatefulSet的yaml文件请参考下面的链接：**
[k8s]: [https://kubernetes.io/zh-cn/docs/tasks/run-application/run-replicated-stateful-application/ "mysql集群yaml"]

**流量调度：Headless Service + 普通Service**

- 写操作：通过`mysql-0.mysql`(Headless Service 提供的固定DNS)直接访问Msater。
- 读操作：通过`mysql-read`(普通Service)实现多个主从节点之间的负载均衡。

### 4. 小结

这篇文章揭示了使用`StatefulSet`的三个核心心法：

1. **人格分裂**：些YAML时要分情况考虑"我是0号Pod该做什么"和"我是N号Pod该做什么"。
2. **阅后即焚**：初始化脚本要具备幂等，执行完成后要清理临时状态文件，防止容器重启后重复初始化导致报错。
3. **容器平等**：Pod内的容器是平等的，Sidecar在执行SQL前必须先做健康检查，等待Mysql主进程就绪。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-16-深度解析DaemonSet]]
- 实战经验：其他有状态应用的容器化方案

## 📚 系列导航
- 上一篇：[[深入理解K8s-14-深入理解StatefulSet之存储状态]]
- 下一篇：[[深入理解K8s-16-深度解析DaemonSet]]
