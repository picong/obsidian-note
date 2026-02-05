---
tags:
  - Kubernetes
  - 调度
created: 2026-01-30
---

# 分布式架构-52-Kubernetes资源模型与调度器设计

## 💡 核心观点
Kubernetes通过定义资源模型来量化供需关系，并利用调度器在节点与Pod之间建立"运行"与"恰当"的匹配关系。通过Requests和Limits的设置、QoS等级、优先级和驱逐机制，Kubernetes在资源约束下实现了最优调度和集群稳定性保障。

## 📝 详细笔记

### Kubernetes资源模型(Resource Model)

资源是Kubernetes实现声明式API的前提。狭义的物理资源主要指计算(CPU/内存)、存储和网络。

#### 资源的分类与特性

| 资源类型   | 代表     | 资源不足时的表现                | 计量单位                                  |
| ------ | ------ | ----------------------- | ------------------------------------- |
| 可压缩资源  | CPU    | 资源不足时,Pod仅会变慢,不会被杀死     | Core/Millicore                        |
| 不可压缩资源 | Memory | 资源不足时,Pod会因OOM被系统杀死      | Bytes(支持Ei、Pi、Ti、Gi、Mi、Ki)           |

#### Requests vs Limits(供需的博弈)
Kubernetes将资源设置分为两个维度，解决用户"过度申请"与"资源利用率"之间的矛盾：

- Requests(请求值)：
  * 用途：供调度器(Scheduler)使用。
  * 作用：调度器根据此值判断节点是否有足够资源容纳Pod。
- Limits(限制值)：
  * 用途：供Cgroups(底层隔离)使用。
  * 作用：限制容器能使用的资源上限(硬限)。

### 稳定性保障：QoS、优先级与驱逐

为了在资源紧张(超卖)的情况下维持系统稳定，Kubernetes设计了一套等级制度。

#### 服务质量等级(QoS Level)
由requests和limits的组合自动推导得出，决定了资源不足时谁先被牺牲：

1. Guaranteed(最高级)：
  a. 所有容器都设置了requests和limits，且值相等。
  b. 待遇：除非超过自身limit或系统极度崩溃，否则最后被驱逐。
2. Burstable(中级)：
  a. 设置了requests但小于limits，或未设置limits。
  b. 待遇：资源弹性，弹性范围内安全，资源紧缺时次优被驱逐。
3. BestEffort(最低级)：
  a. 未设置任何request和limits。
  b. 待遇：能用多少用多少，但资源不足时最先被驱逐。

#### 优先级与抢占(Priority & Preemption)
- PriorityClass：管理员定义的优先级资源。
- 调度抢占：当高优先级Pod无法调度时，会驱逐低优先级Pod以腾出空间(Preemption)。

#### 节点驱逐机制(Eviction)
由节点上kubelet执行，当不可压缩资源(内存、磁盘、Inode)低于阈值时触发。

- 软驱逐(Soft Eviction)：设定较低警戒线 + 观察期(Grace Period)。如果资源回升则不驱逐，否则优雅退出。
- 硬驱逐(Hard Eviction)：设定较高终止线，一旦触及，立即强制杀死Pod。
- 防抖动设计：
  * `--eviction-minimum-reclaim`：驱逐后至少清理多少资源才停止(防止反复驱逐)。
  * `--eviction-pressure-transition-period`：驱逐后一段时间内禁止新Pod调度到该节点。

### 默认调度器架构(Scheduler Design)

面对大规模集群，调度器必须解决准确性与性能(扩展性)的平衡问题。

#### 核心架构：共享状态的双循环
为避免每次调度都发起数千次远程访问，Kubernetes采用了Informer Loop(同步信息)和Scheduler Loop(执行调度)并行工作的模式。

#### 调度过程的两大算法
1. Predicate(过滤-能不能运行)：
  a. 基于硬性条件过滤节点。
  b. 通用过滤：CPU/内存是否足够？端口是否冲突？
  c. 卷过滤：存储卷挂载是否冲突？
  d. 节点过滤：污点(Taints)与容忍度(Tolerations)匹配。
2. Priority(打分-恰不恰当)：
  a. 对符合条件的节点打分(0-10分)。
  b. LeastRequested：选剩余资源最多的节点(负载均衡)。
  c. BalancedResourceAllocation：选各种资源分配最均衡的节点(避免CPU跑满而内存闲置)。
  d. ImageLocality：优先选已有镜像的节点(减少下载时间)。

#### 乐观绑定(Optimistic Binding)
- 问题：调度决策到实际创建Pod有时间差，可能导致状态不一致。
- 策略：调度器先更新本地缓存(Cache)，异步更新etcd。如果最终失败，再由Informer回滚。这保证了调度的高吞吐量。

## 🔗 关联思考
- 相关课题：[[分布式架构-53-默认调度器架构]]
- 资源模型和QoS机制体现了Kubernetes在资源约束下的精细化管理
- 调度器的设计需要在准确性和性能之间权衡

## 🚀 下一步行动
- [ ] 实践配置Pod的Requests和Limits
- [ ] 了解自定义调度器的实现方式

## 📚 系列导航
- 上一篇：[[分布式架构-51-Kubernetes存储生态系统]]
- 下一篇：[[分布式架构-53-默认调度器架构]]
