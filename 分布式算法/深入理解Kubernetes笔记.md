# 深入理解Kubernetes笔记

## 容器基础:从进程开始

> 容器的核心功能：通过约束和修改进程的动态表现，为其创造出一个"边界"。

### 1. 实现容器边界

Docker等大多数Linux容器主要使用Linux内核技术来实现隔离和限制：

1. Cgroups(Control Groups)：主要用来制造约束(限制资源)。
2. Namesace(命名空间)：主要用来修改进程视图(制造隔离的"障眼法")。

Namespace机制详解：

- 工作原理：Namespace机制是Linux 创建进程时的一个可选参数(通过clone()系统调用指定CLONE_NEW...参数)。
- "障眼法"：它为被隔离的应用进程创建了一个全新的进程空间视图，使得该进程误以为自己是该空间中PID=1的进程，从而看不到宿主机上的真实进程空间和其他Namespace里的情况。
- 真实情况：在宿主机真实的进程空间里，这个进程依然是它本来的真实PID。
- 核心结论：容器，其实是一种特殊的进程而已。Docker只是在创建应用进程时，为它们加上了各种Namespace参数。

  Linux提供的Namespace类型：
  
  - PID Namespace：隔离进程编号。
  - Mount Namespace：隔离挂载点信息(文件系统)。
  - Network Namespace：隔离网络设备和配置。
  - IPC Namespace：隔离进程间通信。
  - User Namespace：隔离用户和用户组ID。
  - Cgroups Namespace：隔离Cgroups视图(较新)。

## 2. 容器与虚拟机的对比：

- 虚拟机(VM)工作原理：
  * Hypervisor软件通过硬件虚拟化，模拟出CPU、内存、I/O设备等硬件。
  * 在这些虚拟硬件之上安装Guest OS(客户操作系统)。
  * 应用运行在Guest OS中，拥有自己的文件系统和设备。
- 容器(Container)工作原理：
  * 没有真正的"容器"运行在宿主机里。
  * Docker启动的仍是原来的应用进程。
  * 通过Namespace为这些进程设置隔离视图，使它们"以为"自己运行在独立环境中。
  * 所有容器共享宿主机的Linux内核。

---

## 隔离与限制(Cgroups)

### 1. 容器与虚拟机的架构对比与优势

- 架构定位的修正：Docker Engine(或任何容器管理工具)不应与Hypervisor放在同等位置。容器里的应用进程与宿主机上的其他进程一样，都由宿主机操作系统统一管理，只是拥有额外的Namespace参数设置。Docker扮演的是旁路的辅助和管理角色。
![虚拟机与docker容器对比图](./attachments/251208-171047.png)
- 容器相对优势：
  * 高性能：由于容器是宿主机上的普通进程，消除了Hypervisor拦截和处理带来的虚拟化性能损耗(尤其在计算、网络、磁盘I/O方面)。
  * 敏捷性(轻量级)：无需运行完整的Guest OS，容器的额外资源占用几乎可以忽略不计(VM启动需要占用100-200MB内存)。

---

### 2. Linux Namespace隔离的不足之处(劣势)

虽然Namespace提供了隔离，但相比于虚拟机，其隔离性存在不足：

1. 内核共享
2. 隔离不彻底
3. 安全攻击面大

---

### 3. 容器的资源"限制"即使：Cgroups

- 限制的必要性：尽管有了Namespace隔离，但容器进程在宿主机上与其他进程仍然是平等的竞争关系。如果不加限制，一个容器进程可能会占用所有资源，影响其他进程(包括其他容器)。
- 技术名称：Linux Cgroups(Control Group)。
- 核心作用：限制一个进程组能够使用的资源上限，包括CPU、内存、磁盘I/O、网络带宽等。

Cgroups的工作原理与实践

1. 文件系统接口：Cgroups通过文件目录的方式组织在操作系统的/sys/fs/cgroup路径下。
2. 子系统(Subsystem)：/sys/fs/cgroup下的子目录(如cpu、memory、blkio等)代表了可以被限制的资源种类。
3. 控制组(Control Group)：在子系统目录下创建一个目录(例如mkdir container)，这个新目录就是一个"控制组"。系统会自动生成该子系统对应的资源限制文件。
4. 设置限制：通过修改控制组目录下的资源限制文件来设置资源上限：
  a. 例如，在/sys/fs/cgroup/container 中设置cpu.cfs_quata_us和cpu.cfs_period_us，可以限制CPU使用比例。
