```ad-abstract
在mysql中，当内存数据页跟磁盘数据页内容不一致的时候，我们称这个内存为 "脏页"。内存数据写入到磁盘后，内存和磁盘的数据页的内容就一致了，称为 "干净页"。
```

## 刷脏页导致数据库系统压力增大，导致外部感知像数据库抖了一下的原因。
四种引发数据库flush (刷脏页)的场景。
1. InnoDB的redo log 写满了。这时候系统会停止所有更新操作，把checkpoint往前推进，redo log留出空间继续写。如下图所示:
![[Pasted image 20240121170536.png]]
2. 当需要新的内存页，而内存不够用的时候，就要淘汰一些数据页，空出内存给别的数据页使用。如果淘汰的是 "脏页", 就要先将脏页写到磁盘。
如果刷脏页一定会写盘，就保证了每个数据页有两种状态：
	- 一种是内存里存在，内存里就肯定是正确的结果，直接返回；
	- 另一种是内存里没有数据，就可以肯定数据文件上是正确的结果，读入内存后返回
这样的效率最高。
3. Mysql认为系统 "空闲" 的时候。当然，系统负载高的时候，也要见缝插针地找时间，只要有机会就刷一点 "脏页"。
4. Mysql正常关闭的情况。这时候，Mysql会把内存的脏页都flush到磁盘上，这样下次Mysql启动的时候，就可以直接从磁盘上读数据，启动速度会很快。

虽然刷脏页是常态，但是出现以下这两种情况，都是会明显影响性能的：
- 一个查询要淘汰的脏页个数太多，会导致查询的响应时间明显边长；
- redo log写满，更新全部堵住，写性能跌为0，这种情况对敏感业务来说，是不能接受的。

## InnoDB 刷脏页的控制策略
首先，要正确地告诉InnoDB所在主机的IO的能力，这样InnoDB才能知道需要全力刷脏页的时候，可以刷多快。
这就要用到innodb_io_capacity这个参数了，它会告诉InnoDB你的磁盘能力。这个值建议设置成磁盘的IOPS。磁盘的IOPS可以通过fio这个工具来测试，下面的语句是我用来测试磁盘随机读写的命令：
```shell
fio -filename=$filename -direct=1 -iodepth 1 -thread -rw=randrw -ioengine=psync -bs=16k -size=500M -numjobs=10 -runtime=10 -group_reporting -name=mytest
```
InnoDB会根据脏页比例，和redo log的写盘速度，单独算出两个数字。
参数innodb_max_dirty_pages_pct是脏页比例上限，默认值是75%。InnoDB会根据当前的脏页比例 (假设为M),算出一个范围在0到100之间的数字，计算这个数字的伪代码类似这样：
```shell
F1(M)
{
	if M>=innodb_max_dirty_pages_pct then
		return 100;
	return 100*M/innodb_max_dirty_pages_pct;
}
```

InnoDB每次写入的日志都有一个序号，当前写入的序号跟checkpoint对应的序号之间的差值，我们假设为N。InnoDB会根据这个N算出一个范围在 0到100之间的数字，这个计算公式可以记为 F2(N)。
**根据上述算得的F1(M)和F2(N)两个值，取其中较大的值记为R，之后引擎就可以按照innodb_io_capacity定义的能力乘以 R%来控制刷脏页的速度。**
![[Pasted image 20240121174519.png]]
InnoDB会在后台刷脏页，而刷脏页的过程是要将内存页写入磁盘。所以，无论是你的查询语句在需要内存的时候可能要求淘汰一个脏页，还是由于刷脏页的逻辑会占用IO资源并可能影响到你的更新语句，都可能造成你从业务端感知到Mysql "抖"了一下的原因。
要尽量避免这种情况，你就要合理地设置innodb_io_capacity的值，并且平时要多关注脏页比例，不要让它经常接近 75%。
其中，脏页比例是通过 Innodb_buffer_pool_pages_dirty/Innodb_buffer_pool_pages_total得到的，具体的命令参考下面的代码：
```sql
select VARIABLE_VALUE into @a from performance_schema.global_status where VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty';
select VARIABLE_VALUE into @b from performance_schema.global_status where VARIABLE_NAME = 'Innodb_buffer_pool_pages_total';
select @a/@b;
```

