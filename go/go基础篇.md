## go的常用配置项
![[Pasted image 20250619095010.png]]
## 通过go mod构建模块
```shell
# 初始化go模块
go mod init github.com/picong/hellomodule

# 自动添加和删除依赖
go mod tidy

# 构建
go build main.go
```
- Go包是Go语言的基本组成单元。一个Go程序就是一组包的集合，所有Go代码都位于包中；
- Go源码可以导入其他Go包、Go模块，并使用其中的导出语法元素(首字母大写)，包括类型、变量、函数、方法等，而且，main函数是整个Go应用的入口函数。
- Go源码需要先编译，再分发和运行。如果是单Go源文件的情况，我们可以直接使用go build + Go源文件名的方式编译。不过，对于复杂的Go项目，我们需要在Go Module的帮助下完成项目的构建。

在通过go mod init为当前Go项目创建一个新的module后，随着项目的演进，我们在日常开发过程中，会遇到多种常见的维护Go Module的场景。

其中最常见的就是为项目添加一个依赖包，我们可以通过go get命令手工获取该依赖包的特定版本，更好的方法是通过go mod tidy命令让Go命令自动去分析新依赖并决定使用新依赖的哪个版本。

另外，还有几个场景需要你记住：

- 通过go get我们可以升级或降级某依赖的版本，如果升级或降级前后的版本不兼容，这里千万注意别忘了变化包导入路径中的版本号，这是Go语义导入版本机制的要求；
- 通过go mod tidy，我们可以自动分析Go源码的依赖变更，包括依赖的新增、版本变更以及删除，并更新go.mod中的依赖信息。
- 通过go mod vendor，我们依旧可以支持vendor机制，并且可以对vendor目录下缓存的依赖包进行自动管理。
```shell
# 查看依赖模块的所有版本号
go list -m -versions github.com/sirupsen/logrus

# 手动降级或者升级到v1.9.3版本
go get github.com/sirupsen/logrus@v1.9.3
# 或者使用下面的命令是等价的

go mod edit -require=github.com/sirupsen@v1.9.3
go mod tidy

# 在vendor目录下，创建了一份这个项目的依赖包的副本，并且通过vendor/modules.txt记录了vendor下的module以及版本
go mod vendor
# 通过下面命令来检索vendor中缓存的依赖进行构建
go build -mod=vendor
```
## Go项目的布局标准
### 可执行项目的布局标准如下
```shell
$tree -F exe-layout 
exe-layout
├── cmd/
│   ├── app1/
│   │   └── main.go
│   └── app2/
│       └── main.go
├── go.mod
├── go.sum
├── internal/
│   ├── pkga/
│   │   └── pkg_a.go
│   └── pkgb/
│       └── pkg_b.go
├── pkg1/
│   └── pkg1.go
├── pkg2/
│   └── pkg2.go
└── vendor/
```
### 库项目的典型结构布局
```shell
$tree -F lib-layout 
lib-layout
├── go.mod
├── internal/
│   ├── pkga/
│   │   └── pkg_a.go
│   └── pkgb/
│       └── pkg_b.go
├── pkg1/
│   └── pkg1.go
└── pkg2/
    └── pkg2.go
```

### 小结
首先，对于以生产可执行程序为目的的Go项目，它的典型项目结构分为五部分：
- 放在项目顶层的Go Module相关文件，包括go.mod和go.sum；
- cmd目录：存放项目要编译构建的可执行文件所对应的main包的源码文件；
- 项目包目录：每个项目下的非main包都"平铺"在项目的根目录下，每个目录对应一个Go包；
- internal目录：存放仅项目内部引用的Go包，这些包无法被项目之外引用；
- vendor目录：这是一个可选目录，为了兼容Go 1.5引入的vendor构建模式而存在的。这个目录下的内容均由Go命令自动维护，不需要开发者手动干预。
第二，对于以生产可复用库为目的的Go项目，它的典型结构则要简单许多，我们可以直接理解为在Go可执行程序项目的基础上去掉cmd目录和vendor目录。

## Go语言构建进化史
Go语言最初发布时内置的构建模式为GOPATH构建模式。在这种构建模式下，所有构建都离不开GOPATH环境变量。在这个模式下，Go编译器并没有关注依赖包的版本，开发者也无法控制第三方依赖的版本，导致开发者无法实现可重现的构建。

那么，为了支持可重现构建，Go 1.5版本引入了vendor机制，开发者可以在项目目录下缓存项目的所有依赖，实现可重现构建。但vendor机制依旧不够完善，开发者还需要手工管理vendor下的依赖包，这就给开发者带来了不小的心智负担。

后来，Go 1.11版本中，Go核心团队推出了新一代构建模式：Go Module以及一系列创新机制，包括语义导入版本机制、最小版本选择机制等。语义导入版本机制是Go Moudle其他机制的基础，它是通过在包导入路径中引入主版本号的方式，来区别同一个包的不兼容版本。而且，Go命令使用**最小版本选择**机制进行包依赖版本选择，这和当前主流编程语言，以及Go社区之前的包依赖管理工具使用的算法都有点不同。
![[Pasted image 20250619141346.png]]
**如上图所示，符合项目整体要求的"最小版本"是v1.3.0。**

