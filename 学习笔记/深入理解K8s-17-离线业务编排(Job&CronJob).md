---
tags: [k8s, job, cronjob, 离线任务]
created: 2026-01-29
---

# 深入理解K8s-17-离线业务编排(Job&CronJob)

## 💡 核心观点
> Job和CronJob是Kubernetes中专门用于离线任务的控制器，通过completions和parallelism参数控制任务完成数和并行度，支持一次性任务和定时任务的编排。

## 📝 详细笔记

### 1. 为什么离线业务需要专门的控制器？

- **在线业务(Deployment/StatefulSet)**：追求"永不退出"。如果进程结束，控制器会不断重启它。
- **离线业务(Job)**：追求"完成任务"。任务结束后，Pod应该进入`Completed`状态，而不是被重启。

### 2. Job：一次性任务的管理者

Job负责创建一个或多个Pod，并确保指定数量的Pod成功终止。

- **核心字段解析**：
  * `restartPolicy`：只能设为`Never`(失败则创建新Pod)或`OnFailure`(失败则重启容器)。绝不能设为Always。
  * `backoffLimit`：最大重试次数(默认6)。
  * `activeDeadlineSeconds`：最长运行时间，超时会终止所有相关Pod。
- **Label机制**：Job会自动生成一个带有`controller-uid`的随机Label，防止不同Job之间的Pod相互干扰。

### 3. 并行控制：离线计算的核心

Job通过两个关键参数控制并行计算：

| 参数 | 定义 | 计算公式 |
| --------------- | --------------- | --------------- |
| completions | 最小完成数。即总共需要多少个Pod成功运行完 | 期望数 = completions = Running Pod = Succeeded Pods |
| parallelism | 最大并行度。同一时刻最多允许多少个Pod在运行。 | 实际创建数 = min(期望创建数，parallelism) |

### 4. 三种常见的Job模式

1. **外部管理 + Job模板**：外部程序(如Shell脚本或KubeFlow)替换Yaml中的变量，批量生成Job。
2. **固定任务总数(Work Queue)**: `completions`设为固定值，Pod从队列(RabbitMQ)取任务，处理完即退出。
3. **非固定任务总数**：不设`completions`。Pod循环取任务，直到队列为空才退出。

### 5. CronJob: 定时任务控制器

- **本质**：Job的控制器。不直接管理Pod，而是管理Job。
- **核心配置**：
  * `schedule`：标准Unix Cron格式(分钟、小时、日、月、星期)。
  * `concurrencyPolicy`:
    + Allow(默认): 允许多个Job同时存在。
    + Forbid：不会不会创建新的Pod，该创建周期被跳过。
    + Replace：新Job替换还没完的旧Job。

## 🔗 关联思考
- 相关课题：[[深入理解K8s-18-Kubernetes声明式API与编程范式]]
- 应用场景：批处理任务的最佳实践

## 📚 系列导航
- 上一篇：[[深入理解K8s-16-深度解析DaemonSet]]
- 下一篇：[[深入理解K8s-18-Kubernetes声明式API与编程范式]]
