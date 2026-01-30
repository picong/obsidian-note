---
tags: [k8s, statefulset, 有状态应用]
created: 2026-01-29
---

# 深入理解K8s-13-深入理解StatefulSet之拓扑状态

## 💡 核心观点
> StatefulSet通过Headless Service和唯一编号机制，为有状态应用提供稳定的网络标识和有序的启动/删除顺序，解决了Deployment无法处理的拓扑状态问题。

## 📝 详细笔记

### 1. 为什么需要StatefulSet？

- **Deployment的局限性**：假设所有Pod完全对等、无序、可随时替换(无状态)。
- **有状态应用(Stateful Application)的特征**：
  * 拓扑状态：实例间不对等关系(如主从、主备)或严格的启动/顺序要求。
  * 存储状态：实例与外部持久化数据由绑定关系，重建后需找回"旧数据"。

### 2. 核心机制：Headless Service(无头服务)

StatefulSet实现"拓扑状态"稳定的关键工具。

- **定义方式**：在Service的YAML中设置`cluster: None`。
- **特点**：
  * 没有VIP：不分配虚拟IP，不进行负载均衡。
  * DNS解析：直接将Service的DNS记录解析为代理的所有Pod的IP地址列表。
- **网络身份公式**：`<pod-name>.<svc-name>.<namespace>.svc.cluster.local`

核心价值：为每一个Pod提供一个在集群内永久不变、可解析的"网络标识"。

### 3. StatefulSet的"拓扑状态"保证

Kubernetes通过以下两个手段确保有状态应用的稳定性:

- **唯一编号(Ordinal Index)**：
  * Pod命名规则：`<statefulset-name>-<index>`(如`web-0`,`web-1`)。
  * 有序启动：Pod按照0到N-1的顺序逐一创建。前一个Ready后，后一个才开始创建。
  * 有序删除：删除时按逆序(N-1到0)进行。

- **稳定的网络标识**：
  * 即使Pod被删除并重建，其Name和Hostname保持不变(依然是`web-0`)。
  * 对应的DNS记录(如web-0.nginx)会自动更新到新Pod的IP。
  * 结论：访问者应通过DNS域名访问特定节点，而非IP。

### 4. 关键总结

- StatefulSet = 有序编号 + 稳定的DNS标识。
- 它不保证Pod IP不变，但保证你通过同一个"名字"总能找到对应编号的实例。
- 它是对Deployment的改良，专门处理那些"离了谁都不行"或者"必须按顺序来"的分布式业务。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-14-深入理解StatefulSet之存储状态]]
- 应用场景：哪些应用适合使用StatefulSet

## 📚 系列导航
- 上一篇：[[深入理解K8s-12-Deployment与水平扩展滚动更新]]
- 下一篇：[[深入理解K8s-14-深入理解StatefulSet之存储状态]]
