LocalDate、LocalTime、LocalDateTime、Instant、Duration以及Period

通过LocalDate#atTime方法或者LocalTime#atDate方法，可以创建一个LocalDateTime对象。也可以通过LocalDateTime#toLocalDate方法或者LocalDateTime#toLocalTime方法，从LocalDateTime中提取LocalDate或者LocalTime组件。

作为人类，我们习惯了星期几，几号，几点，几分这样的方式理解日期和时间，但是从计算机的角度来看，建模时间最自然的格式是表示一个持续时间段上某个点的单一大整型数。这也是java.time.Instant类对时间建模的方式，基本上它是以Unix元年时间(传统的设定为UTC时区1970年1月1日午夜时分)开始所经历的秒数进行计算。

可以通过Duration或Period来使用Instant
目前为止，上面所有看到的类都实现了Temporal接口，Temporal接口定义了如何读取和操纵为时间建模的对象的值。创建两个Temporal对象之间的Duration，可以通过Duration的between方法来实现，但是由于LocalDateTime和Instant是为了不同的目的而设计的，因此二者不能混用，此外，因为Duration类主要用于以秒和纳秒衡量时间的长短，所以不能仅向between方法传递一个LocalDate对象做参数。
如果需要以年、月或者日的方式对多个时间单位建模，那么可以使用Period类。
**以下是日期-时间类中表示时间间隔的通用方法：**

| 方法名          | 是否是静态方法 | 方法描述                                 |
| ------------ | ------- | ------------------------------------ |
| between      | 是       | 创建两个时间点之间的interval                   |
| from         | 是       | 由一个临时时间点创建的interval                  |
| of           | 是       | 由它的组成部分创建interval的实例                 |
| parse        | 是       | 由字符串创建interval的实例                    |
| addTo        | 否       | 创建该interval的副本，并将其叠加到某个指定的temporal对象 |
| get          | 否       | 读取该interval的状态                       |
| isNegative   | 否       | 检查该interval是否为负值，不包含零                |
| isZero       | 否       | 检查该interval的时长是否为零                   |
| minus        | 否       | 通过减去一定的时间创建该interval的副本              |
| multipliedBy | 否       | 将interval的值乘以某个标量创建该interval的副本      |
| negated      | 否       | 以忽略某个时长的方式创建该interval的副本             |
| plus         | 否       | 以增加某个指定的时长的方式创建该interval的副本          |
| substrctFrom | 否       | 从指定的temporal对象中减去该interval           |

### 操纵、解析和格式化日期
下面是表示时间点的日期-时间类的通用方法：

| 方法名      | 是否是静态方法 | 方法描述                                                                  |
| -------- | ------- | --------------------------------------------------------------------- |
| between  | 是       | 依据传入的Temporal对象创建对象实例                                                 |
| from     | 是       | 依据传入的Temporal对象创建实例                                                   |
| now      | 是       | 依据系统时钟创建Temporal对象                                                    |
| of       | 是       | 由Temporal对象的某个部分创建该对象的实例                                              |
| parse    | 是       | 由字符串创建Temporal对象的实例                                                   |
| atOffset | 否       | 将Temporal对象和某个时区便宜相结合                                                 |
| atZone   | 否       | 将Temporal对象和某个时区相结合                                                   |
| format   | 否       | 使用某个指定的格式器将Temporal对象转换为字符串(Instant类不提供该方法)                           |
| get      | 否       | 读取Temporal对象的某一部分的值                                                   |
| minus    | 否       | 创建Temporal对象的一个副本，通过将当前Temporal对象的值减去一定的时长创建该副本                       |
| plus     | 否       | 创建Temporal对象的一个副本，通过将当前Temporal对象的值加上一定的时长创建该副本                       |
| with<br> | 否       | 以该Temporal对象为模版，对某些状态进行修改创建该对象的副本创建该interval的副本，并将其创建该interval的副本，并将其 |

### 使用TemporalAdjuster
截至目前，你所看到的所有日期操作都是相对比较直接的。有的时候，你需要进行一些更加复杂的操作，比如，将日期调整到下个周日、下个工作日，或者是本月的最后一天。这时，你可以使用重载版本的with 方法，向其传递一个提供了更多定制化选择的TemporalAdjuster 对象，更加灵活地处理日期。对于最常见的用例，日期和时间API已经提供了大量预定义的TemporalAdjuster。你可以通过TemporalAdjusters类的静态工厂方法访问它们。
```java
mport static java.time.temporal.TemporalAdjusters.*;
LocalDate date1 = LocalDate.of(2014, 3, 18);       ←---- 2014-03-18LocalDate date2 = date1.with(nextOrSame(DayOfWeek.SUNDAY));       ←----2014-03-23LocalDate date3 = date2.with(lastDayOfMonth());       ←---- 2014-03-31
```
### 打印输出以及解析日期-时间对象
处理日期和时间对象时，格式化以及解析日期-时间对象是另一个非常重要的功能。新的java.time.format包就是特别为这个目的而设计的。这个包中最重要的类就是DateTimeFormatter。创建格式器最简单的方法是通过它的静态工厂方法以及常量。
当然也可以通过DateTimeFormatterBuilder来构建更加复杂的格式化器。

### 使用时区
![[Pasted image 20250219113847.png]]
### 利用UTC/格林尼治时间的固定偏差计算时区
另一种比较通用的表达时区的方式是利用当前时区和UTC/格林尼治的固定偏差。比如，基于这个理论，你可以说 "纽约落后于伦敦5小时"。