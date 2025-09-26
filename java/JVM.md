自JDK7起，原本存放在永久代的字符串常量池被移至Java堆之中。

## 记忆集与卡表
记忆集是一种用于记录从非收集区域指向收集区域的指针集合的抽象数据结构。
卡表是记忆集的一种具体实现，它定义了记忆集的记录精度、与堆内存的映射关系等。
HotSpot虚拟机的卡表是一个字节数组，以下代码是HotSpot默认的卡表标记逻辑：
```c
CARD_TABLE [this address >> 9] = 0;
```
字节数组CARD_TABLE的每一个元素都对应着其表示的内存区域中一块特定大小的内存块，这个内存块被称作 "卡页" (Card Page)。一来说，卡页大小都是以2的N次幂的字节数，通过上面的代码可以看出来HotSpot中使用的卡也是2的9次幂，即512字节。那如果卡表表示内存区域的其实地址是0x0000的话，数据CARD_TABLE的第0、1、2号元素如下图所示：
![[Pasted image 20250422170545.png]]
一个卡页的内存中通常包含不止一个对象，只要卡页内有一个(或更多)对象的字段存在着跨代指针，那就将对应卡表的数组元素的值标识为1，称为这个元素变脏(Dirty)，没有则表示为0。在垃圾收集发生时，只要筛选出卡表中变脏的元素，就能轻易得出哪些卡页内存块中包含跨代指针，把它们加入GC Roots中一并扫描。

## 并发标记

## 三色标记(Tri-color Marking)-- 并发标记的辅助推导工具
- **白色**：表示对象尚未被垃圾收集器访问过。显然在可达性分析刚刚开始的阶段，所有的对象都是白色的，若在分析结束的阶段，仍然是白色的对象，即代表不可达。
- **黑色**：表示对象已经被垃圾收集器访问过，且这个对象的所有引用都已经扫描过。黑色的对象代表已经扫描过，它是安全存活的，如果有其他对象引用指向了黑色对象，无须重新扫描一遍。黑色对象不可能直接(不经过灰色对象)指向某个白色对象。
- **灰色**：表示对象已经被垃圾收集器访问过，但这个对象上至少存在一个引用还没有被扫描过。

收集器在对象图上标记颜色，同时用户线程在修改引用关系，这样可能出现两种后果。
- 一种是把原本消亡的独享标记为存活，这种情况会产生一些逃过本次收集的浮动垃圾，下次收集清理掉就好。
- 另一种是把原本存活的对象错误标记为已消亡，这种情况会导致程序发生错误。
下表演示了存活对象被错误标记为已消亡问题的产生：
![[Pasted image 20250423112503.png]]
Wilson于1994年在理论上证明了，当且仅当以下两个条件同时满足时，会产生“对象消失”的问题，即原本应该是黑色的对象被误标为白色：
- 赋值器插入了一条或多条从黑色对象到白色对象的新引用；
- 赋值器删除了全部从灰色对象到该白色对象的直接或间接引用。

因此，我们要解决并发扫描时的对象消失问题，只需破坏这两个条件的任意一个即可。由此分别产生了两种解决方案：增量更新（Incremental Update）和原始快照（Snapshot At The Beginning，SATB）​。

**增量更新**要破坏的是第一个条件，当黑色对象插入新的指向白色对象的引用关系时，就将这个新插入的引用记录下来，等并发扫描结束之后，再将这些记录过的引用关系中的黑色对象为根，重新扫描一次。

**原始快照**要破坏的是第二个条件，当灰色对象要删除指向白色对象的引用关系时，就将这个要删除的引用记录下来，在并发扫描结束之后，再将这些记录过的引用关系中的灰色对象为根，重新扫描一次。这也可以简化理解为，无论引用关系删除与否，都会按照刚刚开始扫描那一刻的对象图快照来进行搜索。

以上无论是对引用关系记录的插入还是删除，虚拟机的记录操作都是通过写屏障实现的。在HotSpot虚拟机中，增量更新和原始快照这两种解决方案都有实际应用，譬如，CMS是基于增量更新来做并发标记的，G1、Shenandoah则是用原始快照来实现。

## 经典收集器
下图是各款经典收集器之间的关系：
![[Pasted image 20250423113424.png]]
## Serial收集器
Serial/Serial Old 收集器的运行过程：
![[Pasted image 20250423114326.png]]
它依然是HotSpot虚拟机运行在客户端模式下的默认新生代收集器，它简单而高效(与其他收集器的单线程相比)，对于内存资源受限的环境，它是所有收集器里额外内存消耗(Memory Footprint)最小的；对于单核处理或处理器核心数较少的环境来说，Serial收集器由于没有现成交互的开销，专心做垃圾收集自然可以获得最高的单线程收集效率。
## ParNew收集器
ParNew收集器实质上是Serial收集器的多线程并行版本，除了同时使用多条线程进行垃圾收集之外，其余的行为包括Serial收集器可以用的所有控制采纳数(例如：-XX：SurvivorRatio、-XX：PretenureSizeThreshold、-XX：HandlePromotionFailure等)、收集算法、Stop The World、对象分配规则、回收策略等都与Serial收集器完全一致。

ParNew/Serial Old收集器的运行示意图如下：
![[Pasted image 20250423115113.png]]
JDK 7之前的遗留系统中首选的新生代收集器，其中有一个与功能、性能无关但其实很重要的原因是：除了Serial收集器外，目前只有它能与CMS收集器配合工作。
ParNew收集器是激活CMS后（使用-XX：+UseConcMarkSweepGC选项）的默认新生代收集器，也可以使用-XX：+/-UseParNewGC选项来强制指定或者禁用它。可以使用-XX：ParallelGCThreads参数来限制垃圾收集的线程数。

在谈论垃圾收集器的上下语境中，"并发"和"并行"可以理解为：
- 并行（Parallel）​：并行描述的是多条垃圾收集器线程之间的关系，说明同一时间有多条这样的线程在协同工作，通常默认此时用户线程是处于等待状态。
- 并发（Concurrent）​：并发描述的是垃圾收集器线程与用户线程之间的关系，说明同一时间垃圾收集器线程与用户线程都在运行。由于用户线程并未被冻结，所以程序仍然能响应服务请求，但由于垃圾收集器线程占用了一部分系统资源，此时应用程序的处理的吞吐量将受到一定影响。
## Parallel Scavenge收集器
Parallel Scavenge收集器也是一款新生代收集器，它同样是基于标记-复制算法实现的垃圾收集器，也是能够并行收集的多线程收集器。它的关注点是达到一个可控制的吞吐量(Throughput)。吞吐量公式如下：
**吞吐量 = 运行用户代码时间 / (运行用户代码时间 + 垃圾收集时间)**

**关键参数设置** 
通过 JVM 参数可动态调整垃圾收集行为，核心参数包括：
1. -XX:GCTimeRatio=N​​
设置吞吐量目标，公式为 1/(1+N)。例如，-XX:GCTimeRatio=19 表示将 5% 的时间用于垃圾回收（默认值为 99，即 1% 的垃圾收集时间）。
2. ​​-XX:MaxGCPauseMillis=N​​
指定最大垃圾回收暂停时间（单位：毫秒）。值越小，暂停时间越短，但可能降低吞吐量。例如，-XX:MaxGCPauseMillis=200 适用于对延迟敏感的场景。
3. ​​-XX:+UseAdaptiveSizePolicy​​
开启自适应调节策略（GC Ergonomics），让 JVM 根据运行时数据动态调整堆大小和垃圾回收参数，平衡吞吐量与暂停时间。
这是一个开关参数，当这个参数被激活之后，就不需要人工指定新生代的大小（-Xmn）​、Eden与Survivor区的比例（-XX：SurvivorRatio）​、晋升老年代对象大小（-XX：PretenureSizeThreshold）等细节参数了，虚拟机会根据当前系统的运行情况收集性能监控信息，动态调整这些参数以提供最合适的停顿时间或者最大的吞吐量。
## Serial Old收集器
Serial Old是Serial收集器的老年代版本，它同样是一个单线程收集器，使用标记-整理算法。这个收集器的主要意义也是供客户端模式下的HotSpot虚拟机使用。如果在服务端模式下，它也可能有两种用途：一种是在JDK 5以及之前的版本中与Parallel Scavenge收集器搭配使用 ，另外一种就是作为CMS收集器发生失败时的后备预案，在并发收集发生Concurrent Mode Failure时使用。下图是Serial/Serial Old收集器的运行示意图：
![[Pasted image 20250423151519.png]]
## Parallel Old收集器
Parallel Old是Parallel Scavenge收集器的老年代版本，支持多线程并发收集，基于标记-整理算法实现。这个收集器是直到JDK6时才开始提供的。
在注重吞吐量或者处理器资源较为稀缺的场合，都可以优先考虑Parallel Scavenge+Parallel Old收集器这个组合，这个组合的工作过程如下图所示：
![[Pasted image 20250423152234.png]]
## CMS收集器
CMS（Concurrent Mark Sweep）收集器是一种以获取最短回收停顿时间为目标的收集器。CMS收集器是基于标记-清除算法实现的，它的运作过程分为四个步骤：
1. 初始标记(CMS initial mark) -- 标记一下GC Roots能直接关联到的对象，速度很快，但是需要STOP THE WORLD
2. 并发标记(CMS concurrent mark) -- 从GC Roots的直接关联对象开始遍历整个对象图，耗时长，但是不需要停顿用户线程
3. 重新标记(CMS remark) -- 增量更新（上面讲过增量更新的过程），需要STOP THE WORLD
4. 并发清除(CMS concurrent sweep) -- 清理掉标记阶段判断的已经死亡的对象，由于不需要移动存活对象，所以这个阶段也是可以与用户线程同时并发的。
由于在整个过程中耗时最长的并发标记和并发清除阶段中，垃圾收集器线程都可以与用户线程一起工作，所以从总体上来说，CMS收集器的内存回收过程是与用户线程一起并发执行的。下图是CMS收集器的运作过程：
![[Pasted image 20250423155518.png]]
### **CMS 收集器的缺点​**​

