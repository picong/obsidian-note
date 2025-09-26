## 约定
对于同一个共享变量而言，一个线程更新了该变量的值之后，其他线程能够读取到这个更新后的值，那么这个值就被称为该变量的相对新值。如果读取这个共享变量的线程在读取并使用该变量的时候其他线程无法更新该变量的值，那么该线程读取到的相对新值就被称为该变量的最新值。
可见性的保障仅仅意味着一个线程能够读取到共享变量的相对新值，而不能保障该线程能够读取到相应变量的最新值。


## 扩展阅读 单处理器系统是否存在可见性问题？
可见性问题是多线程衍生出来的问题，它与程序的目标运行环境是单处理器 (Uni-processor) 还是多核处理器无关。
在目标运行环境是单处理器的情况下，多线程的并发执行实际上是通过时间片 (Time Slice) 分配实现的。此时，虽然多个线程是运行在同一个处理器上的，但是由于在发生上下文切换 (Context Switch) 的时候，一个线程对寄存器 (Register) 变量的修改会被作为该线程的线程上下文保存起来，这导致另外一个线程无法 "看到" 该线程对这个变量的修改，因此，单处理器系统中实现多线程编程可能出现可见性问题。

## 扩展阅读 可见性与原子性的联系与区别
原子性描述的是一个线程对共享变量的更新，从另外一个线程的角度来看，它要么完成了，要么尚未发生，而不是进行中的一种状态。

可见性描述的是一个线程对共享变量的更新对于另一个线程而言是否可见 (或者说什么情况下不可见) 的问题。保障可见性意味着一个线程可以读取到相应共享变量的相对新值。
## 线程的启动、停止与可见性
Java语言规范 (JLS, Java Language Specification) 保证，父线程在启动子线程之前对共享变量的更新对于子线程来说是可见的。
类似地，Java语言规范保证一个线程终止后该线程对共享变量的更新对于调用该线程的join方法的线程而言是可见的。
## 重排序的概念
重排序是对内存访问有关的操作 (读和写) 所做的一种优化，它可以在不影响单线程程序正确性的情况下提升程序的性能。但是，它可能对多线程程序的正确性产生影响，即它可能导致线程安全问题。与可见性问题类似，重排序也不是必然出现的。
重排序的潜在来源有许多，包括编译器 (在Java平台中这基本上指的是JIT编译器)、处理器和存储子系统(包括写缓冲Store Buffer、告诉缓存Cache)。
## 指令重排序
```ad-note
提示：
Java平台包含两张编译器：静态编译器(javac) 和动态编译器 (JIT编译器)。
```
处理器的指令重排序并不会对单线程程序的正确性产生影响，但是它可能导致多线程程序出现非预期的结果。
## 存储子系统重排序
重排序的四种类型：

| 重排序类型          | 含义                                                                         |
| -------------- | -------------------------------------------------------------------------- |
| LoadLoad 重排序   | 该重排序指一个处理器上先后执行两个读内存操作L1和L2，其他处理器对这两个内存操作的感知顺序可能是 L2 -> L1,即L1被重排序到L2之后    |
| StoreStrore重排序 | 该重排序指一个处理器上先后执行两个写内存操作W1和W2，其他处理器对这两个内存操作的感知顺序可能是W2 -> W1，即W1被重排序到W2之后     |
| LoadStore重排序   | 该重排序指一个处理器上先后执行读内存操作L1和写内存操作W2，其他处理器对这两个内存操作的感知顺序可能是 W2 -> L1，即L1被重排序到W2之后 |
| StoreLoad重排序   | 该重排序指一个处理器上先后执行写内存操作W1和读内存操作L2，其他处理器对这两个内存操作的感知顺序可能是 L2 -> W1,即W1被重排序到L2之后 |

![[Pasted image 20240322175228.png]]
## 貌似串行语义
貌似串行语义只是从单线程程序的角度保证重排序后的运行结果不影响程序的正确性，它并不保证多线程环境下程序的正确性。
为了保证貌似串行语义，存在数据依赖关系的语句不会被重排序，只有不存在数据依赖关系的语句才会被重排序。如果两个操作 (指令) 访问同一个变量 (地址)，且其中一个操作 (指令) 为写操作，那么这两种操作之间就存在数据依赖关系 (Data Dependency)，如下表所示。
数据依赖关系类型表：

| 类型       | 代码示例              | 说明                         |
| -------- | ----------------- | -------------------------- |
| 写后读(WAR) | x = 1; y = x + 1; | 后一条语句的操作数包含前一句语句的执行结果      |
| 读后写(RAW) | y = x; x = 1;     | 前一条语句读取一个变量后，后一条语句更新了该变量的值 |
| 写后写      | x=1;x=2;          | 两条语句对同一变量进行写操作             |
## 扩展阅读 单处理器系统是否会受重排序的影响？
编译器重排序，即静态编译器 (对于Java平台指javac) 造成的重排序会对运行在单处理器上的多个线程产生影响。
运行期重排序，包括存储子系统造成的重排序、JIT编译器造成的重排序以及处理器的乱序执行所导致的重排序，并不会对单处理器上运行的多线程产生影响。这是因为，这些重排序都是运行期实现的，即当这些重排序发生的时候，相关指令还没完全执行完毕，即它们的执行结果还没有被提交到主存，此时处理器通常不会进行上下文切换，而是等这些正在执行的指令执行完毕之后再进行上下文切换。
## 保证内存访问的顺序性
从底层角度来说，禁止重排序是通过调用处理器提供相应的指令 (内存屏障) 来实现的。
## 上下文切换
上下文切换 (Context Switch) 在某种程度上可以被看做多个线程共享同一个处理器的产物，它是多线程编程中的一个重要概念。
从Java应用的角度来看，一个线程的声明周期状态在Runnable状态与非Runnable状态之间切换的过程就是一个上下文切换的过程。
## 上下文切换的分类及具体诱因
按照导致上下文切换的因素划分，我们可以将上下文切换分为自发性上下文切换 (Voluntary Context Switch) 和 非自发性上下文切换 (Involuntary Context Switch)。
从Java平台的角度来看，执行下列任意一个方法都会引起自发性上下文切换。
- Thread.sleep(long millis)
- Object.wait()/wait(long timeout) / wait(long timeout, int nanos)
- Thread.yield()
- Thread.join()/Thread.join(long timeout)
- LockSupport.park()
另外，线程发起了I/O操作或者等待其他线程持有锁 也会导致自发性上下文切换。
非自发性上下文切换 指线程由于线程调度器的原因被迫切出。导致非自发性上下文切换的常见因素包括被切出线程的时间片用完或者有一个比被切出线程优先级更高的线程需要被运行。从Java平台的角度来看，Java虚拟机的垃圾回收 (Garbage Collect) 动作也可能导致非自发性上下文切换。

## 显示锁的调度
公平锁保障锁调度的公平性往往是以增加了线程的暂停和唤醒的可能性，即增加了上下文切换为代价的。因此，公平锁被持有的时间相对长或者线程申请锁的平均间隔时间相对长的情形。

## 改进型锁：读写锁
锁的排他性使得多个线程无法以线程安全的方式在同一时刻对共享变量进行读取 (只是读取而不是更新)，这不利于提高系统的并发性。
读写锁适合于在以下条件同时满足的场景中使用：
- 只读操作比写 (更新) 操作要频繁地多；
- 读线程持有锁的时间比较久。
ReetrantReadWriteLock所实现的读写锁是个可重入锁。ReetrantReadWriteLock支持锁的降级 (Downgrage),即一个线程持有读写锁的写锁的情况下可以继续获得相应的读锁，如下所示：
```java
public class ReadWriteLockDowngrade {
	private final ReadWriteLock rwLock = new ReentrantReadWriteLock();
	private final readLock = rwLock.readLock();
	private final writeLock = rwLock.writeLock();

	public void operationWithLockDowngrade() {
		boolen readLockAcquired = false;
		writeLock.lock(); // 申请写锁
		try {
			// 对共享数据进行更新
			// ...
			// 当前线程在持有写锁的情况下申请读锁readLock
			readLock.lock();
			readLockAcqured = true;
		
		} finlly {
			writeLock.unlock(); // 释放写锁
		}

		if (readLockAcqured) {
			try {
			
			} finlly {
				readLock.unlock(); // 释放读锁
			}
		} else {
			// ...
		}
	}

}
```
锁的降级的反面是锁的升级 (Upgrade),即一个线程在持有读写锁的读锁的情况下，申请相应的写锁。ReentrantReadWriteLock并不支持锁的升级。读线程如果要转而申请写锁，需要先释放读锁，然后申请相应的写锁。
## 锁的适用场景
- check-then-act操作
- read-modify-write操作
- 多个线程对多个共享变量进行更新

