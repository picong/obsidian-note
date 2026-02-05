---
tags: [k8s, operator, etcd, 自动化运维]
created: 2026-01-29
---

# 深入理解K8s-22-Operator工作原理

## 💡 核心观点
> Operator = CRD + 自定义控制器，将领域运维知识编程代码，用声明式API描述期望状态，是实现复杂有状态应用自动化运维的最佳实践。

## 📝 详细笔记

### 1. 为什么需要Operator？

#### 1. StatefulSet的局限

StatefulSet适合的前提是：
  a. 拓扑固定(Pod编号不可变)
  b. 存储状态必须强绑定PV
  c. 运维逻辑相对简单(扩缩容 = Pod数量变化)

但现实中的"复杂有状态应用"(如Etcd、Kafka、ElaticSearch)：
  a. 节点加入/删除有复杂协议
  b. 运维过程本身是编程逻辑
  c. YAML越写越像"脚本语言"

StatefulSet无法表单"业务级运维语义"

#### 2. Operator的核心思想(一句话)

> 用Kubernetes的声明式API(CRD)描述"期望状态",用自定义控制器把"领域运维知识"写成代码。

### 2. Operator的技术本质

**Operator = CRD + 自定义控制器**

| 组件 | 职责 |
| -------------- | --------------- |
| CRD | 定义"新的API对象"(业务抽象) |
| CR(实例) | 描述期望状态(如size=3) |
| Controller | 期望状态调协为真实状态 |

本质仍然是Kubernetes控制循环(Reconcile Loop)

### 3. Etcd Operator的整体架构

#### 1. Etcd Operator做了什么？

- 定义一个新资源：EtcdCluster
- 监听EtcdCluster的变化
- 自动完成：
  * 集群创建
  * 节点扩缩容
  * 故障恢复
  * 与备份/恢复Operator协作

#### 2. EtcdCluster CRD (抽象极简)

```yaml
apiVersion: etcd.database.coreos.com/v1beta2
kind: EtcdCluster
spec:
  size: 2
  version: "3.2.13"
```

用户只关心"要什么"
Operator负责"怎么做"

### 4. Etcd Operator的关键设计点

#### 1. 静态集群(Static Cluster)

- Etcd原生支持静态拓扑
- 不依赖额外服务发现
- 非常适合Operator自动化

但难点是：

- 需要精确生成：
  * --initial-cluster
  * --initial-cluster-state
  * --initial-cluster-token

这些复杂参数全部由Operator自动生成

#### 2. 种子节点(Bootstrap)

Etcd Operator的建群流程：

**阶段一：Bootstrap**:

- 先启动一个Seed Member
- initial-cluster-state=new
- 集群中只有自己

**阶段二：动态扩展**：

- 每加一个节点：
  * etcdctl member add
  * 气功新Pod
  * initial-cluster-state=existing

直到节点数 = spec.size

#### 3. 不是用IP，而使用DNS

- Pod创建前IP不可知
- Operator使用Headless Service
- 使用Pod DNS名称：
```yaml
<pod>.<service>.<namespace>.svc.cluster.local
```

这是Operator能稳定生成启动参数的关键

### 5. Etcd Operator的控制循环模型

#### 1. Informer监听EtcdCluster

- Add/Update/Delete事件
- 每一个EtcdCluster -> 一个独立控制循环

> 特点：不是全局一个WorkQueue(可以加)

#### 2. 每个EtcdCluster一个控制循环

这是Etcd Operator的"聪明之处"：

- 每个Etcd Cluster对象
- 对应一个Cluster实例
- 各自并发调协

代码简单、响应更快、但不通用(不推荐大规模照抄)

#### 3. Diff模型(调协核心)

控制循环逻辑：
```yaml
实际Pod数量 vs spec.size
```

| 情况 | 行为 |
| -------------- | --------------- |
| 实际 < 期望 | addOneMember |
| 实际 > 期望 | removeOneMember |
| 相等 | no-op |
![Etcd Operator流程](260120-142139.png))

### 6. 为什么要用StatefulSet + PV?

#### 1. Etcd 本身具备高可用能力

- Raft协议
- 半数以下节点失败仍可写
- Operator只需补齐节点

#### 2. PV不能解决"多数节点失败"

- 超过半数失败：
  * Raft不可写
  * 即使PV在，集群也无法恢复
  * 必须依赖备份

#### 3. 备份/恢复由独立Operator完成

- Etcd Backup Operator
- Etcd Restore Operator

### 7. Operator vs StatefulSet(关键对比)

| 维度   | StatefulSet | Operator |
| ---- | ----------- | -------- |
| 抽象层级 | Pod         | 应用       |
| 运维逻辑 | 固定          | 可编程      |
| 拓扑管理 | 外部编号        | 内部协议     |
| 扩展能力 | 若           | 强        |
| 适合场景 | 简单有状态       | 复杂分布式系统  |

不是替代关系，而是组合关系

> Operator可以直接控制StatefulSet(如 Promethus Operator)

### 8. CRD的适用边界

#### 1. 不适合CRD的场景

- 高频创建/删除对象
- 海量实例(万级以上)
- 强一致、低延迟控制路径

#### 2. CRD性能瓶颈根因

- CRD对象：
  * 以JSON存储
- 原生对象：
  * 以Protobuf存储
- 序列化/反序列化成本高
- etcd压力大

### 9. 工程化建议

#### 1. 不要手写Operator

推荐使用工具：

- Kubebuilder
- Operator SDK (Operator Framework)

#### 2. 什么时候该写Operator？

- 有复杂运维流程
- 有状态应用
- YAML已经写不下去
- 希望把"人肉SOP"编程代码

## 🔗 关联思考
- 相关课题：[[深入理解K8s-23-PV、PVC、StorageClass简介]]
- 最佳实践：如何设计一个好的Operator

## 📚 系列导航
- 上一篇：[[深入理解K8s-21-KubernetesRBAC文章的核心是一个实战]]
- 下一篇：[[深入理解K8s-23-PV、PVC、StorageClass简介]]