5. 进程归属：将被限制的进程PID写入控制目录下的tasks文件，限制即生效。

---

### 4. 容器中的重要概念与遗留问题

- 容器的本质：一个正在运行的Docker容器，就是一个启用了多个Linux Namespace的应用进程，而这个进程能使用的资源量则受Cgroups配置的限制。
- 容器的"但进程"模型：容器本质上是一个进程，用户的应用进程通常就是容器里PID=1的进程：
  * 设计期望：容器和应用能够同生命周期。
  * 问题：容器内不适合同时运行两个不相关的应用，如果需要运行多个应用，需要使用systemd/supervisord等作为PID=1的父进程(但更推荐使用容器设计模式)。
- Cgroups的不完善：/proc文件系统问题：
  * 问题现象：在容器执行top命令查看的其实是/proc目录下的文件，所以显示的是宿主机的CPU和内存数据，而不是当前容器的限制数据。
  * 原因：/proc文件系统不了解Cgroups限制的存在。
  * 解决方案：lxcfs等工具通过FUSE文件系统模拟出正确的/proc信息，供容器内应用读取。

## 深入理解容器镜像与rootfs

### 1. 容器文件系统的真相
- Mount Namespace的误区：仅仅开启Mount Namespace，容器进程看到的文件系统依然是宿主机的。因为容器继承了宿主机的挂载点。
- 改变视图的关键：必须在Namespace创建后，执行挂载操作(mount):
  * Mount：挂载指定目录(如/tmp挂载为tmpfs)。
  * Chroot(Change Root)：将进程的根目录/切换到指定路径。这是容器文件系统的基石。
  * Switching：Docker实际优先使用pivot_root系统调用，不支持时才回退到chroot。

---

### 2. Rootfs(根文件系统)
- 定义：一个包含了操作系统所有文件、配置和目录(如/bin,/etc,/proc)的文件包。
- 躯壳与灵魂：
  * 躯壳(rootfs)：提供应用运行的用户环境(User Space)。
  * 灵魂(Kernel)：容器共享宿主机的操作系统内核。
  * 专家注：这也是容器比虚拟机轻量(因为没有Guest OS内核)，但也比虚拟机隔离性差(共享进内核)的根本原因。
- 价值：一致性。rootfs将应用及其依赖(操作系统级别的依赖)打包在一起，解决了"在我的机器上能跑，在服务器上跑不了"的经典问题。

---

### 3. 联合文件系统(UnionFS)与分层镜像
为了解决rootfs重复制作和更新带来的碎片化问题，Docker引入了Layer(层)的概念。

- 技术原理：UnionFS(如AuFS，OverlayFS)可以将不同位置的目录联合挂在到一个统一的目录下。
- 镜像三层结构：
  * 只读层(Read-Only Layer)：位于最底层，包含基础镜像(如Ubuntu，CentOS)的文件。可能有多个只读层叠加。
  * init层(Internal Layer)：位于中间，Docker自动生成。存放/etc/hosts，/etc/recolv.conf等与当前环境相关的配置。commit时会被忽略。
  * 可读写层(Read-Write Layer)：位于最顶层(容器层)。所有对容器的增删改操作都发生在这里。

---

### 4. Copy-on-Write(CoW)与Whiteout
- 修改文件：当要修改只读层的文件时，系统会将该文件复制到可读写层，然后进行修改(Copy-on-Write)。容器进程只看到最上层的文件。
- 删除文件：当要删除只读层文件时，系统会在可读写层创建一个特殊的Whiteout文件(.wh.foo)。这会"遮挡"住洗面的文件，实现逻辑删除。

## 镜像文件的演进

### 1. 存储驱动的改朝换代：AuFS已成为历史
- 上文是一AuFS为例进行介绍的。
- 现状：AuFS因为未能进入Linux主线内核且性能问题，已经被Overlay2全面取代。
- OverlayFS(Overlsy2)：
  * 架构更简单：只有LowerDir(只读)，UpperDir(读写)，MergedDir(挂载点)，WorkDir(中间处理)。
  * 性能更优：Page Cache共享更好，inode消耗更少。
  * 建议：在生产环境中，现在默认且强烈使用Overlay2。