## 线程同步机制的底层助手：内存屏障
现成获得和释放锁时分别执行的动作：刷新处理器缓存和冲刷处理器缓存。对于同一个锁保护的共享数据而言，前一个动作保证了该锁的当前持有线程能够读取到前一个持有线程对这些数据所做的更新，后一个动作保证了该锁的持有线程对这些数据所做的更新对该锁后续持有线程可见。
Java虚拟机底层实际上是借助内存屏障(Memory Barrier，也称为Fence)来实现上述两个动作的。内存屏障是对一类仅针对内存读、写操作指令的跨处理器架构的比较底层的抽象。内存屏障是被插入到两个指令之间进行使用的，其作用是禁止编译器、处理器重排序从而保障有序性。为了禁止重排序的功能，这些指令也往往具有一个副作用 -- 刷新处理器缓存、冲刷处理器缓存，从而保证可见性。

按照内存屏障所起的作用来划分，将内存屏障划分为一下几种：
- 按照可见性保障来划分，内存屏障可分为加载屏障 (Load Barrier) 和存储屏障 (Store Barrier)。
- 按照有序性保障来划分，内存屏障可以分为获取屏障(Acquire Barrier) 和释放屏障 (Release Barrier)。获取屏障是的是使用方式是在一个读操作之后插入该内存屏障，其作用是禁止该读操作与其后的任何读写操作之间进行重排序。释放屏障的使用方式是在一个写操作之前插入该内存屏障，其作用是禁止该写操作与其前面的任何读写操作之间进行重排序。
![[Pasted image 20240325140558.png]]
为了保障线程安全，我们需要使用Java线程同步机制，而内存屏障则是Java虚拟机在实现Java线程同步机制时锁使用的具体 "工具"。因此，Java应用开发人员一般无须 (也不能) 直接使用内存屏障。不过，JSR166所定义的Java Fences API (java.util.concurrent.atomic.Fences) 使得在Java语言这一层使用内存屏障成为可能。
## 锁与重排序
无论是编译器还是处理器，均还需要遵守以下重排序规则：
- 规则1 --- 临界区内的操作不允许被重排序到临界区之外 。
- 规则2 --- 临界区内的操作之间允许被重排序。
- 规则3 --- 临界区外的操作之间可以被重排序。
![[Pasted image 20240325142822.png]]
讨论上述规则的时候，我们假定代码中只有一个临界区。如果把情形扩展到多个临界区，则为了保证上述规则得以满足且不会导致死锁，一下规则还应被满足。
- 规则4 --- 锁申请 (MonitorEnter) 与锁释放 (MoniterExit) 操作不能被重排序。
- 规则5 --- 两个锁申请操作不能被重排序。
- 规则6 --- 两个锁释放操作不能被重排序。
- 规则7 --- 临界区外的操作可以被重排序到临界区之内。
## 轻量级同步机制：volatile关键字
volatile变量的不稳定性意味着对这种变量的读和写操作都必须从高速缓存或者主内存 (也是通过高速缓存读取) 中读取，以读取变量的相对新值。因此，volatile变量不会编译器分配到寄存器进行存储，对volatile变量的读写操作都是内存访问(访问高速缓存相当于主内存) 操作。
volatile关键字被称为轻量级锁，其作用与锁的作用有相同的地方：保证可见性和有序性。
## volatile的作用
volatile关键字的作用包括：保障可见性、保障有序性和保障long/double型变量读写操作的原子性。
```ad-abstract
约定：
volatile关键字在原子性方面仅保障对被修饰的变量的读操作、写操作本身的原子性。如果要保障对volatile变量的复制操作的原子性，那么这个赋值操作不能涉及任何共享变量 (包括赋值的volatile变量本身) 的访问。
```
写线程对volatile变量的写操作会产生类似于释放锁的效果。读线程对volatile变量的读操作会产生类似于获得锁的效果。因此，volatile具有保障有序性和可见性的作用。
![[Pasted image 20240325151723.png]]
存储屏障具有冲刷处理器缓存的作用，因此在volatile变量写操作之后插入的一个存储屏障就使得该存储屏障前所有操作的结果 (包括volatile变量写操作及该操作之前的任何操作) 对其他处理器来说是可同步的。
![[Pasted image 20240325152744.png]]
volatile禁止了如下重排序：
- 写volatile变量操作与该操作之前的任何读、写操作不会被重排序；
- 读volatile变量操作与该操作之后的任何读、写操作不会被重排序。
```ad-note
volatile关键字在可见性方面仅仅是保证读线程能够读取到共享变量的相对新值。对于引用型变量和数组变量，volatile关键字并不能保证读线程能够读取到相应对象字段(实例变量、静态变量)、元素的相对新值。
```
## volatile变量的开销
volatile变量的读、写操作都不会导致上下文切换，因此volatile的开销要比锁小。volatile变量的读写操作要比普通变量高一些，因为volatile变量的值每次都需要从高速缓存或者主内存中读取或者写入主存，而无法被被暂存在寄存器中，从而无法发挥访问的高效性。
## volatile的典型应用场景与实战案例
典型使用场景：
- **场景一** 使用volatile变量作为状态标志。`volatile boolean flag; if(flag) ...`
- **场景二** 使用volatile保障可见性。
- **场景三** 使用volatile变量替代锁。多个线程共享一组可变状态变量的时候，通常我们需要使用锁来保障对这些变量的更新操作的原子性，以避免产生数据不一致问题。利用volatile变量写操作具有的原子性，我们可以把这一组可变状态变量封装成一个对象，那么对这些状态变量的更新操作就可以通过创建一个新的对象并将该对象引用赋值给相应的引用型变量来实现。在这个过程中，volatile保障了原子性和可见性，从而避免了锁的使用。
- **场景四** 使用volatile实现简易版读写锁。这种建议版读写锁仅涉及一个共享变量并且允许一个线程读取这个共享变量时其他线程可以更新变量 (这是因为读线程并没有加锁)。因此这种读写锁允许读线程可以读取到共享变量的非最新值。该场景的一个典型例子是实现一个计数器，如下所示：
```java
public class Counter {
	private volatile long count;
	public long value() {
		return count;
	}

	public void increment() {
		synchronized (this) {
			count++;
		}
	}
}
```

## 实践：正确实现看似简单的单例模式
双重检测+锁+volatile修饰共享变量，实现安全的单例模式。
这种实践实际上利用了volatile关键字的以下两个作用：
- 保障可见性
- 保障有序性
基于双重检查锁定的正确单例模式实现
```java
public class DCLSingleton {
	private static volatile DCLSingleton instance;

	private DCLSingleton () {
	}

	public static DCLSingleton getInstance () {
		if (null == instance) {
			synchronized(DCLSingleton.class) {
				if (null == instance) {
					instance = new DCLSingleton();
				}
			}
		}
		return instance;
	}
}
```
基于静态内部类的单例模式实现：
```java
public class StaticHolderSingleton {
	private StaticHolderSingleton() {
	}

	private static class InstanceHolder {
		final static StaticHolderSingleton INSTANCE = new StaticHolderSingleton();
	}

	public static StaticHolderSingleton getInstance() {
		return InstanceHolder.INSTANCE;
	}
}
```
我们知道类的静态变量被初次访问会触发Java虚拟机对该类进行初始化，即该类的静态变量的值会变为其初始值而不是默认值。因此，静态方法getInstance()被调用的时候Java虚拟机会初始化这个方法锁访问的内部静态类InstanceHolder。这使得InstanceHolder的静态变量INSTANCE被初始化，从而使StaticHolderSingleton类的唯一实例得以创建。由于类的静态变量只会创建一次，因此StaticHolderSingleton (单例类) 只会被创建一次。