此外，Go命令还可以通过GO111MODULE环境变量进行Go构建模式的切换。但你要注意，从Go 1.11到Go 1.16，不同的Go版本在GO111MODULE为不同值的情况下，开启的构建模式以及具体表现行为也几经变化，这里你重点看一下前面总结的表格。

现在，Go核心团队已经考虑在后续版本中彻底移除GOPATH构建模式，Go Module构建模式将成为Go语言唯一的标准构建模式。所以，**建议你从现在开始就彻底抛弃GOPATH构建模式，全面使用Go Module构建模式**。

## go程序的执行次序
### go包的初始化次数
![[Pasted image 20250619165828.png]]
- 依赖包按"深度优先"的次序进行初始化；
- 每个包内按以"常量 -> 变量 -> init函数"的顺序进行初始化；
- 包内的多个init函数按出现次序进行自动调用。
### **init函数的用途**
- 重置包级变量值
```go
func init() {
    CommandLine.Usage = commandLineUsage // 重置CommandLine的Usage字段，将CommandLine与包变量Usage关联在一起了，当用户自定义的usage复制给了flag.Usage后，就相当于改变了默认代表命令行标志集合的CommandLine变量的Usage
}

func commandLineUsage() {
    Usage()
}

var Usage = func() {
    fmt.Fprintf(CommandLine.Output(), "Usage of %s:\n", os.Args[0])
    PrintDefaults()
}
```
- 实现对包级变量的复杂初始化
- 在init函数中实现"注册模式"
```go
import (
    "database/sql"
    _ "github.com/lib/pq"
)

func main() {
    db, err := sql.Open("postgres", "user=pqgotest dbname=pqgotest sslmode=verify-full")
    if err != nil {
        log.Fatal(err)
    }
    
    age := 21
    rows, err := db.Query("SELECT name FROM users WHERE age = $1", age)
    ...
}
//-------------------------------
// qp包是空导入，但是pq包中的会init方法会被执行，用来将pq自己实现的sql驱动注册到sql包中
func init() {
    sql.Register("postgres", &Driver{})
}
```
### 小结
重点关注init函数具备的几种行为特征：
- 执行顺位排在包内其他语法元素的后面；
- 每个init函数在整个Go程序生命周期内仅会被执行一次；
- init函数是顺序执行的，只有当一个init函数执行完毕后，才会去执行下一个init函数。
## 变量声明
![[Pasted image 20250620170103.png]]
## 代码块与作用域
代码块有显式与隐式之分，显式代码块就是包裹在一对配对大括号内部的语句序列，而隐式代码块则不容易肉眼分辨，它是通过Go语言规范明确规定的。隐式代码块有五种，分别是宇宙代码块、包代码块、文件代码块、分支控制语句隐式代码块，以及switch/select的子句隐式代码块，理解隐式代码块是理解代码块概念以及后续作用域概念的前提与基础。

作用域的概念是Go源码编译过程中标识符（包括变量）的一个属性。Go编译器会校验每个标识符的作用域，如果它的使用范围超出其作用域，编译器会报错。

不过呢，我们可以使用代码块的概念来划定每个标识符的作用域。划定原则就是声明于外层代码块中的标识符，其作用域包括所有内层代码块。但是，Go的这种作用域划定也带来了变量遮蔽问题。简单的遮蔽问题，我们通过分析代码可以很快找出，复杂的遮蔽问题，即便是通过go vet这样的静态代码分析工具也难于找全。

因此，我们只有了解变量遮蔽问题本质，在日常编写代码时注意同名变量的声明，注意短变量声明与控制语句的结合，才能从根源上尽量避免变量遮蔽问题的发生。

## map
**注意：函数类型、map类型以及切片类型是不能作为map的key类型的，这些类型只能和nil进行 == 、!=操作**

Go运行时使用一张哈希表来实现抽象的map类型。运行时实现了map类型操作的所有功能，包括查找、插入、删除等。在编译阶段，Go编译器会将Go语法层面的map操作，重写成运行时对应的函数调用。大致的对应关系是这样的：
```go
// 创建map类型变量实例
m := make(map[keyType]valType, capacityhint) → m := runtime.makemap(maptype, capacityhint, m)

// 插入新键值对或给键重新赋值
m["key"] = "value" → v := runtime.mapassign(maptype, m, "key") v是用于后续存储value的空间的地址

// 获取某键的值 
v := m["key"]      → v := runtime.mapaccess1(maptype, m, "key")
v, ok := m["key"]  → v, ok := runtime.mapaccess2(maptype, m, "key")

// 删除某键
delete(m, "key")   → runtime.mapdelete(maptype, m, “key”)
```
下图是map类型在Go运行时实现的示意图：
![[Pasted image 20250623165401.png]]
hmap的结构的初始状态解释：
![[Pasted image 20250623180606.png]]

