---
tags:
  - Kubenetes
  - 存储
created: 2026-01-30
---

# 分布式架构-49-Kubernetes存储设计理念

## 💡 核心观点
镜像的稳定性(要求数据不变)与生产数据持久性(要求数据可变且持久化)之间的矛盾是容器持久化存储的出发点。Kubernetes通过PV、PVC和StorageClass实现了静态分配和动态分配两种持久化存储方案，其中动态分配是更合理的设计，是工业级编排系统应对大规模应用的必然选择。

## 📝 详细笔记

### Volume概念的演进：操作系统 -> Docker -> Kubernetes

#### 操作系统基础概念
- Mount(挂载)：动词，将外部存储挂载到系统中。
- Volume(卷)：名词，物理存储的逻辑抽象，提供有弹性的分割方式。

#### Docker挂载类型
Docker将操作系统概念延伸到容器，支持三种挂载类型：

| 类型           | 命令参数                   | 作用              | 特点                                                                     |
| ------------ | ---------------------- | --------------- | ---------------------------------------------------------------------- |
| Bind Mount   | -v 或 --mount type=bind | 将宿主机目录/文件映射到容器内 | 最早支持。不受Docker管理和保护，难以跨主机共享，配置繁琐。                                       |
| Volume Mount | --mount type=volume    | 抽象的存储资源。        | 提升了抽象能力。Docker可管理，通过Volume Driver(卷驱动)支持多种存储介质(如网络存储)，减轻了Docker自身的工作量。 |
| tmpfs        | --mount type=tmpfs     | 内存中读写临时数据。      | 非持久化存储，与持久化存储无关。                                                       |

#### Kubernetes Volume的细化
Kubernetes将Volume细化为两类：
- 普通Volume(非持久化)：
  - 目的：为同一个Pod中的多个容器提供共享存储资源。
  - 生命周期：与挂载它的Pod相同。Pod销毁，普通Volume逻辑上不复存在。
- PersistentVolume(PV，持久化卷)：
  - 目的：持久化保存数据。
  - 生命周期：独立于Pod存在，不依附于任何宿主机节点(网络存储为主，或使用Local PV特殊方案)。

### 持久化存储方案：PV、PVC与StorageClass

为实现开发与运维的分离，Kubernetes设计了PersistentVolumeClaim(PVC)资源。

| 资源                         | 角色定位         | 职责描述                       |
| -------------------------- | ------------ | -------------------------- |
| PersistentVolume(PV)       | 运维/管理员负责提供。  | 已被分配好的具体存储(容量、地址、驱动、回收策略等) |
| PersistentVolumeClaim(PVC) | 用户/开发人员负责声明。 | 对所需存储能力的请求(最小容量、访问模式等)。    |

#### Static Provisioning(静态分配)
- 流程：
  - 管理员：手工预先分配若干PV(定义容量、访问模式、回收策略、存储驱动等)。
  - 用户：创建PVC(声明所需容量和访问模式)。
  - Kubernetes：根据供需关系进行撮合，将PVC绑定到满足要求的PV上(一对一独占)。
  - Pod：引用已绑定的PVC。
- 特点：简单直观，适用于中小规模集群、管理员可手工管理存储的场景。但难以自动化，当集群规模增大时，人工分配成为瓶颈，且可能因一对一绑定造成资源浪费。

#### Dynamic Provisioning(动态分配)
- 目标：解决Static Provisioning中人工分配和自动化的难题。
- 核心资源：StorageClass(SC)。
- 流程：
  - 管理员：配置Provisioner(资源分配器)(In-Tree或Out-of-Tree CSI驱动)。
  - 管理员：根据存储性能、类型等配置StorageClass(SC)。
  - 用户：创建PVC，明确指定由哪个SC来处理请求。
  - StorageClass：接管撮合操作，自动生成PV描述信息，并发送给Provisioner。
  - Provisioner：操作背后的存储系统自动分配空间，并返回符合要求的PV供Pod使用。
- 优势：
  - 自动化：解放管理员，Pod自动扩缩时存储也能自动分配。
  - 声明式精髓：用户只需描述意图(PVC)和类型(SC)，不需要关心PV这个中间产物，更符合声明式编程。
  - 可管理性高：回收策略等由Provisioner代码管理，实现更精细的操作(如安全删除)。
- 结论：Dynamic Provisioning是更合理的设计，可以实现Static Provisioning的所有需求，是工业级编排系统应对大规模应用的必然选择。

## 🔗 关联思考
- 相关课题：[[分布式架构-50-Kubernetes存储扩展架构]]
- 存储的动态分配体现了Kubernetes声明式API的设计理念
- PV、PVC的分离实现了开发与运维的职责分离

## 🚀 下一步行动
- [ ] 实践创建PV和PVC资源
- [ ] 了解不同存储类型的StorageClass配置

## 📚 系列导航
- 上一篇：[[分布式架构-48-容器网络与生态CNM与CNI的竞争]]
- 下一篇：[[分布式架构-50-Kubernetes存储扩展架构]]