1. ​**​对 CPU 资源敏感​**​  
    并发阶段会占用部分 CPU 资源（如 4 核 CPU 时占用 25%），可能导致应用程序吞吐量下降。核心数较少时（如 2 核），资源竞争更明显。
2. ​**​内存碎片问题​**​  
    采用​**​标记 - 清除算法​**​导致大量内存碎片。虽然通过`Free-list`管理小块空闲内存，但无法分配大对象时仍需触发 Full GC，而 Full GC 采用串行收集器，停顿时间较长。
    CMS收集器提供了一个-XX：+UseCMS-CompactAtFullCollection开关参数（默认是开启的，此参数从JDK 9开始废弃）​，用于在CMS收集器不得不进行Full GC时开启内存碎片的合并整理过程，由于这个内存整理必须移动存活对象，​（在Shenandoah和ZGC出现前）是无法并发的。
    虚拟机设计者们还提供了另外一个参数-XX：CMSFullGCsBeforeCompaction（此参数从JDK 9开始废弃）​，这个参数的作用是要求CMS收集器在执行过若干次（数量由参数值决定）不整理空间的Full GC之后，下一次进入Full GC前会先进行碎片整理（默认值为0，表示每次进入Full GC时都进行碎片整理）​。
3. ​**​无法处理浮动垃圾​**​  
    并发标记阶段结束后，用户线程可能生成新垃圾（即“浮动垃圾”），需等待下一次 GC 处理，可能导致停顿时间波动。
    
    由于在垃圾收集阶段用户线程还需要持续运行，那就还需要预留足够内存空间提供给用户线程使用，因此CMS收集器不能像其他收集器那样等待到老年代几乎完全被填满了再进行收集，必须预留一部分空间供并发收集时的程序运作使用。
    可以通过调整-XX：CMSInitiatingOccupancyFraction的值来设置CMS的触发百分比。用户应在生产环境中根据实际应用情况来权衡设置。设置的太小会导致频繁触发CMS垃圾收集，如果设置得太大，会导致大量并发失败，而不得不启用后备预案：临时启用Serial Old收集器来重新进行老年代的垃圾收集，这样用户线程的停顿时间会变长。
4. ​**​仅支持老年代回收​**​  
    需配合其他收集器（如 ParNew）处理新生代，无法独立完成全堆回收。
5. ​**​复杂性与开发难度​**​  
    并发执行需解决一致性问题（如写屏障技术），增加了实现和维护的复杂度。

## Garbage First（G1）收集器
JDK9发布之日，G1宣告取代Parallel Scavenge+Parallel Old组合，成为服务端模式下的默认垃圾收集器，而CMS则沦落至被声明为不推荐使用的收集器。

G1可以面向堆内存任何部分来组成回收集(Collection Set，CSet)进行回收，衡量标准不再是它属于哪个分代，而是哪块内存中存放的垃圾数量最多，回收收益最大，这就是G1收集器的Mixed GC模式。

G1不再坚持固定大小以及固定数量的分代区域划分，而是把连续的Java堆划分为多个大小相等的独立区域（Region）​，每一个Region都可以根据需要，扮演新生代的Eden空间、Survivor空间，或者老年代空间。收集器能够对扮演不同角色的Region采用不同的策略去处理，这样无论是新创建的对象还是已经存活了一段时间、熬过多次收集的旧对象都能获取很好的收集效果。

Region中还有一类特殊的Humongous区域，专门用来存储大对象。G1认为只要大小超过了一个Region容量一半的对象即可判定为大对象。每个Region的大小可以通过参数-XX：G1HeapRegionSize设定，取值范围为1MB～32MB，且应为2的N次幂。而对于那些超过了整个Region容量的超级大对象，将会被存放在N个连续的Humongous Region之中，G1的大多数行为都把Humongous Region作为老年代的一部分来进行看待。

G1收集器之所以能建立可预测的停顿时间模型，是因为它将Region作为单次回收的最小单元，即每次收集到的内存空间都是Region大小的整数倍，这样可以有计划地避免在整个Java堆中进行全区域的垃圾收集。更具体的处理思路是让G1收集器去跟踪各个Region里面的垃圾堆积的“价值”大小，价值即回收所获得的空间大小以及回收所需时间的经验值，然后在后台维护一个优先级列表，每次根据用户设定允许的收集停顿时间（使用参数-XX：MaxGCPauseMillis指定，默认值是200毫秒）​，优先处理回收价值收益最大的那些Region。

下图为G1收集器Region分区示意图：
![[Pasted image 20250423175840.png]]

### G1收集器至少有(不限于) 以下这些关键问的细节问题需要妥善解决：
- 将Java堆分成多个独立Region后，Region里面存在的跨Region引用对象如何解决？ -- 使用记忆集避免堆作为GC Roots扫描，G1的每个Region都维护有自己的记忆集。
- 并发标记阶段如何保证收集线程与用户线程互不干扰的运行？ -- G1收集器通过原始快照(SATB) 算法来实现。G1为每一个Region设计了两个名为TAMS（Top at Mark Start）的指针，把Region中的一部分空间划分出来用于并发回收过程中的新对象分配，并发回收时新分配的对象地址都必须要在这两个指针位置以上。G1收集器默认在这个地址以上的对象是被隐式标记过的，即默认它们是存活的，不纳入回收范围。
- 这样建立起可靠的停顿预测模型？ -- G1收集器的停顿预测模型是以衰减均值（Decaying Average）为理论基础来实现的，在垃圾收集过程中，G1收集器会记录每个Region的回收耗时、每个Region记忆集里的脏卡数量等各个可测量的步骤花费的成本，并分析得出平均值、标准偏差、置信度等统计信息。

如果我们不去计算用户线程运行过程中的动作（如使用写屏障维护记忆集的操作）​，G1收集器的运作过程大致可划分为以下四个步骤：
- 初始标记(Initial Marking)：仅仅只是标记一下GC Roots能直接关联到的对象，并且修改TAMS执政的值，让下一个阶段用户线程并发运行时，能正确地在可用的Region中分配新对象。这个阶段需要停顿用户线程，但耗时很短，而且是借用Minor GC的时候同步完成的，所以G1收集器在这个阶段实际并没有额外的停顿。
- 并发标记 （Concurrent Marking）​：从GC Root开始对堆中对象进行可达性分析，递归扫描整个堆里的对象图，找出要回收的对象，这阶段耗时较长，但可与用户程序并发执行。当对象图扫描完成以后，还要重新处理SATB记录下的在并发时有引用变动的对象。
- 最终标记 （Final Marking）​：对用户线程做另一个短暂的暂停，用于处理并发阶段结束后仍遗留下来的最后那少量的SATB记录。
- 筛选回收 （Live Data Counting and Evacuation）​：负责更新Region的统计数据，对各个Region的回收价值和成本进行排序，根据用户所期望的停顿时间来制定回收计划，可以自由选择任意多个Region构成回收集，然后把决定回收的那一部分Region的存活对象复制到空的Region中，再清理掉整个旧Region的全部空间。这里的操作涉及存活对象的移动，是必须暂停用户线程，由多条收集器线程并行完成的
从上述阶段的描述可以看出，G1收集器除了并发标记外，其余阶段也是要完全暂停用户线程的，换言之，它并非纯粹地追求低延迟，官方给它设定的目标是在延迟可控的情况下获得尽可能高的吞吐量，所以才能担当起“全功能收集器”的重任与期望 。

