---
tags:
  - FlexVolume
  - CSI
created: 2026-01-29 10:39
---

# 编写自己的存储插件

## 💡 核心观点
> 详细解释FlexVolume和CSI的工作原理。

## 📝 详细笔记
### 1. 存储插件的核心背景
Kubernetes的持久化存储遵循"两阶段处理"流程(Attach/Mount)，其本质是为了实现存储系统与Kubernetes核心代码代码的解耦。
-  Attach阶段：将远程磁盘挂载到宿主机(如：将阿里云云盘挂载到ECS实例)。
- Mount节点：将宿主机上的磁盘格式化并挂载到容器指定的目录。
### 2. FlexVolume：老牌的脚本化方案
FlexVolume是Kubernetes早期的扩展方式，通过再宿主机特定目录下放置可执行文件(脚本或二进制)来实现。
![[./attachments/Pasted image 20260129110715.png]]
- 工作原来：
	1. 调用链：`kubelet` -> `pkg/volume/flexvolume` -> 执行宿主机上的脚本。
	2. 执行路径：`/usr/libexec/kubernetes/kubelet-plugins/volume/exec/<vendor>~<driver>/<driver>`。
	3. 交互方式：通过命令行参数传递JSON字符串，插件处理完后返回JSON结果给kubelet。
- 局限性(痛点)：
	- 部署麻烦：必须手动再每个Node节点安装插件二进制文件。
	- 功能单一：难以原生支持Dynamic Provisioning(自动创建磁盘)，通常需要额外部署External Provisioner。
	- 无状态：每次调用都是独立的进程，难以缓存中间状态。
### 3. CSI(Container Storage Interface)：现代的标准方案
CSI是目前的行业标准，它仿照了CRI(容器运行时接口)的设计思路，将存储管理从K8s源码中完全剥离。
![[./attachments/Pasted image 20260129110739.png]]
#### 1. 三个核心外部组件(Extenal Components)
这些组件由K8s社区维护，以Sidecar容器的方式与插件运行在同一个Pod中：
- Driver Registrar：负责将插件注册到kubelet。
- External Provisioner：监听PVC，调用插件创建/删除底层的存储卷(CSI Volume)。
- External Attacher：监听VolumeAttachment对象，调用插件进行Attach/Detach操作。
#### 2. 三个gRPC服务(需要开发者实现)
CSI插件本身是一个gRPC Server，需要实现一下服务：
- CSI Identity：暴露插件基本信息(名称、版本、能力)。
- CSI Controller：负责再控制面操作卷(Create/Delete/Publish/Unpublish)。对应Provision和Attach阶段。
- CSI Node：负责在宿主机上操作卷(Stage/Publish)。对应Mount阶段。
### 3. CSI的"三阶段" 模型
相比FlexVolume，CSI将流程细化为：
1. Provision：创建底层的物理/云端存储资源。
2. Attach：将资源挂载到指定的Node。
3. Mount：将挂载到Node的资源进一步挂载到Pod目录。
### 4. 快速比对表

| 特性   | FlexVolume       | CSI                        |
| ---- | ---------------- | -------------------------- |
| 实现方式 | 宿主机可执行文件(脚本/二进制) | gRPC服务(容器化部署)              |
| 部署方式 | 手动分发到每个节点        | 通过DaemonSet/Deployment部署   |
| 核心阶段 | Attach，Mount     | Provision，Attach，Mount     |
| 动态配置 | 困难(需额外开发)        | 原生支持(External Provisioner) |
| 社区趋势 | 已进入维护期/逐渐废弃      | 推荐的主流方案                    |


## 🔗 关联思考
- 相关课题：[[ ]]
- 反向逻辑：有哪些观点是反对这个结论的？

## 🚀 下一步行动
- [ ]