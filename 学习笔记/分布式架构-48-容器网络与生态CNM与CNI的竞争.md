---
tags:
  - CNM
  - CNI
  - 容器
created: 2026-01-30
---

# 分布式架构-48-容器网络与生态CNM与CNI的竞争

## 💡 核心观点
容器网络标准(CNM/CNI)的目的是将网络功能从容器运行时/编排系统中剥离，使其成为外部扩展的功能。CNI(Container Networking Interface)已成为当前的事实标准，而CNM(Container Network Model，由Docker提出)已基本失去实用价值。

## 📝 详细笔记

### CNM与CNI的比较

| 特性   | CNM(Container Network Model)                                                      | CNI(Container Networking Interface)                                            |
| ---- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 提出方  | Docker(libnetwork是其标准实现)                                                          | CoreOS(基于RKT网络，与K8s合作发展)                                                       |
| 现状   | 已失去实用价值，有历史/学术价值                                                                  | 事实标准，获得Kubernetes、RedHat、OpenShift等广泛支持。                                       |
| 目标   | 与CNI完全重叠，导致两者为竞争关系。                                                               | 与CNM目标重叠，但最终胜出。                                                                |
| 设计   | 抽象资源为Sandbox、Endpoint和Network，提供读写接口。                                             | 结构更轻便，也包含Sandbox、Network概念，但利用Kubernetes资源模型。                                  |
| 主要功能 | 1. 网络管理：创建、删除网络，容器接入/退出网络等(CNM定义了10个接口)。<br>2.IP地址管理：为三层网络分配唯一IP地址(依赖协调工具如libkv)。 | 1. 网络管理：网络的增加与删除两项操作。<br>2. IP地址管理：解决IP地址的唯一性、回收和时效性问题(如Host-Local方式比DHCP更实用)。 |

### 网络插件生态与实现模式

目前支持CNI的网络插件众多，但跨主机通信的实现方式主要分为三类：

#### Overlay模式(上层逻辑网络)
- 原理：通过在IP包外部添加额外的包头(如VXLAN、IPIP)进行封装，创建虚拟的逻辑网络。
- 特点：
  - 优点：不受底层物理网络约束，自由度高，易用性好，适用于被限制网络环境(如只允许三层转发)。
  - 缺点：额外的封包/解包导致性能下降(信息密度降低，传输速度较慢)。
- 代表插件：Flannel(VXLAN/UDP)、Calico(IPIP)、Weave。
  - Flannel-VXLAN：相比早期的Flannel-UDP，性能因VXLAN进入Linux内核而大幅提升。

#### 路由模式(Underlay特例)
- 原理：跨主机通信通过路由转发实现，不进行隧道封包。依赖Linux内置的路由协议，将路由表分发到每个主机。
- 特点：
  - 相比Overlay性能有明显提升。
  - 缺点：依赖底层网络环境支持：要么所有主机二层连通，要么不同子网间由BGP的路由相连。
- 代表插件：Flannel(HostGateway)、Calico(BGP模式)。
  - Flannel-HostGateway：Flannel Agent设置主机路由表，数据包被Linux主机直接转发，但无法穿透其他路由设备(如路由器)，需Calico-BGP配合。

#### Underlay模式(容器与宿主机处于同一网络)
- 原理：容器的网络接口直接与底层网络通信，两者地位相同，最大限度利用硬件能力。
- 特点：
  - 优点：通常具有最优秀的性能表现(高吞吐量、低延迟)。
  - 缺点：部署繁琐，直接依赖于硬件和底层网络环境，灵活性不如Overlay。
- 代表插件：MACVLAN、SR-IOV(用于硬件直通)。

### CNI插件的选择
选择CNI插件主要考虑两方面：
- 环境支持：你的系统所处的环境是否支持该网络模式(如网络限制)。
- 性能与功能：
  - 性能：Underlay(MACVLAN/SR-IOV)性能最好，吞吐量最高、延迟最低。Overlay(Flannel-VXLAN)吞吐量较低，延迟较高，但灵活性好。需要在通用性与性能间权衡。
  - 功能：需考虑是否满足特定的功能需求，例如Kubernetes的NetworkPolicy资源(ACL策略)不属于CNI范畴，需要选择支持它的插件(如Calico、Weave)，而Flannel不支持。

## 🔗 关联思考
- 相关课题：[[分布式架构-49-Kubernetes存储设计理念]]
- CNI的胜出体现了云原生生态的开放性和标准化趋势
- 网络插件的选择需要在性能、功能和环境支持之间权衡

## 🚀 下一步行动
- [ ] 实践部署不同的CNI插件(如Flannel、Calico)
- [ ] 深入学习Kubernetes的NetworkPolicy资源

## 📚 系列导航
- 上一篇：[[分布式架构-47-虚拟化网络设备与容器通信原理]]
- 下一篇：[[分布式架构-49-Kubernetes存储设计理念]]