下图是G1收集器的运作不走：
![[Pasted image 20250423181143.png]]
置不同的期望停顿时间，可使得G1在不同应用场景中取得关注吞吐量和关注延迟之间的最佳平衡。不过，这里设置的“期望值”必须是符合实际的，不能异想天开，毕竟G1是要冻结用户线程来复制对象的，这个停顿时间再怎么低也得有个限度。

### **G1和CMS比较**
| **特性​**​      | **​G1 收集器​**​     | **​CMS 收集器**          |
| ------------- | ----------------- | --------------------- |
| **停顿时间**​     | 可预测，支持设定最大停顿时间    | 无法完全避免长停顿（Full GC 频繁） |
| **​内存碎片**​    | 无（标记 - 整理算法）      | 易产生碎片（仅标记 - 清除）       |
| ​**​内存占用**    | 较高（额外 10%-20% 内存） | 较低                    |
| ​**适用场景​**    | 大内存、高吞吐量、低延迟需求    | 小内存、轻量级应用             |
| **​并发模式失效​**​ | 发生概率低（分区扫描）       | 发生概率高（需全堆扫描）          |
### **实际应用建议​**​
1. ​**​选择依据​**​
    - ​**​小内存应用​**​（＜6GB）：CMS 通常表现更优。
    - ​**​大内存应用​**​（≥8GB）：G1 更稳定，可减少碎片化导致的 Full GC。
    - ​**​动态调整需求​**​：G1 支持按收益动态选择回收区域，适应负载变化。
2. ​**​优化方向​**​
    - ​**​G1​**​：需关注内存占用和额外执行负载，可通过调整 Region 数量、TAMS 指针优化并发分配。
    - ​**​CMS​**​：需警惕并发模式失效，可通过增加后台线程或降低堆增长率缓解。

# 低延迟垃圾收集器
下图中浅色阶段表示必须挂起用户线程，深色表示收集器线程与用户线程是并发工作的：
![[Pasted image 20250423185648.png]]

## ZGC收集器
ZGC收集器是一款基于Region内存布局的，jdk21版本之前不设分代的，使用了读屏障、染色指针和内存多重映射等技术来实现可并发的标记整理算法的，以低延迟为首要目标的一款垃圾收集器。

在x64硬件平台下，ZGC的Region可以具有如下图所示的大、中、小三类容量：
- 小型Region（Small Region）​：容量固定为2MB，用于放置小于256KB的小对象。
- 中型Region（Medium Region）​：容量固定为32MB，用于放置大于等于256KB但小于4MB的对象。
- 大型Region（Large Region）​：容量不固定，可以动态变化，但必须为2MB的整数倍，用于放置4MB或以上的大对象。每个大型Region中只会存放一个大对象，这也预示着虽然名字叫作“大型Region”​，但它的实际容量完全有可能小于中型Region，最小容量可低至4MB。大型Region在ZGC的实现中是不会被重分配（重分配是ZGC的一种处理动作，用于复制对象的收集器阶段，稍后会介绍到）的，因为复制一个大对象的代价非常高昂。
![[Pasted image 20250424114615.png]]

ZGC收集器有一个标志性的设计是它采用的染色指针技术(Colored Pointer)，它直接把标记信息记在引用对象的指针上，这时，与其说可达性分析是遍历对象图来标记对象，还不如说是遍历"引用图"来标记"引用"了。
以64位linux为例，64位的指针的高18位不能用来寻址，但剩余的46位指针所能支持的64TB内存在今天仍然能够充分满足大型服务器的需求。因此，ZGC的染色指针将剩余的46位的高4位提取出来存储四个标志信息，当然这也直接导致ZGC能够管理的内存不可以超过4TB。如下图所示：
![[Pasted image 20250424182146.png]]
染色指针的三大优势：
- 染色指针可以是的一旦某个Region的存活对象被移走之后，这个Region立即能够被释放和重用。
- 染色指针可以大幅减少在垃圾收集过程中内存屏障的使用数量，设置写屏障的目的通常是为了记录对象引用的变动情况，如果将这些信息直接维护阿仔指针中，显然就可以省去一些专门的记录。
- 染色指针可以作为一种可扩展的存储结构用来记录更多与对象标记、重定位过程相关的数据，以便日后进一步提升性能。

Linux/x86-64平台上的ZGC使用了多重映射(Multi-Mapping)将多个不同的虚拟内存地址映射到同一个物理内存地址上，也就意味着ZGC虚拟内存中看到的地址空间要比实际的堆内存容量来得跟大。把染色指针中的标志位看做是地址的分段符，那只要将这些不同的地址段都映射到同一个物理内存空间，经过多重映射转换后，就可以使用染色指针正常进行寻址了，效果如下图所示：
![[Pasted image 20250424183311.png]]

### ZGC的运作过程如下所示：
![[Pasted image 20250424183519.png]]
- **并发标记** （Concurrent Mark）​：与G1、Shenandoah一样，并发标记是遍历对象图做可达性分析的阶段，前后也要经过类似于G1、Shenandoah的初始标记、最终标记（尽管ZGC中的名字不叫这些）的短暂停顿，与G1、Shenandoah不同的是，ZGC的标记是在指针上而不是在对象上进行的，标记阶段会更新染色指针中的Marked 0、Marked 1标志位。
- **并发预备重分配** （Concurrent Prepare for Relocate）​：这个阶段需要根据特定的查询条件统计得出本次收集过程要清理哪些Region，将这些Region组成重分配集（Relocation Set）​。GC每次回收都会扫描所有的Region，用范围更大的扫描成本换取省去G1中记忆集的维护成本。ZGC的重分配集只是决定了里面的存活对象会被重新复制到其他的Region中，里面的Region会被释放，而并不能说回收行为就只是针对这个集合里面的Region进行，因为标记过程是针对全堆的。此外，在JDK 12的ZGC中开始支持的类卸载以及弱引用的处理，也是在这个阶段中完成的。
- **并发重分配** （Concurrent Relocate）​：重分配是ZGC执行过程中的核心阶段，这个过程要把重分配集中的存活对象复制到新的Region上，并为重分配集中的每个Region维护一个转发表（Forward Table）​，记录从旧对象到新对象的转向关系。
	- 得益于染色指针的支持，ZGC收集器能仅从引用上就明确得知一个对象是否处于重分配集之中，如果用户线程此时并发访问了位于重分配集中的对象，这次访问将会被预置的内存屏障所截获，然后立即根据Region上的转发表记录将访问转发到新复制的对象上，并同时修正更新该引用的值，使其直接指向新对象，ZGC将这种行为称为指针的“自愈”​（Self-Healing）能力。
	- 还有另外一个直接的好处是由于染色指针的存在，一旦重分配集中某个Region的存活对象都复制完毕后，这个Region就可以立即释放用于新对象的分配（但是转发表还得留着不能释放掉）​，哪怕堆中还有很多指向这个对象的未更新指针也没有关系，这些旧指针一旦被使用，它们都是可以自愈的。
- **并发重映射** （Concurrent Remap）​：重映射所做的就是修正整个堆中指向重分配集中旧对象的所有引用，这一点从目标角度看是与Shenandoah并发引用更新阶段一样的，但是ZGC的并发重映射并不是一个必须要“迫切”去完成的任务，因为前面说过，即使是旧引用，它也是可以自愈的，最多只是第一次使用时多一次转发和修正操作。ZGC很巧妙地把并发重映射阶段要做的工作，合并到了下一次垃圾收集循环中的并发标记阶段里去完成，反正它们都是要遍历所有对象的，这样合并就节省了一次遍历对象图 [9] 的开销。一旦所有指针都被修正之后，原来记录新旧对象关系的转发表就可以释放掉了。
目前，在JDK17中ZGC已经支持商用，在JDK21开始ZGC提供了分代版本，可以通过参数进行设置。
ZGC还有一个常在技术资料上被提及的优点是支持“NUMA-Aware”的内存分配。NUMA（Non-Uniform Memory Access，非统一内存访问架构）是一种为多处理器或者多核处理器的计算机所设计的内存架构。
NUMA架构下，ZGC收集器会优先尝试在请求线程当前所处的处理器的本地内存上分配对象，以保证高效内存访问。在ZGC之前的收集器就只有针对吞吐量设计的Parallel Scavenge支持NUMA内存分配[13] ，如今ZGC也成为另外一个选择。
## Epsilon收集器
Epsilon收集器由RedHat公司在JEP 318中提出，在此提案里Epsilon被形容成一个无操作的收集器（A No-Op Garbage Collector）​，而事实上只要Java虚拟机能够工作，垃圾收集器便不可能是真正“无操作”的。堆的管理和对象的分配这部分功能是Java虚拟机能够正常运作的必要支持，是一个最小化功能的垃圾收集器也必须实现的内容。