基于枚举类型的单例模式实现示例代码：
```java
public static enum Singleton {
	INSTANCE;
	Singleton() {
	}

	public void someService() {
		// Do some service
	}
}
```

## 分而治之
具体来说，多线程编程中分而治之的使用主要有两种方式：基于数据的分割和基于任务的分割。基于任务的分解可以分为按任务的资源消耗属性和按处理步骤分割这两种。
## 按任务的资源消耗属性分割
线程所执行的任务按照其消耗的主要资源可划分为CPU密集型 (CPU-intensive)任务和I/O密集型 (I/O-intensive) 任务。

## 等待与通知：wait/notify
在Java平台中，Object.wait()/Object.wait(long)以及Object.notify()/Object.notifyAll() 可用于实现等待和通知
使用Object.wait()实现等待，其代码模板如下伪代码所示：
```java
// 在调用wait方法前获得相应对象的内部锁
synchronized (someObject) {
	while (保护条件不成立) {
		// 调用Object.wait()暂停当前线程
		someObject.wait();
	}

	// 代码执行到这里说明保护条件已经满足
	// 执行目标动作
	doAction();
}
```
由于一个线程只有在持有一个对象的内部锁的情况下才能够调用该对象的wait方法，因此Object.wait()调用总是放在相应对象所引导的临界区之中。someObject.wait()会以原子操作的方式使其执行线程暂停并使该线程释放其持有的someObject对应的内部锁。someObject.notify()可以唤醒someObject上的一个(任意的) 等待线程。被唤醒的等待线程在其占用处理器继续运行的时候，需要再次申请someObject对应的内部锁。被唤醒的线程在其再次持有someObject对应的内部锁的情况下继续执行someObject.wait()中剩余的指令，直到wait方法返回。
```ad-note
注意：
- 等待线程对保护条件的判断、Object.wait() 的调用总是应该放在相应对象所引导的临界区中的一个循环语句之中。
- 等待线程对保护条件的判断、Object.wait()的执行以及目标动作执行必须放在同一个对象(内部锁) 所引导的临界区之中。
- Object.wait()暂停当前线程时释放的锁只是与该wait方法所属对象的内部锁。当前线程所持有的其他内部锁、显式锁并不会因此而被释放。
```
使用Object.notify()实现通知，其代码模板如下伪代码所示：
```java
synchronized (someObject) {
	// 更新等待线程的保护条件涉及的共享变量
	updateSharedState();
	// 唤醒其他线程
	someObject.notify();
}
```
## wait/notify的开销及问题
- 过早唤醒 (Wakeup too soon) 问题。
- 信号丢失 (Missed Signal) 问题。
- 欺骗性唤醒 (Spurious Wakeup) 问题。
- 上下文切换问题。
以下方法有助于避免或者减少wait/notify导致过多的上下文切换。
- 在保证程序正确性的前提下，使用Object.notify()替代Object.notifyAll()。Object.notify()调用不会导致过早唤醒，因此减少了相应的上下文切换开销。
- 通过线程在执行完Object.notify()/Object.notifyAll()之后尽快释放相应的内部锁。这样可以避免被唤醒的线程在Object.wait()调用返回前再次申请相应内部锁时，由于该锁尚未被通知线程释放而导致该线程被暂停(以再次获得锁的机会)。
```ad-note
使用Object.notify()替代Object.notifyAll()时需要确保以下两个条件同时得以满足：
- 一次通知需要唤醒至多一个线程
- 相应对象上的所有等待线程都是同质等待线程。(所谓同质等待线程 指这些线程使用同一个保护条件，并且这些线程在Object.wait()调用返回之后的处理逻辑一致。)
```
## wait/notify与Thread.join()
Thread.join通过wait来进行等待，线程执行结束后虚拟机会调用该线程对象上的notifyAll方法来进行通知。
## 条件变量
JDK1.5中引入了新的标准类库java.util.concurrent.locks.Condition接口。
```ad-note
Condition接口本身只是对解决过早唤醒问题提供了支持。要真正解决过早唤醒问题，我们需要通过对应用代码维护保护条件与体检变量之间的对应关系，即使用不同的保护条件的等待线程需要调用不同的条件变量的await方法来实现其等待，并使通知线程在更新了相关共享变量之后，仅调用与这些共享变量有关的保护条件所对应的条件变量的signal/signalAll方法来实现通知。
```
## 倒计时协调器：CountDownLatch
CountDownlatch.countDown()相当于一个通知方法，它会在计数器值达到0的时候唤醒相应实例上的所有等待线程。计数器的初始值是在CountDownLatch的构造函数中指定的，如下声明所示：
```java
public CountDownLatch(int count)
```
count参数用于表示先决操作的数量或者需要被执行的次数。当计数器的值达到0之后，该计数器的值就不再发生变化。此时，调用countDown()并不会导致抛出异常，并且后续执行await()的线程也不会被暂停。因此，CountDownLatch的使用是一次性的：一个CountDownLatch实例只能够实现一次等待和唤醒。

## 一手交钱，一手交货：双缓冲与Exchanger
对照CyclicBarrier来说，生产者线程和消费者线程都执行到Excanger.exchange(V)相当于者两个线程都到达了集合点，此时生产者线程和消费者线程各自对Exchanger.exchange(V)的调用就回返回。
## 一个还是一批：产品粒度
产品粒度的确是权衡产品在传输通道上的移动次数和产品所占用的资源的结果。
## 再探线程和任务之间的关系
在生产者---消费者模式中，一个产品也可以代表消费者线程需要执行的任务。
## 线程中断
中断仅仅代表发起线程的一个诉求，而这个诉求能否被满足取决于目标线程自身---目标线程可能满足发起线程的诉求，也可能根本不理会发起线程的诉求！Java平台会为每个线程维护一个被称为中断标记(Interrupt Status) 的布尔型状态变量用于表示相应线程是否接收到了中断，中断标记为true表示相应线程收到了中断。目标线程可以通过Thread.currentThread().isInterrupted() 调用来获取该线程的中断标记值，也可以通过Thread.interrupted()来获取并重置 (也称清空)中断标记值，即Thread.interrupted() 会返回当前线程的中断标记值并将当前线程中断标记重置为false。调用一个线程的interrupt()相当于将该线程(目标线程)的中断标记置为true。

目标线程检查中断标记后所执行的操作，被称为目标线程对中断的响应，简称中断响应。设有个发起线程originator和目标线程target，那么target对中断的响应一般包括：
- 无影响。目标线程无法对中断进行响应。InputStream.read()、ReentrantLock.lock()以及申请内部锁等阻塞方法/操作就属于这种类型。
- 取消任务的运行。originator调用target.interrupt()会使target在侦测到中断 (即中断标记值为true) 那一刻所执行的任务被取消 (终止),而这并不会运行target继续处理其他任务。
- 工作者线程停止。originator调用target.interrupt()会使target终止，即target的声明周期状态变更为TERMINATED。
能够响应中断的方法通常是在执行阻塞操作前判断中断标志，若中断标志值为true则抛出InterruptedException。

## 注意
依照惯例，抛出InterruptedException异常的方法，通常会在其抛出该异常时将当前线程的线程中断标记重置为false。因此一般在判断当前线程的中断标志时，需要调用Thread.interrupted()而非Thread.currentThread().isInterrupted()。

## 线程特有对象
ThreadLocal实例通常会被作为某个类的静态字段使用。防止当前线程中同一个类型的线程特有对象被多次创建。

