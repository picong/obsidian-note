---
tags: [k8s, api, crd, 扩展]
created: 2026-01-29
---

# 深入理解K8s-19-深入解析API对象的奥秘

## 💡 核心观点
> Kubernetes的API对象通过GVR(Group/Version/Resource)组织，经过认证、授权、准入控制等流水线处理后持久化到Etcd，CRD机制允许用户扩展自定义资源类型。

## 📝 详细笔记

### 1. API对象的组织"三围"：GVR

在k8s中，定位一个资源不需要"经纬度",只需要GVR：

- **Group(Api组)**：功能分类(如`batch`为离线业务，核心资源如Pod的Group为空)。
- **Version(Api版本)**：版本管理(如`v1`,`v1alpha1`)，保证向后兼容。
- **Resource(资源类型)**：具体的对象名(如`CronJob`,`Deployment`)。

完整示例：`apis/batch/v2alpha1/cronjobs`
![api对象的树形结构](260114-101039.png))

### 2. 一个YAML的"入库"之旅

当你执行kubectl apply时，ApiServer内部经历了一场复杂的"流水线加工"：

1. **过滤与预处理**：认证(你是谁?)、授权(你能干啥？)、审计(记录你的操作)。
2. **MUX与Routes匹配**：根据URL找到对应的Handler。
3. **Convert(版本转换)**：将不同版本的YAML转换为Super Version(所有版本的并集)，统一处理逻辑。
4. **Admission(准入控制)**：执行Initializer或WebHook，进行动态修改(如注入Sidecar)。
5. **Validation(验证)**：检查字段合法性。
6. **Registry(登记)**：通过验证的对象进入Registry数据结构。
7. **持久化**：序列化后存入Etcd。
![api对象创建流程](260114-103455.png))

### 3. CRD：让k8s认识你的"新物种"

CRD(Custom Resource Definition)允许你香K8s注册自定义资源。

**如何创建一个自定义资源(以Network为例)?**

要让k8s认识并处理你的"新物种"，需要两步走：

| 步骤        | 类比            | 操作内容                                     |
| --------- | ------------- | ---------------------------------------- |
| 定义CRD(宏观) | 告诉电脑"什么是兔子"   | 编写CRD YAML，声明Group/Version/Kind(Network) |
| 描述CR(微观)  | 告诉电脑"这只兔子长啥样" | 编写代码(types.go)定义具体的字段(如cidr，gateway)     |

### 4. 自动化生产线：代码生成工具

K8s及其复杂，手动写API转换和客户端代码很麻烦。所以官方提供了code-generator：

- **Input**：你在`types.go`里写的结构体 + 特殊注释(Tags)。
- **Output**：
  * DeepCopy：对象的深拷贝方法。
  * Clientset：操作该资源的客户端。
  * Informers/Listers：高效监听资源变化的核心组件。

注：你会发现即使不写代码，只apply一个CRD YAML，kubectl get 也能生效。那是由于K8s帮你存了"原始数据"，但要实现业务逻辑(比如真去创建一个网络)，必须依靠生成的代码编写Controller。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-20-Kubernetes自定义控制器(CustomController)深度笔记]]
- 扩展机制：CRD vs API Aggregation

## 📚 系列导航
- 上一篇：[[深入理解K8s-18-Kubernetes声明式API与编程范式]]
- 下一篇：[[深入理解K8s-20-Kubernetes自定义控制器(CustomController)深度笔记]]