RedHat提出了垃圾收集器的统一接口，即JEP 304提案，Epsilon是这个接口的有效性验证和参考实现，同时也用于需要剥离垃圾收集器影响的性能测试和压力测试。

为了应对新的技术潮流，最近几个版本的JDK逐渐加入了提前编译、面向应用的类数据共享等支持。Epsilon也是有着类似的目标，如果读者的应用只要运行数分钟甚至数秒，只要Java虚拟机能正确分配内存，在堆耗尽之前就会退出，那显然运行负载极小、没有任何回收行为的Epsilon便是很恰当的选择。
## 收集器的权衡
假设某个直接面向用户提供服务的B/S系统准备选择垃圾收集器，一般来说延迟时间是这类应用的主要关注点，那么：
- 如果你有充足的预算但没有太多调优经验，那么一套带商业技术支持的专有硬件或者软件解决方案是不错的选择，Azul公司以前主推的Vega系统和现在主推的Zing VM是这方面的代表，这样你就可以使用传说中的C4收集器了
- 如果你虽然没有足够预算去使用商业解决方案，但能够掌控软硬件型号，使用较新的版本，同时又特别注重延迟，那ZGC很值得尝试。
- 如果你对还处于实验状态的收集器的稳定性有所顾虑，或者应用必须运行在Win-dows操作系统下，那ZGC就无缘了，试试Shenandoah吧。
- 如果你接手的是遗留系统，软硬件基础设施和JDK版本都比较落后，那就根据内存规模衡量一下，对于大概4GB到6GB以下的堆内存，CMS一般能处理得比较好，而对于更大的堆内存，可重点考察一下G1。
当然，以上都是仅从理论出发的分析，实战中切不可纸上谈兵，根据系统实际情况去测试才是选择收集器的最终依据。
## 虚拟机及垃圾收集器日志
JDK9开始，Hotspot所有功能的日志都归到了 "-Xlog"参数上，这个参数的能力也相应被极大扩展了：
```shell
-Xlog[:[selector][:[output][:[decorators][:output-options]]]]
```
命令行中最关键的参数是选择器（Selector）​，它由标签（Tag）和日志级别（Level）共同组成。垃圾收集器的标签名称为“gc”​，由此可见，垃圾收集器日志只是HotSpot众多功能日志的其中一项，全部支持的功能模块标签名如下所示：
```shell
add，age，alloc，annotation，aot，arguments，attach，barrier，biasedlocking，blocks，bot，breakpoint，bytecode，census，class，classhisto，cleanup，compaction，comparator，constraints，constantpool，coops，cpu，cset，data，defaultmethods，dump，ergo，event，exceptions，exit，fingerprint，freelist，gc，hashtables，heap，humongous，ihop，iklass，init，itables，jfr，jni，jvmti，liveness，load，loader，logging，mark，marking，metadata，metaspace，method，mmu，modules，monitorinflation，monitormismatch，nmethod，normalize，objecttagging，obsolete，oopmap，os，pagesize，parser，patch，path，phases，plab，preorder，promotion，protectiondomain，purge，redefine，ref，refine，region，remset，resolve，safepoint，scavenge，scrub，setting，stackmap，stacktrace，stackwalk，start，startuptime，state，stats，stringdedup，stringtable，subclass，survivor，sweep，system，task，thread，time，timer，tlab，unload，update，verification，verify，vmoperation，vtables，workgang
```

日志级别从低到高，共有Trace，Debug，Info，Warning，Error，Off六种级别，日志级别决定了输出信息的详细程度，默认级别为Info。
还可以使用修饰器（Decorator）来要求每行日志输出都附加上额外的内容，支持附加在日志行上的信息包括：
- time：当前日期和时间。
- uptime：虚拟机启动到现在经过的时间，以秒为单位。
- timemillis：当前时间的毫秒数，相当于System.currentTimeMillis()的输出。
- uptimemillis：虚拟机启动到现在经过的毫秒数。
- timenanos：当前时间的纳秒数，相当于System.nanoTime()的输出。
- uptimenanos：虚拟机启动到现在经过的纳秒数。
- pid：进程ID。
- tid：线程ID。
- level：日志级别。
- tags：日志输出的标签集。
如果不指定，默认值是uptime、level、tags这三个，此时日志输出类似于以下形式：
```shell
[3.080s][info][gc,cpu] GC(5) User=0.03s Sys=0.00s Real=0.01s>)
```
### 以下均以JDK 9的G1收集器（JDK 9下默认收集器就是G1，所以命令行中没有指定收集器）为例:
1. 查看GC基本信息，在JDK9之前使用-XX: +PrintGC，JDK9后使用 -Xlog: gc
2. 查看GC详细信息，在JDK9之前使用-XX: +PrintGCDetails，在JDK9之后使用-Xlog: gc*
3. 查看GC前后的堆、方法区可用容量变化，在JDK9之前使用 -XX: +PrintHeapAtGC，JDK9之后使用-Xlog: gc+heap=debug
4. 查看GC过程中用户线程并发时间以及停顿的时间，在JDK9之前使用-XX: PrintGCApplicationConcurrentTime 以及 -XX: +PrintGCApplicationStoppedTime，JDK9之后使用-Xlog: safepoint
5. 查看收集器Ergonomics机制（自动设置堆空间各分代区域大小、收集目标等内容，从Parallel收集器开始支持）自动调节的相关信息。在JDK 9之前使用-XX：+PrintAdaptive-SizePolicy，JDK 9之后使用-Xlog：gc+ergo*=trace：
6. 查看熬过收集后剩余对象的年龄分布信息，在JDK 9前使用-XX：+PrintTenuring-Distribution，JDK 9之后使用-Xlog：gc+age=trace：
## 垃圾收集器参数总结
![[Pasted image 20250425112049.png]]
(续)
![[Pasted image 20250425112110.png]]
## 内存分配
```ad-note
-client设置为客户端模式在windows 64为系统中是不支持的，如果需要切换到Serial/Serial Old收集器组合需要使用参数：-XX: +UseSerialGC
```

## 对象优先在Eden分配
大多数情况下，对象在新生代Eden区中分配。当Eden区没有足够空间进行分配时，虚拟机将发起一次Minor GC。
-Xms20M、-Xmx20M、-Xmn10M这三个参数限制了Java堆大小为20MB，不可扩展，其中10MB分配给新生代，剩下的10MB分配给老年代。
-XX：Survivor-Ratio=8决定了新生代中Eden区与一个Survivor区的空间比例是8∶1
在Minor GC期间虚拟机如果发现对象无法被放入Survivor空间，就会通过分配担保机制提前将对象转移到来年代去。
## 大对象直接进入老年代
HotSpot虚拟机提供了-XX：PretenureSizeThreshold参数（单位是byte），指定大于该设置值的对象直接在老年代分配，这样做的目的就是避免在Eden区及两个Survivor区之间来回复制，产生大量的内存复制操作。
```ad-note
-XX：PretenureSizeThreshold参数只对Serial和ParNew两款新生代收集器有效，HotSpot的其他新生代收集器，如Parallel Scavenge并不支持这个参数。
```
## 长期存活对象将进入老年代
1. **基本规则**
虚拟机给每个对象定义了一个对象年龄（Age）计数器，存储在对象头中。
对象通常在Eden区里诞生，如果经过第一次Minor GC后仍然存活，并且能被Survivor容纳的话，该对象会被移动到Survivor空间中，并且将其对象年龄设为1岁。对象在Survivor区找那个每熬过一次Minor GC，年龄就增加1岁，当增加到一定程度(默认15)，就会被晋升到老年代中。-XX：MaxTenuringThreshold参数可以设置晋升到老年代的年龄。
2. **动态规则**
如果在Survivor空间中相同年龄所有对象大小的总和大于Survivor(suvivor是from 或 to其中一块空间的大小)空间的一半，年龄大于或等于该年龄的对象就可以直接进入老年代，无须等到-XX:MaxTenuringThreshold中要求的年龄。
3. **空间分配担保**
在发生Minor GC之前，虚拟机必须先检查老年代最大可用的连续空间是否大于新生代所有对象总空间，如果大于，那这一次Minor GC可以确保是安全的。如果不大于，则虚拟机会先查看 -XX:HandlePromotionFailure参数的设置值是否允许担保失败；如果允许，那会继续检查老年代最大可用的连续空间是否大于历次晋升到老年代对象的平均大小，如果大于，将尝试进行一次Minor GC，尽管这次Minor GC是有风险的；如果小于，或者-XX:HandlePromotionFailure设置为false，那这时就要改为进行一次Full GC。