ThreadLocal的内部实现机制：
在Java平台中，每个线程(Thread实例)内部会维护一个类似HashMap的对象，我们称之为ThreadLocalMap。每个ThreadLocalMap内部会包含若干Entry。Entry的Key是一个ThreadLocal实例，Value是一个线程特有对象。因此，Entry的作用相当于为其属主线程建立起一个ThreadLocal实例与一个线程特有对象之间的对应关系。由于Entry对TheadLocal实例的引用(通过Key引用)是一个弱引用,因此它不会阻止被引用的TheadLocal实例被垃圾回收。当一个TheadLocal实例没有对其可达的强引用时，这个实例可以被垃圾回收，即其所在的Entry的Key会被置为null。另一方面，由于Entry对线程特有对象的引用是强引用，因此如果无效条目本身有对它的可达强引用，那么无效条目也会阻止其引用的线程特有对象被垃圾回收。有鉴于此，当ThreadLocalMap中有新的ThreadLocal到线程特有对象的映射关系被创建的时候，ThreadLocalMap会将无效条目清理掉，这打破了无效条目对线程特有对象的强引用，从而使相应的线程特有对象能够被垃圾回收。
![[Pasted image 20240409144411.png]]
由于ThreadLocal可能导致内存泄露、伪内存泄露的最小前提是线程持有对线程特有对象的可达强引用。因此我们只要打破这种引用，即通过在当前线程中调用ThreadLocal.remove()将线程特有对象从其Entry中剥离，便可以使线程特有对象以及线程局部变量都可以被垃圾回收。如果我们仅仅是打破线程特有对象对ThreadLocal的引用关系，那么只有线程局部变量可以被垃圾回收，而伪内存泄露仍然存在，即线程特有对象可能仍然无法被垃圾回收。
对于同一个ThreadLocal实例，ThreadLocal.remove能奏效的前提是，其执行线程与ThreadLocal.get()/set(T)的执行线程必须是同一个线程。在Web应用中，为了规避ThreadLocal可能导致的内存泄露、伪内存泄露，我们通常需要在javax.serverlet.Filter接口实现类的doFilter方法中调用ThreadLocal.remove()。这其实是利用Filter的一个重要特征：Web服务器对同一个HTTP请求进行处理时，Filter.doFilter方法的执行线程与Servlet的执行线程(即Sevlet.service方法的执行线程)是同一个线程。

## 线程特有对象的典型应用场景
- **场景一** 需要使用非线程安全对象，但又不希望因此而引入锁。
- **场景二** 使用线程安全对象，但希望避免其使用的锁的开销和相关问题。
- **场景三** 隐式参数传递(Implicit Parameter Passing)。现成特有对象在一个具体的线程中，它是线程全局可见的。
- **场景四** 特定于线程的单例模式。如果我们希望对于某个类每个线程有且仅有该类的一个实例，那么就可以使用线程特有对象。
## 现成特有对象可能导致的问题及其规避
- 退化与数据错乱。由于线程和任务之间可以使一对多的关系，因此线程特有对象就相当于一个线程所执行的多个任务之间的共享对象。如果线程特有对象是个有状态对象且其状态会随着相应线程所执行的任务而改变，那么这个线程所执行的下一个任务可能"看到"来自前一个任务的数据，而这个数据可能与该任务并不匹配，从而导致数据错乱。
下面的模板代码可以避免ThreadLocal可能导致的数据错乱：
```java
public abstract class XAbstractTask implements Runnable {

	static ThreadLocal<HashMap<String, String>> configHolder = new ThreadLocal<>(){
		@Override
		protected HashMap<String, String> initialValue() {
			return new HashMap<>();
		}
	};

	// 该方法总是会在任务处理逻辑被执行前执行
	protected void preRun() {
		// 清空线程特有对象HashMap实例，以保证每个任务执行前HashMap内容是干净的
		configHolder.get().clear();
	}

	protected void postRun() {
		// do nothing
	}

	// 留给子类用于实现任务处理逻辑
	protected abstract void doRun();

	@Override
	public final void run() {

		try{
			preRun();
			doRun();
		} finally {
			postRun();
		}
	}

}
```
- ThreadLocal可能导致内存泄露、伪内存泄露。
```ad-seealso
**术语定义**
内存泄露(Memory Leak) 指由于对象永远无法被垃圾回收导致其占用的Java虚拟机内存无法被释放。持续的内存泄露会导致Java虚拟机可用内存逐渐减少，并最终可能导致Java虚拟机内存溢出(Out of Memory),直到Java虚拟机宕机。
伪内存泄露(Memory Pseudo-leak) 类似于内存泄露。所不同的是，伪内存泄露中对象占用的内存空间可能会被回收，也可能永远无法回收(此时，就变成了内存泄露)。
```

## 小结
Java运行时空间可分为堆空间、非堆空间以及栈空间。栈空间是线程私有空间，而堆空间和非堆空间都是线程共享空间。堆空间用于存储对象以及类的实力变量，它是Java虚拟机启动时分配的可以动态扩容的存储空间。非堆空间用于存储类的静态变量以及其他元数据，它是Java虚拟机启动时分配的可以动态扩容的存储空间。栈空间用于存储线程所执行的方法的局部变量、返回值等私有数据，它是线程创建时分配的容量固定不可变的存储空间。
无状态对象不包含任何实力变量以及可更新的静态变量。

## 死锁产生的条件与规避
线程一旦产生死锁，那么这些线程及相关的资源将满足如下全部条件。
- 资源互斥(Mutual Exclusion)。
- 资源不可抢夺(No Preemption)。
- 占用并等待资源(Hold and Wait)。
- 循环等待资源(Circular Wait)。
规避死锁的方法：
- 粗锁法(Coarsen-grained Lock) --- 使用粗粒度的锁代替多个锁。从消除 "占用并等待资源"出发我们不难想到的一种方法就是，采用一个粒度较粗的锁来替代原先的多个粒度较细的锁，这样涉及的线程只需要申请一个锁从而避免了死锁。
- 锁排序法 (Lock Ordering) --- 相关线程使用全局统一的顺序申请锁。
- 使用ReentrantLock.tryLock(long, TimeUnit)申请锁。该方法申请锁的含义是在超时时间内，如果相应的锁申请成功，那么该方法返回true；如果在tryLock执行的那一刻相应的锁正被其他线程持有，那么该方法会使当前线程暂停，直到这个锁被申请成功或者等待超过指定的超时时间(此时该方法返回false)。
- 使用开放调用 (Open Call) --- 在调用外部方法时不加锁。
- 使用锁的替代品，concurrenthashmap之类的线程安全集合。
## Thread dump的方式
linux系统执行一下命令查看Thread dump
```shell
ps -ef | grep java // 获取进程号
kill -3 <pid> // 获取Thread dump
```
JVM自带的工具获取线程堆栈
```shell
ps -ef | grep java / jps (获取PID)
jstack [-l] <pid> | tee -a jsatack.log (获取ThreadDump)
```

## 死锁的恢复
```ad-note
**注意**
由于导致死锁的线程的不可控性(比如第三方软件启动的线程),因此死锁恢复的实际可操作性并不强：对死锁进行的故障恢复尝试可能都是徒劳的(故障线程可能无法响应中断)且有害的(可能导致活锁等问题)。
```

可以通过ThreadMXBean.findDeadLockedThreads() 调用来实现死锁检测。ThreadMXBean类是JMX(Java Management Extension) API的一部分，因此其提供的功能也可以通过jconsone、jvisualvm手工调用。
死锁恢复之后，如果不进行后续的代码修改，恢复后可能很快就再次进入死锁了，由此可见，死锁自动恢复的实际意义并不大。

## 信号丢失锁死
信号丢失锁死是由于没有相应的通知线程来唤醒等待线程而使等待线程一直处于等待状态的一种活性故障。典型的例子是等待线程在执行Object.wait()/Condition.await()前没有对保护条件进行判断，而此时保护条件实际上可能已然成立，然而伺候可能并无其他线程更新相应保护条件设计的共享变量使其成立并通知等待线程。因此Object.wait()/Condition.await()必须放在一个循环语句中，CountDownLatch.countDown()调用没有放在finally块中可能导致CountDownLactch.awit()的执线程一直处于等待状态，而使其任务一直无法进展。
## 嵌套监视器锁死
嵌套监视器锁死(Nested Monitor Lockout) 是嵌套锁导致等待线程永远无法被唤醒的一种活性故障。
![[Pasted image 20240411161036.png]]
## 线程饥饿
线程饥饿(Thread Starvation) 是指线程一直无法获得其所需的资源而导致其任务一直无法进展的一种活性故障。

