---
tags: [k8s, deployment, 滚动更新]
created: 2026-01-29
---

# 深入理解K8s-12-Deployment与水平扩展滚动更新

## 💡 核心观点
> Deployment通过两层控制器架构(Deployment -> ReplicaSet -> Pod)实现版本管理，支持滚动更新、回滚和水平扩展，是Kubernetes中最常用的无状态应用编排控制器。

## 📝 详细笔记

### 1. 核心层级架构

Deployment是一个两层控制器，其层级关系如下：

- **第一层**：Deployment控制ReplicaSet(版本管理)。
- **第二层**：ReplicaSet控制Pod(副本数管理)。

注：这种设计实现了"应用版本"与"ReplicaSet"的一一对应。每一个新的ReplicaSet都代表应用的一个新版本。

### 2. 水平扩展/缩容(Scaling)

- **原理**：Deployment Controller只需要修改它所控制的ReplcaSet的replicas字段。
- **指令**：`kubectl scale deployment nginx-deployment --replias=4`

### 3. 滚动更新(Rolling Update)

这是Deployment最强大的编排能力，允许在不中断服务的情况下升级。

- **执行过程**：
  * 创建一个新版本的ReplicaSet。
  * 新RS"水平扩展"出一个Pod。
  * 旧RS"水平收缩"掉一个Pod。
  * 交替进行，知道旧RS副本数为0，新RS达到DESIRED数量。

- **状态字段解读**：
  * DESIRED：期望副本数。
  * UP-TO-DATE：已升级到最新的Pod数。
  * AVAILABLE：用户真正可用的Pod数(Running + 最新版 + Ready健康检查通过)。

### 4. 版本控制与回滚(Rollback)

依靠保留旧版本的ReplicaSet，Deployment可以轻松实现"一键回滚"。

- 查看历史：`kubectl rollout history deployment/nginx-deployment `
- 回滚至上一个版本：`kubectl rollout undo deployment/nginx-deployment`
- 回滚至指定版本：`kubectl rollout undo ... --to-revision=2`
- 控制历史版本数量：设置spec.revisionHistoryLimit(若为0则无法回滚)

### 5. 滚动更新策略控制

通过RollingUpdateStrategy确保服务连续性：

- **maxSurge**：升级过程中，最多比DESIRED数量多出多少个Pod。
- **maxUnavailable**：升级过程中，最多有多少个Pod处于不可用状态。

### 6. 建议

如果你需要对 Deployment 进行多次修改（如改镜像、改配置、改 Labels），为了避免每改一次都触发一次滚动更新，可以使用以下技巧：

- 暂停：kubectl rollout pause（进入暂停状态，修改不会触发更新）。
- 修改：执行多次 kubectl set image 或 kubectl edit。
- 恢复：kubectl rollout resume（所有修改合并为一次滚动更新）。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-13-深入理解StatefulSet之拓扑状态]]
- 生产实践：滚动更新参数的最佳配置

## 📚 系列导航
- 上一篇：[[深入理解K8s-11-编排的本质--控制器模式]]
- 下一篇：[[深入理解K8s-13-深入理解StatefulSet之拓扑状态]]