bucket中tophash区域是用来快速定位key位置的：
![[Pasted image 20250623181119.png]]
**key存储区域：**
当我们声明一个map类型变量，比如var m map[string]int时，Go运行时就会为这个变量对应的特定map类型，生成一个runtime.maptype实例。如果这个实例已经存在，就会直接复用。maptype实例的结构是这样的：
```go
type maptype struct {
    typ        _type
    key        *_type
    elem       *_type
    bucket     *_type // internal type representing a hash bucket
    keysize    uint8  // size of key slot
    elemsize   uint8  // size of elem slot
    bucketsize uint16 // size of bucket
    flags      uint32
} 
```
**Go运行时就是利用maptype参数中的信息确定key的类型和大小的。** map所用的hash函数也存放在maptype.key.alg.hash(key, hmap.hash0)中。同时maptype的存在也让Go中所有map类型都共享一套运行时map操作函数，而不是像C++那样为每种map类型创建一套map操作函数，这样就节省了对最终二进制文件空间的占用。

**value存储区域**
和key一样，这个区域的创建也是得到了maptype中信息的帮助。Go运行时采用了把key和value分开存储的方式，而不是采用一个kv接着一个kv的kv紧邻方式存储，这带来的其实是算法上的复杂性，但却减少了因内存对齐带来的内存浪费。
![[Pasted image 20250623181353.png]]
另外，还有一点我要跟你强调一下，如果key或value的数据长度大于一定数值，那么运行时不会在bucket中直接存储数据，而是会存储key或value数据的指针。目前Go运行时定义的最大key和value的长度是这样的：
```go
// $GOROOT/src/runtime/map.go
const (
    maxKeySize  = 128
    maxElemSize = 128
)
```

**map扩容**
当**count > LoadFactor * 2^B**或overflow bucket过多时，运行时会自动对map进行扩容。目前Go最新1.17版本LoadFactor设置为6.5（loadFactorNum/loadFactorDen）。这里是Go中与map扩容相关的部分源码：
```go
// $GOROOT/src/runtime/map.go
const (
	... ...

	loadFactorNum = 13
	loadFactorDen = 2
	... ...
)

func mapassign(t *maptype, h *hmap, key unsafe.Pointer) unsafe.Pointer {
	... ...
	if !h.growing() && (overLoadFactor(h.count+1, h.B) || tooManyOverflowBuckets(h.noverflow, h.B)) {
		hashGrow(t, h)
		goto again // Growing the table invalidates everything, so try again
	}
	... ...
}
```
这两方面原因导致的扩容，在运行时的操作其实是不一样的。如果是因为overflow bucket过多导致的“扩容”，实际上运行时会新建一个和现有规模一样的bucket数组，然后在assign和delete时做排空和迁移。

如果是因为当前数据数量超出LoadFactor指定水位而进行的扩容，那么运行时会建立一个**两倍于现有规模的bucket数组**，但真正的排空和迁移工作也是在assign和delete时逐步进行的。
原bucket数组会挂在hmap的oldbuckets指针下面，直到原buckets数组中所有数据都迁移到新数组后，原buckets数组才会被释放。
![[Pasted image 20250623181540.png]]
**map不支持并发的读写/写写并发操作**
并发下面的读写错做可以使用[sync.Map](https://pkg.go.dev/sync#Map)来代替。

### 小结
- 不要依赖map的元素遍历顺序；
- map不是线程安全的，不支持并发读写；
- 不要尝试获取map中元素（value）的地址。


## 结构体
对于结构体这类复合类型，我们通过类型字面值方式来定义，它包含若干个字段，每个字段都有自己的名字与类型。如果不包含任何字段，我们称这个结构体类型为空结构体类型，空结构体类型的变量不占用内存空间，十分适合作为一种“事件”在并发的Goroutine间传递。

当我们使用结构体类型作为字段类型时，Go还提供了“嵌入字段”的语法糖，关于这种嵌入方式，我们在后续的课程中还会有更详细的讲解。另外，Go的结构体定义不支持递归，这点你一定要注意(但是可以引用本身类型的指针)。

结构体类型变量的初始化有几种方式：零值初始化、复合字面值初始化，以及使用特定构造函数进行初始化，日常编码中最常见的是第二种。支持零值可用的结构体类型对于简化代码，改善体验具有很好的作用。另外，当复合字面值初始化无法满足要求的情况下，我们需要为结构体类型定义专门的构造函数，这种方式同样有广泛的应用。

结构体类型是既数组类型之后，又一个以平铺形式存放在连续内存块中的类型。不过与数组类型不同，由于内存对齐的要求，结构体类型各个相邻字段间可能存在“填充物”，结构体的尾部同样可能被Go编译器填充额外的字节，满足结构体整体对齐的约束。正是因为这点，我们在定义结构体时，一定要合理安排字段顺序，要让结构体类型对内存空间的占用最小。