## 小结
![[Pasted image 20240411165651.png]]
# 线程管理

## 线程组
线程组 (ThreadGroup类)可以用来表示一组相似的线程。
**提示**
多数情况下，我们可以忽略线程组这一概念以及线程组的存在。

## 可靠性： 线程的未捕获异常与监控

## 线程的高效利用：线程池
```ad-note
**提示**
对于CPU密集型线程，线程数通常可以设置为Ncpu + 1；对于I/O密集型线程，优先考虑将线程数设置为1，仅在线程不够用的情况下将线程数向2xNcpu靠近。这里的线程数量在线程池中对应的参数是maximumThreadSize参数。
```
当线程池当前线程数量达到corePoolSize后，客户端再提交任务，线程池会将任务存入工作队列，存入工作队列调用的是BlockingQueue的非阻塞方法offer(E e),因此工作队列满并不会使提交任务的客户端线程暂停。当工作队里满的时候，线程池会继续创建新的工作者线程，知道当前线程池大小达到最大线程池大小。
![[Pasted image 20240412104440.png]]
ThreadPoolExecutor.prestarAllCoreThreads()使得我们可以使线程池未接收到任何任务的情况下预先创建并启动所有核心线程，这样可以减少任务被线程池处理时所需的等待时间(等待核心线程的创建与启动)。
ThreadPoolExecutor.shutdown()/shutdownNow()方法可用来关闭线程池。使用shutdown关闭线程池的时候，已提交的任务会被继续执行，而新提交的任务会像线程池饱和时那样被拒绝掉。
```ad-note
**注意**
客户端代码应该尽可能早地向线程池提交任务，并仅在需要相应任务的处理结果数据的那一刻才调用Future.get()方法。
```
一般客户端线程在执行Future.get(long, TimeUnit)的时候，需要捕获TimeoutException异常，在catch中调用Future.cancel(true)来取消相应任务的执行(因为此时我们已经不再需要该任务的处理结果了)。
## 线程池监控
![[Pasted image 20240412142028.png]]
如果有必要的话，我们可以通过创建ThreadPoolExecutor的子类并在子类的beforeExecute/afterExecute方法实现监控逻辑，比如计算任务执行的平均耗时。
## 线程池死锁
```ad-note
**注意**
同一个线程池只能用于执行相互独立的任务。彼此有依赖关系的任务需要提交给不同的线程池执行以避免死锁。
```
## 工作者线程的异常终止
```ad-note
通过ThreadPoolExecutor.submit调用提交给线程池执行的任务，其执行过程中抛出的未捕获异常并不会导致与该线程池中的工作者线程关联的UncaughtExceptionHandler的uncaughtException方法被调用。
```

## 阻塞队列
一般而言，一个方法或者操作如果能够导致其执行线程被暂停(生命周期状态为WAITING或者BLOCKED)，那么我们就称相应的方法/操作为阻塞方法或者阻塞操作。可见，阻塞方法/操作能够导致上下文切换。常见的阻塞方法/操作包括InputStream.read()、ReentrantLock.lock()、申请内部锁等。相反,如果一个方法或者操作并不会导致其执行线程被暂停，那么相应的方法/操作就被称为非阻塞方法或者非阻塞操作。
BlockingQueue的put/take方法是阻塞方法,阻塞队列也支持非阻塞式操作。比如BlockingQueue接口定义的offer(E)和poll分别相当于put和take的非阻塞版。非阻塞式方法通常用特殊的返回值表示操作结果：offer(E)的返回值fasle表示入队列失败，poll()返回null表示队列为空。

阻塞队列按照其存储空间的容量是否受限制来划分，可分为有界队列和无界队列。有界队列的存储容量限制是由应用程序指定的，无界队列的最大存储容量为Integer.MAX_VALUE(2^31 - 1)个元素。
有界队列可以使用ArrayBlockingQueue或者LinkedBlockingQueue来实现。LinkedBlockingQueue能实现无界队列，也能实现有界队列。
![[Pasted image 20240412153505.png]]
## 异步计算助手：FutureTask
FutureTask.done() 方法中的代码可能需要再调用FutureTask.get()前调用FutureTask.done()方法中的代码可能需要再调用FutureTask.get()前调用FutureTask.isCancelled()来判断任务是否被取消，以免FutureTask.get()调用抛出CancellationException异常(运行时异常)。
## 可重复执行的异步任务
FutureTask基本上是被设计用来表示一次性执行任务的，其内部会维护一个表示任务运行状态 (包括开始运行、已经运行结束等)的状态变量，FutureTask.run()在执行任务处理逻辑前会先判断任务的运行状态，如果该任务已经被执行过，那么FutureTask.run()会直接返回。
## 计划任务
`ScheduledExecutorService`接口定义的方法按其功能可分为以下两种。
- 延迟执行提交的任务。这包括以下两个方法：
```java
<V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit);

ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit);
```
- 周期性地执行提交的任务。这包括以下两个方法：
```java
ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay, long period, TimeUnit unit);

ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay, long delay, TimeUnit unit);
```
```ad-note
**注意**
一个任务的执行耗时超过period或者delay所表示的时间只会导致该任务的下一次执行时间被相应地推迟，而不会导致该任务被并发执行。
```

## 任务执行结果处理、异常处理与任务取消
延迟执行的任务最多会被执行一次，因此利用schedule方法的返回值(ScheduledFuture实例)便能获取这种计划任务的执行结果、执行过程中抛出的异常以及取消任务的执行。周期性执行的任务会不断地被执行，直到任务被取消或者相应方法的ShceduledExecutorService实例被关闭。因此，scheduleAtFixedRate方法、scheduleWithFixedDelay方法的返回值(`ScheduledFuture<?>`)能够取消相应的任务，但是它无法获取计划任务的一次或者多次的执行结果。如果我们需要对周期性执行的计划任务的执行结果进行处理，那么可以考虑AsyncTask来表示计划任务。
```ad-note
**注意**
即使我们在创建ScheduledExecutorService实例的时候指定一个线程工厂，并使线程工厂未其创建的线程关联一个UncaughtExceptionHandler，当计划任务抛出未捕获异常的时候该UncaughtExceptionHandler也不会被ScheduledExecutorService实例调用。
提交给ScheduledExecutorService执行的计划任务在其执行过程中如果抛出未捕获异常(Uncaught Exception)，那么该任务后续就不会再被执行。
```

## java异步编程总结：
![[Pasted image 20240415152458.png]]
## 多线程程序测试
应对多线程程序测试的困难性的常用措施包括：提高代码的可测试性、使用静态检查工具、代码复审以及选用简单有效的多线程测试工具。
## 可测试性
- 抽象(Abstraction) 与实现 (Implementation)分离。
- 数据与数据来源分离。
- 依赖注入(Dependency Injection)。一来注入使得我们对一个对象进行单元测试时可以使用一个测试桩(Stub)对象来替代该对象的真实依赖，从而简化了单元测试。
- 关注点分离(Separation Of Concern)。在多线程程序中，将程序中的功能型关注点与线程相关的性能关注点分离可以极大地提高代码的可测试性。
- 使工作者线程数可以配置。
## 静态检查工具：FindBugs

## 多线程程序的单元测试：JCStress
JCStress提供了一组注解和工具类，这极大地简化了测试代码编写。

| 注解/类                                          | 解释                                                    |
| --------------------------------------------- | ----------------------------------------------------- |
| @JCSTress                                     | 代表被注释的类是一个JCStress测试用例                                |
| @State                                        | 代表被注释的类包含共享状态                                         |
| @Actor                                        | 代表被注释的方法为并发操作                                         |
| @Arbiter                                      | 相当于一种特殊的@Actor，其注释的方法会在同一个测试用例内所有@Actor注释的并发操作结束后才被执行 |
| @Outcome                                      | 代表被注释的测试用例(类)的可能输出结果及其是否可接受                           |
| IntResult1、IntResult2、LongResult1、LongResult2 | 这些代表测试的结果                                             |


