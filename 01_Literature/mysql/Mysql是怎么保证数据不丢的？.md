## binlog的写入机制
其实，binlog的写入逻辑比较简单：事务执行过程中，先把日志写到binlog cache，事务提交的时候，再把binlog cache写入到binlog文件中。
一个事务的binlog是不能拆开的，因此不论这个事务多大，也要确保一次性写入。这就涉及到了binlog cache的保存问题。
系统给binlog分配了一片内存，每个线程一个，参数binlog_cache_size用于控制单个线程内binlog cache所占用的大小。如果超过了这个参数规定的大小，就要暂时存到磁盘。

事务提交的时候，执行器吧binlog cache里的完整事务写入到binlog中，并清空binlog cache。状态如图1所示。
![[Pasted image 20231225160236.png]]
可以看到，每个线程有自己的binlog cache，但是共用同一份binlog文件。
- 图中write，指的是把日志写入到文件系统的page cache，并没有把数据持久化到磁盘，所以速度比较快。
- 图中的fsync，才是将数据持久化到磁盘的操作。一般情况下，我们任务fsync才占此磁盘的IOPS。
write和fsync的时机，是由参数sync_binlog控制的：
1. sync_binlog=0的时候，表示每次提交事务都只write，不fsync；
2. sync_binlog=1的时候，表示每次提交事务都会执行fsync；
3. sync_binlog=N(N>1)的时候，表示每次提交事务都write，但累计N个事务后才fsync。

## redo log的写入机制
事务的执行过程中，生成的redo log是先写到redo log buffer的。
Mysql的redo log的存储状态如下图所示：
![[Pasted image 20231225160855.png]]
这三种状态分别是：
1. 存在redo log buffer中，物理上是在Mysql进程内存中，就是图中的红色部分；
2. 写到磁盘(write)，但是没有持久化(fsync)，屋里上是在文件系统的page cache里面的，也就是图中的黄色部分。
3. 持久化到磁盘，对应的是hard disk，也就是图中的绿色部分。
日志写到redo log buffer是很快的，write到pagecache也差不多，但是持久化到磁盘的速度就慢多了。

为了控制redo log的写入策略，InnoDB提供了innodb_flush_log_at_trx_commit参数，它有三种可能取值：
1. 设置为0的时候，表示每次事务提交时都只是把redo log留在redo log buffer中；
2. 设置为1的时候，表示每次事务提交都将redo log直接持久化到磁盘；
3. 设置为2的时候，表示每次事务提交时都只是吧redo log写入到page cache。
InnoDB有一个后台线程，每隔1秒，就会把redo log buffer中的日志，调用write写到文件系统的page cache中，然后调用fsync持久化到磁盘。
```ad-note
注意，事务执行中间过程的redo log也是直接写在redo log buffer中的，这些redo log 也会被后台线程一起持久化到磁盘。也就是说，一个没有提交的事务的redo log，也是可能已经持久化到磁盘的。
```
实际上，除了后台线程每秒一次的轮询操作外，还有两种场景会让一个没有提交的事务的redo log写入到磁盘中。
1. 一种是，redo log buffer占用的空间即将达到innodb_log_buffer_size 一半的时候，后台线程会主动写盘。注意，由于这个事务并没有提交，所以这个写盘操作只是write，而没有调用fsync，也就是只留在了文件系统的page cache。
2. 另一种是，并行的事务提交的时候，顺带将这个事务的redo log buffer持久化到磁盘。

这里需要说明的是，我们介绍两阶段提交的时候说过，时序上redo log先prepare，再写binlog，最后再把redo log commit。
如果innodb_flush_log_trx_commit设置为1，那么redo log 在prepare阶段就要持久化一次，因为有一个奔溃恢复逻辑是要依赖于prepare的redo log，再加上binlog来恢复的。

每秒一次后台轮询刷盘，再加上奔溃恢复这个逻辑，InnoDB就任务redo log在commit的时候就不需要fsync了，只会write到文件系统的page cache中就够了。

通常我们说Mysql的 "双 1"配置，指的是sync_binlog和innodb_flush_at_trx_commit都设置成1.也就是说，一个事务完整提交前，需要等待两次刷盘，一次是redo log (prepare 阶段), 一次是binlog。

这里，我需要先和你介绍日志逻辑序列号(log sequence number, LSN)的概念。LSN是单调递增的，用来对应redo log的一个个写入点。每次写入长度为length 的 redo log，LSN的值就会加上length。
![[Pasted image 20231225180131.png]]


实际上，写binlog是分成两步的：
1. 先把binlog 从binlog cache中写到磁盘上的binlog文件；
2. 调用fsync 持久化。
![[Pasted image 20231225180553.png]]
但是通常情况下第3步执行得会很快，所以binlog的write和fsync间的间隔时间短，导致能集合到一起持久化的binlog比较少，因此binlog 的组提交的效果通常不如redo log的效果那么好。
如果想提升binlog组提交的效果，可以通过设置binlog_group_commit_sync_delay和binlog_group_commit_sync_no_delay_count来实现。

1. binlog_group_commit_sync_delay参数，表示延迟多少微妙后才调用fsync;
2. binlog_group_commit_sync_no_delay_count参数，表示累积多少次以后才调用fsync。
这两个条件是或的关系，也就是说只要有一个满足条件就会调用fsync。

所以，当binlog_group_commit_sync_delay设置为0的时候，binlog_group_commit_sync_no_delay_count也无效了。

## WAL机制主要得益于两个方面：
1. redo log 和 binlog 都是顺序写，磁盘的顺序写比随机写速度要快；
2. 组提交机制，可以大幅度降低磁盘的IOPS消耗。

## 问题：如果你的Mysql现在出现了性能瓶颈，而且瓶颈在IO上，可以通过哪些方法来提升性能呢？
针对这个问题，可以考虑以下三种方法：
1. 设置binlog_group_commit_sync_delay和binlog_group_commit_sync_no_delay_count参数，减少binlog的写盘次数。这个方法是基于 "额外的故意等待"来实现的，因此可能会增加语句的响应时间，但没有丢失数据的风险。
2. 将sync_binlog设置为大于1的值 (比较常见的是100~1000)。这样做的风险是，主机掉电时会丢失binlog 日志。
3. 将innodb_flush_log_at_trx_commit设置为2.这样做的风险是，主机点掉的时候会丢失数据。
不建议吧innodb_flush_log_at_trx_commit 设置为0. 因为把这个参数设置为0，表示redo log只保存在内存中，这样的话Mysql 本身异常重启也会丢数据，风险太大。而redo log写到文件系统的page cache的速度也是很快的，所以将这个参数设置为2跟设置为0其实性能差不多，但这样做Mysql异常重启时就不会丢失数据了，相比之下风险会更小。