---

### 2. 镜像分发的革命：按需加载(lazy Loading)
- 痛点：传统镜像(OCI v1)必须下载完成所有层才能启动容器。随着AI模型和复杂应用导致镜像越拉越大(GB级别)，启动速度变慢。
- 新技术：
  * eStargz(Google)：重组镜像内的文件布局，使得容器运行时可以只拉取需要的文件快，无需下载整个镜像。
  * Nydus(Dragonfly/Alibaba)：一种优化的容器文件系统。它将元数据和数据分离，支持"秒级启动"，并利用P2P技术加速分发。
- 趋势：从"全量下载"转向"按需流式加载"。

---

### 3. 隔离技术的反击：沙箱容器(Sandboxed Containers)
- 课程观点：容器共享内核，隔离性不如虚拟机。
- 最新进展：为了解决共享内核的安全风险，出现了基于轻量级虚拟化的容器运行时：
  * kata container：每个Pod运行在一个独立的轻量虚拟机(Micro VM)中，拥有独立的内核。
  * gVisor(Google)：在用户态模拟了一个内核层，拦截并处理系统调用，不直接让容器接触宿主机内核。
- 适用场景：多租户环境、Serverless平台、高安全敏感业务。

---

### 4. 构建工具的进化：脱离Docker Daemon
- 过去：docker build 强依赖Docker Daemon。
- 线下：Kubernetes集群中(特别是CI/CD流水线)，我们倾向于使用无守护进程(Daemonless)的构建工具：
  * Kaniko：谷歌开源，可以在K8s Pod中构建镜像并推送到仓库，无需特权模式。(目前已归档)。
  * BuildKit：Docker的下一代构建引擎，支持并行构建、缓存优化，速度极快。

## 重新认识Docker容器

### 1. 容器构建与镜像制作(Dockerfile)
Dockerfile是制作容器镜像的**声明式** 方式，它将复杂的rootfs制作过程标准化。

| 原语 | 作用 | 原理关联 | 关键点 |
| --------------- | --------------- | --------------- | --------------- |
| FROM | 指定基础镜像 | 基于现有rootfs | 避免重复安装环境(如python2.7-slim) |
| RUN | 在容器内部执行shell命令 | CoW（写时复制） | 没孩子行一个RUN都会生成一个新的镜像层。 |
| ADD/COPY | 将宿主机文件复制到容器内 | rootfs增量 | 复制操作也创建新的镜像层 |
| ENV/EXPOSE | 设置环境变量、暴露端口 | 写入镜像层元数据。 | 即使没有修改文件，也会生成一个空层。 |
| CMD/ENTRYPOINT |  定义容器启动时执行的命令 | 容器进程的PID 1 | 完整格式是 ENTRYPOINT CMD；默认隐含 ENTRYPOINT为/bin/sh -c|

  精髓：docker build 的过程等同于：启动一个基础镜像容器 -> 依次执行Dockerfile总的原语 -> 每一步操作的结果都保存为一个增量只读镜像层。

![容器全景图](./attachments/251209-175214.png)

---

### 2. Docker容器的本质与隔离机制
容器本质是运行在宿主机上的一个进程，该进程通过Linux内核技术被赋予了"隔离"和"限制"的能力

#### 1. docker exec 的实现原理
docker exec允许你进入一个正在运行的容器，其核心是利用Linux Namespace的文件表示和setns()系统调用。

- Namespac文件：每个运行中的进程(包括容器进程)的各种Namespace信息，都以虚拟文件的形式存在于宿主机上：/proc/[PID]/ns/目录下。
- setns()系统调用：docker exec启动一个新的进程(例如 /bin/bash)，然后通过setns()系统调用，将这个新进程加入到目标容器进程(PID 1)已有的Namespace中：
  * 例如，加入容器的Network Namespace后，新进程就只能看到容器内部的网络设备和配置。
- 共享Namespace：一个进程一旦加入，它与目标容器进程就会共享Namespace(例如 /proc/[PID]/ns/net文件会指向同一个net:[inode号])。
- 特殊用法：docker run -net container:`<ID>`可以让一个新容器直接共享量一个容器的Network Namespace，常用于Pod(Kubernetes)模型的网络实现。