# 多线程编程的硬件基础与Java内存模型
## 高速缓存
![[Pasted image 20240416111120.png]]
缓存条目可被进一步划分为Tag、Data Block以及Flag这三个部分，其中Data Block也被称为缓存行(Cache Line)，它是高速缓存与主内存之间的数据交换最小单元，用于存储从内存中读取的或者准备写入内存的数据。Tag则包含了与缓存行中数据相应的内存地址的部分信息，Flag用于表示相应缓存行的状态信息。
![[Pasted image 20240416111514.png]]
通过lscpu命令可以在linux系统中查看缓存层级。
## 缓存一致性协议（Cache Coherence Protocol）
MESI(Modified-Exclusive-Shared-Invalid)协议是一种广为使用的缓存一致性协议，x86处理器所使用的缓存一致性协议就是基于MESI协议的。MESI协议对内存数据访问的控制类似于读写锁，它使得针对同一地址的读内存操作是并发的，而针对同一地址的写内存操作是独占的，即针对同一内存地址进行的写操作在任意一个时刻只能够由一个处理器执行。在MESI协议中，一个处理器往内存中写数据时必须持有该数据的所有权。
在Processor 0读取内存的时候，即便Processor 1对响应的内存数据进行了更新且这种更新还停留在Processor 1的高速缓存中而造成高速缓存与主内存中的数据不一致，在MESI消息的协调下这种不一致也并不会导致Processor 0读取到一个过时的旧值。
## 硬件缓冲区：写缓冲器与无效化队列
![[Pasted image 20240416135246.png]]
引入写缓冲器之后，处理器在执行写操作时会做这样的处理：如果相应的缓存条目状态为E或者M，那么处理器可能会直接将数据写入相应的缓存行而无须发送任何消息；如果相应的缓存条目状态为S，那么处理器会先将写操作的相关数据(包括数据和待操作的内存地址)存入写缓冲器的条目之中，并发送Invalidate消息；如果相应的缓存条目为I，我们就成相应的写操作遇到了写未命中，那么此时处理器会先将写操作相关的数据存入写缓冲器的条目之中，并发送Read Invalidate消息。
一个处理器接收到其他处理器所回复的针对同一个缓存条目的所有Invalidate Acknowledge消息的时候，该处理器会将写缓冲器中针对相应地址的写操作结果写入相应的缓存个行中，此时写操作对其执行处理器之外的其他处理器来说才算是完成的。
由此可见，写缓冲器的引入使得处理器在执行写操作的时候可以不等待Invalidate Acknowledge消息，从而减少了写操作的延时，这使得写操作的执行处理在其他处理器回复Invalidate Acknowledge/Read Response消息这段时间内能够执行其他指令，从而提高了处理器的指令执行效率。
引入无效化队列(Invalidate Queue)之后，处理器接收到Invalidate消息之后并不删除消息中指定地址对应的副本数据，而是将消息存入无效化队列之后就恢复Invalidate Acknowledge消息，从而减少了写操作执行处理器所需的等待时间。有些处理器(比如x86)可能没有使用无效化队列。
写缓冲器和无效化队列引入又会带来一些新的问题 ---- 内存重排序和可见性问题。
## 存储转发
处理器在执行读操作的时候会根据相应的内存地址查询写缓冲器，如果写缓冲器存在相应的条目，呢么该条目所代表的写操作的结果数据就回直接作为该读操作的结果返回，否则，处理器才从高速缓存中读取数据。

写缓冲器是造成内存可见性问题的根本，因此为了保障可见性，编译器等底层系统需要借助一类被称为内存屏障的特殊指令，内存屏障中的存储屏障(Store Barrier) 可以使执行该指令的处理器冲刷其写缓冲器。
冲刷写缓冲只解决了可见性问题的一半，另一半是无效化队列导致的。无效化队列的引入本身也会导致新的问题 ---- 处理器在执行内存读取操作前如果没有根据无效化队列中的内容将该处理器上高速缓存中的相关副本数据删除，那么就可能导致该处理器读到的数据是过时的旧数据，从而使得其他处理器所做的更新丢失。加载屏障(Load Barrier)会更具无效化队列内容所制定的内存地址，将相应处理器上的高速缓存中相应的缓存条目的状态都标记为I，从而使该处理器后续执行针对相应地址的读内存操作时必须发送Read消息，以将其他处理器对相关共享变量所做的更新同步到该处理器的高速缓存中，我们需要清空该处理器上的写缓冲器以及无效化队列。
## 基本内存屏障
处理器支持那种内存重排序(LoadLoad从排序、LoadStore重排序、StoreStore重排序和StoreLoad重排序)，就会提供能够禁止相应才重排序的指令，这些指令就被称为基本内存屏障。
编译器(JIT编译器)、运行时(Java虚拟机)和处理器都会尊重内存屏障，从而保障其作用得以落实。
- LoadLoad屏障是通过清空无效化队列来实现禁止LoadLoad重排序的。
- StoreStore屏障可以通过对写缓冲器中的条目进行标记来实现禁止StoreStore重排序。
- 就处理器的具体实现而言，许多处理器往往将StoreLoad屏障实现为一个通用基本内存屏障,即StoreLoad屏障能够实现其他3种基本内存屏障的效果。但是StoreLoad屏障的开销也是最大的，StoreLoad屏障会使无效队列被清空，并将写缓冲器中的条目冲刷(写入)高速缓存。
## Java同步机制与内存屏障
Java虚拟机对synchronized、volatile和final关键字的语义实现就是借助内存屏障的。获取屏障和释放屏障相当于由基本内存屏障组合而成的符合屏障。获取屏障相当于LoadLoad屏障和LoadStore屏障的组合，它能够禁止该屏障之前的任何读操作与该屏障之后的任何读、写操作之间进行重排序。释放屏障相当于LoadStore屏障和StoreStore屏障的组合，它能够禁止该屏障之前的任何读、写操作与该屏障之后的任何写操作之间进行重排序。
## volatile关键字的实现
Java虚拟机(JIT)在volatile变量写操作之前插入的释放屏障使得该屏障之前的任何读、写操作都先于这个volatile变量写操作被提交，而虚拟机(JIT)在volatile变量读操作之后插入的获取屏障使得这个volatile变量的读操作先于该屏障之后的任何读、写操作被提交。写线程和读线程各通过各自执行的释放屏障和获取屏障保障了有序性。
写线程、读线程通过释放屏障和获取屏障的这种配对使用保障了读线程对写线程执行的写操作的感知顺序与程序顺序一致，即保障了有序性。
Java虚拟机(JIT)会在volatile变量写操作之后插入一个StoreLoad屏障。该屏障不仅禁止该屏障之后的任何读操作与该屏障之前的任何写操作(包括该volatile写操作)之间进行重排序，它还起到以下两个作用。
- 充当存储屏障。StoreLoad屏障通过清空其执行处理器的写缓冲器使得该屏障前的所有写操作的结果得以大大告诉缓存，从而使得这些更新对其他处理器而言是可同步的。
- 充当加载屏障，以消存储转发的副作用。这是利用了StoreLoad屏障能够清空无效队列的功能，从而使其他处理器对volatile变量所做的更新能够被同步到volatile变量读线程的执行处理器上。（这是在同一个处理器上读取同一个volatile变量需要保证可见性。）
Java虚拟机(JIT)在volatile变量读操作前插入的一个加载屏障相当于LoadLoad屏障，它通过清空无效化队列来使得其后的读操作有机会读取到其他处理器对共享变量所做的更新。(保证其他处理器读取该volatile变量时的可见性。)
```ad-note
由于x86处理器仅支持StoreLoad重排序，因此在x86处理器下Java虚拟机会将LoadLoad屏障、LoadStore屏障以及StoreStore屏障映射为空指令。也就是说，x86处理器下的Java虚拟机无须再volatile读操作前、volatile读操作以及volatile写操作前插入任何指令，而只需要在volatile写操作后插入一个StoreLoad屏障，这个屏障在Hotspot虚拟机中是由一个Lock前缀的空操作指令充当的。
```
## synchronized关键字的实现
Java虚拟机(JIT)会在monitorenter对应的指令后临界区开始前的地方插入一个获取屏障。Java虚拟机会在临界区结束后monitorexit对应的指令前的地方插入一个释放屏障。这里，获取屏障和释放屏障一起保障了临界区内的任何读、写操作都无法被重排序到临界区之外，再加上锁的排他性，这使得临界区内的操作具有原子性。
## final关键字的实现
Java虚拟机会在final字段初始化之后插入一个StoreStore屏障以禁止final字段初始化以及该操作之前的所有写操作和对象发布之间的重排序(包括指令重排序和内存重排序)。由于某些处理(比如x86处理器)可能不支持StoreStore重排序，因此运行在这种处理器上的Java虚拟机只需要保障其JIT编译器不讲final字段的初始化操作重排序到其构造器结束之后，而无需插入相应的StoreStore屏障。
## Java内存模型 
内存一致性模型(Memory Consistency Model)，也被称为内存模型(Memory Model)。
不同的处理器架构有着不同的内存模型，因此这些处理器对有序性的保障程度各异。Java作为一个跨平台的语言，为了屏蔽不同处理器的内存模型差异，它必须定义自己的内存模型，这个模型就被称为Java内存模型。
## happen(s)-before关系
Java标准库类也定义了一些happens-before规则，这些规则建立在Java内存模型所定义的基本happens-before规则只上。
这些happens-before规则最终是由Java虚拟机、编译器以及处理器一同协作来落实的，而内存屏障则是Java虚拟机、编译器和处理器之间的 "沟通"纽带。
## 对象的安全发布
程序顺序规则与happens-before关系的传递性，使得锁对可见性和有序性的保障从临界区内扩展到临界区之前。这才是对象安全发布的实质 --- 不仅仅使一个对象的引用对其他线程可见，还要保障该对象的引用对其他线程课件钱，发布线程对该对象所执行的操作对其他线程来说是可见且有序的。

