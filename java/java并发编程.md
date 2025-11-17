## 管程
**定义**：**管程是指共享变量以及对共享变量的操作过程，让他们支持并发。** 

在管程的发展史上，先后出现过三种不同的管程模型，分别是：Hasen模型、Hoare模型和MESA模型。其中，现在广泛应用的是MESA模型，并且Java管程的实现参考的也是MESA模型。

管程解决互斥问题的思路很简单，就是将共享变量及其对共享变量的操作统一封装起来。假如我们要实现一个线程安全的阻塞队列，一个最直观的想法就是：将线程不安全的队列封装起来，对外提供线程安全的操作方法，例如入队操作和出队操作。

在管程模型里，共享变量和对共享变量的操作是被封装起来的，图中最外层的框就代表封装的意思。框的上面只有一个入口，并且在入口旁边还有一个入口等待队列。当多个线程同时试图进入管程内部时，只允许一个线程进入，其他线程则在入口等待队列中等待。这个过程类似就医流程的分诊，只允许一个患者就诊，其他患者都在门口等待。

管程里还引入了条件变量的概念，而且**每个条件变量都对应有一个等待队列，**如下图，条件变量A和条件变量B分别都有自己的等待队列。
![[Pasted image 20250604185411.png]]

### wait()的正确姿势
MESA管程中有一个特有的编程范式：
```java
while(条件不满足) {
	wait();
}
```
1. Hasen模型里面，要求notify()放在代码的最后，这样T2通知完T1后，T2就结束了，然后T1再执行，这样就能保证同一时刻只有一个线程执行。
2. Hoare模型里面，T2通知完T1后，T2阻塞，T1马上执行；等T1执行完，再唤醒T2，也能保证同一时刻只有一个线程执行。但是相比Hasen模型，T2多了一次阻塞唤醒操作。
3. MESA管程里面，T2通知完T1后，T2还是会接着执行，T1并不立即执行，仅仅是从条件变量的等待队列进到入口等待队列里面。这样做的好处是notify()不用放到代码的最后，T2也没有多余的阻塞唤醒操作。但是也有个副作用，就是当T1再次执行的时候，可能曾经满足的条件，现在已经不满足了，所以需要以循环方式检验条件变量。
### notify()何时可以使用
除非经过深思熟虑，否则尽量使用notifyAll()。可以使用notify()需要满足以下三个条件：
1. 所有等待线程拥有相同的等待条件；
2. 所有等待线程被唤醒后，执行相同的操作；
3. 只需要唤醒一个线程。
## 创建多少线程合适？
对于CPU密集型计算，多线程本质上是提升多核CPU的利用率，所以对于一个4核的CPU，每个核一个线程，理论上创建4个线程就可以了，再多创建线程也只是增加线程切换的成本。所以，**对于CPU密集型的计算场景，理论上“线程的数量=CPU核数”就是最合适的**。不过在工程上，**线程的数量一般会设置为“CPU核数+1”**，这样的话，当线程因为偶尔的内存页失效或其他原因导致阻塞时，这个额外的线程可以顶上，从而保证CPU的利用率。

对于I/O密集型的计算场景，比如前面我们的例子中，如果CPU计算和I/O操作的耗时是1:1，那么2个线程是最合适的。如果CPU计算和I/O操作的耗时是1:2，那多少个线程合适呢？是3个线程，如下图所示：CPU在A、B、C三个线程之间切换，对于线程A，当CPU从B、C切换回来时，线程A正好执行完I/O操作。这样CPU和I/O设备的利用率都达到了100%。
![[Pasted image 20250604195759.png]]
三线程执行示意图

通过上面这个例子，我们会发现，对于I/O密集型计算场景，最佳的线程数是与程序中CPU计算和I/O操作的耗时比相关的，我们可以总结出这样一个公式：

> 最佳线程数=1 +（I/O耗时 / CPU耗时）

