---
tags: [k8s, pod, 健康检查, 配置管理]
created: 2026-01-29
---

# 深入理解K8s-10-深入解析Pod对象(二)使用进阶

## 💡 核心观点
> 通过Projected Volume实现配置注入，通过Probe机制实现健康检查和自愈能力，通过PodPreset实现统一配置管理，这些是生产环境中Pod运维的核心技术。

## 📝 详细笔记

### 1. 投射数据卷(Projected Volume)

Projected Volume是k8s v1.11+的重要特性。它的本质是：将集群内的元数据或配置信息，像"投影"一样映射到Pod内部的卷中。

| 类型 | 核心作用 | 技术要点 |
| --------------- | --------------- | --------------- |
| Secret | 存放敏感数据(如数据库密码、Token) | 数据在Etcd中以Base64编码存储(非加密，需开启加密插件) |
| ConfigMap | 存放非敏感数据(如.yaml文件) | 支持文件热更新，容器内文件随Etcd数据更新而自动变化 |
| Downward API | 让容器获取Pod自身的元数据 | 可获取Pod IP、Node Name、Labels、CPU/MEM限制等 |
| ServiceAccountToken | 存放API Server的访问凭证 | 默认自动挂载在`/var/run/secrets/Kubernetes.io/serviceaccount` |

注：获取配置建议优先使用Volume挂载而非环境变量。环境变量不支持热更新，而Volume挂载文件由kubelet维护，具备自动更新能力。

### 2. 容器健康检查：Probe(探针)机制

这是生产环境"自愈能力"的核心。

- **livenessProbe(存活探针)**:
  * 作用：判断容器是否还在"活着"。
  * 失败后果：Kubelet会杀掉该容器，并根据restartPolicy进程重启(重建)。

- **readinessProbe(就绪探针)**:
  * 作用: 判断容器是否"准备好接收流量"。
  * 失败后果：Pod会从Service的Endpoints中剔除，流量不再切入，但不会重启容器。

**探测方式对比**：

1. ExecAction：在容器内执行命令(看退出码是否为0)。
2. HTTPGetAction：发起HTTP GET请求(看状态码是否在200-400之间)。
3. TCPSocketAction：检查端口是否可以建立TCP连接。

### 3. Pod恢复策略：restartPolicy

重启永远发生在当前节点，Pod不会因为容器失败而自动漂移到其他Node。

- Always(默认)：只要退出就重启。
- OnFailure：只有非正常退出(退出码非0)才重启。
- Never：从不重启。适用于需要保留退出后现场(日志、文件)进行Debug的场景。

### 4. 自动化利器：PodPreset(Pod预设置)

解决痛点：运维人员希望统一给Pod注入环境变量、挂载存储，而不需要开发人员在每个YAML里重复编写。

- **工作原理**：通过selector匹配带有特定Label的Pod。
- **合并规则**：Pod创建时，API Server自动将PodPreset定义的内容合并到Pod对象中。
- **冲突处理**：如果PodPreset注入的字段与Pod原始字段冲突，则冲突部分不予修改。

### 5. In-Cluster编程

ServiceAccount是K8s内部服务的身份卡。

- 如果你想在Pod里写代码调用K8s API，无需手动配置Token。
- 直接使用官方Client库，它会自动识别挂载到`var/run/secrets/...`下的Token，这被称为InClusterConfig模式。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-11-编排的本质--控制器模式]]
- 生产实践：健康检查策略的最佳配置

## 📚 系列导航
- 上一篇：[[深入理解K8s-09-Pod的基本概念]]
- 下一篇：[[深入理解K8s-11-编排的本质--控制器模式]]