在JDK 6 Update 24之后，虽然源码中还定义了-XX：HandlePromotionFailure参数，但是在实际虚拟机中已经不会再使用它。JDK 6 Update 24之后的规则变为只要老年代的连续空间大于新生代对象总大小或者历次晋升的平均大小，就会进行Minor GC，否则将进行Full GC。下面是HotSpot中空间分配检查的代码片段：
```c++
bool TenuredGeneration::promotion_attempt_is_safe(size_t max_promotion_in_bytes) const { 
	// 老年代最大可用的连续空间 
	size_t available = max_contiguous_available(); 
	// 每次晋升到老年代的平均大小 
	size_t av_promo = (size_t)gc_stats()->avg_promoted()->padded_average(); 
	// 老年代可用空间是否大于平均晋升大小，或者老年代可用空间是否大于当此GC时新生代所有对象容量 
	bool res = (available >= av_promo) || (available >= max_promotion_in_bytes); 
	return res; 
}
```

## jps：虚拟机进程状况工具
jps（JVM Process Status Tool），除了名字像UNIX的ps命令之外，它的功能也和ps命令类似：可以列出正在运行的虚拟机进程，并显示虚拟机执行主类（Main Class，main()函数所在的类）名称以及这些进程本地虚拟机唯一ID即进程ID。
jps命令格式：
```shell
jps [options] [hostid]
```
jps 执行样例：
```shell
jps -l 2388 D:\Develop\glassfish\bin\..\modules\admin-cli.jar 2764 com.sun.enterprise.glassfish.bootstrap.ASMain 3788 sun.tools.jps.Jps
```
jps还可以通过RMI协议查询开启了RMI服务的远程虚拟机进程状态，参数hostid为RMI注册表中注册的主机名。jps的其他常用选项如下所示：

| 选项  | 作用                            |
| --- | ----------------------------- |
| -q  | 只输出LVMID，省略主类的名称              |
| -m  | 输出虚拟机启动时传递给主类main()函数的参数      |
| -l  | 输出主类的全名，如果进程执行的是JAR包，则输出JAR路径 |
| -v  | 输出虚拟机进程启动时的JVM参数              |
## jstat：虚拟机统计信息监视工具
jstat（JVM Statistics Monitoring Tool）是用于监视虚拟机各种运行状态信息的命令行工具。它可以显示本地或者远程 [1] 虚拟机进程中的类加载、内存、垃圾收集、即时编译等运行时数据。

jstat命令格式为：
```shell
jstat [ option vmid [interval[s|ms] [count]] ]
```
如果是本地虚拟机进程，VMID与LVMID是一致的；如果是远程虚拟机进程，那VMID的格式应当是：
```shell
[protocol:][//]lvmid[@hostname[:port]/servername]
```
参数interval和count代表查询间隔和次数，如果省略这2个参数，说明只查询一次。假设需要每250毫秒查询一次进程2764垃圾收集状况，一共查询20次，那命令应当是：
```shell
jstat -gc 2764 250 20
```
jstat工具的主要选项如下表所示：
![[Pasted image 20250430103344.png]]
## jinfo：Java配置信息工具
jinfo（Configuration Info for Java）的作用是实时查看和调整虚拟机各项参数。
jinfo还可以使用-sysprops选项把虚拟机进程的System.getProperties()的内容打印出来。JDK 6之后，jinfo在Windows和Linux平台都有提供，并且加入了在运行期修改部分参数值的能力（可以使用-flag[+|-]name或者-flag name=value在运行期修改一部分运行期可写的虚拟机参数值）​。在JDK 6中，jinfo对于Windows平台功能仍然有较大限制，只提供了最基本的-flag选项。
jinfo命令格式：
```shell
jinfo [ option ] pid
```
执行样例：查询CMSInitiatingOccupancyFraction参数值
```shell
jinfo -flag CMSInitiatingOccupancyFraction 1444 -XX:CMSInitiatingOccupancyFraction=85
```
## jmap：Java内存影像工具
jmap（Memory Map for Java）命令用于生成堆转储快照（一般称为heapdump或dump文件）​。如果不使用jmap命令，要想获取Java堆转储快照也还有一些比较“暴力”的手段：譬如-XX：+HeapDumpOnOutOfMemoryError参数，可以让虚拟机在内存溢出异常出现之后自动生成堆转储快照文件，通过-XX：+HeapDumpOnCtrlBreak参数则可以使用`[Ctrl]+[Break]`键让虚拟机生成堆转储快照文件，又或者在Linux系统下通过Kill-3命令发送进程退出信号“恐吓”一下虚拟机，也能顺利拿到堆转储快照。

jmap的作用并不仅仅是为了获取堆转储快照，它还可以查询finalize执行队列、Java堆和方法区的详细信息，如空间使用率、当前用的是哪种收集器等

jmap命令格式：
```shell
jmap [ option ] vmid
```
option选项的合法值与具体含义如下表：
![[Pasted image 20250430110318.png]]

使用jmap生成dump文件的例子：
```shell
jmap -dump:format=b,file=eclipse.bin 3500 Dumping heap to C:\Users\IcyFenix\eclipse.bin ... Heap dump file created
```
## jhat：虚拟机堆转储快照分析工具
DK提供jhat（JVM Heap Analysis Tool）命令与jmap搭配使用，来分析jmap生成的堆转储快照。jhat内置了一个微型的HTTP/Web服务器，生成堆转储快照的分析结果后，可以在浏览器中查看。**最新版本的JDK已经移除了该工具。** 

VisualVM，以及专业用于分析堆转储快照文件的Eclipse Memory Analyzer、IBM HeapAnalyzer  等工具，都能实现比jhat更强大专业的分析功能。
## jstack：Java堆栈跟踪工具
jstack（Stack Trace for Java）命令用于生成虚拟机当前时刻的线程快照（一般称为threaddump或者javacore文件）​。程快照就是当前虚拟机内每一条线程正在执行的方法堆栈的集合，生成线程快照的目的通常是定位线程出现长时间停顿的原因，如线程间死锁、死循环、请求外部资源导致的长时间挂起等，都是导致线程长时间停顿的常见原因。线程出现停顿时通过jstack来查看各个线程的调用堆栈，就可以获知没有响应的线程到底在后台做些什么事情，或者等待着什么资源。

jstack命令格式：
```shell
jstack [ option ] vmid
```
option选项的合法值与具体含义如表所示：
![[Pasted image 20250430113206.png]]
从JDK 5起，java.lang.Thread类新增了一个getAllStackTraces()方法用于获取虚拟机中所有线程的StackTraceElement对象。使用这个方法可以通过简单的几行代码完成jstack的大部分功能。
## 基础工具总结
- 基础工具：用于支持基本的程序创建和运行：
![[Pasted image 20250430113756.png]]
- 安全：用于程序签名、设置安全测试等：
![[Pasted image 20250430113912.png]]
- ...
- 性能监控和故障处理：用于监控分析Java虚拟机运行信息，排查问题
![[Pasted image 20250430114207.png]]
- ...
- REPL和脚本工具
![[Pasted image 20250430114241.png]]
## JHSDB：基于服务性代理的调试工具
下表是JCMD、JHSDB与原基础工具实现相同功能的简要对比。
![[Pasted image 20250430143020.png]]

JHSDB是一款服务性代理(Serviceability Agent，SA) 实现的进程外调试工具。服务型代理是HotSpot虚拟机中一组用于映射Java虚拟机运行信息的、主要基于Java语言(含少量JNI代码)实现的API集合。服务型代理以HotSpot内部的数据结构为参照物进行设计，把这些C++的数据抽象成Java模型对象，相当于HotSpot的C++代码的一个镜像。通过服务性代理的API，可以在一个独立的Java虚拟机的进程里分析其他HotSpot虚拟机的内部数据，或者从HotSpot虚拟机进程内存中dump出来的转储快照里还原出它的运行状态细节。服务性代理的工作原理跟Linux上的GDB或者Windows上的Windbg是相似的。

下面是JHSDB的测试代码，通过JHSDB来查找：代码中的staticObj、instanceObj、localObj这三个变量本身（而不是它们所指向的对象）存放在哪里？
```java
/**
 * staticObj、instanceObj、localObj存放在哪里？
 */
public class JHSDB_TestCase {

    static class Test {
        static ObjectHolder staticObj = new ObjectHolder();
        ObjectHolder instanceObj = new ObjectHolder();

        void foo() {
            ObjectHolder localObj = new ObjectHolder();
            System.out.println("done");    // 这里设一个断点
        }
    }

    private static class ObjectHolder {}

    public static void main(String[] args) {
        Test test = new JHSDB_TestCase.Test();
        test.foo();
    }
}

```