我们令R=I/O耗时 / CPU耗时，综合上图，可以这样理解：当线程A执行IO操作时，另外R个线程正好执行完各自的CPU计算。这样CPU的利用率就达到了100%。

不过上面这个公式是针对单核CPU的，至于多核CPU，也很简单，只需要等比扩大就可以了，计算公式如下：

> 最佳线程数=CPU核数 * [ 1 +（I/O耗时 / CPU耗时）]

## Semaphore（信号量）
信号量模型还是很简单的，可以简单概括为：**一个计数器，一个等待队列，三个方法**。在信号量模型里，计数器和等待队列对外是透明的，所以只能通过信号量模型提供的三个方法来访问它们，这三个方法分别是：init()、down()和up()。你可以结合下图来形象化地理解。

![](https://o.alldu.cn/docs/java%e5%b9%b6%e5%8f%91%e7%bc%96%e7%a8%8b%e5%ae%9e%e6%88%98/assets/6dfeeb9180ff3e038478f2a7dccc9b5c.png)

信号量模型图

这三个方法详细的语义具体如下所示。

- init()：设置计数器的初始值。
- down()：计数器的值减1；如果此时计数器的值小于0，则当前线程将被阻塞，否则当前线程可以继续执行。
- up()：计数器的值加1；如果此时计数器的值小于或者等于0，则唤醒等待队列中的一个线程，并将其从等待队列中移除。
在Java SDK并发包里，init()对应的是构造函数，down()和up()对应的则是acquire()和release()。
Semaphore可以允许多个线程访问一个临界区。

## ReadWriteLock(读写锁)
实现类为:ReentrantReadWriteLock.
所有的读写锁都遵守以下三条基本原则：

1. 允许多个线程同时读共享变量；
2. 只允许一个线程写共享变量；
3. 如果一个写线程正在执行写操作，此时禁止读线程读共享变量。
java中，ReadWriteLock不支持锁的升级，但是支持锁的的降级。
```java
// 锁升级，r是读锁，w是写锁，下面的代码会死锁
//读缓存
r.lock();         ①
try {
  v = m.get(key); ②
  if (v == null) {
    w.lock();
    try {
      //再次验证并更新缓存
      //省略详细代码
    } finally{
      w.unlock();
    }
  }
} finally{
  r.unlock();     ③
}
```

```java
// 锁降级
class CachedData {
  Object data;
  volatile boolean cacheValid;
  final ReadWriteLock rwl =
    new ReentrantReadWriteLock();
  // 读锁  
  final Lock r = rwl.readLock();
  //写锁
  final Lock w = rwl.writeLock();

  void processCachedData() {
    // 获取读锁
    r.lock();
    if (!cacheValid) {
      // 释放读锁，因为不允许读锁的升级
      r.unlock();
      // 获取写锁
      w.lock();
      try {
        // 再次检查状态  
        if (!cacheValid) {
          data = ...
          cacheValid = true;
        }
        // 释放写锁前，降级为读锁
        // 降级是可以的
        r.lock(); ①
      } finally {
        // 释放写锁
        w.unlock(); 
      }
    }
    // 此处仍然持有读锁
    try {use(data);} 
    finally {r.unlock();}
  }
}
```

读写锁类似于ReentrantLock，也支持公平模式和非公平模式。读锁和写锁都实现了 java.util.concurrent.locks.Lock接口，所以除了支持lock()方法外，tryLock()、lockInterruptibly() 等方法也都是支持的。但是有一点需要注意，那就是只有写锁支持条件变量，读锁是不支持条件变量的，读锁调用newCondition()会抛出UnsupportedOperationException异常。

## StampedLock 支持三种锁模式
- **写锁（Exclusive Lock）**
    
    - 独占锁，类似 `ReentrantReadWriteLock` 的写锁。
        
    - 获取方法：`long stamp = lock.writeLock();`
        
    - 解锁需匹配戳记：`lock.unlockWrite(stamp);`
        
- **悲观读锁（Pessimistic Read Lock）**
    
    - 共享锁，会阻塞写锁。
        
    - 获取方法：`long stamp = lock.readLock();`
        
    - 解锁：`lock.unlockRead(stamp);`
        
- **乐观读（Optimistic Read）**
    
    - **无锁读**：不阻塞其他线程，允许写操作发生。
        
    - 获取戳记：`long stamp = lock.tryOptimisticRead();`
        
    - **需验证戳记**：`if (!lock.validate(stamp)) { /* 升级锁 */ }`
### 乐观读的工作流程如下所示：
```java
public void read() {
    long stamp = lock.tryOptimisticRead(); // 1. 尝试乐观读（无锁）
    readData();                           // 2. 读取数据到局部变量
    if (!lock.validate(stamp)) {          // 3. 验证戳记是否有效
        stamp = lock.readLock();          // 4. 失效则升级为悲观读锁
        try {
            readData();                  // 5. 重新读取数据
        } finally {
            lock.unlockRead(stamp);      // 6. 释放读锁
        }
    }
    useData();                           // 7. 使用数据
}
```
### **内部实现关键**

- **状态变量**：  
    使用 `long state` 的低 7 位表示写锁状态（重入次数），高位记录读锁数量。
    
- **戳记组成**：  
    包含锁状态版本号、锁模式（读/写/乐观）、读锁计数等。
    
- **乐观读验证**：  
    `validate(stamp)` 检查戳记后是否有写锁被获取（通过版本号对比）。
    
- **等待队列**：  
    使用 CLH 变体管理阻塞线程，避免写线程饥饿。
### **注意事项**
- StampedLock不支持重入。这个是在使用中必须要特别注意的。
- 另外，StampedLock的悲观读锁、写锁都不支持条件变量，这个也需要你注意。
- 还有一点需要特别注意，那就是：如果线程阻塞在StampedLock的readLock()或者writeLock()上时，此时调用该阻塞线程的interrupt()方法，会导致CPU飙升。
## CountDownLatch VS CyclicBarrier
CountDownLatch和CyclicBarrier是Java并发包提供的两个非常易用的线程同步工具类，这两个工具类用法的区别在这里还是有必要再强调一下：**CountDownLatch主要用来解决一个线程等待多个线程的场景**，可以类比旅游团团长要等待所有的游客到齐才能去下一个景点；而**CyclicBarrier是一组线程之间互相等待**，更像是几个驴友之间不离不弃。除此之外CountDownLatch的计数器是不能循环利用的，也就是说一旦计数器减到0，再有线程调用await()，该线程会直接通过。但**CyclicBarrier的计数器是可以循环利用的**，而且具备自动重置的功能，一旦计数器减到0会自动重置到你设置的初始值。除此之外，CyclicBarrier还可以设置回调函数，可以说是功能丰富。
CountDownLatch示例：
```java
public class CountDownLatchTest {

    private final static ExecutorService executor = Executors.newFixedThreadPool(2);
    public static void main(String[] args) throws InterruptedException {
        long start = System.currentTimeMillis();

        CountDownLatch latch = new CountDownLatch(2);

        executor.execute(() -> {
            try {
                Thread.sleep(1000);
                System.out.println("task1");
                latch.countDown();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });


        executor.execute(() -> {
            try {
                Thread.sleep(3000);
                System.out.println("task2");
                latch.countDown();
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });

        latch.await();

        System.out.println("任务完成");
        System.out.println("耗时:" + (System.currentTimeMillis() - start));
    }

}
```
CyclicBarrier示例：
```java
public class CyclicBarrierTest {

    private static final ExecutorService executor = Executors.newFixedThreadPool(2);

    public static void main(String[] args) {
        CyclicBarrier cyclicBarrier = new CyclicBarrier(2, () -> {
            System.out.println("完成一批工作");
        });

        executor.execute(() -> {
            long l = 0;
            for(;;) {
                try {
                    TimeUnit.SECONDS.sleep(1);
                    l++;
                    System.out.println(Thread.currentThread().getName() + ":" +l);
                    cyclicBarrier.await();
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }
        });


        executor.execute(() -> {
            long l = 0;
            for(;;) {
                try {
                    TimeUnit.SECONDS.sleep(2);
                    l++;
                    System.out.println(Thread.currentThread().getName() + ":" +l);
                    cyclicBarrier.await();
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }
        });
    }

}

```

## 并发容器
并发容器虽然数量非常多，但依然是前面我们提到的四大类：List、Map、Set和Queue，下面的并发容器关系图，基本上把我们经常用的容器都覆盖到了。
![[Pasted image 20250605154648.png]]
### CopyOnWriteArrayList
CopyOnWriteArrayList内部维护了一个数组，成员变量array就指向这个内部数组，所有的读操作都是基于array进行的，如下图所示，迭代器Iterator遍历的就是array数组。
![[Pasted image 20250605154804.png]]
写操作，比如add操作，CopyOnWriteArrayList会将array复制一份，然后在新复制处理的数组上执行增加元素操作，执行完成后再将array指向这个新的数组。
![[Pasted image 20250605154927.png]]
使用CopyOnWriteArrayList需要忍受的两个点：
- CopyOnWriteArrayList仅适用于写操作非常少的场景，而且能够容忍读写的短暂不一致。例如上面的例子中，写入的新元素并不能立刻被遍历到。
- 另一个需要注意的是，CopyOnWriteArrayList迭代器是只读的，不支持增删改。因为迭代器遍历的仅仅是一个快照，而对快照进行增删改是没有意义的。
### ConcurrentHashMap和ConcurrentSkipListMap
ConcurrentHashMap的key是无序的，而ConcurrentSkipListMap的key是有序的。
下面这个表格总结了Map相关的实现类对于key和value的要求：
![[Pasted image 20250605155303.png]]
ConcurrentSkipListMap里面的SkipList本身就是一种数据结构，中文一般都翻译为“跳表”。跳表插入、删除、查询操作平均的时间复杂度是 O(log n)，理论上和并发线程数没有关系，所以在并发度非常高的情况下，若你对ConcurrentHashMap的性能还不满意，可以尝试一下ConcurrentSkipListMap。

### CopyOnWriteArraySet和ConcurrentSkipListSet
使用场景可以参考前面讲述的CopyOnWriteArrayList和ConcurrentSkipListMap，它们的原理都是一样的。
### Queue
可以从以下两个维度来分类。一个维度是**阻塞与非阻塞**，所谓阻塞指的是当队列已满时，入队操作阻塞；当队列已空时，出队操作阻塞。另一个维度是**单端与双端**，单端指的是只能队尾入队，队首出队；而双端指的是队首队尾皆可入队出队。Java并发包里**阻塞队列都用Blocking关键字标识，单端队列使用Queue标识，双端队列使用Deque标识**。

这两个维度组合后，可以将Queue细分为四大类，分别是：

1 .**单端阻塞队列**：其实现有ArrayBlockingQueue、LinkedBlockingQueue、SynchronousQueue、LinkedTransferQueue、PriorityBlockingQueue和DelayQueue。内部一般会持有一个队列，这个队列可以是数组（其实现是ArrayBlockingQueue）也可以是链表（其实现是LinkedBlockingQueue）；甚至还可以不持有队列（其实现是SynchronousQueue），此时生产者线程的入队操作必须等待消费者线程的出队操作。而LinkedTransferQueue融合LinkedBlockingQueue和SynchronousQueue的功能，性能比LinkedBlockingQueue更好；PriorityBlockingQueue支持按照优先级出队；DelayQueue支持延时出队。

2 .**双端阻塞队列**：其实现是LinkedBlockingDeque。

3.**单端非阻塞队列**：其实现是ConcurrentLinkedQueue。- 4.**双端非阻塞队列**：其实现是ConcurrentLinkedDeque。


只有ArrayBlockingQueue和LinkedBlockingQueue是支持有界的，所以**在使用其他无界队列时，一定要充分考虑是否存在导致OOM的隐患**。

## CompletableFuture
### 创建CompletableFuture对象
```java
//使用默认线程池
static CompletableFuture<Void> 
  runAsync(Runnable runnable)
static <U> CompletableFuture<U> 
  supplyAsync(Supplier<U> supplier)
//可以指定线程池  
static CompletableFuture<Void> 
  runAsync(Runnable runnable, Executor executor)
static <U> CompletableFuture<U> 
  supplyAsync(Supplier<U> supplier, Executor executor)  
```

`runAsync(Runnable runnable)`和`supplyAsync(Supplier<U> supplier)`，它们之间的区别是：Runnable 接口的run()方法没有返回值，而Supplier接口的get()方法是有返回值的。上面代码中，前两个方法和后两个方法的区别在于：后两个方法可以指定线程池参数。

默认情况下CompletableFuture会使用公共的ForkJoinPool线程池，这个线程池默认创建的线程数是CPU的核数（也可以通过JVM option:-Djava.util.concurrent.ForkJoinPool.common.parallelism来设置ForkJoinPool线程池的线程数）。如果所有CompletableFuture共享一个线程池，那么一旦有任务执行一些很慢的I/O操作，就会导致线程池中所有线程都阻塞在I/O操作上，从而造成线程饥饿，进而影响整个系统的性能。所以，强烈建议你要**根据不同的业务类型创建不同的线程池，以避免互相干扰**。

创建完CompletableFuture对象之后，会自动地异步执行runnable.run()方法或者supplier.get()方法，对于一个异步操作，你需要关注两个问题：一个是异步操作什么时候结束，另一个是如何获取异步操作的执行结果。因为CompletableFuture类实现了Future接口，所以这两个问题你都可以通过Future接口来解决。

### ComletionStage接口
任务是有时序关系的，比如有**串行关系、并行关系、汇聚关系**等。
![[Pasted image 20250605183948.png]]
串行关系
![[Pasted image 20250605184004.png]]
并行关系
![[Pasted image 20250605184012.png]]
汇聚关系

### **描述串行关系**
ompletionStage接口里面描述串行关系，主要是thenApply、thenAccept、thenRun和thenCompose这四个系列的接口。

thenApply系列函数里参数fn的类型是接口Function，这个接口里与CompletionStage相关的方法是 `R apply(T t)`，这个方法既能接收参数也支持返回值，所以thenApply系列方法返回的是`CompletionStage<R>`。

而thenAccept系列方法里参数consumer的类型是接口`Consumer<T>`，这个接口里与CompletionStage相关的方法是 `void accept(T t)`，这个方法虽然支持参数，但却不支持回值，所以thenAccept系列方法返回的是`CompletionStage<Void>`。

thenRun系列方法里action的参数是Runnable，所以action既不能接收参数也不支持返回值，所以thenRun系列方法返回的也是`CompletionStage<Void>`。

这些方法里面Async代表的是异步执行fn、consumer或者action。其中，需要你注意的是thenCompose系列方法，这个系列的方法会新创建出一个子流程，最终结果和thenApply系列是相同的。
```java
CompletionStage<R> thenApply(fn);
CompletionStage<R> thenApplyAsync(fn);
CompletionStage<Void> thenAccept(consumer);
CompletionStage<Void> thenAcceptAsync(consumer);
CompletionStage<Void> thenRun(action);
CompletionStage<Void> thenRunAsync(action);
CompletionStage<R> thenCompose(fn);
CompletionStage<R> thenComposeAsync(fn);
```

使用示例：
```java
CompletableFuture<String> f0 = 
  CompletableFuture.supplyAsync(
    () -> "Hello World")      //①
  .thenApply(s -> s + " QQ")  //②
  .thenApply(String::toUpperCase);//③

System.out.println(f0.join());
//输出结果
HELLO WORLD QQ
```
### **2. 描述AND汇聚关系**
CompletionStage接口里面描述AND汇聚关系，主要是thenCombine、thenAcceptBoth和runAfterBoth系列的接口，这些接口的区别也是源自fn、consumer、action这三个核心参数不同。它们的使用你可以参考上面烧水泡茶的实现程序，这里就不赘述了。
```java
CompletionStage<R> thenCombine(other, fn);
CompletionStage<R> thenCombineAsync(other, fn);
CompletionStage<Void> thenAcceptBoth(other, consumer);
CompletionStage<Void> thenAcceptBothAsync(other, consumer);
CompletionStage<Void> runAfterBoth(other, action);
CompletionStage<Void> runAfterBothAsync(other, action);
```
### **3.描述OR汇聚关系**
CompletionStage接口里面描述OR汇聚关系，主要是applyToEither、acceptEither和runAfterEither系列的接口，这些接口的区别也是源自fn、consumer、action这三个核心参数不同。
```java
CompletionStage applyToEither(other, fn);
CompletionStage applyToEitherAsync(other, fn);
CompletionStage acceptEither(other, consumer);
CompletionStage acceptEitherAsync(other, consumer);
CompletionStage runAfterEither(other, action);
CompletionStage runAfterEitherAsync(other, action);
```

### **4.异常处理**
CompletionStage接口给我们提供的方案非常简单，比try{}catch{}还要简单，下面是相关的方法，使用这些方法进行异常处理和串行操作是一样的，都支持链式编程方式。
```java
CompletionStage exceptionally(fn);
CompletionStage<R> whenComplete(consumer);
CompletionStage<R> whenCompleteAsync(consumer);
CompletionStage<R> handle(fn);
CompletionStage<R> handleAsync(fn);
```
exceptionally()的使用非常类似于try{}catch{}中的catch{}，但是由于支持链式编程方式，所以相对更简单。既然有try{}catch{}，那就一定还有try{}finally{}，whenComplete()和handle()系列方法就类似于try{}finally{}中的finally{}，无论是否发生异常都会执行whenComplete()中的回调函数consumer和handle()中的回调函数fn。whenComplete()和handle()的区别在于whenComplete()不支持返回结果，而handle()是支持返回结果的。

## CompletionService
CompletionService的默认实现是ExecutorCompletionService，它的视线原理是内部维护了一个阻塞队列，当任务执行结束就把任务的执行结果加入到阻塞队列中，不同的是CompletionService是把任务执行结果的Future对象加入到阻塞队列中。这个实现类的构造方法有两个，分别是：

1. `ExecutorCompletionService(Executor executor)`；
2. `ExecutorCompletionService(Executor executor, BlockingQueue<Future<V>> completionQueue)`。
这两个构造方法都需要传入一个线程池，如果不指定completionQueue，那么默认会使用无界的LinkedBlockingQueue。
### CompletionService接口说明
```java
Future<V> submit(Callable<V> task);
Future<V> submit(Runnable task, V result);
Future<V> take() 
  throws InterruptedException;
Future<V> poll();
Future<V> poll(long timeout, TimeUnit unit) 
  throws InterruptedException;
```
其中两个submit是用来提交任务的，类似于ThreadPoolExecutor中的submit方法定义。

CompletionService接口其余的3个方法，都是和阻塞队列相关的，take()、poll()都是从阻塞队列中获取并移除一个元素；它们的区别在于如果阻塞队列是空的，那么调用 take() 方法的线程会被阻塞，而 poll() 方法会返回 null 值。 `poll(long timeout, TimeUnit unit)` 方法支持以超时的方式获取并移除阻塞队列头部的一个元素，如果等待了 timeout unit时间，阻塞队列还是空的，那么该方法会返回 null 值。

当需要批量提交异步任务的时候建议你使用CompletionService。CompletionService将线程池Executor和阻塞队列BlockingQueue的功能融合在了一起，能够让批量异步任务的管理更简单。除此之外，CompletionService能够让异步任务的执行结果有序化，先执行完的先进入阻塞队列，利用这个特性，你可以轻松实现后续处理的有序性，避免无谓的等待，同时还可以快速实现诸如Forking Cluster这样的需求。
## Fork Join Pool
### ForkJoinPool的工作原理：
ForkJoinPool内部有多个任务队列，当我们通过ForkJoinPool的invoke()或者submit()方法提交任务时，ForkJoinPool根据一定的路由规则把任务提交到一个任务队列中，如果任务在执行过程中会创建出子任务，那么子任务会提交到工作线程对应的任务队列中。**也就是说ForkJoinPool中的每一个工作线程给对应一个任务队列。**

ForkJoinPool支持一种叫做“**任务窃取**”的机制，如果工作线程空闲了，那它可以“窃取”其他工作任务队列里的任务。

ForkJoinPool中的任务队列采用的是双端队列，工作线程正常获取任务和“窃取任务”分别是从任务队列不同的端消费，这样能避免很多不必要的数据竞争。
![[Pasted image 20250606135501.png]]
## ThreadLocal
原理：
Thread这个类内部有一个私有属性threadLocals，其类型是ThreadLocalMap，ThreadLocalMap的key是ThreadLocal。
![[Pasted image 20250609101606.png]]
在Java的实现方案里面，ThreadLocal仅仅是一个代理工具类，内部并不持有任何与线程相关的数据，所有和线程相关的数据都存储在Thread里面，这样的设计容易理解。
这样设计，**不容易产生内存泄露**。ThreadLocal持有的Map会持有Thread对象的引用，这就意味着，只要ThreadLocal对象存在，那么Map中的Thread对象就永远不会被回收。ThreadLocal的生命周期往往都比线程要长，所以这种设计方案很容易导致内存泄露。而Java的实现中Thread持有ThreadLocalMap，而且ThreadLocalMap里对ThreadLocal的引用还是弱引用（WeakReference），所以只要Thread对象可以被回收，那么ThreadLocalMap就能被回收。

### ThreadLocal与内存泄露
线程池中线程的存活时间太长，往往都是和程序同生共死的，这就意味着Thread持有的ThreadLocalMap一直都不会被回收，再加上ThreadLocalMap中的Entry对ThreadLocal是弱引用（WeakReference），所以只要ThreadLocal结束了自己的生命周期是可以被回收掉的。但是Entry中的Value却是被Entry强引用的，所以即便Value的生命周期结束了，Value也是无法被回收的，从而导致内存泄露。
我们需要在使用ThreadLocal的时候一定要，通过**try{}finally{}** 在finally中调用ThreadLocal#remove()方法手动释放value。

### InheritableThreadLocal与继承性
如果你需要子线程继承父线程的线程变量，Java提供了InheritableThreadLocal来支持这种特性。

## guarded suspension模式
多线程中的设计模式，Guarded Suspension：
直译过来就是"保护性地暂停"，下图是该模式的结构图，一个GuardedObject，内部有一个成员变量---受保护的对象，以及两个成员方法---`get(Predicate<T> p)`和 `onChanged(T obj)`方法。
![[Pasted image 20250609104929.png]]
GuardedObject的内部实现非常简单，是管程的一个经典用法：
```java
class GuardedObject<T>{
  //受保护的对象
  T obj;
  final Lock lock = 
    new ReentrantLock();
  final Condition done =
    lock.newCondition();
  final int timeout=1;
  //获取受保护对象  
  T get(Predicate<T> p) {
    lock.lock();
    try {
      //MESA管程推荐写法
      while(!p.test(obj)){
        done.await(timeout, 
          TimeUnit.SECONDS);
      }
    }catch(InterruptedException e){
      throw new RuntimeException(e);
    }finally{
      lock.unlock();
    }
    //返回非空的受保护对象
    return obj;
  }
  //事件通知方法
  void onChanged(T obj) {
    lock.lock();
    try {
      this.obj = obj;
      done.signalAll();
    } finally {
      lock.unlock();
    }
  }
}
```
Guarded Suspension模式本质上是一种等待唤醒机制的实现，只不过Guarded Suspension模式将其规范化了。规范化的好处是你无需重头思考如何实现，也无需担心实现程序的可理解性问题，同时也能避免一不小心写出个Bug来。但Guarded Suspension模式在解决实际问题的时候，往往还是需要扩展的，扩展的方式有很多，本篇文章就直接对GuardedObject的功能进行了增强，Dubbo中DefaultFuture这个类也是采用的这种方式。
Guarded Suspension模式有一个很形象的非官方名字：多线程版本的if。
## Thread-Per-Message模式
是为每个任务分配一个独立的线程，这是一种最简单的分工方法，实现起来也非常简单。对应到现实世界，其实就是委托代办。

Thread-Per-Message模式的一个最经典的应用场景是**网络编程里服务端的实现**，服务端为每个客户端请求创建一个独立的线程，当线程处理完请求后，自动销毁，这是一种最简单的并发处理网络请求的方法。

Thread-Per-Message模式在Java领域并不是那么知名，根本原因在于Java语言里的线程是一个重量级的对象，为每一个任务创建一个线程成本太高，尤其是在高并发领域，基本就不具备可行性。不过这个背景条件目前正在发生巨变，Java语言未来一定会提供轻量级线程，这样基于轻量级线程实现Thread-Per-Message模式就是一个非常靠谱的选择。（协程可以解决这个问题）

当然，对于一些并发度没那么高的异步场景，例如定时任务，采用Thread-Per-Message模式是完全没有问题的。实际工作中，我就见过完全基于Thread-Per-Message模式实现的分布式调度框架，这个框架为每个定时任务都分配了一个独立的线程。

## Worker Thread模式
![[Pasted image 20250609183151.png]]
通过上面的图，你很容易就能想到用阻塞队列做任务池，然后创建固定数量的线程消费阻塞队列中的任务。其实你仔细想会发现，这个方案就是Java语言提供的线程池。
**提交到相同线程池中的任务一定是相互独立的，否则就一定要慎重**。如果任务之间有依赖关系，最好将任务区分开来，用不同的线程池处理不同的任务，防止出现死锁问题。
## 生产者-消费者模式
生产者-消费者模式的核心是一个**任务队列**，生产者线程生产任务，并将任务添加到任务队列中，而消费者线程从任务队列中获取任务并执行。下面是生产者-消费者模式的一个示意图：
![[Pasted image 20250610140701.png]]
两阶段终止模式是一种通用的解决方案。但其实终止生产者-消费者服务还有一种更简单的方案，叫做 **“毒丸”对象**。简单来讲，“毒丸”对象是生产者生产的一条特殊任务，然后当消费者线程读到“毒丸”对象时，会立即终止自身的执行。

## Actor的规范化定义
Actor是一种基础的计算单元，具体来讲包括三部分能力，分别是：

1. 处理能力，处理接收到的消息。
2. 存储能力，Actor可以存储自己的内部状态，并且内部状态在不同Actor之间是绝对隔离的。
3. 通信能力，Actor可以和其他Actor之间通信。

当一个Actor接收的一条消息之后，这个Actor可以做以下三件事：

1. 创建更多的Actor；
2. 发消息给其他Actor；
3. 确定如何处理下一条消息。

Actor可以创建新的Actor，这些Actor最终会呈现出一个树状结构，非常像现实世界里的组织结构，所以利用Actor模型来对程序进行建模，和现实世界的匹配度非常高。Actor模型和现实世界一样都是异步模型，理论上不保证消息百分百送达，也不保证消息送达的顺序和发送的顺序是一致的，甚至无法保证消息会被百分百处理。虽然实现Actor模型的厂商都在试图解决这些问题，但遗憾的是解决得并不完美，所以使用Actor模型也是有成本的。