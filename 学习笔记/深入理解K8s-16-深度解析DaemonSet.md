---
tags: [k8s, daemonset, 守护进程]
created: 2026-01-29
---

# 深入理解K8s-16-深度解析DaemonSet

## 💡 核心观点
> DaemonSet确保集群中每个节点运行且仅运行一个特定Pod副本，通过nodeAffinity和Tolerations机制实现，是部署网络插件、存储插件和监控Agent的标准方式。

## 📝 详细笔记

### 1. 核心定义与特征

DaemonSet的主要作用是在集群中运行"守护进程"Pod。它具备一下三个"唯一性"特征：

- **全覆盖**：Pod运行在集群里的每一个Node上。
- **唯一性**：每个节点上有且只有一个这样的Pod实例。
- **自维护**：新节点加入时自动创建，旧节点删除时自动回收。

### 2. 典型应用场景

- 网络插件Agent(如Flannel，Calico)：处理节点容器网络。
- 存储插件Agent(如Ceph，GlusterFS)：挂载远程卷。
- 运维监控/日志(如Fluentd，Promethues Agent)：搜集节点数据。

### 3. 工作原理：如何确保"每台都有"？

DaemonSet并不是靠简单的魔法，而是通过控制器模型和调度增强实现的：

| 机制 | 描述 |
| -------------- | --------------- |
| 控制器模型 | 遍历所有Node，检查Pod数量(0则创建，>1则删除，1则正常) |
| nodeAffinity | 自动在Pod对象中加入节点亲和性，将Pod绑定到特定Node |
| Tolerations | 关键点！自动加入容忍度，使其忽略节点的unschedulable污点，甚至能在master节点上运行。 |

注：DaemonSet的Pod往往比集群网络插件还早出现。通过"容忍"`network-uavailable`污点，它们可以在网络还没通的时候就调度成功，从而完成网络插件自身的初始化。

### 4. 版本管理与ControllerRevision

不同于Deployment使用ReplicaSet来记录版本，DaemonSet使用了一个通用的API对象：`ControllerRevision`。

- **本质**：在Data字段里保存了该版本完整的DaemonSet API对象快照。
- **操作**：
  * 查看历史：`kubectl rollout history ds <name>`
  * 版本回滚：`kubectl rollout undo ds <name> --to-revision=1`
- **逻辑**：回滚实际上是读取旧的快照，对当前DaemonSet执行一次PATCH操作。

### 5. StatefulSet的"灰度发布"

#### StatefulSet的Partition(分区更新):

- **作用**：实现金丝雀发布或灰度发布。
- **用法**：设置`spec.updateStrategy.rollingUpdate.partition=N`。
- **效果**：只有序号>=N的Pod会被更新，序号<N的Pod即使被删除重启，也会保持旧版本。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-17-离线业务编排(Job&CronJob)]]
- 应用场景：DaemonSet vs Deployment的选择

## 📚 系列导航
- 上一篇：[[深入理解K8s-15-深入理解StatefulSet之实践部署Mysql一主多从集群]]
- 下一篇：[[深入理解K8s-17-离线业务编排(Job&CronJob)]]
