---
created: 2026-02-04 10:20
tags:
  - CSI
  - Kubenetes
---

# 26 CSI插件编写指南

## 💡 核心观点
> CSI插件需要用户自行编写的三个服务：CSI Identity、CSI Controller、CSI Node。
> 这三个服务是怎么跟Kubernetes或者kubelet进行交互，一起完成持久化存储的工作流程。

## 📝 详细笔记
### 1. CSI Identity服务
服务接口：
- GetPluginInfo: 返回当前插件的名字和版本号。
- GetPluginCapabilities: 返回这个CSI插件的"能力"。
- Probe接口：用来检查这个CSI插件是否正常工作。
### 2. CSI Controller服务
服务接口：
- CreateVolume/DeleteVolume: 调用插件对应的服务端的能力来创建/删除存储卷。(这两个接口对应的是"Provisioner阶段",调用者是External Provisoner)。
- CtrollerPublishVolume/ControllerUnpublishVolume: 将上面步骤创建的存储卷挂载到宿主机上/移出已挂载到宿主机上的存储卷。(这个两个接口对应的是"Attach阶段"，调用者是External Attacher)。
	- External Attacher的工作原来是：AttachDetachController控制循环，循环检查Pod所对应的PV，以及该POD对应的宿主机上的该PV的挂载情况来决定是否创建VolumeAttachment对象，从而触发监听该VolumeAttachment的External Attacher来调用CSI Contoller来进行Attach/Dettach。
### 3. CSI Node服务
服务接口：
- NodeStageVolume: 格式化Volume在宿主机上的存储设备，然后挂载到一个临时目录(Staging)上。
- NodePublishVolume: 将上面挂载的临时目录绑定挂载到Volume在宿主机上对应的目录上，这样就完成了对该volume目录的"持久化"的处理。

这两个接口是被kubelet的VolumeManagerReconciler调用的，对应的其实是这个控制循环中的两步操作分别叫做：MountDevice和SetUp。
有的时候CSI Node不需要实现NodeStageVolume接口，比如像NFS这种远程文件服务，不存在存储设备，所以只需要实现NodePublishVolume接口。

### 4. 插件部署流程(需要实践)
1. 创建Secret
2. 通过命令部署CSI插件`$ kubectl apply -f https://raw.githubusercontent.com/digitalocean/csi-digitalocean/master/deploy/kubernetes/releases/csi-digitalocean-v0.2.0.yaml`

### 5. 插件部署的常用原则
- 因为需要为kubelet提供CSI Node服务，所以需要通过DaemonSet在每个节点上都启动一个CSI插件。
- 因为要保证CSI在集群中中永远只会有一个提供CSI Controller服务的Pod在运行(保证CSI插件的正确性)，所以需要通过StatefulSet来在任意一个节点上来启动一的CSI插件(StatefulSet的replicas设置为1)。

### 6. 下面是CSI插件运行的流程图和时序图
```mermaid
graph TD
    %% 角色定义
    subgraph User_Action [用户操作]
        A[创建 PVC] --> B[创建 Pod]
    end

    subgraph Control_Plane [Master 节点控制平面]
        C[External Provisioner]
        D[PV Controller]
        E[AD Controller]
    end

    subgraph CSI_Controller_Pod [CSI Controller 插件服务]
        F[CreateVolume]
        G[ControllerPublishVolume]
    end

    subgraph Node_A [宿主机 Node A]
        H[Kubelet / VolumeManager]
        I[CSI Node 插件服务]
    end

    %% 流程连接
    A -->|监听| C
    C -->|调用 gRPC| F
    F -->|返回| PV[创建 PV 资源]
    PV -->|匹配绑定| D
    D -->|PVC 进入| Bound[Bound 状态]

    B -->|调度到 Node A| E
    E -->|创建| VA[VolumeAttachment 对象]
    VA -->|监听| ExtAttacher[External Attacher]
    ExtAttacher -->|调用 gRPC| G
    G -->|执行 Attach| Attach[将云盘挂载到虚拟机]

    Attach -->|触发| H
    H -->|调用 gRPC| I
    I -->|NodeStageVolume| Stage[格式化设备并挂载到 Staging 目录]
    Stage -->|NodePublishVolume| Mount[将 Staging 目录挂载到 Pod 目录]
    Mount -->|完成| Running[Pod 容器启动并使用存储]

    %% 样式美化
    style A fill:#e1f5fe,stroke:#01579b
    style B fill:#e1f5fe,stroke:#01579b
    style F fill:#fff9c4,stroke:#fbc02d
    style G fill:#fff9c4,stroke:#fbc02d
    style I fill:#c8e6c9,stroke:#2e7d32
    style Bound fill:#ffe0b2,stroke:#ef6c00
```

```mermaid
sequenceDiagram

    autonumber

    participant User as 用户

    participant PVC_Object as PVC 资源

    participant Ext_Provisioner as External Provisioner (Sidecar)

    participant CSI_Controller as CSI Controller (插件实现)

    participant AD_Controller as AD Controller (K8s 内核)

    participant Ext_Attacher as External Attacher (Sidecar)

    participant Kubelet as Kubelet (Node A)

    participant CSI_Node as CSI Node (插件实现)

  

    Note over User, PVC_Object: 1. Provision 阶段 (创建存储)

    User->>PVC_Object: 创建 PVC

    Ext_Provisioner->>PVC_Object: 监听 (Watch) 到新 PVC

    Ext_Provisioner->>CSI_Controller: 调用 CreateVolume (gRPC)

    CSI_Controller-->>Ext_Provisioner: 返回 VolumeID 和信息

    Ext_Provisioner->>PVC_Object: 创建并绑定 PV

  

    Note over User, AD_Controller: 2. Attach 阶段 (挂载到云主机)

    User->>Kubelet: 创建使用该 PVC 的 Pod

    AD_Controller->>AD_Controller: 监听到 Pod 调度至 Node A

    AD_Controller->>Ext_Attacher: 创建 VolumeAttachment 对象

    Ext_Attacher->>CSI_Controller: 调用 ControllerPublishVolume (gRPC)

    Note right of CSI_Controller: 在云平台执行 Attach 操作

    CSI_Controller-->>Ext_Attacher: 返回成功

  

    Note over Kubelet, CSI_Node: 3. Mount 阶段 (宿主机格式化与挂载)

    Kubelet->>CSI_Node: 调用 NodeStageVolume (gRPC)

    Note right of CSI_Node: 格式化设备并挂载到 Staging 目录

    CSI_Node-->>Kubelet: 返回成功

    Kubelet->>CSI_Node: 调用 NodePublishVolume (gRPC)

    Note right of CSI_Node: Bind Mount 到 Pod 目录

    CSI_Node-->>Kubelet: 返回成功

  

    Note over User, Kubelet: 4. 运行阶段

    Kubelet->>User: 启动容器 (Running)
```

---
文章链接：[31 | 容器存储实践：CSI插件编写指南-深入剖析Kubernetes-极客时间](https://time.geekbang.org/column/article/64392)