#### 2. 容器生命周期中的PID 1
- dockerinit(初始化进程)：Docker并非直接运行应用进程。它首先会创建一个dockerinit进程。
- 职责：dockerinit负责在容器内部完成所有初始化操作，包括：
  * 准备rootfs(联合挂载)。
  * 配置hostname和挂载设备。
  * 执行完初始化后，dockerinit会通过execv()系统调用，用应用进程(ENTRYPOINT + CMD)取代自己。
- 结果：应用进程取代了dockerinit，因此它成为了容器内唯一且真正的PID 1进程。

---

### 3. 数据卷Volume的核心原理
Volume机制用于解决容器内部文件与宿主机之间的**持久化**和**共享**的问题。

#### 1. Volume挂载的本质
Volume 机制的关键在于利用了绑定挂载(Bind Mount)机制，并且执行时机非常巧妙。

- 挂载时机：在容器的Mount Namespace已经开启，但容器进程**尚未执行chroot(或pivot_root)** 切换根目录之前。
- 核心操作：在宿主机空间内，将Volume指定宿主机目录(如/home)通过绑定挂载，挂载到容器rootfs可读写层上的对应目录(如/var/lib/docker/overlay2/[id]/diff/test)上。

#### 2. 绑定挂载(Bind Mount)机制
- 作用：允许将一个目录或文件挂载到另一个指定的目录上，实现内容替换。
- Linux原理：绑定挂载相当于inode替换。当修改挂载点(如容器内的/test目录)时，实际修改的是被挂载目录(宿主机上的/home)的inode。
- 隔离性：由于这个挂载操作发生在容器的Mount Namesspace内，因此宿主机无法感知这次挂载。这保证了容器的隔离性。

#### 3. Volume不会被提交
- docker commit机制：有docker commit发生在宿主机空间，且宿主机看不到容器内部的绑定挂载。
- 结果：在宿主机看来，可读写层(UpperDir)上Volume挂载点(如/test)始终是空的，因此Volume里的实际数据不会被提交到新的镜像中。

## Kubernetes本质
### 1. 容器基础再认识
- 容器 = 隔离环境 + 镜像:
  * 静态部分：容器镜像(rootfs联合挂载) -> 开发者真正关系的载体
  * 动态部分：容器运行时(Namespace + Cgroups) -> 底层实现细节
- 关键洞察：在"开发-测试-发布"流程中，传递的是镜像而非运行时

---


### 2. 从容器到容器云的飞跃
- 容器云价值链条
 ```shell
 开发者 -> 镜像 -> 云平台 -> 生态服务(CI/CD/监控/安全等)
```
- 核心逻辑：云厂商通过镜像直接连接开发者，沉淀整个技术栈价值

---


### 3. Kubernetes架构精要

控制平面(Master节点)

| 组件 | 职责 | 要点 |
| --------------- | --------------- | --------------- |
| kube-apiserver | API入口，数据验证 | 集群总工 |
| kube-scheduler | Pod调度决策 | 工作分配员 |
| kube-controller-manager | 集群状态调节 | 系统管家 |
| etcd | 持久化存储 | 集群大脑记忆 |


工作节点(Node节点)
| 组件 | 职责 | 交互接口 |
| --------------- | --------------- | --------------- |
| kubelet | 节点核心代理 | 与Master通信 |
| 容器运行时 | 运行容器 | CRI接口 |
| 网络插件 | 配置网络 | CNI接口 |
| 存储插件 | 配置存储 | CSI接口 |
| Device Plugin | 管理特殊硬件 | gRPC协议 |


![Kubernetes全局架构](./attachments/251210-172437.png)

--- 

### 4. 核心设计理念：处理关系的艺术

1. 关系抽象(源自Borg经验):
  - 核心观点：“大规模集群中任务建关系处理才是最难的”
  - 关系类型处理：
    - 紧密协作 -> Pod(共享Network Namespace + Volume)
    - j服务访问 -> Service(固定IP/域名，解耦动态Pod)
    - 安全凭证 -> Secret(自动挂载敏感数据)
    - 特殊形态 -> 专用控制器：
      * Deployment：无状态应用
      * StatfulSet：有状态应用
      * DaemonSet：守护进程
      * Job/CronJob：一次性/定时任务

