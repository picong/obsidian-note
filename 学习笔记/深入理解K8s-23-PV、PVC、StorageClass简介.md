---
tags: [k8s, 存储, pv, pvc, storageclass]
created: 2026-01-29
---

# 深入理解K8s-23-PV、PVC、StorageClass简介

## 💡 核心观点
> Kubernetes通过PV/PVC实现存储的接口与实现分离，通过StorageClass实现动态供给，采用两阶段处理(Attach和Mount)将远程存储变成容器内的目录。

## 📝 详细笔记

### 1. 核心组件：解耦与面向对象

k8s存储设计的核心思想是将"存储需求"与"存储实现"解耦，类似于编程中的"接口"与"实现"。

| 组件                         | 角色  | 核心关注点                        | 负责人  |
| -------------------------- | --- | ---------------------------- | ---- |
| PVC(PersistentVolumeClain) | 接口  | 声明Pod需要多少存储、什么权限(ROW/RWX)    | 开发人员 |
| PV(PersistentVolume)       | 实现  | 定义存储的具体类型、位置、参数(NFS/Ceph/云盘) | 运维人员 |
| StorageClass               | 模板  | 定义PV的属性和自动创建PV的插件            | 运维人员 |

### 2. 存储绑定的"红娘"：PersistentVolumeController

- **机制**：运行在Master节点上的控制器。
- **任务**：不断减少"单身"的PVC，在集群中寻找满足条件的PV进行绑定。
- **绑定标志**：将PV的名字填入PVC对象的`spec.volumeName`字段。
- **匹配条件**：
  * PV属性满足PVC(如：容量大小、访问模式)。
  * StorageClassName必须一致。

### 3. 持久化卷的"两阶段处理"(Two-Stage Process)

这是k8s让远程存储编程容器内目录的关键过程。

**第一阶段: Attach(挂载设备)**

- **操作**：将远程磁盘(如云盘)挂载到宿主机。
- **执行者**：Master节点上的`AttachDetachController`。
- **逻辑**：类似`gcloud attach-disk`或将云硬盘插入服务器。

**第二阶段：Mount(挂载目录)**

- **操作**：格式化磁盘并挂载到宿主机上的Pod Volume目录。
- **执行者**：Node节点上的`kubelet`(具体由`VolumeManagerReconciler`协程处理)。
- **路径实例**：`/var/lib/kubelet/pods/<PodID>/volumes/kubernetes.io~<Type>/<Name>`。

注意：如果是NFS这种网络文件系统，没有"磁盘设备"，则直接跳过Attach阶段，直接执行Mount。

### 4. 动态供给：Dynamic Provisioning

为了解决成千上万个PV手动创建(Static Provisioning)太累的问题，k8s引入了StorageClass。

- **原理**：
  * 运维预先定义`StorageClass`(包含存储插件Provisioner和参数)。
  * 开发创建PVC时指定`storageClassName`。
  * k8s自动调用存储插件，在后端创建真实的存储空间，并自动生成对应的PV。

### 5. 为什么这么设计？

1. **不足为主循环**：Mount操作是耗时(涉及网络/磁盘I/O)，K8s将其设计在独立的协程中，保证`kubelet`主循环不会因为存储挂载慢而卡死。
2. **云原生兼容性**：通过这种抽象，Pod YAML无需修改即可在AWS、阿里云、私有化Ceph集群间迁移，只需更换背后的StorageClass即可。
3. **安全性与职责分离**：开发不用关心Ceph的密钥、NFS的IP地址，这些敏感和专业信息都封装在PV/StorageClass中。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-24-本地持久化卷(LocalPersistentVolume)]]
- 存储方案：不同存储后端的选择

## 📚 系列导航
- 上一篇：[[深入理解K8s-22-Operator工作原理]]
- 下一篇：[[深入理解K8s-24-本地持久化卷(LocalPersistentVolume)]]