由于JHSDB本身对压缩指针的支持存在很多缺陷，建议用64位系统的读者在实验时禁用压缩指针，另外为了后续操作时可以加快在内存中搜索对象的速度，也建议读者限制一下Java堆的大小。本例中，笔者采用的运行参数如下：
```shell
-Xmx10m -XX:+UseSerialGC -XX:-UseCompressedOops
```
使用以下命令进入JHSDB的图形化模式:
```shell
jhsdb hsdb --pid 12233
```
首先点击菜单中的Tools->Heap Parameters ，结果如图所示:
![[Pasted image 20250430163338.png]]
打开Windows->Console窗口，使用scanoops命令在Java堆的新生代（从Eden起始地址到To Survivor结束地址）范围内查找ObjectHolder的实例，注意这里类要全路径，结果如下所示：
```shell
hsdb>scanoops 0x00007f32c7800000 0x00007f32c7b50000 com.hmilyylimh.cloud.facade.demo.JHSDB_TestCase$ObjectHolder
0x00007f32c7a7c458 JHSDB_TestCase$ObjectHolder
0x00007f32c7a7c480 JHSDB_TestCase$ObjectHolder
0x00007f32c7a7c490 JHSDB_TestCase$ObjectHolder
```
再使用Tools->Inspector功能确认一下这三个地址中存放的对象，结果如图所示：
![[Pasted image 20250430163544.png]]
Inspector为我们展示了对象头和指向对象元数据的指针，里面包括了Java类型的名字、继承关系、实现接口关系，字段信息、方法信息、运行时常量池的指针、内嵌的虚方法表（vtable）以及接口方法表（itable）等。

接下来要根据堆中对象实例地址找出引用它们的指针，在命令行中使用如下命令：
```shell
hsdb> revptrs 0x00007f32c7a7c458 Computing reverse pointers... Done. Oop for java/lang/Class @ 0x00007f32c7a7b180
```
通过Inspector查看该对象实例，可以清楚看到这确实是一个java.lang.Class类型的对象实例，里面有一个名为staticObj的实例字段:
![[Pasted image 20250430163723.png]]
JDK 7及其以后版本的HotSpot虚拟机选择把静态变量与类型在Java语言一端的映射Class对象存放在一起，存储于Java堆之中，从我们的实验中也明确验证了这一点 。
接下来继续查找第二个对象实例：
```shell
hsdb>revptrs 0x00007f32c7a7c480 Computing reverse pointers... Done. Oop for JHSDB_TestCase$Test @ 0x00007f32c7a7c468
```
![[Pasted image 20250430163835.png]]
这个结果完全符合我们的预期，第二个ObjectHolder的指针是在Java堆中JHSDB_TestCase$Test对象的instanceObj字段上。

但是我们采用相同方法查找第三个ObjectHolder实例时，JHSDB返回了一个null。
看来revptrs命令并不支持查找栈上的指针引用，不过没有关系，得益于我们测试代码足够简洁，人工也可以来完成这件事情。在Java Thread窗口选中main线程后点击Stack Memory按钮查看该线程的栈内存，如图所示。
![[Pasted image 20250430163924.png]]
这个线程只有两个方法栈帧，尽管没有查找功能，但通过肉眼观察在地址0x00007f32e771c998上的值正好就是0x00007f32c7a7c490，而且JHSDB在旁边已经自动生成注释，说明这里确实是引用了一个来自新生代的JHSDB_TestCase$ObjectHolder对象。
JHSDB提供了非常强大且灵活的命令和功能，本节的例子只是其中一个很小的应用，读者在实际开发、学习时，可以用它来调试虚拟机进程或者dump出来的内存转储快照，以积累更多的实际经验。
## Jconsole：Java监视与管理控制台
JConsole (Java Monitoring and Management Console) 是一款基于JMX（Java Management Extensions）的可视化监视、管理工具。它的主要功能是通过JMX的MBean(Managed Bean) 对系统进行信息收集和参数动态调整。JMX是一种开放性的技术，不仅可以用在虚拟机本身的管理上，还可以运行于虚拟机之上的软件中，典型的如中间件大多也基于JMX来实现管理与监控。虚拟机对JMX MBean的访问也是完全开放的，可以使用代码调用API、支持JMX协议的管理控制台，或者其他符合JMX规范的软件进行访问。

启动JConsole连接本地对应的JVM进程后，可以在内存页签中观察内存使用情况：
![[Pasted image 20250430174135.png]]

可以在线程页签中选择对应的线程观察当前线程处于什么状态：
![[Pasted image 20250430174241.png]]
![[Pasted image 20250430174248.png]]
![[Pasted image 20250430174317.png]]

通过点击死锁检测按钮，可以看到当前进程中死锁的线程情况：
![[Pasted image 20250430174346.png]]
## VisualVM：多合-故障处理工具
VisualVM (All-in-one Java Troubleshooting Tool) 是功能最强大的运行监视和故障处理程序之一。它除了常规的运行监视、故障处理外，还提供其他方面的能力，譬如性能分析（Profiling）。相比第三方工具，VisualVM还有一个很大的优点：不需要被监视的程序基于特殊Agent去运行，因此它的通用性很强，对应用程序实际性能的影响也较小。
### 有了插件扩展支持的VisualVM可以做到：
- 显示虚拟机进程以及进程的配置、环境信息（jps、jinfo）​。
- 监视应用程序的处理器、垃圾收集、堆、方法区以及线程的信息（jstat、jstack）​。
- dump以及分析堆转储快照（jmap、jhat）​。
- 方法级的程序运行性能分析，找出被调用最多、运行时间最长的方法。
- 离线程序快照：收集程序的运行时配置、线程dump、内存dump等信息建立一个快照，可以将快照发送开发者处进行Bug反馈。
- 离线程序快照：收集程序的运行时配置、线程dump、内存dump等信息建立一个快照，可以将快照发送开发者处进行Bug反馈。
![[Pasted image 20250430182758.png]]
### 生成、浏览堆转储快照
- 在“应用程序”窗口中右键单击应用程序节点，然后选择“堆Dump”​。
- 在“应用程序”窗口中双击应用程序节点以打开应用程序标签，然后在“监视”标签中单击“堆Dump”​。
![[Pasted image 20250430183729.png]]
### 分析程序性能
在Profiler页签中，VisualVM提供了程序运行期间方法级的处理器执行时间分析以及内存分析。做Profiling分析肯定会对程序运行性能有比较大的影响，所以一般不在生产环境使用这项功能，或者改用JMC来完成，JMC的Profiling能力更强，对应用的影响非常轻微。
![[Pasted image 20250430183802.png]]
```ad-note
注意 　在JDK 5之后，在客户端模式下的虚拟机加入并且自动开启了类共享—这是一个在多虚拟机进程共享rt.jar中类数据以提高加载速度和节省内存的优化，而根据相关Bug报告的反映，VisualVM的Profiler功能会因为类共享而导致被监视的应用程序崩溃，所以读者进行Profiling前，最好在被监视程序中使用-Xshare：off参数来关闭类共享优化。
```

### BTrace动态日志跟踪
BTrace 是一个很神奇的VisualVM插件，它本身也是一个可运行的独立程序。BTrace的作用是在不中断目标程序运行的前提下，通过HotSpot虚拟机的Instrument功能 动态加入原本并不存在的调试代码。这项功能对实际生产中的程序很有意义：如当程序出现问题时，排查错误的一些必要信息时（譬如方法参数、返回值等）​，在开发时并没有打印到日志之中以至于不得不停掉服务时，都可以通过调试增量来加入日志代码以解决问题。

笔者准备了一段简单的Java代码来演示BTrace的功能：产生两个1000以内的随机整数，输出这两个数字相加的结果，如代码清单如下所示。
```java
public class BTraceTest {

    public int add(int a, int b) {
        return a + b;
    }

    public static void main(String[] args) throws IOException {
        BTraceTest test = new BTraceTest();
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        for (int i = 0; i < 10; i++) {
            reader.readLine();
            int a = (int) Math.round(Math.random() * 1000);
            int b = (int) Math.round(Math.random() * 1000);
            System.out.println(test.add(a, b));
        }
    }
}

```

使用下面的Script来增强运行时输出参数：
```java
/* BTrace Script Template */
import com.sun.btrace.annotations.*;
import static com.sun.btrace.BTraceUtils.*;

@BTrace
public class TracingScript {
        @OnMethod(
    clazz="org.fenixsoft.monitoring.BTraceTest",
    method="add",
    location=@Location(Kind.RETURN)
)

public static void func(@Self org.fenixsoft.monitoring.BTraceTest instance,int a, int b,@Return int result) {
    println("调用堆栈:");
    jstack();
    println(strcat("方法参数A:",str(a)));
    println(strcat("方法参数B:",str(b)));
    println(strcat("方法结果:",str(result)));
}
}

```

