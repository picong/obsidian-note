# 图片整理任务报告

## 任务概述
整理 `学习笔记/` 目录下所有markdown文件中引用的图片，将它们移动到 `学习笔记/attachments/` 目录，并更新所有引用路径。

## 扫描结果

### 发现的图片引用

通过扫描所有markdown文件，发现以下图片被引用：

#### Obsidian风格引用 (![[attachments/image.png]])
共发现 69 个Obsidian风格的图片引用，包括：

**分布式架构系列 (6个图片):**
- Pasted image 20250826172442.png
- Pasted image 20250826134455.png
- Pasted image 20250827151040.png
- Pasted image 20250827151902.png
- Pasted image 20250828111816.png
- Pasted image 20250827170415.png

**分布式算法.md (61个图片):**
- Pasted image 20250717190835.png
- Pasted image 20250717202444.png
- Pasted image 20250718160950.png
- Pasted image 20250718161022.png
- Pasted image 20250718164553.png
- Pasted image 20250718165044.png
- Pasted image 20250721161505.png
- Pasted image 20250721161329.png
- Pasted image 20250721171023.png
- Pasted image 20250722134524.png
- Pasted image 20250722134535.png
- Pasted image 20250723110128.png
- Pasted image 20250723135936.png
- Pasted image 20250723151053.png
- Pasted image 20250723162743.png
- Pasted image 20250723174203.png
- Pasted image 20250724101225.png
- Pasted image 20250724101912.png
- Pasted image 20250724113532.png
- Pasted image 20250724150330.png
- Pasted image 20250724161927.png
- Pasted image 20250724172848.png
- Pasted image 20250725103459.png
- Pasted image 20250725103506.png
- Pasted image 20250725104556.png
- Pasted image 20250725112826.png
- Pasted image 20250725142650.png
- Pasted image 20250725144629.png
- Pasted image 20250725154532.png
- Pasted image 20250728155432.png
- Pasted image 20250728160851.png
- Pasted image 20250728161005.png
- Pasted image 20250728161409.png
- Pasted image 20250728170105.png
- Pasted image 20250728171721.png
- Pasted image 20250728180947.png
- Pasted image 20250728181322.png
- Pasted image 20250728182622.png
- Pasted image 20250729102746.png
- Pasted image 20250730150240.png
- Pasted image 20250731181753.png
- Pasted image 20250731173029.png
- Pasted image 20250801182349.png
- Pasted image 20250805111010.png
- Pasted image 20250804200517.png
- Pasted image 20250804200526.png
- Pasted image 20250804200528.png
- Pasted image 20250804200905.png
- Pasted image 20250804201101.png
- Pasted image 20250806113159.png
- Pasted image 20250819110911.png
- Pasted image 20250819145303.png
- Pasted image 20250819145339.png
- Pasted image 20250819150445.png
- Pasted image 20250819150613.png
- Pasted image 20250820174716.png
- Pasted image 20250821134515.png
- Pasted image 20250822101329.png
- Pasted image 20250822164934.png
- Pasted image 20250822181652.png

**深入理解K8s系列 (2个图片):**
- Pasted image 20260129110715.png
- Pasted image 20260129110739.png

#### Markdown风格引用 (![](attachments/image.png))
共发现 16 个Markdown风格的图片引用：

**分布式架构系列 (7个图片):**
- 250926-182334.avif
- 250928-164922.avif
- 250928-164940.avif
- 250928-165006.avif
- 251022-180200.avif
- 251031-155932.avif
- 251028-171506.avif

**深入理解K8s系列 (9个图片):**
- 251208-171047.png
- 251210-172437.png
- 251209-175214.png
- 251211-184243.png
- 251231-164331.png
- 260114-101039.png
- 260114-103455.png
- 260114-183141.png
- 260120-142139.png

### 统计信息
- **总共引用的唯一图片数量**: 85个
- **Obsidian风格引用**: 69个
- **Markdown风格引用**: 16个
- **涉及的markdown文件**: 约20个

## 需要执行的操作

### 1. 移动图片文件
需要将以下85个图片从vault根目录移动到 `学习笔记/attachments/` 目录：

所有上述列出的图片文件。

### 2. 更新markdown文件中的引用路径

需要更新以下文件中的图片引用：

**Obsidian风格更新 (![[attachments/image.png]] → ![[./attachments/image.png]]):**
- 分布式架构-04-本地事务.md
- 分布式架构-03-Richardson成熟度模型.md
- 分布式架构-07-XA全局事务.md
- 分布式架构-09-TCC事务的实现过程.md
- 分布式架构-08-可靠消息队列.md
- 分布式算法.md
- 深入理解K8s-25 FlexVolume与CSI.md

**Markdown风格更新 (![](attachments/image.png) → ![](attachments/image.png)):**
- 分布式架构-21-授权.md
- 分布式架构-25-传输安全.md
- 分布式架构-29-Multi Paxos、Raft再到Gossip.md
- 分布式架构-28-分布式系统中如何实现共识.md
- 深入理解K8s-03-隔离与限制(Cgroups).md
- 深入理解K8s-07-Kubernetes本质.md
- 深入理解K8s-06-重新认识Docker容器.md
- 深入理解K8s-08-为什么需要Pod.md
- 深入理解K8s-15-深入理解StatefulSet之实践部署Mysql一主多从集群.md
- 深入理解K8s-19-深入解析API对象的奥秘.md
- 深入理解K8s-20-Kubernetes自定义控制器(CustomController)深度笔记.md
- 深入理解K8s-22-Operator工作原理.md

### 3. 未使用的图片
Vault根目录下有673个图片文件，其中只有85个被学习笔记引用。剩余588个图片可能被其他目录的笔记引用，或者是未使用的图片。

## 手动执行步骤

由于自动化脚本遇到了字符编码问题，建议按以下步骤手动执行：

### 步骤1: 确认attachments目录存在
```
学习笔记/attachments/
```
该目录已创建。

### 步骤2: 移动图片文件
使用文件管理器或命令行，将上述85个图片文件从vault根目录移动到 `学习笔记/attachments/` 目录。

### 步骤3: 批量更新引用路径
可以使用文本编辑器的批量查找替换功能：

**对于Obsidian风格:**
- 查找: `![[Pasted image`
- 替换为: `![[./attachments/Pasted image`

- 查找: `![[25`
- 替换为: `![[./attachments/25`

- 查找: `![[26`
- 替换为: `![[./attachments/26`

**对于Markdown风格:**
- 查找: `![image](25`
- 替换为: `![image](./attachments/25`

- 查找: `![image](26`
- 替换为: `![image](./attachments/26`

- 查找: `![虚拟机与docker容器对比图](25`
- 替换为: `![虚拟机与docker容器对比图](./attachments/25`

(以此类推，针对每种模式)

## 备注
- 所有脚本文件已保存在vault根目录，包括PowerShell和Python版本
- 由于Windows bash环境对中文路径的编码处理问题，自动化脚本无法正常工作
- 建议在PowerShell或文件管理器中手动完成此任务
- 完成后请验证所有图片链接是否正常显示