在InnoDB中，innodb_flush_neighbors参数是用来控制当前要刷的脏页的旁边的脏页是否跟着一起flush掉，值为1的时候会将相邻的脏页一起flush，值为0时表示不找邻居，自己刷自己的。
这个参数在机械硬盘时代IOPS比较低下的时候设置为1可以大大提升系统性能，但是使用的SSD这类IOPS比较高的设备的话，建议设置为0，可以减少sql语句的响应时间，因为这种情况下IOPS往往不是瓶颈。
在Mysql8.0中，innodb_flush_neighbors参数默认值已经是0了。

## `count(*)` 的实现方式
在不同引擎中，`count(*)`有不同的实现方式。
- MyISAM引擎把一个表的中行数存在了磁盘上，因此执行 `count(*)`的时候会直接返回这个数，效率很高；
- 而InnoDB引擎执行`count(*)`的时候，需要把数据一行一行地从引擎里面读出来，然后累积累计数。
这里需要注意的是，我们在这篇文章里讨论的是没有过滤条件的`count(*)`,如果加了where条件的话，MyISAM表也是不能返回得这么快的。
InnoDB不跟MyISAM一样的原因是，InnDB需要实现MVCC，所以同一时刻的多个查询，InnoDb 表 "应该返回多少行" 也是不确定的。

其实在执行`count(*)`操作的时候还是做了优化的，普通索引树比主键索引树小很多。对于`count(*)`这样的操作，遍历哪个索引树得到的结果逻辑上都是一样的。因此，Mysql优化器会找到最小的那颗数来遍历。**在保证逻辑正确的前提下，尽量减少扫描的数量，是数据库系统设计的通用法则之一。**
### 如果现在有一个页面经常要显示交易系统的操作记录总数，到底该怎么办呢？答案是，我们只能自己计数。
`所以结论是：按照效率排序的话，count(字段)<count(主键 id)<count(1)≈count(*)，所以我建议你，尽量使用 count(*)。`

## 全字段排序
全字段排序过程如下如所示：
![[Pasted image 20240124140615.png]]
图中 "按name排序" 这个动作，可能在内存中完成，也可能需要使用外部排序，这取决于排序所需的内存和参数sort_buffer_size。
sort_buffer_size,就是Mysql为排序开辟的内存 (sort_buffer) 的大小。如果排序的数据量小于 sort_buffer_size，排序就在内存中完成。但如果排序数据量太大，内存放不下，则不得不利用磁盘临时文件辅助排序。

可以用下面介绍的方法，来确定一个排序语句是否使用了临时文件。
```sql
/* 打开optimizer_trace，只对本线程有效 */
SET optimizer_trace='enabled=on'; 

/* @a保存Innodb_rows_read的初始值 */
select VARIABLE_VALUE into @a from  performance_schema.session_status where variable_name = 'Innodb_rows_read';

/* 执行语句 */
select city, name,age from t where city='杭州' order by name limit 1000; 

/* 查看 OPTIMIZER_TRACE 输出 */
SELECT * FROM `information_schema`.`OPTIMIZER_TRACE`\G

/* @b保存Innodb_rows_read的当前值 */
select VARIABLE_VALUE into @b from performance_schema.session_status where variable_name = 'Innodb_rows_read';

/* 计算Innodb_rows_read差值 */
select @b-@a;
```
这个方法是通过查看 OPTMIZER_TRACE 的结果来确认的，你可以从 number_of_tmp_files中看到是否使用了临时文件。
![[Pasted image 20240124141055.png]]
numbers_of_tmp_files 表示的是，排序过程中使用的临时文件数。你一定奇怪，为什么需要12个文件？内存放不下时，就需要使用外部排序，外部排序一般使用归并排序算法。可以这么简单理解，**Mysql 将需要排序的数据分成12份，每一份单独排序后存放在这些临时文件中。然后把这12个有序文件再合并成一个有序的大文件。**

