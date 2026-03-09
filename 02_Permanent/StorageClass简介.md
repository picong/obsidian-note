---
created: 2026-02-13 15:38
status: child
tags:
  - strorageclass
  - pv
---

# StorageClass简介

> 定义：自动生成PV的"模板",它解耦了运维人员和应用开发人员之间的工作内容。

- 核心属性：
	- Parameters(参数)：声明存储的细节(如IPOS，存储的类型)。
	- Provisioner(插件)：决定用什么插件(如rook)。

- Daynamic Provisoning工作流：
	1. 定义模板：运维创建`StorageClass`对象。
	2. 触发时机：开发人员创建PVC，该PVC声明了`storageClassName`。
	3. 生成PV：控制循环监测到有该StorageClass对应的PVC创建，调用provisioner指定的插件创建后端存储，自动生成k8s中的PV对象。
	4. 自动绑定：PVC自动与该PV进行绑定，参考[[PVC-PV绑定原理]]。

- Static Provisioning与DefaultStorageClass
	- Static Provisioning：如果storageClassName没有对应的StorageClass，那么就退化为Static Provisioning了，需要运维手动创建PV。
	- 如果没有声明storageClassName没有声明，会由[[Admission Plugin]] -- "DefaultStorageClass"进行拦截，然后将默认SC填充到该字段。
		- 关键annotation：`storageclass.kubernetes.io/is-default-class: "true"`

大致流程如下：
![[Pasted image 20260205114605.png]]

---
## 参考文献
- 来源: [[23-PV、PVC、StorageClass简介]]