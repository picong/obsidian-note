---
tags: [k8s, 存储, local-pv, 性能]
created: 2026-01-29
---

# 深入理解K8s-24-本地持久化卷(LocalPersistentVolume)

## 💡 核心观点
> Local PV通过延迟绑定(WaitForFirstConsumer)机制，在调度时综合考虑节点资源和PV位置，为高I/O性能需求的有状态应用提供了本地存储解决方案，但需要应用层具备数据备份能力。

## 📝 详细笔记

### 1. 为什么需要 Local PV?

虽然远程存储(NFS，Ceph，云硬盘)是主流，但本地存储在特定场景下不可替代：

- **高I/O性能**：直接使用宿主机SSD，读写延迟远低于网络存储。
- **适用场景**：分布式数据存储(MongoDB, Cassandra)、分布式文件系统(GlusterFS, Ceph)或高并发缓存应用。
- **风险提示**：数据不具备跨节点冗余。如果宿主机宕机且无法恢复，数据会丢失。应用层必须具备数据备份和恢复能力。

### 2. PV/PVC体系的设计价值

"过度设计"了吗？PV/PVC的核心价值在于解耦与可扩展性。

- **统一接口**：开发人员只管写PVC，无需关心底层是本地盘还是阿里云ESSD。
- **扩展能力**：正因为有了这层抽象，kubernetes才能在不破坏现有Pod定义的前提下，通过修改PV的处理逻辑(如引入延迟绑定)来支持本地存储。

### 3. Local PV的两大设计难点

- **存储抽象**："一个PV一块盘":
  * 原则：严禁直接将宿主机目录(hostPath)当做PV。
  * 原因：hostPath不可控，容易写满磁盘导致宿主机宕机，且缺乏I/O隔离。
  * 做法：Local PV对应的应是宿主机上的一块独立磁盘或块设备。

- **调度关联**："在调度时考虑Volume分布":
  * 挑战：常规PV是"先调度，后挂载"；Local PV是磁盘已经在某台机器上了，Pod必须调过去。
  * 方案：
    + NodeAffinity：在PV对象中声明节点亲和性，告诉调度器这个PV只能在node-1上用。
    + VolumeBindingChecker：调度器在过滤阶段会检查Pod声明的PV是否在该节点上可用。

### 4. 关键特性：延迟绑定(WaitForFirstConsumer)

这是Local PV的核心黑科技，通过StorageClass中的`volumeBindingMode`: `WaitForFirstConsumer`实现。

- **传统绑定问题**：PVC一创建就立即寻找匹配的PV绑定。如果绑定了node-1的PV，但Pod因为其他约束(如CPU不足)无法去node-1，Pod就会永远处于Pending。

- **延迟绑定逻辑**：
  * PVC创建后保持Pending，不立刻找PV。
  * 等到声明该PVC的Pod进入调度器。
  * 调度器综合考虑节点资源、亲和性及PV所在位置，选出最优节点。
  * 最后时刻再触发PVC与该节点上PV的绑定。

### 5. 时间操作路线图

- **准备环境**：在宿主机挂载独立磁盘(或用RAM Disk模拟)。
- **定义PV**：声明`local.path`并设置`nodeAffinity`。
- **创建SC**：设置`provisioner: no-provisioner`(本地卷不支持自动创建存储空间)及`volumeBindingMode: WaitForFirstConsumer`>
- **创建PVC/PV**：常规声明即可。

小技巧：生产环境下建议使用Static Provisioner(以DaemonSet运行)。它会自动监控宿主机指定目录，发现新挂载的磁盘并自动创建PV对象。

## 🔗 关联思考
- 相关课题：
- 性能优化：Local PV vs 远程存储的权衡

## 📚 系列导航
- 上一篇：[[深入理解K8s-23-PV、PVC、StorageClass简介]]
- 本系列完结，返回：[[深入理解Kubernetes笔记]]