1. 声明式API
- 核心模式：
  * 编排对象(Pod/Deployment/StatefulSet等)：描述应用是什么
  * 服务对象(Service/Secret/HPA等)：描述应用如何工作
- 使用方式：编写YAML声明期望状态 -> 系统自动达成

---

### 5. Kubernetes本质 vs. 竞品

| 维度 | Kubernetes | Docker Swarm |
| --------------- | --------------- | --------------- |
| 核心能力 | 容器关系编排 | 容器调度 |
| 设计思想 | 抽象普适，为未来扩展预留 | 问题驱动，针对性解决 |
| API风格 | 声明式(Declarative) | 命令式(Imperative) |
| 状态管理 | 声明期望状态，自动调节 | 执行具体命令 |
| 源头灵感 | Google Borg论文(生产验证) | 新设计 |

## 为什么需要Pod

### 1. Pod的本质定位
- 核心定义：Pod是Kubernetes中最小的API对象和原子调度单位
- 哲学视角：
  * 容器 = 云计算系统的进程
  * Kubernetes = 云计算的操作系统
  * Pod = 操作系统中的进程组
- Pod是逻辑概念，不是实际的隔离环境，它是一组共享资源的容器集合。

---

### 2. 为什么需要Pod？解决的核心问题
1. 进程组写作需求：
  a. 现实场景：操作系统中进程通常以"组"方式协作(如rsyslog由多个子进程组成)
  b. 容器困境：容器"单进程模型"限制(容器没有管理多个进程的能力，PID=1进程就是应用本身)
  c. 调度难题：传统调度器无法处理"成组调度(gang sheduling)"问题
```shell
示例：三个相关容器需要3GB内存
问题：若前两个容器占用了node-2的2.5GB，第三个容器无法调度。
Pod方案：按整个Pod资源需求一次性调度，避免资源碎片
```
2. “超亲密关系”处理：
  a. 定义：容器间存在以下一种或多种紧密关系：
    i. 频繁本地通信
    ii. 直接文件交换
    iii. 非常频繁的远程调用
    iv.  共享Linux Namespace
  b. 重要区分：不是所有关系的容器都应在同一Pod:
    i. 同Pod：紧密协作、必须同机部署的组件
    ii. 不同Pod：如PHP应用与Mysql，适合松耦合部署

---

### 3. Pod的实现原理
- 核心机制：Infra容器:
  * 角色：Pod中的"奠基者"，永远第一个创建
  * 实现：使用特殊镜像`k8s.gcr.io/pause`(仅100-200KB,汇编编写，永远暂停状态)
  * 功能：
    + "Hold"Network Namespace
    + 为其他容器提供共享网络基础
    + 定义Pod生命周期(Pod生命周期只与Infra容器一致)
![Pod组成图](./attachments/251211-184243.png)

- 资源共享机制
  | 共享资源 | 实现方式 | 效果 |
  | --------------- | --------------- | --------------- |
  | Network Namespace | 其他容器Join Infra容器网络 | 所有容器共享同一IP |
  | Volume | 在Pod层级定义Volume，容器声明挂载 | 多容器共享同一volume |
  
- 网络特性：
  * 一个Pod只有一个IP地址
  * 所有网络资源(端口、路由表)Pod内共享
  * 网络插件只需要配置Pod(Infra容器)的Network Namespace，无需关注单个容器

---

### 4. 容器设计模式：Sidecar模式

- 模式定义：
  * 核心思想：在Pod中启动一个辅助容器(sidecar)，完成独立于主进程之外的工作
  * 优势：解耦功能、提高复用性、简化容器设计

- 典型场景：
  * 场景1：WAR包与WEB服务器
  * 工作流程：Init Container复制WAR包 → 共享Volume → Tomcat容器读取并部署
  - 优势：解耦应用与运行时，独立更新WAR包或Tomcat

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: javaweb-2
spec:
  initContainers:  # 优先执行的辅助容器
  - image: geektime/sample:v2
    name: war
    command: ["cp", "/sample.war", "/app"]
    volumeMounts:
    - mountPath: /app
      name: app-volume
  containers:
  - image: geektime/tomcat:7.0
    name: tomcat
    volumeMounts:
    - mountPath: /root/apache-tomcat-7.0.42-v2/webapps
      name: app-volume
  volumes:
  - name: app-volume
    emptyDir: {}  # 临时共享存储