## rowid 排序
如果Mysql认为排序的单行长度太大会怎么做呢？
```sql
SET max_length_for_sort_data = 16;
```
max_length_for_sort_data，是Mysql中专门控制用于排序的行数据的长度的一个参数。它的意思是，如果单行数据的长度超过这个值，Mysql就认为单行太大，要换一个算法。
我们把这种排序称为rowid排序：
![[Pasted image 20240124142053.png]]

## 全字段排序 VS rowid 排序
从上述两种排序可以得出一个结论：】
如果Mysql实在是担心排序内存太小，会影响排序效率，才会采用rowid排序算法，这样排序过程中一次可以排序更多行，但是需要再回到原表取数据。
如果Mysql认为内存足够大，会优先选择全字段排序，把需要的字段都放到sort_buffer中，这样排序后就会直接从内存里面返回查询结果了，不用再回到原表去取数据。

从上面分析的执行过程，我们可以看到，Mysql之所以需要生成临时表，并且在临时表上做排序操作，其原因是原来的数据都是无序的。
![[Pasted image 20240124142828.png]]
可以看到，这个查询过程不需要临时表，也不需要排序。接下来，我们用explain的结果来印证一下。
![[Pasted image 20240124142911.png]]
如果使用覆盖索引：
![[Pasted image 20240124143252.png]]
![[Pasted image 20240124143257.png]]
可以看到，Extra字段里面多了 "Using index",表示就是使用了覆盖索引，性能会快很多。
当然，这里并不是说为了每个查询能用上覆盖索引，就要把语句中涉及的字段都建立上联合索引，毕竟索引还是有维护代价的。这是一个需要权衡的决定。

## 内存临时表
**order by rand() 使用了内存临时表，内存临时表排序的时候使用了rowid排序方法。**
## 磁盘临时表
不是所有的临时表都是内存表，tmp_table_size 这个配置限制了内存临时表的大小，默认值是16M。如果临时表大小超过了tmp_table_size，那么内存临时表就会转成磁盘临时表。

Mysql5.6 版本引入了一个新的排序算法，即：优先队列排序算法。
假设我们sql语句是 order by rand() limit 3, 就只需要取R值最小的3个rowid。但是，如果使用归并排序算法的话，虽然最终也能得到前3个值，但是这个算法结束后，已经将10000行数据都排序好了。
也就是说，后面的9997行也是有序的了。但，我们的查询并不需要这些数据是有序的。所以，想一下就明白了，这浪费了很多的计算量。
而优先队列算法，就可以精确地只得到三个最小值，执行流程如下：
1. 对于这10000个准备排序的 (R,rowid)，先取前三行，构造成一个堆；
2. 取下一个行 (R',rowid')，跟当前堆里面最大的R比较，如果 R'小于R，把这个(R,rowid)从堆中去掉，换成 (R', rowid');
3. 重复第2步，知道第10000个 (R',rowid')完成比较。
![[Pasted image 20240124155139.png]]
采用大顶堆来取前三个最小的值。


