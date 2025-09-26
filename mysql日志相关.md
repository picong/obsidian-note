下图为一次两阶段提交的图：
![[Pasted image 20240123105933.png]]
奔溃恢复是的判断规则：
1. 如果redo log 里面的事务是完整的，也就是已经有了commit标识，则直接提交；
2. 如果redo log 里面的事务只有完整的prepare，则判断对应的事务 binlog 是否存在并完整：
	1. 如果是，则提交事务；
	2. 否则，回滚事务。
这里，时刻B发生crash对应的就是2(1)的情况，奔溃恢复过程中事务会被提交。
## Mysql怎么知道binlog是完整的？
binlog是有完整格式的：
- statement 格式 的binlog，最后会有COMMIT；
- row格式的binlog，最后会有一个XID event。
另外，在Mysql5.6.2版本以后，还引入了binlog-checksum参数，用来验证binlog内容的正确性。

## 为什么需要两阶段提交？
其实，两阶段提交是经典的分布式系统问题，并不是Mysql独有的。
如果必须要举一个场景，来说明这么做的必要性的话，那就是事务的持久性问题。
对于InnoDB引擎来说，如果redo log 提交完成了，事务就不能回滚 (如果这允许回滚，就可能覆盖掉别的事务的更新)。而如果 redo log 直接提交，然后 binlog 写入的时候失败，InnoDB又回滚不了，数据和binlog日志又不一致了。
两阶段提交就是为了给所有人一个机会，当每个人都说 "我 ok"的时候，再一起提交。

## 正常运行中的实例，数据写入后的最终罗盘，是从redo log更新过来的还是 buffer pool 更新过来的呢？
实际上，redo log 并没有记录数据页的完整数据，所以它并没有能力自己去更新磁盘数据页，也就不存在 "数据落盘，是由redo log 更新过去" 的情况。
1. 如果是正常运行的实例的话，数据页被修改以后，跟磁盘的数据页不一致，称为脏页。最终数据落盘，就是把内存中的数据页写盘。这个过程，甚至与redo log毫无关系。
2. 在奔溃恢复场景中，InnoDB如果判断到一个数据页可能在奔溃恢复的时候丢失了更新，就会将它读到内存，然后让 redo log 更新内存内容。更新完成后，内存页变成脏页，就回到了第一种情况的状态。

## 业务需求问题
>业务上有这样的需求，A、B两个用户，如果互相关注，则称为好友。设计上是两张表，一个是like表，一个是friend表，like表有 user_id、liker_id两个字段。语句执行逻辑是这样的：
>以A关注B为例：
>第一步，先查询对方有没有关注自己 (B 有没有 关注A)
>`select * from like where user_id = B and liker_id = A;`
>如果有，则成为好友
>insert into friend;
>没有，则只是单向关注关系
>insert into like;
>但是如果 A、B同时关注对方，会出现不会成为好友的情况。因为上面第1步，双方都没关注对方。第1步即使使用了排它锁也不行，因为记录不存在，行锁无法生效。
>这种情况，在Mysql锁层面有没有办法处理？

```sql
CREATE TABLE `like` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `liker_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id_liker_id` (`user_id`,`liker_id`)
) ENGINE=InnoDB;

CREATE TABLE `friend` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `friend_1_id` int(11) NOT NULL,
  `friend_2_id` int(11) NOT NULL,
  UNIQUE KEY `uk_friend` (`friend_1_id`,`friend_2_id`),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
```
![[Pasted image 20240124101329.png]]并发"喜欢"逻辑操作顺序

以上操作顺序，会导致业务层面的的bug，因为记录不存在，行锁无法生效。解决办法如下：

首先，要给 "like" 表增加一个字段，比如叫作 relation_ship，并设为整型，取值 1 、2 、3。
>值是1的时候，表示user_id关注liker_id;
>值是2的时候，表示liker_id关注user_id;
>值是3的时候，表示互相关注。

然后，当A关注B的时候，逻辑改成如下所示的样子：
应用代码里面，比较A 和 B 的大小，如果 A < B，就执行下面的逻辑
```sql
begin; /*启动事务*/
insert into `like` (user_id, liker_id, relation_ship) values(A, B, 1) on duplicate key update relatin_ship=relation_ship | 1;
select relation_ship from `like` user_id=A and liker_id=B;
/* 代码中判断返回的relation_ship
	如果是1，事务结束，执行commit
	如果是3，则执行下面这两个语句;
*/
insert ignore into friend (friend_1_id, friend_2_id) values (A, B);
commit;
```
如果A>B，则执行下面的逻辑：
```sql
begin; /*启动事务*/
insert into `like` (user_id, liker_id, relation_ship) values (B, A, 2) on duplicate key update relation_ship=relation_ship | 2;
/*代码中判断返回的 relation_ship
	如果是2，事务结束，执行commit
	如果是3，则执行下面这两个语句：
*/
insert ignore into friend (friend_1_id, friend_2_id) values (B,A);
commit;
```

## "order by" 的工作原理
explain语句返回结果中Extra字段中的 "Using filesort" 表示的就是需要排序，Mysql会给每个线程分配一块内存用于排序，称为 sort_buffer。
如下所示，是全字段排序的流程：
![[Pasted image 20240124104327.png]]
图中 "按 name排序"这个动作，可能在内存中完成，也可能需要使用外部排序，这取决于排序所需的内存和参数sort_buffer_size。

可以用下面介绍的方法，来确定一个排序语句是否使用了临时文件。
```sql
/* 打开optimizer_trace,只对本县城有效 */
SET optimizer_trace='enabled=on';
/* @a保存Innodb_rows_read的初始值 */
select VARIABLE_VALUE into @a from performance_schema.session_status where variable_name = 'Innodb_rows_read';

/*执行语句*/
select city, name, age from t where city='杭州' order by name limit 1000;

/* 查看OPTIMIZER_TRACE 输出*/
select * from `information_schema`.`optimizer_trace` \G;

/* @b保存Innodb_rows_read 的当前值 */
select VARIABLE_VALUE into @b from performance_schema.session_status where variable_name = 'Innodb_rows_read';

/*计算Innodb_rows_read差值*/
select @b-@a;
```
这个方法是通过查看OPTIMIZER_TRACE的结果来确认的，你可以从 number_of_tmp_files中看到是否使用了临时文件。
![[Pasted image 20240124105353.png]]全排序的OPTIMIZER_TRANCE部分结果