```
- 场景2：日志收集：
  - 架构：
    - 主容器：将日志写入共享Volume
    - Sidecar容器：从共享Volume读取日志，转发到日志系统
  - 优势：日志收集逻辑与应用逻辑分离，无需修改主应用

---

### 5. 核心洞见与设计哲学

1. Pod vs 虚拟机
  - 新视角：Pod扮演传统"虚拟机"角色，容器是虚拟机中运行的程序
  - 迁移指导：将虚拟机中运行的多个进程，转化为Pod中的多个容器：
    - 有启动顺序的 → Init Container
    - 并行运行的 → 普通容器
    - 共享资源的 → 通过Volume共享

2. 容器本质认知
  - 关键原则：一个容器 = 一个进程（严格说是缺乏进程管理能力的单进程模型）
  - 反模式警告：
    - 避免在单容器中运行多进程
    - 避免"Docker in Docker"等复杂嵌套方案
    - 不要将容器视为"轻量级虚拟机"

3. 架构演进
  - 从单体到微服务：Pod提供自然过渡路径
  - 最佳实践：松耦合设计，每个容器专注单一职责

## Pod的基本概念

### 1. Kubernetes的关键理念与核心抽象

#### 1.1 Pod是最小编排单位
- Kubernetes的核心设计：Pod，而非容器，是调度、网络、存储和安全策略管理的对象。
- Pod在语义上接近"轻量虚拟机"：
  * 容器在Pod内共享环境(特别是Linux Namespace与资源视图)。
  * Pod承担"机器角色"，容器是"程序"。

#### 1.2 Pod与Container的关系
- container是Pod.spec中的普通字段。
- Pod管的是整体(网络、存储、调度、安全)，Container管运行逻辑(镜像、命令、挂载)。

---

### 2. Pod的关键字段与语义

#### 2.1 调度相关字段(Pod 级别)

| 字段 | 作用 |
| -------------- | --------------- |
| nodeSelect | 指定Pod必须调度到具备特定label的节点。 |
| nodeName | 指定目标节点(跳过调度器)，常用于调试。 |
| affinity/anti-affinity | 更细粒度的调度约束。 |

#### 2.2 网络/存储/安全(Pod级别)
- Pod整体的“机身配置”:
  * hostNetwork/hostPID/hostIPC：共享宿主机Namespace。
  * volumes：定义存储卷。
  * securityContext(Pod级别)：定义整体安全策略。

#### 2.3 /etc/hosts控制(Pod级别)
- hostAliases:
  * 以声明方式修改hosts文件。
  * Pod重建后由Kubelet重写；不可直接手动修改。

---

### 3. Pod内多容器协作机制

#### 3.1 Linux Namespace 共享
- Pod设计核心目标：让同一个Pod内的容器尽可能共享Namespace，类似进程在同一台机器上运行。
- 常见共享模式：
  * shareProcessNamespace: true -> 容器共享PID Namespace，可互相看到对方进程(含pause容器)。
  * hostNetwork/HostPID/hostIPC -> 直接使用宿主机的Namespace

#### 3.2 Init Container

- 与普通容器等价定义，但执行顺序严格控制：
  * 顺序必定为initContainer1 -> 2 -> ... -> containers。
  * 用于依赖准备、环境检查等场景。

--- 

### 4. Container(容器)级别的关键字
- ImgagePullPolicy:
  * 如果镜像标签是latest或者没有指定tag，则默认ImagePullPolicy=Always。-- 总是拉去像，至于底层CRI是否会根据layer进行hash的判断，这里不谈。
  * 如果镜像标签是其他具体标签(如nginx:1.21)
  * IfNotPresent:宿主机没有才拉取(推荐生产环境配合使用具体版本号并配合此项)。
  * Never：只使用本地镜像。
- Lifecycle(生命周期钩子)：
  * postStart：容器启动后立即执行。注意：它与ENTRYPOINT异步执行，不保证先后顺序。
  * preStop：容器被杀死前执行。它是同步阻塞的，常用于应用的"优雅退出"(如关闭数据库连接)。

---

### 4. Pod的生命周期与状态机
Pod的status.phase是判断应用健康状况的第一窗口：

1. Pending：资源请求已提交，但尚未调度成功或镜像正在下载。
2. Running：至少一个容器正在运行。
3. Succeeded：所有容器正常退出(状态码0)，多见于Job任务。
4. Failed：至少一个容器非正常退出。
5. Unknown：Kubelet失去联系(通常是网络插件或节点宕机问题)。
注：Running不等于Ready：Running仅代表进程在运行，而Ready(属于Conditions)才代表Pod已经通过了健康检查，可以对外接收流量。

## 深入解析Pod对象(二)使用进阶
### 1. 投射数据卷(Projected Volume)
Projected Volume是k8s v1.11+的重要特性。它的本质是：将集群内的元数据或配置信息，像"投影"一样映射到Pod内部的卷中。
| 类型 | 核心作用 | 技术要点 |
| --------------- | --------------- | --------------- |
| Secret | 存放敏感数据(如数据库密码、Token) | 数据在Etcd中以Base64编码存储(非加密，需开启加密插件) |
| ConfigMap | 存放非敏感数据(如.yaml文件) | 支持文件热更新，容器内文件随Etcd数据更新而自动变化 |
| Downward API | 让容器获取Pod自身的元数据 | 可获取Pod IP、Node Name、Labels、CPU/MEM限制等 |
| ServiceAccountToken | 存放API Server的访问凭证 | 默认自动挂载在`/var/run/secrets/Kubernetes.io/serviceaccount` |

注：获取配置建议优先使用Volume挂载而非环境变量。环境变量不支持热更新，而Volume挂载文件由kubelet维护，具备自动更新能力。

---

### 2. 容器健康检查：Probe(探针)机制
这是生产环境"自愈能力"的核心。

- livenessProbe(存活探针):
  * 作用：判断容器是否还在"活着"。
  * 失败后果：Kubelet会杀掉该容器，并根据restartPolicy进程重启(重建)。
- readinessProbe(就绪探针):
  * 作用: 判断容器是否"准备好接收流量"。
  * 失败后果：Pod会从Service的Endpoints中剔除，流量不再切入，但不会重启容器。

探测方式对比：

1. ExecAction：在容器内执行命令(看退出码是否为0)。
2. HTTPGetAction：发起HTTP GET请求(看状态码是否在200-400之间)。
3. TCPSocketAction：检查端口是否可以建立TCP连接。

---

### 3. Pod恢复策略：restartPolicy
重启永远发生在当前节点，Pod不会因为容器失败而自动漂移到其他Node。

- Always(默认)：只要退出就重启。
- OnFailure：只有非正常退出(退出码非0)才重启。
- Never：从不重启。适用于需要保留退出后现场(日志、文件)进行Debug的场景。

---

### 4. 自动化利器：PodPreset(Pod预设置)
解决痛点：运维人员希望统一给Pod注入环境变量、挂载存储，而不需要开发人员在每个YAML里重复编写。

- 工作原理：通过selector匹配带有特定Label的Pod。
- 合并规则：Pod创建时，API Server自动将PodPreset定义的内容合并到Pod对象中。
- 冲突处理：如果PodPreset注入的字段与Pod原始字段冲突，则冲突部分不予修改。

---

### 5. In-Cluster编程
ServiceAccount是K8s内部服务的身份卡。

- 如果你想在Pod里写代码调用K8s API，无需手动配置Token。
- 直接使用官方Client库，它会自动识别挂载到`var/run/secrets/...`下的Token，这被称为InClusterConfig模式。

## 编排的本质 -- 控制器模式
### 1. 核心哲学：控制循环(Control Loop)
Kubernetes的编排并不神秘，其核心是一个不断运行的死循环。它通过不断地将"实现"与"理想"对比，来驱动系统状态的改变。

- 实际状态(Actual State)：由集群本身汇报(如Kubelet汇报的容器状态)。
- 期望状态(Desired State)：由用户通过YAML声明(如Deployment中的replicas:3)。
- 协调(Reconcile)：对比两者的差异，并执行写操作(创建或删除Pod)使其趋于一致。

伪代码描述逻辑：
```go
for {
  实际状态 := 获取集群中对象X的实际状态
  期望状态 := 获取集群中对象X的期望状态
  if 实际状态 == 期望状态 {
    continue // 休息一会儿
  } else {
    执行编排动作，将实际状态调整为期望状态
  }
}
```
---

### 2. 控制器的组成结构
一个标准的控制器对象(如Deployment)通常由两部分组成：

1. 控制器定义：包含期望状态(如副本数、标签选择器selector等)。
2. 被控制对象的模版(PotTemplate)：定义了要生成的Pod应该长什么样(镜像、端口、挂载等)。

---

### 3. kube-controller-manager：控制器的集合
在k8s架构中，由一个专门的组件叫kube-controller-manager。它并不是一个单一的控制器，而是一系列控制器的合集。

- 每一个控制器负责一种资源：DeploymentController、JobController、StatefulSetController等。
- 它们都在同一个进程中运行，各自执行自己的控制循环。

--- 

### 4. 面向API对象编程
在控制器模式下，我们对集群的操作不再是"命令式"的(例如：运行一个容器)，而是"声明式"的(例如：我想要3个这样的容器)。

- OwnerReference：每个被创建出来的Pod都会有一个ownerReference字段，指向它的"拥有者"(如 ReplicaSet)，这保证了对象之间的从属关系。

---

### 5. 控制器模式 vs 事件驱动
| 维度 | 事件驱动(Event-Driven) | 控制器模式(Controller Pattern) |
| --------------- | --------------- | --------------- |
| 触发机制 | 某个事件发生时触发动作 | 定期循环检查(边缘触发+水平触发) |
| 可靠性 | 如果事件丢失或处理失败，可能导致状态不一致 | 只要循环在，即使错过某次事件，下次循环依然能修复状态 |
| 状态维护 | 关注"过程"和"变化" | 关注"结果"和"最终一致性" |


- 所有控制器共用一个逻辑：无论是简单的Deployment还是复杂的StatefulSet，核心都是Reconcile Loop。
- Informer机制：虽然逻辑上是循环，但为了性能，k8s内部使用Informer机制来实现"及时通知"，避免频繁空转。

## Deployment与水平扩展/滚动更新
### 1. 核心层级架构
Deployment是一个两层控制器，其层级关系如下：

- 第一层：Deployment控制ReplicaSet(版本管理)。
- 第二层：ReplicaSet控制Pod(副本数管理)。
注：这种设计实现了"应用版本"与"ReplicaSet"的一一对应。每一个新的ReplicaSet都代表应用的一个新版本。

---

### 2. 水平扩展/缩容(Scaling)
- 原理：Deployment Controller只需要修改它所控制的ReplcaSet的replicas字段。
- 指令：`kubectl scale deployment nginx-deployment --replias=4`

---

### 3. 滚动更新(Rolling Update)
这是Deployment最强大的编排能力，允许在不中断服务的情况下升级。

- 执行过程：
  * 创建一个新版本的ReplicaSet。
  * 新RS"水平扩展"出一个Pod。
  * 旧RS"水平收缩"掉一个Pod。
  * 交替进行，知道旧RS副本数为0，新RS达到DESIRED数量。
- 状态字段解读：
  * DESIRED：期望副本数。
  * UP-TO-DATE：已升级到最新的Pod数。
  * AVAILABLE：用户真正可用的Pod数(Running + 最新版 + Ready健康检查通过)。

---

### 4. 版本控制与回滚(Rollback)
依靠保留旧版本的ReplicaSet，Deployment可以轻松实现"一键回滚"。

- 查看历史：`kubectl rollout history deployment/nginx-deployment `
- 回滚至上一个版本：`kubectl rollout undo deployment/nginx-deployment`
- 回滚至指定版本：`kubectl rollout undo ... --to-revision=2`
- 控制历史版本数量：设置spec.revisionHistoryLimit(若为0则无法回滚)

---

### 5. 滚动更新策略控制
通过RollingUpdateStrategy确保服务连续性：

- maxSurge：升级过程中，最多比DESIRED数量多出多少个Pod。
- maxUnavailable：升级过程中，最多有多少个Pod处于不可用状态。

---

### 6. 建议
如果你需要对 Deployment 进行多次修改（如改镜像、改配置、改 Labels），为了避免每改一次都触发一次滚动更新，可以使用以下技巧：

- 暂停：kubectl rollout pause（进入暂停状态，修改不会触发更新）。
- 修改：执行多次 kubectl set image 或 kubectl edit。
- 恢复：kubectl rollout resume（所有修改合并为一次滚动更新）。
