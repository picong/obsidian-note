---
tags: [k8s, docker, volume]
created: 2026-01-29
---

# 深入理解K8s-06-重新认识Docker容器

## 💡 核心观点
> Docker容器的本质是运行在宿主机上的特殊进程，通过Dockerfile实现镜像构建，通过Volume机制实现数据持久化，通过docker exec可以进入运行中的容器。

## 📝 详细笔记

### 1. 容器构建与镜像制作(Dockerfile)

Dockerfile是制作容器镜像的**声明式** 方式,它将复杂的rootfs制作过程标准化。

| 原语 | 作用 | 原理关联 | 关键点 |
| --------------- | --------------- | --------------- | --------------- |
| FROM | 指定基础镜像 | 基于现有rootfs | 避免重复安装环境(如python2.7-slim) |
| RUN | 在容器内部执行shell命令 | CoW（写时复制） | 没孩子行一个RUN都会生成一个新的镜像层。 |
| ADD/COPY | 将宿主机文件复制到容器内 | rootfs增量 | 复制操作也创建新的镜像层 |
| ENV/EXPOSE | 设置环境变量、暴露端口 | 写入镜像层元数据。 | 即使没有修改文件，也会生成一个空层。 |
| CMD/ENTRYPOINT |  定义容器启动时执行的命令 | 容器进程的PID 1 | 完整格式是 ENTRYPOINT CMD；默认隐含 ENTRYPOINT为/bin/sh -c|

精髓：docker build 的过程等同于：启动一个基础镜像容器 -> 依次执行Dockerfile总的原语 -> 每一步操作的结果都保存为一个增量只读镜像层。

![容器全景图](attachments/251209-175214.png)

### 2. Docker容器的本质与隔离机制

容器本质是运行在宿主机上的一个进程，该进程通过Linux内核技术被赋予了"隔离"和"限制"的能力

#### 1. docker exec 的实现原理

docker exec允许你进入一个正在运行的容器，其核心是利用Linux Namespace的文件表示和setns()系统调用。

- **Namespac文件**：每个运行中的进程(包括容器进程)的各种Namespace信息，都以虚拟文件的形式存在于宿主机上：/proc/[PID]/ns/目录下。
- **setns()系统调用**：docker exec启动一个新的进程(例如 /bin/bash)，然后通过setns()系统调用，将这个新进程加入到目标容器进程(PID 1)已有的Namespace中：
  * 例如，加入容器的Network Namespace后，新进程就只能看到容器内部的网络设备和配置。
- **共享Namespace**：一个进程一旦加入，它与目标容器进程就会共享Namespace(例如 /proc/[PID]/ns/net文件会指向同一个net:[inode号])。
- **特殊用法**：docker run -net container:`<ID>`可以让一个新容器直接共享量一个容器的Network Namespace，常用于Pod(Kubernetes)模型的网络实现。

#### 2. 容器生命周期中的PID 1

- **dockerinit(初始化进程)**：Docker并非直接运行应用进程。它首先会创建一个dockerinit进程。
- **职责**：dockerinit负责在容器内部完成所有初始化操作，包括：
  * 准备rootfs(联合挂载)。
  * 配置hostname和挂载设备。
  * 执行完初始化后，dockerinit会通过execv()系统调用，用应用进程(ENTRYPOINT + CMD)取代自己。
- **结果**：应用进程取代了dockerinit，因此它成为了容器内唯一且真正的PID 1进程。

### 3. 数据卷Volume的核心原理

Volume机制用于解决容器内部文件与宿主机之间的**持久化**和**共享**的问题。

#### 1. Volume挂载的本质

Volume 机制的关键在于利用了绑定挂载(Bind Mount)机制，并且执行时机非常巧妙。

- **挂载时机**：在容器的Mount Namespace已经开启，但容器进程**尚未执行chroot(或pivot_root)** 切换根目录之前。
- **核心操作**：在宿主机空间内，将Volume指定宿主机目录(如/home)通过绑定挂载，挂载到容器rootfs可读写层上的对应目录(如/var/lib/docker/overlay2/[id]/diff/test)上。

#### 2. 绑定挂载(Bind Mount)机制

- **作用**：允许将一个目录或文件挂载到另一个指定的目录上，实现内容替换。
- **Linux原理**：绑定挂载相当于inode替换。当修改挂载点(如容器内的/test目录)时，实际修改的是被挂载目录(宿主机上的/home)的inode。
- **隔离性**：由于这个挂载操作发生在容器的Mount Namesspace内，因此宿主机无法感知这次挂载。这保证了容器的隔离性。

#### 3. Volume不会被提交

- **docker commit机制**：有docker commit发生在宿主机空间，且宿主机看不到容器内部的绑定挂载。
- **结果**：在宿主机看来，可读写层(UpperDir)上Volume挂载点(如/test)始终是空的，因此Volume里的实际数据不会被提交到新的镜像中。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-07-Kubernetes本质]]
- 实践技巧：Volume的使用场景和最佳实践

## 📚 系列导航
- 上一篇：[[深入理解K8s-05-镜像文件的演进]]
- 下一篇：[[深入理解K8s-07-Kubernetes本质]]
