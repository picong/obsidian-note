HyperLolog并不是一种新的数据结构 (实际类型为字符串类型)， 而是一种基数算法，通过HyperLogLog可以利用极小的内存空间完成独立总数的统计，数据集可以是IP、Email、Id等等。HyperLogLog提供了3个命令：pfadd、pfcount、pfmerge。例如2016-03-06的访问用户是uuid-1、uuid-2、uuid-3、uuid-4,2016-03-05的访问用户是uuid-4、uuid-5、uuid-6、uuid-7，如图3-15所示。

## 7.3. Is Set-up the Right Thing for You ?
We already know now that it is usually a good thing to make sure that we test a "fresh" SUT and collaborators before putting them through their paces with our test methods. However, this raises the question of how this has been achieved. And this is where some issues arise.
As we already know, JUnit creates a new instance of a test class before each of its methods is executed. This allows us to create the SUT and collaborators in different places. Firstly, we could create the SUT and collaborators along with their declaration as instance members. Secondly, we could create objects within test methods. Thirdly, we could create objects within the specialized set-up methods. Last, but not least, we could combine all of these options. Let us take a closer look at these alternatives.
This is true, but not something you should worry about. From my experience, such situations (where onw assertion failure "hides" another failures), is more than rare - in fact I can not recall it ever happened to me. I shield myself from such effect, writing assertions one by one, and following the TDD rhythm. Of course, this does not defend me against such effect, when I introduce some changes to an existing calss. However, as stated previously, I believe this threat to be more of theoretical, than practical meaning.

- that the SUT must be created before injection happens (see the example in Listing 9.10)
- that Mockito uses relection, which can lower code coverage measures (and that it bypasses setters)

在上一篇文章中，我和你介绍了间隙锁和next-key lock的概念，但是并没有说明加锁规则。间隙锁的概念理解起来确实有点儿难，尤其在配合上行锁以后，很容易在判断是否会出现锁等待的问题上犯错。
所以今天，我们就先从这个加锁规则开始吧。
首先说明一下，这下加锁规则我没在别的地方看到类似的总结，以前我自己判断的时候都是想着代码里面的实现来脑补的。这次为了总结成不看代码的同学也能理解规则，是我又重新刷了代码临时总结出来的。所以，这个规则又以下两条前提说明：
