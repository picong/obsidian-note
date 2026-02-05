---
tags: [k8s, 声明式API, 编程范式]
created: 2026-01-29
---

# 深入理解K8s-18-Kubernetes声明式API与编程范式

## 💡 核心观点
> Kubernetes的声明式API通过Merge能力和控制循环实现了多客户端协作和自动化运维，这是K8s区别于命令式系统的核心优势，也是云原生编程的基础范式。

## 📝 详细笔记

### 1. 核心概念对比：命令式vs.声明式

这是理解k8s运行机制的第一步。

| 模式 | 代表操作 | 核心逻辑 | 缺点/局限 |
| --------------- | --------------- | --------------- | --------------- |
| 命令式命令行 | docker run/docker service update | 直接下达动作指令 | 难以记录中间状态，不适合大规模自动化。 |
| 命令式配置文件 | kubectl create/kubectl replace | 将参数写在文件里，但底层仍是替换原有对象 | 无法处理多个客户端同时修改一个对象的情况(会冲突) |
| 声明式API | kubectl apply | 只声明"最终状态",系统自动计算并执行Patch（增量更新） | 需要系统具备强大的Merge能力和控制循环。 |

### 2. 为什么声明式API是k8s的灵魂？

- **具备Merge能力**：支持多个写端(如不同的Controller)同时对一个对象进行修改，而不会互相覆盖。
- **无需认为干预**：系统通过"控制循环 (Controller Loop)"不断对比"实际状态"与"期望状态",自动进行调解(Reconcile)。
- **下线更新**：支持在不中断业务的前提下，对API对象进行细粒度的修改。

### 3. 实战案例：Istio与Sidecar注入

Istio如何在用户"无感"的情况下，往Pod里塞进一个Envoy代理？

**技术原理：Dynamic Admission Control(动态准入控制)**

1. **Initializer(初始化器)**：在Pod真正创建前，API Server会先调用Initializer。
2. **自动注入流程**：
  a. 用户提交一个普通的Pod YAML。
  b. Initializer控制器捕捉到这个新建Pod的信号。
  c. 控制器读取ConfigMap中的Envoy配置。
  d. 使用TwoWayMergePatch技术，将Envoy的容器定义"合并"进原始Pod对象中。
  e. 完成注入后，清楚`pengding`状态，Pod正式由系统调度创建。

注：虽然现在Istio更多使用`MutatingAdmissionWebHook`(准入钩子),但其背后的声明式Patch思路是一脉相承的。

### 4. Kubernetes编程范式(Summary)

**Kubernetes编程范式 = 声明式API + 自定义控制器(Custom Controller)**

- **声明式API**：定义你的"期望状态"(CRD)。
- **控制器**：一个死循环，不断观察集群状态，一旦发现实际与期望不符，就发起`PATCH`请求。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-19-深入解析API对象的奥秘]]
- 设计哲学：声明式vs命令式的权衡

## 📚 系列导航
- 上一篇：[[深入理解K8s-17-离线业务编排(Job&CronJob)]]
- 下一篇：[[深入理解K8s-19-深入解析API对象的奥秘]]
