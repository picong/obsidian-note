---
tags: [k8s, rbac, 权限, 安全]
created: 2026-01-29
---

# 深入理解K8s-21-KubernetesRBAC文章的核心是一个实战

## 💡 核心观点
> RBAC(基于角色的访问控制)通过Subject(用户/组/ServiceAccount)、Role(权限规则)和Binding(绑定关系)三元组模型，实现了灵活的权限管理和安全隔离。

## 📝 详细笔记

### 1. RBAC核心模型：三元组逻辑

理解RBAC只需要记住一个简单的公式：谁(Subject)穿上衣服(Role)，就能干什么(Rules)。

- **Subject(被作用者)**：
  * User(人)：外部认证系统提供的用户(如LDAP)。
  * Group(组)：逻辑集合，方便批量授权。
  * ServiceAccount(内置)：Pod里的程序访问API Server时使用的身份。

- **Role/ClusterRole(角色/权限规则)**：
  * 定义了对哪些资源(Resources)能做哪些操作(Verbs)。

- **RoleBinding/ClusterRoleBinding(绑定关系)**：
  * 将上述两者"缝合"在一起的连接线。

### 2. 关键API对象对比

| 维度      | Role/RoleBinding        | ClusterRole/ClusterRoleBinding |
| ------- | ----------------------- | ------------------------------ |
| 作用范围    | Namespace级别(仅在特定命名空间生效) | 集群级别(全集权生效)                    |
| 典型场景    | 给某个开发小组分配特定项目的增删改查权限。   | 授权访问Node信息、PV、或者跨Namespace     |
| 非命名空间资源 | 不支持(无法操作Node、Namespace) | 支持                             |

### 3. 实战：ServiceAccount的授权的全链路

在k8s编程和插件开发中，这是最常用的链路：

1. **创建身份**： `ServiceAccount`(SA)。
2. **定义权限**：`Role`(rules：pods，verbs：get，list...)
3. **实施绑定**：`RoleBinding`将SA与Role绑定。
4. **注入Pod**：在Pod定义中指定serviceAccountName。
5. **自动挂载**：K8s会自动将SA的Token挂载到容器目录：`/var/run/secrets/kubernetes.io/serviceaccoutn`。

### 4. Tips

- **system:前缀**：带有此前缀的角色是K8s系统预留的(如`system:kube-scheduler`)，不要随意修改。
- **默认角色**：K8s内置了`view`，`edit`，`admin`，`cluster-admin`四个ClusterRole：
  * `view`是查问题的神器，建议分配给普通观察者。
  * `cluster-admin`拥有"上帝权限"，绑定时需极其谨慎。
- **用户组技巧**：
  * system:serviceaccounts：代表全集群所有SA。
  * system:serviceaccounts:`<namesapace>`：代表特定命名空间下所有SA。

### 5. 如何为Namespace下的默认ServiceAccount绑定一个只读权限的角色？

核心思路：使用`ClusterRoleBinding`将内置角色`view`绑定到全局用户组`system:serviceaccounts`。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-22-Operator工作原理]]
- 安全最佳实践：最小权限原则的实施

## 📚 系列导航
- 上一篇：[[深入理解K8s-20-Kubernetes自定义控制器(CustomController)深度笔记]]
- 下一篇：[[深入理解K8s-22-Operator工作原理]]