执行步骤如下：
点击Start按钮后稍等片刻，编译完成后，Output面板中会出现“BTrace code successfuly deployed”的字样。当程序运行时将会在Output面板输出如图4-23所示的调试信息。
![[Pasted image 20250430184205.png]]
BTrace能够实现动态修改程序行为，是因为它是基于Java虚拟机的Instrument开发的。Instrument是Java虚拟机工具接口（Java Virtual Machine Tool Interface，JVMTI）的重要组件，提供了一套代理（Agent）机制，使得第三方工具程序可以以代理的方式访问和修改Java虚拟机内部的数据。阿里巴巴开源的诊断工具Arthas也通过Instrument实现了与BTrace类似的功能。

## class文件格式
![[Pasted image 20250507182747.png]]

## 类加载的时机
下图是类的生命周期：
![[Pasted image 20250521173408.png]]
《Java虚拟机规范》中并没有强制约束，类加载过程中的第一个阶段"加载"是在什么时候发生。而是严格规定了有且只有六种情况必须立即对类进行"初始化"(而加载、验证、准备自然需要在此之前开始):
1. 遇到new、getstatic、putstatic或invokestatic这四条字节码指令时，如果类型没有进行过初始化，则需要先触发其初始化阶段
2. 使用java.lang.reflect包的方法对类型进行反射调用的时候，如果类型没有进行过初始化，则需要先触发其初始化
3. 当初始化类的时候，如果发现其父类还没有进行过初始化，则需要先触发其父类的初始化
4. 当虚拟机启动时，用户需要指定一个要执行的主类（包含main()方法的那个类）​，虚拟机会先初始化这个主类
5. 当使用JDK 7新加入的动态语言支持时，如果一个java.lang.invoke.MethodHandle实例最后的解析结果为REF_getStatic、REF_putStatic、REF_invokeStatic、REF_newInvokeSpecial四种类型的方法句柄，并且这个方法句柄对应的类没有进行过初始化，则需要先触发其初始化
6. 当一个接口中定义了JDK 8新加入的默认方法（被default关键字修饰的接口方法）时，如果有这个接口的实现类发生了初始化，那该接口要在其之前被初始化
以上6种情形都被称为主动引用，以下是一些被动引用的例子：
- 通过子类引用父类的静态字段，不会导致子类初始化
- 通过数组定义来引用类，不会触发此类的初始化
- 常量在编译阶段会存入调用类的常量池中，本质上没有直接引用到定义常量的类，因此不会触发定义常量的类的初始化。

# 程序编译与代码优化
## 前端编译与优化
比较有代表性的编译器产品：
- **前端编译器**：JDK的Javac、Eclipse JDT中的增量式编译器(ECJ)。
- **即时编译器**：HotSpot虚拟机的C1、C2编译器，Graal编译器。
- **提前编译器**：JDK的Jaotc、GNU Compiler for the Java(GCJ)、Excelsior JET。

Javac确实是做了许多针对Java语言编码过程的优化措施来降低程序员的编码复杂度、提高编码效率。相当多新生的Java语法特性，都是靠编译器的“语法糖”来实现，而不是依赖字节码或者Java虚拟机的底层改进来支持。我们可以这样认为，Java中即时编译器在运行期的优化过程，支撑了程序执行效率的不断提升；而前端编译器在编译期的优化过程，则是支撑着程序员的编码效率和语言使用者的幸福感的提高

### Javac的编译过程
![[Pasted image 20250522140917.png]]
Javac编译动作的入口是com.sun.tools.javac.main.JavaCompiler类，整个编译过程如下图所示：
![[Pasted image 20250522141006.png]]

### 包装类的 `等于等于`运算不在遇到算术运算的情况下不会自动拆箱，以及它们的equals()方法不处理数据转型的关系。

## 即时编译器
- 为何HotSpot虚拟机要使用解释器与即时编译器并存的架构？
- 为何HotSpot虚拟机要实现两个(或三个) 不同的即时编译器？
- 程序合适使用解释器执行？合适使用编译器执行？
- 那些程序代码会被编译为本地代码？如何编译本地代码？
- 如何从外部观察到即时编译器的编译过程和编译结果？
依靠方法调用触发的编译，是虚拟机中标准的即时编译。由循环体触发的，热点只是方法的一部分，但编译器必须以整个方法作为编译对象，只是执行入口会稍有不同，编译时会传入执行入口点字节码序列化。这种编译方式因为编译发生子啊发放执行的过程中，因此被很形象地成为"栈上替换" (On Stack Replacement, OSR)，即方法的栈帧还在栈上，方法就被替换了。

热点探测并不一定要知道方法具体被调用了多少次，目前主流的热点探测判定方式有两种 ，分别是：
- 基于采样的热点探测（Sample Based Hot Spot Code Detection）​。
- 基于计数器的热点探测（Counter Based Hot Spot Code Detection）​。
HotSpot虚拟机中使用的是第二种基于计数器的热点探测方法，为了实现热点计数，HotSpot为每个方法准备了两类计数器：方法调用计数器（Invocation Counter）和回边计数器（Back Edge Counter，​“回边”的意思就是指在循环边界往回跳转）​。
- -XX: CompileThreshold 方法调用计数器阈值，客户端模式下默认是1500次，服务端模式下默认是10000次
- -XX：-UseCounterDecay来关闭热度衰减，让方法计数器统计方法调用的绝对次数，这样只要系统运行时间足够长
- -XX：CounterHalfLifeTime参数设置半衰周期的时间，单位是秒
![[Pasted image 20250523095858.png]]

回边计数器，它的作用是统计一个方法中循环体代码执行的次数 [3] ，在字节码中遇到控制流向后跳转的指令就称为“回边（Back Edge）​”​，很显然建立回边计数器统计的目的是为了触发栈上的替换编译。

-XX：OnStackReplacePercentage来间接调整回边计数器的阈值，其计算公式有如下两种：
- 客户端模式下，方法调用计数器阈值（-XX：CompileThreshold）乘以OSR比率（-XX：OnStackReplacePercentage）除以100。其中-XX：OnStackReplacePercentage默认值为933，如果都取默认值，那客户端模式虚拟机的回边计数器的阈值为13995。
- 服务端模式下：方法调用计数器阈值（-XX：CompileThreshold）乘以（OSR比率（-XX：OnStackReplacePercentage）减去解释器监控比率（-XX：InterpreterProfilePercentage）的差值）除以100。其中-XX：OnStack ReplacePercentage默认值为140，-XX：InterpreterProfilePercentage默认值为33，如果都取默认值，那服务端模式虚拟机回边计数器的阈值为10700
![[Pasted image 20250523100119.png]]
与方法计数器不同，回边计数器没有计数热度衰减的过程，因此这个计数器统计的就是该方法循环执行的绝对次数。当计数器溢出的时候，它还会把方法计数器的值也调整到溢出状态，这样下次再进入该方法的时候就会执行标准编译过程。
## 编译过程
在默认条件下，无论是方法调用产生的标准编译请求，还是栈上替换编译请求，虚拟机在编译器还未完成编译之前，都仍然将按照解释方式继续执行代码，而编译动作则在后台的编译线程中进行。
### 客户端编译器大致的执行过程如下图：
![[Pasted image 20250523101817.png]]
### 服务端模式下的即时编译过程
而服务端编译器则是专门面向服务端的典型应用场景，并为服务端的性能配置针对性调整过的编译器，也是一个能容忍很高优化复杂度的高级编译器，几乎能达到GNU C++编译器使用-O2参数时的优化强度。它会执行大部分经典的优化动，例如：无用代码消除（Dead Code Elimination）​、循环展开（Loop Unrolling）​、循环表达式外提（Loop Expression Hoisting）​、消除公共子表达式（Common Subexpression Elimination）​、常量传播（Constant Propagation）.....

服务端编译采用的寄存器分配器是一个全局图着色分配器，它可以充分利用某些处理器架构（如RISC）上的大寄存器集合。
## 提前编译
提前编译有两条明显的分支（jaotc和substrate都是属于graal vm）：
- 一条分支是做与传统C、C++编译器类似的，在程序运行之前把程序代码编译成机器码的静态翻译工作（Substrate VM）；
- 另一条分支是把原本即时编译器在运行时要做的编译工作提前做好保存下来（Jaotc的提前编译）。
## 编译器优化技术
以下四项是有代表性的优化技术：
- 最重要的优化技术之一：方法内联。
- 最前沿的优化技术之一：逃逸分析。
- 语言无关的经典优化技术之一：公共子表达式消除。
- 语言相关的经典优化技术之一：数据边界检查消除。
## 方法内联
方法内联其实就是把目标方法的代码原封不动地 "复制" 到发起调用的方法之中，避免发生真实的方法调用。但实际上Java虚拟机中的内联过程却远没有想象中容易，甚至如果不是即时编译器做了一些特殊的努力，按照经典编译原理的优化理论，大多数的Java方法都无法进行内联。