```ad-note
**提示**
- 程序顺序规则与happens-before关系的传递性，使得volatile关键字/锁对可见性和有序性的保障从临界区内扩展到临界区之前。
- 对象的安全发布不仅仅意味着使一个对象的引用对其他线程可见，它还意味着我们要保障该对象的引用对其他线程课件钱，发布线程对该对象所执行的操作对其他线程来说是可见且有序的。
```
## JSR 133
为了修复早期Java内存模型中存在的缺陷，JSR 133(133号Java Specification Request，又被称为Java Memory Model) 为Java语言定义了一个新的内存模型。
## 小结
![[Pasted image 20240417184201.png]]
# Java多线程程序的性能调校
## Java虚拟机对内部锁的优化
自Java 6/Java 7开始，Java虚拟机对内部锁的实现进行了一些优化。这些优化主要保罗锁消除(Lock Elision)、锁粗化(Lock Coarsening)、偏向锁(Biased Locking)以及适应性锁(Adaptive Locking)。这些优化仅在Java虚拟机server模式下起作用。
## 锁消除
![[Pasted image 20240418135123.png]]
锁消除优化所依赖的逃逸分析技术自Java SE 6u23起默认是开启的，但是锁消除优化是在Java 7开始引入的。
锁消除优化还可能需要以JIT编译器的内联优化为前提。而一个方法是否被JIT编译器内联取决于改方法的热度以及该方法对应的字节码尺寸(Bytecode Size)。
在锁消除的作用下，利用ThreadLocal将一个线程安全的对象 (比如Random)作为一个线程特有对象来使用，不仅仅可以避免锁的争用，还可以彻底消除这些对象内部使用的锁的开销。
## 锁粗化(Lock Coarsening/Lock Merging)
对于相邻的几个同步块，如果这些同步块使用的是同一个锁实例，那么JIT编译器会将这些同步块合并为一个大同步块，从而避免了一个线程反复申请、释放同一个锁所导致的开销。
![[Pasted image 20240418140457.png]]
锁粗化默认是开启的。开启关闭的虚拟机参数分别为：-XX:+EliminateLocks,-XX:-EliminateLocks
## 偏向锁
Java虚拟机在实现monitorenter字节码和monitorexit字节码时需要借助一个原子操作(CAS操作),这操作代价相对来说比较昂贵。因此，Java虚拟机会为每个对象维护一个偏好(Bias),即一个对象对应的内部锁第一次被一个线程获得，那么这个线程就会被记录为该对象的偏好线程(Biased Thread)。这个线程后续无论是再次申请锁还是释放该锁，都无须借助原先昂贵的原子操作，从而减少了锁的申请与释放的开销。
当一个对象的偏好线程以外的其他线程申请该对象的内部锁时，Java虚拟机需要收回(Revoke)该对象对原偏好线程的"偏好"并重新设置该对象的偏好线程。这个偏好收回和重新分配的过程的代价也是比较昂贵的，因此，偏向锁优化只适合于存在相当大一部分锁并没有被争用的系统之中。
偏向锁优化默认是开启的。开启和关闭偏向锁的虚拟机参数分别为：`-XX:+UseBiasedLocking`/`-XX:-UseBiasedLocking`
## 适应性锁
适应性锁(Adaptive Locking,也被称为Adaptive Spinning)是JIT编译器对内部锁实现锁做的一种优化。
存在锁争用的情况下，一个线程申请一个锁的时候如果这个锁恰好被其他线程持有，那么这个线程就需要等待该锁被其持有线程释放。实现这种等待的一种保守方法时将这个线程暂停(现成的生命周期状态变为非Runnable状态)。由于暂停线程会导致上下文切换，因此对于一个具体锁实例来说，这种策略比较适合于系统中绝大多数线程度该锁的持有时间较长的场景这样才能抵消上下文切换的开销。另一种实现方法就是采用忙等(Busy Wait)。忙等是通过反复执行空操作直到所需的条件成立为只而实现等待的。这种策略的好处是不会导致上下文切换，缺点是比较耗费处理器资源。
Java虚拟机会根据其运行过程中收集到的信息来判断这个锁是属于被线程持有时间"较长"的还是"较短"的。对于被线程持有时间"较长"的锁，Java虚拟机会选用暂停等待策略；而对于被线程持有时间"较短"的锁，Java虚拟机会选用忙等等待策略。Java虚拟机也可能先采用忙等待策略，在忙等失败的情况下再采用暂停等待策略。Java虚拟机的这种优化就被称为适应性锁(Adaptive Locking)，这种优化同样也需要JIT便器接入。

