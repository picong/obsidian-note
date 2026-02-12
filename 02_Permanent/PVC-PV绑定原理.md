---
created: 2026-02-12 11:29
status:
tags:
  - pvc
  - pv
---

# PVC-PV绑定原理

- 什么时候进行绑定的？(创建Pod的时候进行绑定，绑定成功后，Pod才会被调度器调度到Node上面进行运行)。
- 绑定的流程是怎么样的？(Pod创建时，Master节点上会有一个控制循环--PersistentVolumeController，这个控制循环会循环监测，Pod上面的PVC是否处于bound状态，如果处于没有bound就会去轮询已存在的PV，看是否有可以与PVC进行绑定的PV。该控制循环负责撮合。)，整个流程如下图所示：
```mermaid
graph TD
    Start((用户创建 Pod & PVC)) --> CheckPV{系统中是否有<br/>合适的 PV?}
    
    %% 失败路径
    CheckPV -- 无 --> PodError[Pod 启动报错<br/>Pending/Error]
    PodError --> AdminAction[运维人员手动<br/>创建 PV]
    
    %% 控制循环介入
    AdminAction --> PVCController
    PVCController[<b>PersistentVolumeController</b><br/>扮演'红娘'角色] --- Loop([持续监听控制循环])
    Loop --> CheckStatus{PVC 是否处于<br/>Bound 状态?}
    
    %% 绑定逻辑
    CheckStatus -- 否 --> SearchPV[遍历所有可用 PV]
    SearchPV --> Match{发现匹配的 PV?}
    Match -- 是 --> Binding[<b>执行绑定</b><br/>将 PV 名称填入 PVC 的<br/>spec.volumeName 字段]
    
    %% 成功路径
    Binding --> BoundStatus[PVC 进入 Bound 状态]
    CheckPV -- 有 --> BoundStatus
    BoundStatus --> PodStart((Pod 成功启动))

    %% 样式美化
    style PVCController fill:#f96,stroke:#333,stroke-width:2px
    style Binding fill:#bbf,stroke:#333,stroke-width:2px
    style PodError fill:#ff9999,stroke:#333
```


- 绑定成功的条件：
	- PVC要求的容量跟PV的容量相匹配
	- PVC的StorageClassname属性跟PV的StorageClassName一致，如果StorageClass存在的话就是PV的创建就不需要运维手动操作(Dynamic Provisioning)，这部分内容请参考[[Dynamic/Static Provioning]]。

---
## 参考文献
- 来源: [[23-PV、PVC、StorageClass简介]]