只有使用invokespecial指令调用的私有方法、实例构造器、父类方法和使用invokestatic指令调用的静态方法才会在编译期进行解析。除了上述四种方法之外（最多再除去被final修饰的方法这种特殊情况，尽管它使用invokevirtual指令调用，但也是非虚方法，​《Java语言规范》中明确说明了这点）​，其他的Java方法调用都必须在运行时进行方法接收者的多态选择，它们都有可能存在多于一个版本的方法接收者，简而言之，Java语言中默认的实例方法是虚方法

Java虚拟机首先引入了一种名为类型继承关系分析（Class Hierarchy Analysis，CHA）的技术。
假如向CHA查询出来的结果是该方法确实有多个版本的目标方法可供选择，那即时编译器还将进行最后一次努力，使用内联缓存（Inline Cache）的方式来缩减方法调用的开销。
如果真的出现方法接收者不一致的情况，就说明程序用到了虚方法的多态特性，这时候会退化成超多态内联缓存（Megamorphic Inline Cache）​，其开销相当于真正查找虚方法表来进行方法分派。
## 逃逸分析
逃逸分析的基本原理是：分析对象动态作用域，当一个对象在方法里面被定义后，它可能被外部方法所引用，例如作为调用参数传递到其他方法中，这种方法称为方法逃逸；甚至还有可能被外部线程访问到，譬如赋值给可以在其他线程中访问的实力变量，这种称为线程逃逸；从不逃逸、方法逃逸到线程逃逸，称为由低到高的不同逃逸程度。

果能证明一个对象不会逃逸到方法或线程之外，或者逃逸程度比较低（只逃逸出方法而不会逃逸出线程）​，则可能为这个对象实例采取不同程度的优化，如：
- 栈上分配(Stack Allocations)：如果确定一个对象不会逃逸出线程之外，那让这个对象在栈上分配内存将会是一个很不错的主意，对象所占用的内存空间就可以随栈帧出栈而销毁。
- 标量替换(Scalar Replacement)：假如逃逸分析能够证明一个对象不会被方法外部访问，并且这个对象可以被拆散，那么程序真正执行的时候将可能不去创建这个对象，而改为直接创建它的若干个被这个方法使用的成员变量来代替。
- 同步消除(Synchronization Elimination)：线程同步本身是一个相对耗时的过程，如果逃逸分析能够确定一个变量不会逃逸出线程，无法被其他线程访问，那么这个变量的读写肯定就不会有竞争，对这个变量实施的同步措施也就可以安全地消除掉。
如果要百分之百准确地判断一个对象是否会逃逸，需要进行一系列复杂的数据流敏感的过程间分析，才能确定程序各个分支执行时对此对象的影响。前面介绍即时编译、提前编译优劣势时提到了过程间分析这种大压力的分析算法正是即时编译的弱项。可以试想一下，如果逃逸分析完毕后发现几乎找不到几个不逃逸的对象，那这些运行期耗用的时间就白白浪费了，所以目前虚拟机只能采用不那么准确，但时间压力相对较小的算法来完成分析。

某些版本（如JDK 6 Update 18）中还曾经完全禁止了这项优化，一直到JDK 7时这项优化才成为服务端编译器默认开启的选项。如果有需要，或者确认对程序运行有益，用户也可以使用参数-XX：+DoEscapeAnalysis来手动开启逃逸分析，开启之后可以通过参数-XX：+PrintEscapeAnalysis来查看分析结果。有了逃逸分析支持之后，用户可以使用参数-XX：+EliminateAllocations来开启标量替换，使用+XX：+EliminateLocks来开启同步消除，使用参数-XX：+PrintEliminateAllocations查看标量的替换情况。

## 公共子表示消除
公共子表达式消除是一项非常经典的、普遍应用于各种编译器的优化技术，它的含义是：如果一个表达式E之前已经被计算过了，并且从先前的计算到现在E中所有变量的值都没有发生变化，那么E的这次出现就称为公共子表达式。对于这种表达式，没有必要花时间再对它重新进行计算，只需要直接用前面计算过的表达式结果代替E。
## 数组边界检查消除
无论如何，为了安全，数组边界检查肯定是要做的，但数组边界检查是不是必须在运行期间一次不漏地进行则是可以“商量”的事情。例如：
- 数组下标是一个常量，如foo[3]​，只要在编译期根据数据流分析来确定foo.length的值，并判断下标“3”没有越界，执行的时候就无须判断了。
- 更加常见的情况是，数组访问发生在循环之中，并且使用循环变量来进行数组的访问。如果编译器只要通过数据流分析就可以判定循环变量的取值范围永远在区间`[0，foo.length)`之内，那么在循环中就可以把整个数组的上下界检查消除掉，这可以节省很多次的条件判断操作。

为了消除这些隐式开销，除了如数组边界检查优化这种尽可能把运行期检查提前到编译期完成的思路之外，还有一种避开的处理思路—隐式异常处理，Java中空指针检查和算术运算中除数为零的检查都采用了这种方案。

进入异常处理器的过程涉及进程从用户态转到内核态中处理的过程，结束后会再回到用户态，速度远比一次判空检查要慢得多。当foo极少为空的时候，隐式异常优化是值得的，但假如foo经常为空，这样的优化反而会让程序更慢。幸好HotSpot虚拟机足够聪明，它会根据运行期收集到的性能监控信息自动选择最合适的方案。

与语言相关的其他消除操作还有不少，如自动装箱消除（Autobox Elimination）​、安全点消除（Safepoint Elimination）​、消除反射（Dereflection）等。

## Graal编译器
JDK 9时发布的JEP 243：Java虚拟机编译器接口（Java-Level JVM Compiler Interface，JVMCI）使得Graal可以从HotSpot的代码中分离出来。JVMCI主要提供如下三种功能：
- 应HotSpot的编译请求，并将该请求分发给Java实现的即时编译器。
- 允许编译器访问HotSpot中与即时编译相关的数据结构，包括类、字段、方法及其性能监控数据等，并提供了一组这些数据结构在Java语言层面的抽象表示。
- 提供HotSpot代码缓存（Code Cache）的Java端抽象表示，允许编译器部署编译完成的二进制机器码。
## Java 内存模型与线程
//TODO

## 偏向锁和轻量级锁的区别
### **1. 核心目标**

|**锁类型**|**优化目标**|
|---|---|
|**偏向锁**|**消除无竞争场景下的同步开销**（单线程重复访问同步块时无需任何原子操作）。|
|**轻量级锁**|**应对低竞争场景**（多线程交替访问同步块，但实际未发生并发冲突），通过CAS避免重量级锁的开销。|

---

### **2. 实现机制**

#### **(1) 偏向锁**

- **加锁过程**：
    
    1. **首次加锁**：当线程首次进入同步块时，JVM将对象头中的Mark Word设置为偏向模式，记录**线程ID**和**时间戳（Epoch）**。
        
    2. **后续访问**：同一线程再次进入同步块时，直接检查对象头中的线程ID是否匹配。若匹配，无需任何同步操作（如CAS）。
        
- **锁释放**：
    
    - 偏向锁**不会主动释放**，只有在其他线程尝试竞争时触发**偏向锁撤销**（Revoke）。
        

#### **(2) 轻量级锁**

- **加锁过程**：
    
    1. **创建锁记录（Lock Record）**：线程在栈帧中分配一个锁记录空间，存储对象头的Mark Word副本。
        ![[Pasted image 20250526184413.png]]
    2. **CAS替换**：尝试通过CAS操作将对象头的Mark Word替换为指向锁记录的指针。
        
    3. **成功**：若CAS成功，对象头标志位变为轻量级锁（`00`）。
        
    4. **失败**：若CAS失败（竞争发生），升级为重量级锁。
        
- **锁释放**：
    
    1. **CAS还原**：通过CAS将Mark Word替换回锁记录中保存的原始Mark Word。
        
    2. **成功**：释放锁，恢复无锁状态。
        
    3. **失败**：说明锁已升级为重量级锁，需通过重量级锁的流程释放。
### **3. 锁升级与降级**

- **偏向锁 → 轻量级锁**：  
    当其他线程尝试获取偏向锁时，触发**偏向锁撤销**，升级为轻量级锁（通过CAS竞争）。
    
- **轻量级锁 → 重量级锁**：  
    当多个线程竞争同一轻量级锁（自旋失败），升级为重量级锁（操作系统级互斥量）。
    
- **降级**：  
    轻量级锁和重量级锁**不会降级**，但偏向锁在撤销后可能重新偏向其他线程。

下图是HotSpot虚拟机对象头Mark Word：
![[Pasted image 20250526184218.png]]

