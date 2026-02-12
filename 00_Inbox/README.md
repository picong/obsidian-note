---
tags:
  - 索引
  - Inbox
created: 2026-02-10
---

# 📥 Inbox

> *快速捕捉灵感与想法的地方*

## 📝 闪念笔记

这里存放日常的闪念笔记和临时想法。

```dataview
TABLE file.mtime as "修改时间"
FROM "00_Inbox"
WHERE file.name != "README"
SORT file.mtime DESC
LIMIT 20
```

## 💡 使用说明

**收件箱的作用：**
- 快速记录突然的想法和灵感
- 临时存放待整理的笔记
- 作为知识处理的第一站

**处理流程：**
1. 📝 快速记录 → 收件箱
2. 🔍 定期回顾 → 提炼整理
3. 📚 归档分类 → 移至对应文件夹

## 🔗 相关链接

- [[首页|返回首页]]
- [[03_Maps/首页索引|完整索引]]
- [[01_Literature/README|文献笔记]]
