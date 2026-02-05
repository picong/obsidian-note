---
tags: [k8s, statefulset, 存储, pv, pvc]
created: 2026-01-29
---

# 深入理解K8s-14-深入理解StatefulSet之存储状态

## 💡 核心观点
> StatefulSet通过volumeClaimTemplates为每个Pod自动创建专属PVC，实现Pod与PV的一对一绑定，确保Pod重建后能找回原有数据，这是存储状态管理的核心机制。

## 📝 详细笔记

### 1. PV与PVC：存储的"接口"与"实现"

为了解决开发者不懂底层存储架构、运维不希望暴露基础设施细节的问题，Kubernetes引入了：

- **PVC(Persistent Volume Claim)**：接口/需求。开发者生命"我需要1GBi的可读写存储"，而不必关心底层是Ceph还是阿里云盘。
- **PV(Persistent Volume)**：实现/资源。运维人员预先创建好的、对应真实存储资产的对象。
- **核心逻辑**：PVC与符合条件的PV自动绑定，Pod通过引用PVC来使用存储。

### 2. StatefulSet的核心武器：`volumeClaimTemplates`

这是StatefulSet与Deployment在存储处理上的本质区别：

- **Deployment**：所有Pod共享同一个PVC(通常只能用于分布式文件系统如NFS)。
- **StatefulSet**：使用PVC模板：
  * 自动编号：它会为每一个Pod自动创建一个专属PVC。
  * 命名规则：`<PVC名字>-<StatefulSet名字>-编号`(如`www-web-0`)。
  * 一对一绑定：`web-0`永远只挂载`www-web-0`，`web-1`永远只挂载`www-web-1`。

### 3. 存储状态的"持久化"原理(关键流程)

StatefulSet如何保证Pod重建后数据不丢？

1. **数据写入**：Pod web-0运行，数据写入其挂载的PV中(数据实际存在远程存储服务器上)。
2. **Pod删除**：执行`kubectl delete pod web-0`。此时Pod消失 了，但PVC和PV依然存在。
3. **Pod重建**：Statefulset控制器发现少了一个web-0，重新创建它。
4. **重新关联**：新web-0启动时，声明的需求依然是www-web-0。Kubernetes发现这个PVC已经存在且Bound(绑定)了旧PV，于是直接挂载。
5. **结果**：新Pod瞬间找回了旧Pod的数据。

### 4. 总结：StatefulSet的"三位一体"

StatefulSet通过整合三项技术实现了有状态应用的编排：

1. **拓扑状态**：通过唯一编号确定创建/删除顺序。
2. **网络标识**：通过Headless Service配合编号提供唯一的DNS访问入口。
3. **存储状态**：通过PVC模板为每个编号的Pod绑定一个独立的、生命周期脱离Pod的持久化存储。

### 5. 思考题：如果分布式应用(如分布式数据库)能自动同步数据，还有必要让Pod与PV一对一绑定吗？

这取决于数据量和恢复成本：

- **有必要的情况(常见)**: 如果数据量巨大(TB级)，新Pod启动后从零同步数据会导致巨大的网络带宽开销和漫长的预热期。此时，"数据就位"(保留原PV)能实现秒级恢复。
- **没必要的情况(极少数)**: 如果数据极小，或者应用本身就设计为"内存型+全量重拉"，那么不绑定PV可以让调度更灵活。
- **结论**：在Kubernetes生态中，为了生产环境的稳定性，通常建议保留一对一绑定，因为"拉取现成数据"永远比"网络重传数据"快且稳。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-15-深入理解StatefulSet之实践部署Mysql一主多从集群]]
- 技术细节：PV的生命周期管理

## 📚 系列导航
- 上一篇：[[深入理解K8s-13-深入理解StatefulSet之拓扑状态]]
- 下一篇：[[深入理解K8s-15-深入理解StatefulSet之实践部署Mysql一主多从集群]]
