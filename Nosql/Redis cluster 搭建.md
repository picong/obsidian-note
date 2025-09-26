## Step1：创建redis.conf文件，文件内容如下：
```shell
# redis.conf file
port 7000
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes
```
## Step2：创建6个目录，我们要搭建3主3从的集群
```shell
mkdir -p {7000..7005}
```
## Step3：将最小的配置文件复制到上面创建的目录中，并修改对应端口号
```shell
for i in {7000..7005}; do cp redis.conf $i; done
```
## Step4：分别进入上面创建的目录中(一定要进入目录，否则会报错)，启动redis-server
```shell
# Terminal tab 1
cd 7000
/path/to/redis-server ./redis.conf
# Terminal tab 2
cd 7001
/path/to/redis-server ./redis.conf
... and so on.
```
## Step5：构建集群，一主一从的分布
```shell
# --cluster-replicas 1表示从节点个数为1个，0表示没有从节点
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 \
127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
--cluster-replicas 1
```
## Step6~Step7：拷贝配置文件修改端口号，启动两个新的redis实例
```shell
$ mkdir 7006 7007
$ cp 7000/redis.conf 7006/redis.conf
$ cp 7000/redis.conf 7007/redis.conf

# Terminal tab 7
$ cd 7006
$ redis-server ./redis.conf
# Terminal tab 8
$ cd 7007
$ redis-server ./redis.conf
```
## Step8：添加新的集群切片
```shell
redis-cli --cluster add-node 127.0.0.1:7006 127.0.0.1:7000
```
默认加入就是主节点。
## Step9：为新加入的切面主节点添加从节点
```shell
# 通过该命令打印切片信息，获取id
redis-cli -p 7000 cluster nodes
> 46a768cfeadb9d2aee91ddd882433a1798f53271 127.0.0.1:7006@17006 master - 0 1616754504000 0 connected
...

# cluster-slave标签表明新加入的节点作为--cluster-master-id对应的id对应的分片的从节点
redis-cli -p 7000 --cluster add-node 127.0.0.1:7007 127.0.0.1:7000 --cluster-slave --cluster-master-id 46a768cfeadb9d2aee91ddd882433a1798f53271
```
## Step10：新加入的分片此时还没有分配slot，可以通过--cluster reshard来手动分配
```shell
redis-cli -p 7000 --cluster reshard 127.0.0.1:7000
# 命令执行时会询问几个问题，需要根据实际情况填写
How many slots do you want to move (from 1 to 16384)? (需要移动多少slots)
What is the receiving node ID? (目的master的id)
Please enter all the source node IDs.
  Type 'all' to use all the nodes as source nodes for the hash slots.
  Type 'done' once you entered all the source nodes IDs.
Source node #1: all
(这个选项填all表示从所有可用的集群中的主节点进行槽的迁移，也可以填主节点的id以done结尾)

# 查看迁移后的槽分配情况
redis-cli -p 7000 cluster slots
```

## Step11: 通过redis-cli连接集群
```shell
redis-cli -p 7000 -c
```