## 锁的开销与锁争用见识
锁的开销包括以下几个方面
- 上下文切换与线程调度开销。
- 内存同步、编译器优化受限的开销。
- 限制可伸缩性。
锁的开销主要体现在争用所(Contened Lock)上面，因此，减少锁的开销的一个基本思路就是消除锁的使用(使用锁的替代品)或者降低锁的争用程度。
就具体实现而言，降低锁的争用程度可以从减小临界区长度以及减小锁的粒度着两个方面入手。另外，我们也可以从减少线程所需申请的锁的数量或者通过使用锁的替代品来减少乃至避免锁的开销。
## 使用可参数化锁
如果一个方法或者类内部使用的锁实例可以由该方法、类的客户端代码指定，那么我们就称这个锁是可参数化的，相应的，这个锁就被称为可参数化的锁。可参数化的锁在特定情况下有助于减少线程执行过程中参与的锁实例的个数，从而减少锁的开销。
例如Writer抽象类可以通过子类化修改lock对象，就是可以通过实例化之类，在子类中将锁修改为调用方传入的锁，由于锁的可重入行，print方法执行线程在已经持有this所代表的锁的情况下重新申请/释放这个锁的开销已经降低了不少。
从面相对象编程的角度来看，使用可参数化锁一定程度上破坏了封装性。假如指定的锁实例被其他代码不恰当地使用了，那么可参数化锁的使用可能会增加锁的争用。
## 减小临界区的长度
减小临界区的长度可以减少锁被持有的时间从而降低锁被争用的概率，这有利于减少锁的开销。
## 减小锁的粒度
降低锁的争用程度的另外一种思路是降低锁的申请频率。而减小锁的粒度可以降低锁的申请频率，从而减小锁被争用的概率。减小锁粒度的一种常见方法时将一个粒度较粗的锁拆分成若干粒度更细的锁，其中每个锁仅负责保护原粗粒度锁所保护的所有共享变量中的一部分共享变量。这种技术被称为锁拆分技术(Lock Splitting)。
![[Pasted image 20240418175947.png]]
锁拆分这种技术可以演进为另外一种被称为锁分段的技术。锁分段(Lock Striping)是指对同一个数据结构内不同部分的数据使用不同锁实例进行加锁的技术。ConcurrentHashMap内部就使用了锁分段技术。
![[Pasted image 20240418185734.png]]
锁分段会使对整个对象进行加锁变得困难甚至于不可能。
## 减少系统内耗：上下文切换
由于锁的争用会导致上下文切换，因此减少锁的争用或者避免锁的使用都可以减少上下文切换。另外，我们也可以从以下几个方面入手来减少上下文切换。
- 控制线程数量。
- 避免在临界区中执行阻塞式I/O等阻塞操作。避免在临界区中执行阻塞式I/O等阻塞操作的典型技巧是在多线程环境中特意使用单线程来执行I/O操作。
- 避免在临界区中执行比较耗时的操作。
- 减少Java虚拟机的垃圾回收。
## 性能的隐形杀手：伪共享
由于一个缓存行中可以存储多个变量的副本，因此即便是在两个线程各自仅访问各自的共享变量(它们之间不存在共同的共享变量)的情况下，一个线程更新其共享变量可能导致另外一个线程访问其共享变量时产生缓存未命中，这种现象就被称为伪共享(False Sharing)。
伪共享会导致缓存未命中，从而降低处理器执行内存读、写操作的效率。
## Java对象内存布局
为了提高内存访问的效率并减少由此导致的内存空间的浪费，Java虚拟机会依照一定的规则将一个对象的对象头及该对象包含的实例字段分配到内存空间中进行存储。
**规则1** 对象是以8字节为粒度(Granularity)进行对齐(Aligned)的。
**规则2** 对象中的实力字段按照如下顺序而非源代码声明顺序排列。
- long型变量和double型变量
- int型变量和float变量
- short型变量char型变量
- boolean型变量和byte型变量
- 引用型变量
**规则3** 继承自父类的实例字段不会与类本身定义的实例字段混杂在一起进行存储。
## 伪共享的侦测与消除
消除伪共享的一个方法就是填充(Padding)。填充就是通过在类中添加一些"无用的"实例变量来"干扰"对象的内存布局，以使特定的实力变量能够独自占用一个缓存行的空间，从而避免和谐实例变量与其他实例变量被加载到同一个缓存行之中。
与其他多线程有关的问题类似，伪共享问题由于与缓存行宽度以及对象的具体内存布局有关，因此也不是必然出现的。
Java8根据JDK第142号增强提案引入了一个特殊的注解`@sun.mis.Contened`，该注解可以用来注释字段和类。该注解的作用是给Java虚拟机一个提示---被注释的字段或者类的实力可能面临伪共享问题。Java虚拟机则根据这个注解进行填充来使得被注释的实力变量或者类的实力能够被加载到单独的缓存行之中。由于目前默认情况下该注解仅开放给JDK内部的类，因此，应用自身的类要使用该注解时需要开启Java虚拟机的开关"-XX:-RestrictContended"。
## 小结
![[Pasted image 20240419163856.png]]
## 为并发而生的CompletableFuture和结合器
采用CompletableFuture#thenCombine()方法来组合多个CompletableFuture，避免了调用Future#get()方法带来的阻塞消耗。
![[Pasted image 20240527181503.png]]
如果需要处理大量的Future对象，那么在这种情况下，避免由于调用get()产生的阻塞、并发性的损失甚至是死锁，使用CompletableFuture以及接合器通常是最佳的选择。

注意，阻塞和非阻塞通常用于描述操作系统的某种I/O实现。这些术语也常常等价地用在非I/O的上下文中，即 "异步调用" 和 "同步调用"。
## Future错误处理
如果CompletableFuture#comlete()之前发生了异常，会导致执行任务的线程被杀死，如果get()是没有带超时时间的调用，会导致调用get方法的客户端永久地的被阻塞。
可以在客户端调用get()方法带超时时间的重载版本来避免永久阻塞的问题，等到超时后get将抛出TimeoutException。但是如果希望客户端获悉出了什么异常，需要使用CompletableFuture的completeExceptionlly方法，该方法会将导致CompletableFuture内发生问题的异常抛出到客户端。
## 使用工厂方法supplyAsync 创建CompletableFuture
`supplyAsync`方法接受一个生产者(Supplier) 作为参数，返回一个CompletableFuture对象，该对象完成异步执行后会读取调用生产者方法的返回值。生产者方法会交由ForkJoinPool池中的某个执行线程运行，但是可以使用supplyAsync方法的重载版本，传递第二个参数指定不同的执行线程执行生产方法。工厂方法创建的CompletableFuture已经提供了错误管理机制。
如果你进行的是计算密集型的操作，并且没有I/O，那么推荐使用Stream接口，因为实现简单，同时效率也可能是最高的。
反之，如果你并行的工作单元还涉及等待IO的操作(包括网络连接等待)，那么使用CompletableFuture灵活性更好。这种情况不适用并行流的另一个原因是，处理流的流水线中如果发生I/O等待，流的延迟特性会让我们很难判断到底什么时候触发了等待。

直到调用的CompletableFuture执行结束，使用的thenApply方法都不会阻塞你代码的执行。这意味着，CompletableFuture最终结束运行时，我们希望传递Lambda表达式给thenApply方法调用。

thenCompose方法允许你对两个异步操作进行流水线，第一个操作完成时，将其结果作为参数传给第二个操作。CompletableFuture还提供了一个带Async结尾的thenComposeAsync方法，还提供了其他方法的带Async结尾的方法。通常来说，名称总不带Async的方法和它的前一个任务一样，在同一个线程中运行，而名称Async结尾的方法会将后续任务提交到一个线程池，所以每个任务是由不同的线程处理的。

## 将两个CompletableFuture对象整合起来，无论它们是否存在依赖
如果两个CompletableFuture没有依赖关系，而且并不希望等到第一个任务完全结束才开始第二个任务。这种情况下，应该使用thenCombine方法，它接受名为BiFunctin的第二个参数，这个参数定义了当两个CompletableFuture对象完成计算后，结果如何合并。和thenCompose方法一样，thenCombine方法也提供了一个Async的版本，这里，如果使用thenCombineAsync会导致BiFunction中定义的合并操作被提交到线程池中，那么由另一个任务异步的方式执行。
## 高效地使用超时机制
Java 9通过CompletableFuture提供了多个方法，可以更加灵活地设置线程的超时机制。orTimeout在指定的超时导到时，会通过ScheduledThreadExecutor线程结束该CompletableFuture对象，并抛出一个TimeoutException异常，它的返回值是一个新的CompletableFuture独享。
## 响应CompletableFuture的completion事件
CompletableFuture的thenAccept方法接受CompletableFuture执行完毕后的返回值做参数。和之前的thenCompose和thenCombine方法一样，thenAccept方法也提供了一个异步版本，名为thenAcceptAsync。异步版本的方法会对处理结果的消费者进行调度，从线程池找那个选择一个新的线程继续执行，不再由同一个线程完成CompletableFuture的所有任务。
allOf工厂方法接受一个由CompletableFuture构成的数组，数组中的所有CompletableFuture对象执行完成之后，它返回一个CompletableFuture<Void>对象。如果对allOf方法返回的CompletableFuture执行join操作，表示要等到数组中的所有CompletableFuture全部执行完毕。
而在另一些场景中，你可能希望只要CompletableFuture对象数组中有任何一个执行完毕就不再等待，在这种情况下，可以使用一个类似的工厂方法anyOf。