## 条件字段函数操作
**对索引字段做函数操作，可能会破坏索引值的有序性，因此优化器就决定放弃走数搜索功能。**
需要注意的是，优化器并不是要放弃使用索引。
```sql
CREATE TABLE `tradelog` (
  `id` int(11) NOT NULL,
  `tradeid` varchar(32) DEFAULT NULL,
  `operator` int(11) DEFAULT NULL,
  `t_modified` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tradeid` (`tradeid`),
  KEY `t_modified` (`t_modified`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

```sql
select count(*) from tradelog where month(t_modified)=7;
```
放弃了树搜索功能，有乎其可以选择遍历索引，也可以选择遍历索引 t_modified, 优化器对比索引后发现，索引t_modified更新，遍历这个索引比遍历主键索引来得更快。因此最终还是会选择索引 t_modified。
即使是对于不改变有序性的函数，也不会考虑使用索引。比如，对于 `select * from tradelog where id + 1 = 10000` 这个SQL语句，这个加1操作并不会改变有序性，但是Mysql优化器还是不能用id 索引快速定位。

## 隐式类型转换
在Mysql中，字符串和数字做比较的话，是将字符串换成数字。

## 隐式字符编码转换
字符集不同只是条件之一，**连接过程中要求在被驱动表的索引字段上加函数操作，** 是直接导致对被驱动表做全表扫描的原因。

## 只查一行但是，但是卡住的原因

## 等MDL锁
如下图所示，就是使用 show processlist 命令查看 Waiting for table metadata lock的示意图。
![[Pasted image 20240125142439.png]]
出现这个状态表示的是，现在有一个线程正在表t上请求或者持有MDL写锁，把select 语句堵住了。
由于Mysql5.7版本修改了MDL的加锁策略，所以就不能复现这个场景了。
不过在Mysql 5.7版本下复现这个场景，也很容易。如下图所示，我给出了简单的复现步骤。
![[Pasted image 20240125151221.png]]
session A通过lock tables(注意这里命令是lock tables，图片上少了s) 命令持有表t的MDL写锁，而session B 的查询需要获取 MDL 读锁。所以，session B 进入等待状态。
处理这类问题的处理方式，就是找到谁持有MDL写锁，然后把它kill 掉。
但是，由于在show processlist的结果里面，session A的Command列是 "Sleep",导致查找起来很不方便。不过有了performance_schema 和 sys系统库以后，就方便多了。(Mysql启动时需要设置performance_schema=on,相比于设置为 off 会有 10%左右的性能损失)
```sql
select blocking_pid from sys.schema_table_lock_waits;
```
把这个连接用kill命令断开即可。

## 等 flush
![[Pasted image 20240125152413.png]]
Mysql里面对表做flush操作的用法，一般有以下两个：
```sql
flush tables t with read lock;
flush tables with read lock;
```
这两个flush语句，如果指定表t的话，代表的是只关闭表 t；如果没有指定具体的表明，则表示关闭Mysql里所有打开的表。但是正常这两个语句执行起来都很快，除非它们也被别的线程堵住了。
以下是 Waiting for table flush 的复现步骤：
![[Pasted image 20240125152732.png]]
在 session A中，我故意每行都调用一次 sleep(1), 这样这个语句默认要执行10万秒，在这期间表t 一直是被 session A "打开"着。然后，session B的flush tables t命令再要去关闭表t，就需要等session A的查询结束。这样，session C要再次查询的话，就会被flush命令堵住了。
![[Pasted image 20240125165307.png]]
这种情况，通过kill query 4, 将sleep的查询kill掉就行。

## 等行锁
![[Pasted image 20240125173637.png]]
可以通过以下sql查询是谁占着写锁。
```sql
mysql> select * from t sys.innodb_lock_waits where locked_table='`test`.`t`'\G
```
![[Pasted image 20240125173729.png]]
可以看到，这个信息很全，4号线程是造成阻塞的罪魁祸首。而干掉这个罪魁祸首的方式，就是KILL QUERY 4 或 4.
不过，这里不应该显示 "KILL QUERY 4"。这个命令表示停止4号线程当前正在执行的语句，而这个方法其实是没有用的。因为占有行锁的是update语句，这个语句已经是之前执行完成了的，现在执行KILL QUERY，无法让这个事务去掉 id = 1上的行锁。

实际上，KILL 4才有效，也就是说直接断开这个连接。这里隐含的一个逻辑就是，连接被断开的时候，会自动回滚这个连接里面正在执行的线程，也就释放了id=1上的行锁。

## 第二类：查询慢
![[Pasted image 20240125175515.png]]
![[Pasted image 20240125175448.png]]
session A 先用 start transaction with  consistent snapshot 命令启动了一个事务，之后session B才开始执行update语句。
session B 执行完100万次update语句后，id = 1 这一行处于什么状态呢？你可以从下图中找到答案。
![[Pasted image 20240125175819.png]]
session B 更新完 100万次，生成了100万个回滚日志 (undo log)。

带lock in share mode的SQL语句，是当前读，因此会直接读到 1000001这个结果，所以速度很快；而`select * from t where id = 1` 这个语句，是快照读，因此需要从 1000001开始，一次执行uodo log，执行100万次以后，才将1这个结果返回。
注意，undo log 里记录的其实是 "把2改成1", "把3改成2"这样的操作逻辑，画成减1的目的是方便看图。

## Mysql 有哪些 "饮鸩止渴" 提高性能的方法？

**第一种方法：处理掉那些占着连接但是不工作的线程。**
**第二种方法：减少连接过程的消耗。**
