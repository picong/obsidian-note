---
tags:
  - k8s
  - 存储
  - pv
  - pvc
created: 2026-02-05 14:21
---

# 24-本地持久化卷(LocalPersistentVolume)

## 💡 核心观点
> PV和PVC体系给用户定制持久化卷带了比较的高的灵活性。Local Persistent Volume：通过StorageClass里面的延迟绑定的属性，让PVC和PV的绑定延迟到调度发生的时刻，让PV的位置也成为了Pod调度的过滤条件。并且要求使用Local Persistent的应用必须具备数据备份和恢复的能力。

## 📝 详细笔记
### 1.Local Persistent Volume适用范围及难点
- **适用范围**：优先级较高的系统应用，需要在多个节点上存储数据，并且对I/O较为敏感。许多数据存储应用例如MongoDB、Canssandra等以及分布式文件系统。并且要求这些应用必须具备数据备份和数据恢复的能力，否则节点宕机将丢失数据。
- **设计难点**：
	- **如何将本地磁盘抽象成PV**，我们不能直接使用hostPath+NodeAffinity来实现，因为如果跟操作系统共用本地磁盘，很容易造成磁盘被写满导致节点宕机，从而导致数据丢失的问题。我们只能是通过在宿主机上插入额外的磁盘来实现LCV，即**一个PV一块盘**。
	- **调度器要怎么将POD调度到PVC匹配的PV所在的节点上面去**：在调度Pod的时候，必须要知道哪些节点上有哪些Local PV，然后根据Local PV的分布再决定将Pod调度到哪个节点上去。--- 在k8s的调度器中，有一个叫做`VolumeBindingChecker`的过滤器条件专门负责这个过滤。

### 2. 在本地k8s集群中使用Local PV的步骤
> 首先我们要在集群里配置好磁盘或者块设备。在公有云上面，这个操作就相当于是在虚拟机上面额外挂载一个磁盘。

1. 创建一个挂载点，比如`/mnt/disks`,然后将挂载进来的磁盘或块设备挂载到我们创建的挂载点上。对于实验环境，我们可以挂载几个内存盘来模拟本地磁盘。`mount -t tmpfs $val /mnt/disks/$vol`。
2. 定义本地磁盘的PV，该PV定义需要定义`local`字段，该字段正是上面磁盘挂载的目录`/mnt/disks/vol`。还需要定义nodeAffinity字段，该字段指定PV所在节点的名字。后面Pod调度的时候需要依赖该字段进行节点的选择。
3. 创建PV：`kubectl create -f local-pv.yaml`。
4. 创建StorageClass来描述这个PV:
	- 属性`provisioner: kubernetes.io/no-provisioner`，因为Local PV暂时不支持Dynamic Provisioning。
	- 属性`volumeBindingMode: WaitForFirstConsumer`，该属性是PVC和PV延迟绑定的关键。k8s中的VolumeController根据该字段来判断不立即将PVC和PV进行绑定。
	- 在调度器中维护了一个与Volume Controller类似的控制循环，它专门负责哪些声明了"延迟绑定"的PV和PVC进行绑定工作。这样设计不会拖慢调度器的调度性能。
	- 创建普通的PVC，该PVC除了声明使用PV的属性外，还需要注意storageClassName字段要和PV保持一致。
	- 创建Pod，该Pod api中volumes的需要声明使用上面定义的PVC，即可在创建该Pod的时候触发PVC和PV的绑定。
5. 手动删除Local PV的流程：
	1. 删除使用这个PV的Pod；
	2. 从宿主机移除本地磁盘；
	3. 删除PVC；
	4. 删除PV。
**注意：可以使用k8s提供的Static Provisioner，通过启动DaemonSet来自动创建/删除 Local PV(可以更改配置)** 

---
文章链接：[29 | PV、PVC体系是不是多此一举？从本地持久化卷谈起-深入剖析Kubernetes-极客时间](https://time.geekbang.org/column/article/42819)