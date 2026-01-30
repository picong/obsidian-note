---
tags:
  - Kubernetes
  - 存储
created: 2026-01-30
---

# 分布式架构-50-Kubernetes存储扩展架构

## 💡 核心观点
Kubernetes借鉴了传统操作系统接入或移除设备的方法，将存储管理分解为Provision、Attach、Mount三个核心操作及其逆操作。同时支持FlexVolume和CSI两种存储扩展机制，其中CSI是当前重点发展的开放标准。

## 📝 详细笔记

### Kubernetes存储架构模型

Kubernetes借鉴了传统操作系统接入或移除设备的方法，将存储管理分解为六个核心操作，由存储插件实现，并由Kubernetes的控制器和管理器进行调用：

| 操作              | 类比       | 作用                                | 逆操作           | 调用者                      |
| --------------- | -------- | --------------------------------- | ------------- | ------------------------ |
| Provision(准备)   | 购买新存储设备  | 确定来源、容量                           | Delete(移除)    | PV控制器                    |
| Attach(附加)      | 存储设备接入   | 确定设备名称、驱动方式等面向系统侧信息。              | Detach(分离)    | AD控制器/VolumeManager      |
| Mount(挂载)       | 设备挂载到指定位置 | 确定访问目录、文件系统格式等面向应用侧信息。            | Unmount(卸载)   | Volume Manager           |

#### Kubernetes核心组件
- PV控制器(PersistentVolume Controller):
  * 管理PersistentVolume(PV)和PersistentVolumeClaim(PVC)的生命周期。
  * 管理存储插件的Provision/Delete操作。
- AD控制器(Attach/Detach Controller):
  * 确保Pod所在节点附加好所需存储，并在Pod销毁后分离存储。
  * 调用存储插件的Attach/Detach操作(默认模式)。
- Volume管理器(Volume Manager)-kubelet内置：
  * 负责本节点Volume的Attach/Detach/Mount/Unmount操作。
  * 默认只执行Mount/Unmount。

### 存储扩展机制：FlexVolume与CSI

Kubernetes同时支持两种独立的存储扩展机制，但发展方向和成熟度不同：

#### FlexVolume(早期私有机制)
- 特点：Kubernetes早期支持(1.2开始)，是针对Kubernetes的私有扩展。
- 状态：已处于冻结状态，不再发展新功能。
- 实现：仅是一个实现Attach/Detach/Mount/Unmount操作的可执行文件(如Shell脚本)，部署在每个节点的特定目录。
- 不足：
  * 非全功能：不包含Provision/Delete，需要额外编写External Provisioner实现Dynamic Provisioning。
  * 部署繁琐：独立于Kubernetes，新节点需手动部署或用DaemonSet维护。
  * 协作不便：每次操作都是独立调用，接口之间协作(如传递状态)需依赖临时文件，不够严谨。

#### CSI(Container Storage Interface-开放标准)
- 特点：Kubernetes 1.9开始加入，是公开的技术规范，可被任何容器运行时/编排引擎支持。
- 状态：目前Kubernetes重点发展的扩展机制。
- 优势：完善、易于部署和维护。插件本身是一组标准的Kubernetes资源(如gRPC服务的StatefulSet/DaemonSet)。
- CSI组件(Kubernetes实现)：
  * External Provisioner，External Attacher，External Resizer，External Snapshotter等，调用第三方插件接口。
- 第三方插件(存储提供商实现)-三大gRPC接口：
  * CSI Identity接口：描述插件基本信息、版本和健康状态。
  * CSI Controller接口：从存储系统角度管理资源(Provision，Delete，Attach，Detach，快照)。通常部署为StatefulSet。
  * CSI Node接口：从集群节点角度操作资源(分区、格式化、Mount/Unmount)。通常部署为DaemonSet。

### 存储驱动迁移：In-Tree到Out-of-Tree
- 背景：Kubernetes早期内置了大量In-Tree存储驱动。
- 问题：缺乏灵活性、设计可靠性和安全性问题。
- 趋势：从1.14版本开始，Kubernetes启动了In-Tree存储驱动的CSI外置迁移(Out-of-Tree)工作。
- 兼容性设计(CSIMigration)：
  * 为了遵守"升级版本不应影响已有功能"的原则，Kubernetes提出了CSIMigration方案。
  * 这允许Out-of-Tree的CSI驱动能够自动伪装成旧的In-Tree接口(如awsElasticBlockStorage)来提供服务。
  * 这体现了Kubernetes设计中在理论最优与现实兼容性之间权衡的理念。

## 🔗 关联思考
- 相关课题：[[分布式架构-51-Kubernetes存储生态系统]]
- CSI的设计体现了云原生的开放性和标准化趋势
- 存储扩展架构的演进反映了Kubernetes从单体到可扩展的架构演变

## 🚀 下一步行动
- [ ] 深入学习CSI的三大接口规范
- [ ] 了解主流存储提供商的CSI驱动实现

## 📚 系列导航
- 上一篇：[[分布式架构-49-Kubernetes存储设计理念]]
- 下一篇：[[分布式架构-51-Kubernetes存储生态系统]]
