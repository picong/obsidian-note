---
created: 2026-02-12 10:41
status:
tags:
  - pv
  - pvc
---

# PVC和PV存在的简介

- PV是用来描述持久存储的属性，例如容量，远程存储服务的地址、端口以及一些apiKey之类的跟远程存储服务通信的一些信息，一般Static Provisioning需要由运维人员手动维护这个PV的yaml文件。还需要明确指定StorageClassName字段，用来和PVC进行匹配。

- 而PVC则是用来描述引用该PVC的Pod需要多大的容量，以及是ReadOnly还是ReadWriteOnce等需求，还需要明确指定StroageClassName字段，用来和PV进行匹配，PVC-PV绑定的逻辑的请参考[[PVC-PV绑定原理]]。

---
## 参考文献
- 来源: [[23-PV、PVC、StorageClass简介]]