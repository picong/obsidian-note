---
tags:
  - Rest
created: 2026-01-30
---

# 分布式架构-03-Richardson成熟度模型

## 💡 核心观点
Richardson成熟度模型(Richardson Maturity Model，RMM)将服务接口按照"REST的程度"，从低到高分为0至3共4级，帮助评估API的RESTful程度。

## 📝 详细笔记

### Richardson成熟度模型的四个级别

Richardson将服务接口按照"REST的程度"，从低到高分为0至3共4级：

1. **The Swamp of Plain Old XML**：完全不REST。
2. **Resources**：开始引入资源的概念。
3. **HTTP Verbs**：引入统一接口，映射到HTTP协议的方法上。
4. **Hypermedia Controls(超文本驱动)**。

![[Pasted image 20250826134455.png]]

### 各级别的特点

- **Level 0**：使用HTTP作为传输协议，但不使用HTTP的任何特性
- **Level 1**：引入资源概念，每个资源有独立的URI
- **Level 2**：正确使用HTTP动词(GET、POST、PUT、DELETE等)
- **Level 3**：使用HATEOAS(Hypermedia As The Engine Of Application State)，响应中包含相关资源的链接

## 🔗 关联思考
- 相关课题：[[分布式架构-02-Rest]]
- 大多数所谓的REST API实际上只达到了Level 2
- Level 3的HATEOAS在实践中较少被完全实现

## 🚀 下一步行动
- [ ] 评估现有项目的REST成熟度级别
- [ ] 学习HATEOAS的实现方式

## 📚 系列导航
- 上一篇：[[分布式架构-02-Rest]]
- 下一篇：[[分布式架构-04-本地事务]]
