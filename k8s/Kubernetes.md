kubernetes机构图
![[Pasted image 20240603114424.png]]
Kubernetes由Master和Node两张节点组成，而这两种角色分别对应着控制节点和计算节点。
Master组成：`负责API服务的kube-apiserver`、`负责调度的kube-scheduler`、`负责容器编排的kube-controller-manager`。
整个集群的持久化数据，则由kube-apiserver处理后保存在Etcd中。
**在Kubernetes项目中，kubelet只要负责跟容器运行时(比如Docker项目)打交道。**
**kubelet通过gRPC协议跟一个叫做Device Plugin的插件进行交互。**
**kubelet的另一个重要功能，则是调用网络插件和存储插件为容器配置网络和持久化存储。**
Kubernetes项目最主要的设计思想是，从更宏观的角度，以统一的方式来定义任务之间的各种关系，并且为将来支持更多种类的关系留有余地。
**Service服务的主要作用，就是作为Pod的代理入口(Portal)，从而代替Pod对外暴露一个固定的网络地址。**
Kubernetes项目核心功能的"全景图":
![[Pasted image 20240603142332.png]]
## 除了应用与应用之间的关系外，应用运行的形态是影响"如何容器化这个应用"的第二个重要因素。
为此，Kubernetes定义了新的、基于Pod改进后的对象。比如Job，用来描述一次性运行的Pod(比如，大数据任务)；再比如DaemonSet，用来描述每个宿主机上必须且只能运行一个副本的守护进程服务；又比如CronJob，则用于描述定时任务等等。
在Kubernetes中的使用方法：
- 首先，通过一个"编排对象"，比如Pod、Job、CronJob等，来描述你试图管理的应用；
- 然后，再为它定义一些"服务对象",比如Service、Secret、Horizontal Pod Autoscaler(自动水平扩展器)等。这些对象，会负责具体的平台级功能。
上述方法，就是所谓的"声明式API"。这种API对应的"编排对象"和"服务对象",都是Kubernetes项目中的API对象(API Object)。
**容器最典型的特征之一：无状态。**
而容器的持久化存储，就是用来保存容器存储状态的重要手段：存储插件会在容器里挂载一个基于网络或者其他机制的远程数据卷，使得在容器里创建的文件，实际上是保存在远程存储服务器上，或者以分布式的方式保存在多个节点上，而与当前宿主机没有任何绑定关系。这样，无论你在其他哪个宿主机上启动新的容器，都可以请求挂载指定的持久化存储卷，从而访问到数据卷里保存的内容。**这就是"持久化"的含义。**

不推荐是使用`kubectl run`来运行容器，而推荐使用下面的指令来运行容器：
```bash
kubectl create -f 我的配置文件
# 修改配置后，替换原来的pod
kubectl replace -f 我的配置文件
# 推荐使用kubectl apply -f 我的配置文件来进行更新
```
作为用户，我们不必关心当前的操作是创建，还是更新，你执行的命令始终是kubctl apply,而Kubenetes则会根据YAML文件的内容变化，自动进行具体的处理。
一个栗子：
```yaml
apiVersion: apps/v1 
kind: Deployment 
metadata: 
  name: nginx-deployment 
spec: 
  selector: 
    matchLabels: 
      app: nginx 
  replicas: 2 
  template: 
    metadata: 
      labels: 
        app: nginx 
    spec: 
      containers: 
      - name: nginx 
        image: nginx:1.21.3 
        ports: 
        - containerPort: 80 
        volumeMounts: 
        - mountPath: "/usr/share/nginx/html" 
          name: nginx-vol 
      volumes: 
      - name: nginx-vol 
        hostPath: 
          path: /var/data
```
所谓Deployment，是一个定义了多副本应用(即多个副本Pod)的对象。此外，Deployment还负责在Pod定义发生变化时，对每个副本进行滚动更新(Rolling Update)。

一个Kubernetes的API对象的定义，大多可以分为Metadata 和 Spec两个部分。前者存放的是这个对象的元数据，对所有API对象来说，这部分的字段和格式基本上是一样的；而后者存放的，则是属于这个对象独有的定义，用来描述它所要表达的功能。

查询对应label的pod列表的命令：
```bash
kubectl get pods -l app=nginx
```
查看具体pod的详情的命令：
```bash
kubectl describe pod pod名称
```
从Kubernetes集群中删除这个Nginx Deployment，执行：
```bash
kubectl delete -f nginx-deployment.yaml
```

```ad-info
volumes中的emptyDir类型是什么：
它其实就等同于我们之前讲过的Docker的隐式Volume参数，即：不显示声明宿主机目录的Volume。所以，Kubenetes也会在宿主机上创建一个临时目录，这个目录将来会被绑定挂载到容器所声明的Volume目录上。
```

**在Kubernetes中，我们经常会看到它通过一种API对象来管理另一种API对象，比如Deployment和Pod之间的关系；而由于Pod是"最小"的对象，所以它往往都是被其他对象控制的。这种组合方式，正是Kubernetes进行容器编排的重要模式。**
想这样的Kubenetes API独享，往往由Metadata 和 Spec两部分组成，其中Metadata里的 Labels字段是Kubenetes过滤对象的主要手段。
在这些字段里面，容器想要使用的数据卷，也就是Volume，正是Pod的Spec字段的一部分。而Pod里的每个容器，则需要显示的声明自己要挂在哪个Volume。

## Pod的实现原理
首先，关于Pod最重要的一个事实是：它只是一个逻辑概念。
Pod，其实是一组共享了某些资源的容器。
具体的说：**Pod里的所有容器，共享的是同一个Network Namespace，并且并可以声明共享同一个Volume。**
![[Pasted image 20240604114638.png]]
在Kubernetes中，Infra容器永远都是第一个被创建的容器，这样才能保证Pod里面的容器能够通过Join Network Namespace的方式与Infra容器的网络处于同一Namespace下面，可以通过localhost进行本地通信。

共享Volume就简单多了：Kubernetes项目只要把所有Volume的定义都设计在Pod层级即可。
Pod里的容器只要声明挂载同一个Volume，就一定可以共享这个Volume对应的宿主目录。
下面的声明中，Tomcat容器启动时，它的webapps目录下就一定会存在sample.war文件：这个文件正是WAR包容器启动时拷贝到这个volume里面的，而这个Volume是被这连个容器共享的。我们用Init Container的方式优先运行WAR包容器，扮演了一个sidecar的角色。
Dockerfile的内容如下：
![[Pasted image 20240604162124.png]]
tomcat的pod声明如下：
![[Pasted image 20240604162029.png]]
## NodeSelector:一个供用户将Pod与Node进行绑定的字段
```yaml
apiVersion: v1
kind: Pod
...
spec:
	nodeSelector:
	disktype: ssd
```
**NodeName** ：一旦Pod的这个字段被赋值，Kubernetes就回认为这个Pod已经经过调度了。
**HostAliases: 定义了Pod的hosts文件(比如/etc/hosts)里的内容**，用法如下：
```yaml

apiVersion: v1
kind: Pod
...
spec:
	hostAliases:
	- ip: "10.1.2.3"
	  hostnames:
	  - "foo.remote"
	  - "bar.remote"
...
```
**凡是跟容器的Linux Namespace相关的属性，也一定是Pod级别的。**
**凡是Pod中的容器要共享宿主机的Namespace，也一定是Pod级别的定义。**

kubernetes中，有几种特殊的volume，它们存在的意义不是为了存数据，而是提前准备数据，然后投射(Project)到容器当中。
Kubernetes支持的Projected Volume一共有四种：
1. Secret：它的作用，是帮你把Pod想要访问的加密数据，存放到Etcd中。然后，你就可以通过Pod的容器里挂载Volume的方式，访问到这些Secret里保存的信息了；
3. ConfigMap: 它与Seceret的区别在于，ConfigMap保存的是不需要加密的、应用所需的配置信息;
4. Downward API: 它的作用是，让Pod里的容器能够直接获取到这个Pod API对象本身的信息;
5. ServiceAccountToken：它就是Kubernetes系统内置的一种"账户服务"，它是Kubernetes进行权限分配的对象，它其实是一种特殊的Secret。
需要注意的是，Downward API能够获取到的信息，一定是Pod里的容器进程启动之前就能够确定下来的信息。如果想获取如PID这类信息，可以考虑在Pod里定义一个sidecar容器。
**这种把Kubernetes客户端以容器的方式运行在集群里，然后使用default Service Account自动授权的方式，被称作"InClusterConfig"，也是最推荐的进行Kubernetes API变成的授权方式。**

Pod的恢复过程，永远都是发生在当前节点上，而不会跑到别的节点上去。一旦一个Pod与一个节点(Node)绑定，除非这个绑定发生了变化(pod.spec.node字段被修改)，否则它永远都不会离开这个节点。如果你想让Pod出现在其他的可用节点上，就必须使用Deployment这样的"控制器"来管理Pod，哪怕你只需要一个Pod副本。
## restartPlolicy和Pod里容器的状态，以及Pod状态的对应关系
1. **只要Pod的retartPolicy指定的策略允许重启异常的容器(比如：Always)，那么这个Pod就会保持Running状态，并进行容器重启。** 否则，Pod就会进入Failed状态。
2. **对于包含多个容器的Pod，只有它里面所有容器都进入异常状态后，Pod才会进入Failed状态。** 在次之前，Pod都是Running状态。此时，Pod的READY字段会显示正常容器的个数。
## livenessProbe 可以通过在容器中执行命令、发起Http请求、监听端口方式来进行健康检查，从而影响Pod的声明周期
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: test-liveness-exec
spec:
  containers:
  - name: liveness
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
```
发起http请求：
```yaml
...
livenessProbe:
     httpGet:
       path: /healthz
       port: 8080
       httpHeaders:
       - name: X-Custom-Header
         value: Awesome
       initialDelaySeconds: 3
       periodSeconds: 3
```
监听端口：
```yaml
...
    livenessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 15
      periodSeconds: 20
```
## readinessProbe检查结果的成功与否，决定的这个Pod是不是能通过Service的方式访问到，而并不影响Pod的声明周期。

通过PodPreset对象，凡是想在开发人员编写的Pod里追加的字段，都可以通过这种方式来预定好，比如下面这个yaml:
```yaml
apiVersion: settings.k8s.io/v1alpha1
kind: PodPreset
metadata:
  name: allow-database
spec:
  selector:
    matchLabels:
      role: frontend
  env:
    - name: DB_PORT
      value: "6379"
  volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```
**PodPreset里定义的内容，只会在Pod API对象被创建之前追加在这个对象本身上，而不会影响任何Pod的控制器的定义。**

对Deployment以及其他类似的控制器，做一个简单总结：
![[Pasted image 20240605145407.png]]
如上图所示，**类似Deployment这样的一个控制器，实际上都是由上半部分的控制器定义(包括期望状态)，加上下半部分的被控制对象的模板组成的。**
一个ReplicaSet对象，其实就是由副本数目的定义和一个Pod模板组成的。Deployment控制器实际操纵的，正式这样的ReplicaSet对象，而不是Pod对象。
![[Pasted image 20240605152346.png]]
ReplicaSet负责通过"控制器模式"，保证系统中Pod的个数永远等于指定的个数。这也正是Deployment只允许容器的restartPolicy=Always的主要原因：只有容器能保证自己始终是Running状态的前提下，ReplicaSet调整Pod的个数才有意义。
通过kubectl edit命令，把API对象的内容下载到本地文件，修改后再提交上去。
```bash
kubectl edit deployment/nginx-deployment
```
**将一个集群中正在运行的多个Pod版本，交替地逐一升级的过程，就是"滚动更新"。**
通过下面的命令滚动查看deployment的状态：
```bash
kubectl rollout status deployment/nginx-deployment
```
直接修改nginx-deployment所使用的镜像的命令：
```bash
kubectl set image deplyment/nginx-deployment nginx=nginx:{version}
```
如果升级失败，可以使用下面的命令把整个Deployment回滚到上一个版本：
```bash
kubectl rollout undo deployment/nginx-deployment
```
通过下面的命令，可以查看每次Deployment变更对应的版本：
```bash
$ kubectl rollout history deployment/nginx-deployment
deployments "nginx-deployment"
REVISION CHANGE-CAUSE
1 kubectl create -f nginx-deployment.yaml --record
2 kubectl edit deployment/nginx-deployment
3 kubectl set image deployment/nginx-deployment nginx=nginx:1.91
```
通过在`kubectl rollout undo` 命令行最后，加上要回滚的指定版本的版本号，就可以回滚到指定版本了：
```bash
kubectl rollout undo deployment/nginx-deployment --to-revision=2
```
让一个Deployment进入一个 "暂停"状态：
```bash
kubectl rollout pause deployment/nginx-deployment
```
pause之后并且这期间我们对Deployment进行了多次修改，然后通过下面的指令来对Deployment进行恢复，多次修改，只会触发一次ReplicaSet的生成：
```bash
kubectl rollout resume deployment/nginx-deployment
```
Deployment对象有一个字段，叫作spec.revisionHistoryLimit，就是Kubernetes为Deployment保留的"历史版本"个数。如果把它设置为0，就再也不能做回滚操作了。

## StatefulSet
**StatefulSet的核心功能，就是通过某种方式记录这些状态，然后在Pod被重新创建时，能够为新Pod恢复这些状态。**
Service是如何被访问到的：
- **第一种方式，是以Service的VIP (Virtual IP，即：虚拟IP)方式。**
- **第二种方式，就是以Service的DNS方式。**
在Service DNS的方式下，具体还可以分为两种处理方法：
第一种处理方法，是Normal Service。这种情况下，访问的服务地址会解析为service的VIP，后面的流程就跟VIP方式一致了。
第二种处理方法，就是Headless Service。这时候访问的DNS记录直接会被解析为这个service代理的某一个Pod的IP地址。
**可以看到，这里的区别在于，Headless Service不需要分配一个VIP，而是可以直接以DNS记录的方式解析出被代理Pod的IP地址。**
下面是一个标准的Headless Service对应的Yaml文件：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
```
下面是一个statefulSet的Yaml文件：
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.9.1
        ports:
        - containerPort: 80
          name: web
```
通过下面命令启动一个退出后就会被删除的一次性Pod（这里需要注意，新版busybox显示会有些问题）：
```bash
kubectl run -i --tty --image busybox:1.28.4 dns-test --restart=Never --rm /bin/sh
```
在这个Pod的容器里面，尝试用nslookup命令，解析一下Pod对应的Headless Service：
```bash
nslookup web-0.nginx

Server: 10.96.0.10

Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name: web-0.nginx

Address 1: 10.244.0.22 web-0.nginx.default.svc.cluster.local

nslookup web-1 nginx
Server: 10.96.0.10

Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name: web-1.nginx

Address 1: 10.244.0.23 web-1.nginx.default.svc.cluster.local
```
**如果通过`kubectl delete pod -l app=nginx` 删除这两个Pod，会发现这两个Pod被删除之后，Kubernetes会按照原先编号的顺序，创建出两个新的Pod。并且，Kubernetes依然为它们分配了与原来相同的"网络身份"：web-0.nginx和web-1.nginx。**
通过这种严格的对应规则，**StatefulSet就保证了Pod网络标识的稳定性。**

通过这种方法，**Kubernetes就成功地将Pod的拓扑状态(比如：那个节点先启动，哪个节点后启动），按照Pod的"名字+编号"的方式固定了下来。**
由于Pod的IP地址并不是固定的，所以，对于"有状态的应用"实例的访问，必须使用DNS记录或者hostname的方式。
## Persistent Volume Claim
PVC其实就是一种特殊的Volume。只不过一个PVC具体是什么类型的Volume，要在跟某个PV绑定之后才知道。
当然，PVC与PV的绑定得以实现的前提是，运维人员已经在系统里创建好了符合条件的PV；或者，你的Kubernetes集群运行在公有云上。
## StatefulSet的工作原理
**首先，StatefulSet的控制器直接管理的是Pod。** 这是因为，StatefulSet里的不同Pod实例，不再像ReplicaSet中那样都是完全一样的，而是有细微区别的。比如，每个Pod的hostname、名字等都是不同的、携带了编号的。而StatefulSet区分这些实例的方式，就是通过在Pod的名字里加上事先约定好的编号。
**其次，Kubernetes通过Headless Service，为这些有编号的Pod，在DNS服务器中生成带有同样编号的DNS记录。** 只要StatefulSet能够保证这些Pod名字里的编号不变，那么Service里类似于web-0.nginx.default.svc.cluster.local这样的DNS记录也就不会变，而这条记录解析出来的Pod的Ip地址，则会随着后端Pod的删除和再创建而自动更新。这当然是Service机制的能力，不需要StatefulSet操心。
**最后，StatefulSet还为每一个Pod分配并创建一个同样编号的PVC。** 这样，Kubenetes就可以通过Persistent Volume机制为这个PVC绑定上对应的PV，从而保证了每一个Pod都拥有一个独立的Volume。
在这种情况下，即使Pod被删除，它所对应的PVC和PV依然会保留下来。所以当这个Pod被重新创建出来之后，Kubernetes会为它找到同样编号的PVC，挂载这个PVC对应的Volume，从而获取到以前保存在Volume里的数据。
下面是statefulSet的Api：
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.3
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

通过`kubectl create/apply` 创建好statefulset之后就会看到Kubernetes里面出现了两个Pvc对象：
```bash
$ kubectl create -f stateful.yaml

$ kubectl get pvc
NAME STATUS VOLUME CAPACITY ACCESS MODES STORAGECLASS VOLUMEATTRIBUTESCLASS AGE
www-web-0 Bound pvc-cf9d92bd-b3ef-4ab1-9a5b-0274cbdd5b94 1Gi RWO standard 11m
www-web-1 Bound pvc-12911131-9326-4fa8-93ba-55ab5dfdaee3 1Gi RWO standard 11m
```
通过下面的命令往两个不同的容器当中的nginx首页写入hostname：
```bash
for i in 0 1; do kubectl exec web-$i -- sh -c 'echo hello $(hostname) > /usr/share/nginx/html/index.html'; done
```
通过下面的命令可以在容器内访问nginx首页：
```bash
for i in 0 1; do kubectl exec -it web-$i -- curl localhost; done
```
然后用下面的命令删除掉pod后，发现再次访问，对应的pod名称的nginx中的首页还是之前的内容：
```bash
$ kubectl delete pod -l app=nginx
$ kubectl exec -it web-0 -- curl localhost

hello web-0
```

只需要修改StatefulSet的Pod模板，就会自动触发 "滚动更新"。
```bash
$ kubectl patch statefulset mysql --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"mysql:5.7.23"}]'

statefulset.apps/mysql patched
```
`kubectl patch` 以"补丁"的方式（JSON格式的）修改一个API对象的指定字段，也就是"/spec/template/spec/containers/0/image"。
修改完成后，StatefulSet Controller就回按照与Pod编号相反的顺序，从最后一个Pod开始，逐一更新这个StatefulSet管理的每一个Pod。如果更新发生了错误，这次"滚动更新"就会停止。StatefulSet的"滚动更新"还允许我们进行更精细的控制，比如金丝雀发布(Canary Deploy) 或者灰度发布，**这意味着应用的多个实例中被指定的一部分不会被更新到最新的版本。**

`kubectl patch` (也可以通过 `kubectl edit`直接编辑这个对象)，修改这个mysql的statefulset的patition后，当我滚动升级的时候，只会对序号大于或者等于2的Pod进行升级。
```bash
$ kubectl patch statefulset mysql -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":2}}}}'

statefulset.apps/mysql patched
```
## DaemonSet
顾名思义，DaemonSet的主要作用，是让你在Kubernetes集群里，运行一个Daemon Pod。所以，这个Pod有如下三个特征：
1. 这个Pod运行在Kubernetes进群里的每个节点(Node) 上；
2. 每个节点上只有一个这样的Pod实例；
3. 当有新的节点加入Kubernetes集群后，该Pod会自动地在新节点上被创建出来；而当旧节点被删除后，它上面的Pod也相应地会被回收掉。

**DaemonSet 其实是一个非常简单的控制器。** 在它的控制循环中，只需要遍历所有节点，然后根据节点上是否有被管理Pod的情况，来决定是否要创建或者删除一个Pod。
只不过，在创建每一个Pod的时候，DaemonSet会自动给这个Pod加上一个nodeAffinity，从而保证这个Pod只会在指定节点上启动。同时，它还会自动给这个Pod加上一个Toleration，从而忽略节点的 unschedulable "污点"。

DaemonSet使用ControllerRevision，来保存和管理自己对应的 "版本"。这种 "面相API对象"的设计思路，大大简化了控制器本身的逻辑，也正是Kubernetes项目 "声明式API"的优势所在。其实，在Kubernetes项目里，ControllerRevision其实是一个通用的版本管理对象。这样，Kubernetes项目就巧妙地避免了每种控制器都要维护一套冗余的代码和逻辑的问题。

## Job 与 CronJob
下面是Job Api对象的对象例子：
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2
  completions: 4
  template:
    spec:
      containers:
      - name: pi
        image: resouer/ubuntu-bc
        command: ["sh", "-c", "echo 'scale=10000; 4*a(1)' | bc -l "]
      restartPolicy: Never
  backoffLimit: 4
```
通过`kubectl create` 成功创建后，通过下面的命令来查看Job对象：
```bash
$ kubectl describe jobs/pi
Name:             pi
Namespace:        default
Selector:         controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
Labels:           controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
                  job-name=pi
Annotations:      <none>
Parallelism:      1
Completions:      1
..
Pods Statuses:    0 Running / 1 Succeeded / 0 Failed
Pod Template:
  Labels:       controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
                job-name=pi
  Containers:
   ...
  Volumes:              <none>
Events:
  FirstSeen    LastSeen    Count    From            SubobjectPath    Type        Reason            Message
  ---------    --------    -----    ----            -------------    --------    ------            -------
  1m           1m          1        {job-controller }                Normal      SuccessfulCreate  Created pod: pi-rq5rl
```
可以看到，这个Job对象在创建后，它的Pod模板，被自动加上了一个controller-uid=<一个随机字符串>这样的Label。而这个Job对象本身，则被自动加上了这个Label对应的Selector，从而保证了Job与它所管理的Pod之间的匹配关系。
在这个例子中，**定义了restartPolicy=Never，那么离线作业失败后 Job Controller就会不断地尝试创建一个新Pod。为了防止无限进行下去，在Job对象的spec.backoffLimit字段里定义了重试次数为4，而这个字段的默认值是6.** 注意：Job Controller重新创建Pod的间隔是呈指数增加的。为了避免Pod一直运行下去，有一个`spec.activeDeadlineSeconds`字段可以设置最长运行时间。
在Job对象中，负责并行控制的参数有两个：
1. spec.parallelism，它定义的是一个Job在任意时间最多可以启动多少个Pod同时运行；
2. spec.completions，它定义的是Job至少要完成Pod数目，即Job的最小完成数。

三种常用的使用Job对象的方法：
**第一种用法：外部管理器 + Job模板** (kubeflow)。这种模式下使用Job对象，completions和paralelism这两个字段都应该使用默认值1，而不应该由我们自行设置。
**第二种用法：拥有固定任务数目的并行Job。** 
**第三种用法，也是很常用的一个用法：指定并行度(parallelism)，但不设置固定的completions的值。** 这种用法，对应的是"任务总数不固定" 的场景。
## CronJob
下面是一个CronJob的Api对象示例：
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```
CronJob与Job的关系，正如同Deployment与Pod的关系一样。CronJob是一个专门用来管理Job对象的控制器。只不过，它创建和删除Job的依据，是schedule字段定义的、一个标准的Unix Cron格式的表达式。

需要注意的是，由于定时任务的特殊性，很可能某个 Job 还没有执行完，另外一个新 Job 就产生了。这时候，你可以通过 spec.concurrencyPolicy 字段来定义具体的处理策略。比如：
1. concurrencyPolicy=Allow，这也是默认情况，这意味着这些 Job 可以同时存在；
2. concurrencyPolicy=Forbid，这意味着不会创建新的 Pod，该创建周期被跳过；
3. concurrencyPolicy=Replace，这意味着新产生的 Job 会替换旧的、没有执行完的 Job。
## 声明式API与Kubernetes编程范式
可以简单的理解为，kubectl replace的执行过程，是使用心得YAML文件中的API对象，**替换原有的API对象；** 而kubectl apply，则是执行了一个**对原有API对象的PATCH操作。**
更进一步地，这意味着kube-apiserver在响应命令式请求的时候，一次只能处理一个写请求，否则会有产生冲突的可能。而对于声明式请求，一次能处理多个写操作，并且具备Merge能力。
**Istio项目使用的，是Kubernetes中的一个非常重要的功能，叫作Dynamic Admission Control。**
- 首先，所谓 "声明式"，指的就是我只需要提交一个定义好的API对象来 "声明"，我所期望的状态是什么样子。
- 其次， "声明式API"允许有多个API写端，以PATCH的方式对API对象进行修改，而无需关心本地原始YAML文件的内容。
- 最后，也是最重要的，有了上述两个能力，Kubernetes项目才可以基于API对象的增、删、改、查，在完全无需外界干预的情况下，完成对 "实际状态" 和 "期望状态" 的调谐(Reconcile)过程。
**Istio项目的核心，就是由无数个运行在应用Pod中的Envoy容器组成的服务代理网格。** 这也正是Service Mesh的含义。
在使用Initializer的流程中，最核心的步骤，莫过于Initializer "自定义控制器"的编写过程。它遵循的，正是标准的 "Kubernetes编程范式"，即：
> **如何使用控制器模式，同Kubernetes里Api对象的 "增、删、改、查" 进行协作，进而完成用户业务逻辑的编写过程。**
## API对象
在Kubernetes项目中，一个API对象在Etcd里的完整资源路径，是由：Group (API组)、Version(API版本) 和 Resource (API资源类型) 三个部分组成的。
通过这样的结构，整个Kubernetes里的所有API对象，实际上就可以用如下的树形结构表示出来：
![[Pasted image 20240613160919.png]]
**Kubernetes是如何对Resource、Group和Version进行解析，从而在Kubernetes项目里找到CronJob(以此资源说明)对象的定义呢？**
- **首先， Kubernetes会匹配API对象的组。**
-  **然后，Kubernetes会进异步匹配到API对象的版本号**
-  **最后，Kubernetes会匹配API对象的资源类型。**

然后APIServer就可以继续创建这个CronJob对象了。下图阐述了这个创建过程：
![[Pasted image 20240613162401.png]]

下图是Kubernetes中一个自定义控制器的工作原理：
![[Pasted image 20240614101216.png]]
```ad-summary
所谓Informer，就是一个自带缓存和索引机制，可以触发Handler的客户端库。这个本地缓存在Kubernetes中一般被称为Store，索引一般被称为Index。

Reflector和Informer之间，用到了一个 "增量先进先出队列" 进行协同。而Informer与你要编写的控制循环之间，则使用了一个工作队列来进行协同。

在实际应用中,除了控制循环之外的所有代码，实际上都是Kubernetes为你自动生成的，即：pkg/client/{informers,listners,clients}里的内容。

而这些自动生成的代码，就为我们提供了一个可靠而高效地获取API对象 "期望状态" 的编程库。

所以，接下来，作为开发者，我们只需要关注如何拿到 "实际状态"，然后如何拿它去跟 "期望状态" 做对比，从而决定接下来要做的业务逻辑即可。

以上内容，就是Kubernetes API编程范式的核心思想。
```

## 基于角色的权限控制:RBAC
1. Role: 角色，定义了一组对Kubernetes API对象的操作权限。
2. Subject：被作用者，既可以是 "人"，也可以是 "机器"，也可以使用Kubernetes里定义的 "用户".
3. RoleBinding：定义了 "被作用者" 和 "角色" 的绑定关系。
**使用Role和RoleBinding的组合，只能控制在同一个Namespace下面生效。**
**对于非Namespaced (Non-namespaced) 对象 (比如：Node)，或者想要作用于所有的Namespace的时候，我们就需要使用ClusterRole和ClusterRoleBinding这两个组合。**
## Operator工作原理
Operator的工作原理：实际上是利用了Kubernetes的自定义API资源 (CRD)，来描述我们想要部署的 "有状态应用"；然后在自定义控制器里，根据自定义API对象的变化，来完成具体的部署和运维工作。可以使用Operator-SDK来生成模板代码，基本自己只需要实现Controller的逻辑。

## PV、PVC、StorageClass的基本概念
PV描述的，是持久化存储数据卷。这个API对象主要定义的是一个持久化存储在宿主机上的目录，比如一个NFS的挂载目录。
通常情况下，PV对象是由运维人员事先创建在Kubernetes集群里待用的。
PVC描述的，则是Pod所希望使用的持久化存储的属性。比如，Volume存储的大小、可读写权限等等。
PVC对象通常由开发人员创建；或者以PVC模板的方式成为StatefulSet的一部分，然后StatefulSet控制器负责创建带编号的PVC。
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    role: web-frontend
spec:
  containers:
  - name: web
    image: nginx
    ports:
      - name: web
        containerPort: 80
    volumeMounts:
        - name: nfs
          mountPath: "/usr/share/nginx/html"
  volumes:
  - name: nfs
    persistentVolumeClaim:
      claimName: nfs
```
可以看到，Pod需要做的，就是在volumes字段里声明自己要使用的PVC名字。接下来，等这个Pod创建之后，kubelet就会把这个PVC所对应的PV，也就是NFS类型的Volume，挂载在这个Pod容器内的目录上。
大多数情况下，持久化Volume的实现，往往依赖于一个远程存储服务，比如：远程文件存储(比如，NFS、GlusterFS)、远程块存储(比如，公有云提供的远程磁盘)等等。

**这个准备"持久化"宿主机目录的过程，我们可以形象地成为"两阶段处理"**
当一个Pod调度到一个节点上之后，kubelet就要负责为这个Pod创建它的Volume目录。
**接下来kubelet的操作，取决于我们Volume的类型。**
如果我们的Volume类型是远程块存储(比如Google Cloud的Persistent Disk)。
- **第一阶段：** 为虚拟机挂载远程磁盘(通过调用远程磁盘服务的接口来完成)，在Kubernetes中，我们把这个阶段称为Attach。
- **第二阶段：** 将磁盘格式化并挂载到Volume宿主机目录上，这个阶段我们一般称为：Mount。
如果Volume类型是远程文件存储(比如NFS)的话，kubelet可以跳过"第一阶段"的操作，这是因为一般来说，远程文件存储并没有一个"存储设备"需要挂载在宿主机上。
实际上，PV的处理流程似乎跟Pod以及容器的启动流程没有太多的耦合，只要kubelet在向Docker发起CRI请求之前，确保"持久化"的宿主机目录已经处理完毕即可。
所以，在Kubernetes中，上述**关于PV的"两阶段处理"流程，是靠独立于kubelet主控制循环(Kubelet Sysnc Loop)之外的两个控制循环来实现的。**

"第一阶段"的Attach(以及Dettach)操作，是由Volume Controller负责维护的，这个控制循环的名字叫作：**AttachDettachContoller**。它的作用，就是不断检查每一个Pod对应的PV，和这个Pod所在宿主机之间挂载的情况，从而决定，是否需要对这个PV进行Attach(或者Dettach)操作。
需要注意，作为Kubernetes内置的控制器，Volume Controller自然是kube-controller-manager的一部分。所以，AttachDetachController也一定是运行在Master节点上的。当然，Attach操作只需要调用公有云或者具体存储项目的API，并不需要在具体的宿主机上执行操作，所以这个设计没有任何问题。
而"第二阶段"的Mount(以及Unmount)操作，必须发生在Pod对应的宿主机上，所以它必须是kubelet组件的一部分。这个控制循环的名字，叫作：VolumeManagerReconciler，它运行起来之后，是一个独立于kubelet主循环的Goroutine。
通过将Volume的处理同kubelet的主循环解耦，Kubernetes就避免了这些耗时的远程挂载操作拖慢kubelet的主控制循环，进而导致Pod的创建效率大幅下降的问题。
**kubelet的一个主要设计原则，就是它的主控制循环绝对不可以被block。**

Dynamic Provisioning机制工作的核心，在于一个名叫StorageClass的API对象。而StorageClass对象的作用，其实就是创建PV的模板。
StorageClass对象会定义如下两个部分内容：
- 第一，PV的属性。比如，存储类型、Volume的大小等等。
- 第二，创建这种PV需要用到的存储插件。比如，Ceph等等。
PVC的spec.storageClass字段的值要和创建的storageClass的name一致，然后根据storage创建出来PV的storageClass字段的值也要保持跟PVC中的storageClass一致。**这是因为，Kubernetes只会将StorageClass相同的PVC和PV绑定起来。**
## 小结
![[Pasted image 20240702162457.png]]
从图中我们可以看到，在这个体系中：
- PVC描述的，是Pod想要使用的持久化存储的属性，比如存储的大小、读写权限等。
- PV描述的，则是一个具体的Volume的属性，比如Volume的类型、挂载目录、远程存储服务器地址等。
- 而StorageClass的作用，则是充当PV的模板。并且，只有属于一个StorageClass的PV和PVC，才可以绑定在一起。
当然，StorageClass的另一个重要作用，是指定PV的Provisioner(存储插件)。这时候，如果你的存储插件支持Dynamic Provisioning的话，Kubernetes就可以自动为你创建PV了。
## Local Persistent Volume
在使用Local Persistent Volume的时候，我们必须想办法推迟这个"绑定"操作。
具体推迟到调度的时候。
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node-1
```

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
StorageClass里的volumeBindingMode=WaitForFirstConsumer的含义，就是告诉Kubernetes里的Volume控制循环：虽然你已经发现这个StorageClass关联的PVC与PV可以绑定在一起，但请不要现在就执行这个绑定操作。
通过这个延迟绑定机制，原本实时发生的PVC和PV的绑定过程，就被延迟到了Pod第一次调度的时候在调度器中进行，从而保证了这个绑定结果不会影响Pod的正常调度。
在具体实现中，调度器实际上维护了一个与Volume Controller类似的控制循环，专门负责为那些声明了"延迟绑定"的PV和PVC进行绑定工作。
通过这样的设计，这个额外的绑定操作，并不会拖慢调度器的性能。而当一个Pod的PVC尚未完成绑定时，调度器也不会等待，而是会直接把这个Pod重新放回到待调度队列，等到下一个调度周期再做处理。
**需要注意的是，手动创建PV的方式，即Static的PV管理方式，在删除PV时需要按照如下流程执行操作：**
1. 删除使用这个PV的Pod；
2. 从宿主机移除本地磁盘(比如，umount它)；
3. 删除PVC；
4. 删除PV。
如果不按照这个流程，这个PV的删除就回失败。
由于手动创建/删除PV的操作比较繁琐，Kubernetes提供了一个Static Provisioner来帮助你管理这些PV。
比如，我们现在的所有磁盘，都挂载在宿主机的/mnt/disks目录下。
那么，当Static Provisioner启动后，它就会通过DaemonSet，自动检查每个宿主机的/mnt/disks目录。然后，调用Kubernetes API，为这些目录下面的每一个挂载，创建一个对应的PV对象出来。
这个PV里的各种定义，比如StorageClass的名字、本地磁盘挂载点的位置，都可以通过Provisioner的配置文件指定(https://github.com/kubernetes-retired/external-storage/tree/master/local-volume/helm)。当然，provisioner也会负责PV的删除工作。

## 存储插件：FlexVolume与CSI
Kubernetes里通过存储插件管理容器持久化存储的原理，可以用下图来进行描述：
![[Pasted image 20240703110617.png]]
可以看到，在上述体系下，无论是FlexVolume，还是Kubernetes内置的其他存储插件，它们实际上担任的角色，仅仅是Volume管理中的"Attach阶段"和"Mount阶段"的具体执行者。而像Dynamic Provisioning这样的功能，就不是存储插件的责任，而是Kubernetes本身存储管理功能的一部分。

相比之下，**CSI插件体系的设计思想，就是把这个Provision阶段，以及Kubernetes里的一部分存储管理功能，从主干代码里剥离出来，做成了几个单独的组件。** 这些组件会通过Watch API监听Kubernetes里与存储相关的事件变化，比如PVC的创建，来执行具体的存储管理动作。
而这些管理动作，比如"Attach 阶段"和"Mount 阶段"的具体操作，实际上就是通过调用CSI插件来完成的。
![[Pasted image 20240703111138.png]]
External Components：
其中，**Driver Registrar组件，负责将插件注册到kubelet里面** (这可以类比为，将可执行文件放在插件目录下)。而在具体实现上，Driver Registrar需要请求CSI插件的Identity服务来获取插件信息。
而**External Provisioner 组件，负责的正是Provision阶段。** 在具体实现上，External Provisioner监听(Watch) 了APIServer里的PVC对象。当一个PVC被创建时，它就会调用CSI Controller的CreateVolume方法，为你创建对应的PV。
**需要注意的是：由于CSI插件是独立于Kubernetes之外的，所以CSI的API里不会直接使用Kubernetes定义的PV类型，而是会自己定义个单独的Volume类型。**
最后一个**External Attacher组件，负责的正是"Attach 阶段"**。在具体是线上，它监听了APIServer里VolumeAttachment对象的变化。VolumeAttachment对象是Kubernetes确认一个Volume可以进入"Attach 阶段"的重要标志。
在实际使用CSI插件的时候，我们会将这个三个External Components作为sidecar容器和CSI插件放置在同一个Pod中。由于External Components对CSI插件的调用非常频繁，所以这种sidecar的部署方式非常高效。

CSI插件里的三个服务：CSI Identity、CSI Controller和CSINode。
其中，**CSI插件的CSI Identity服务，负责对外暴露这个插件本身的信息**
而**CSI Controller服务，定义的则是对CSI Volume (对应Kubernetes里的PV)的管理接口，** 比如：创建和删除CSI Volume、对CSI Volume进行Attach/Dettach (在CSI里，这个操作被叫做Publish/Unpublish)，以及对CSI Volume进行Snapshot等。
不难发现，CSI Controller服务里定义的这些操作有个共同特点，那就是它们都无需在宿主机上进行，而是属于Kubernetes里Volume Controller的逻辑，也就是属于Master 节点的一部分。
需要注意的是，正如我在前面提到的那样，CSI Controller 服务的实际调用者，并不是 Kubernetes（即：通过 pkg/volume/csi 发起 CSI 请求），而是 External Provisioner 和 External Attacher。这两个 External Components，分别通过监听 PVC 和 VolumeAttachement 对象，来跟 Kubernetes 进行协作。
而**CSI Volume需要在宿主机上执行的操作，都定义在了CSI Node服务里**

有了CSI插件之后，Kubernetes本身依然按照前面PV、PVC、StorageClass的方式工作，唯一的区别在于：
- 当AttachDetachController需要进行 "Attach" 操作时，它实际上会执行到pkg/volume/csi目录中，创建一个VolumeAttachment对象，从而触发External Attacher调用CSI Controller服务的ControllerPublishVolume方法。
- 当VolumeManagerReconciler需要进行 "Mount" 操作时，它实际上也会执行到pkg/volume/csi目录中，直接向CSI Node服务发起调用NodePublishVolume方法的请求。

## 同一个宿主机中docker容器网络
![[Pasted image 20240705165121.png]]
在默认情况下，**被限制在Network Namespace里的容器进程，实际上是通过 Veth Pair设备 + 宿主机网桥的方式，实现了跟其他容器的数据交换。**

与之类似地，当在一台宿主机上，访问改宿主机上的容器的IP地址时，这个请求的数据包，也是先根据路由规则到达 docker2 网桥，然后被转发到对应的Veth Pair设备，最后出现在容器里。如下图所示：
![[Pasted image 20240705165538.png]]

如果跨主机间的容器之间的网络，需要通过软件的方式(或者通过路由表配置)，来实现互通：
![[Pasted image 20240705171437.png]]

## 容器跨主机网络
目前，Flannel框架，支持三种后端提供容器网络功能的实现，分别是：
1. VXLAN；
2. host-gw;
3. UDP。
UDP模式：
Flannel会在宿主机上创建出一系列的路由规则，会创建一个flannel0设备(它是一个TUN设备)。在Linux中，TUN设备是一种工作在三层(Network Layer)的虚拟网络设备。TUN设备的功能非常简单，即：**在操作系统内核和用户应用程序之间传递IP包。**
以flannel0设备为例：
像上面提到的情况，当操作系统将一个IP包发送给flannel0设备之后，flannel0就会把这个IP包，交给创建这个设备的应用程序，也就是Flannel进程。这是一个内核态向用户态的流动方向。反之，如果Flannel进程向flannel0设备发送了一个IP包，那么这个IP包就会出现在宿主机网络栈中，然后根据宿主机的路由表进行下一步处理。这是一个从用户态向内核态的流动方向。
flanneld进程又是如何知道这个IP地址对应的容器，是运行在Node X上的呢？
Flannel项目里面有个非常重要的概念：子网(Subnet)。
事实上，在由Flannel管理的容器网络里，一台宿主机上的所有容器，都属于该宿主机被分配的一个"子网"。
而这些子网与宿主机的对应关系，正是保存在Etcd当中：
```shell
$ etcdctl ls /coreos.com/network/subnets
/coreos.com/network/subnets/100.96.1.0-24
/coreos.com/network/subnets/100.96.2.0-24
/coreos.com/network/subnets/100.96.3.0-24
```
key由子网等信息构成，而value正是子网所在的宿主机的ip：
```shell
$ etcdctl get /coreos.com/network/subnets/100.96.2.0-24
{"PublicIP":"10.168.0.3"}
```

下图所示，是基于Flannel UDP模式的跨主通信的基本原理：
![[Pasted image 20240708153359.png]]

实际上，相比于两台宿主机之间的直接通信，基于Flannel UDP模式的容器通信多了一个额外的步骤，即flanneld的处理过程。而这个过程，由于使用到了flannel0这个TUN设备，仅在发出IP包的过程中，就需要经过三次用户态与内核态之间的数据拷贝，如下图所示：
![[Pasted image 20240708153655.png]]
第一次：用户态的容器进程发出的IP包经过docker0网桥进入内核态；
第二次：IP包根据路由表进入TUN (flannel0) 设备，从而回到用户态的flanneld进程；
第三次：flanneld进行UDP封包之后重新进入内核态，将UDP包通过宿主机的eth0发出去。
Flannel对UDP的封装解封装的过程都是由用户态完成的。在Linux系统中，上下文切换和用户态操作的代价其实是比较高的，这也正是造成Flannel UDP模式性能不好的主要原因。(Flannel UDP模式已被废弃)
所以说，**我们在进行系统级编程的时候，有一个非常重要的优化原则，机会要减少用户态到内核态的切换次数，并且把核心的处理逻辑都放在内核态进行。** 这也是为什么，Flannel后来支持的VXLAN模式，逐渐成了主流容器网络方案的原因。
## VXLAN
为了能够在二层网络上打通"隧道"，VXLAN会在宿主机上设置一个特殊的网络设备作为"隧道"的两端。这个设备就叫做VTEP，即：VXLAN Tunnel End Point(虚拟隧道端点)。
而VTEP设备的作用，其实跟前面的flanneld进程非常相似。只不过，它进行封装和解封装的对象，是二层数据帧；而且这个工作的执行流程，全部都是在内核里完成的(因为VXLAN本身就是Liunx内核中的一个模块)。
![[Pasted image 20240708154736.png]]
当新的Node启动并加入Flannel网络之后，在所有其他节点上，flanneld就会添加一条类似如下所示的路由规则：
```shell
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
...
10.1.16.0       10.1.16.0       255.255.255.0   UG    0      0        0 flannel.1
```
这条规则的意思是：凡是发往10.1.16.0/24网路的IP包，都需要经过flannel.1设备发出，并且，它最后被发往的网关地址是：10.1.16.0.
现在已经知道了"目的VTEP设备"的IP地址。需要根据ARP表的功能获取目标VTEP的MAC地址。而这个要用到的ARP记录，也是flanneld进程在Node2节点启动时，自动添加在其他各个节点上的。
```shell
# 在 Node 1 上
$ ip neigh show dev flannel.1
10.1.16.0 lladdr 5e:f8:4f:00:e3:37 PERMANENT
```
![[Pasted image 20240708160153.png]]
上图上Flannel VXLAN模式的内部帧。内部帧的目的MAC地址是目的VTEP的MAC地址，是无法在宿主机二层网路里进行传输。所以接下来，Linux内核还需要再把"内核数据帧"进一步封装成为宿主机网络里的一个普通的数据帧，从而才能通过宿主机的eth0网卡进行传输。
在VXLAN头里有一个重要的标志叫做VNI，它是VTEP设备识别某个数据帧是不是应该归自己处理的重要标识。而在Flannel中，VNI的默认值是1，这也是为何，宿主机上的VTEP设备都叫做flannel.1的原因，这里的"1"，其实就是VNI的值。
**然后，Linux内核会把这个数据帧封装进一个UDP包里发出去。**
这个场景下，flannel.1设备实际上要扮演一个"网桥"的角色，在二层网络进行UDP包的转发。而在Linux内核里面，"网桥"设备进行转发的依据，来自于一个叫做FDB(Forwarding Database)的转发数据库。
这个flannel.1 "网桥"对应的FDB信息，也是flanneld进程负责维护的。它的内容可以通过bridge fdb命令查看到，如下所示：
```shell
# 在 Node 1 上，使用“目的 VTEP 设备”的 MAC 地址进行查询
$ bridge fdb show flannel.1 | grep 5e:f8:4f:00:e3:37
5e:f8:4f:00:e3:37 dev flannel.1 dst 10.168.0.3 self permanent
```

接下来的流程，就是一个正常的、宿主机网络上的封包工作。最终封装完可以通过eth0传输出去的包如下图所示：
![[Pasted image 20240708163318.png]]
这个包经过eth0传输到目的宿主机的eth0网卡后，目的宿主机的内核网络栈会发下这个数据帧里有VXLAN Header，并且VNI=1。所以Linux内核会对它进行拆包，拿到里面的内部数据帧，然后根据VNI值，把它交给目的宿主机上的flannel.1设备。
而flannel.1设备则会进一步拆包，取出 "原始IP包"。接下来就是但是容器网络的处理流程。如上面网络最开始处的图所示。

## 网络模型与CNI网络插件
Kubernetes是通过一个叫作CNI的接口，维护了一个单独的网桥来代替docker0.这个网桥的名字叫作：CNI网桥，它在宿主机上的设备名称默认是：cni0。
![[Pasted image 20240709095113.png]]
CNI的设计思想，就是：**Kubernetes在启动Infra容器之后，就可以直接调用CNI网络插件，为这个Infra容器的Network Namespace，配置符合预期的网络栈。**

在部署Kubernetes的时候，有一个步骤是安装kubernetes-cni包，它的目的就是在宿主机上安装CNI插件所需的基础可执行文件。
```bash
$ ls -al /opt/cni/bin/
total 73088
-rwxr-xr-x 1 root root  3890407 Aug 17  2017 bridge
-rwxr-xr-x 1 root root  9921982 Aug 17  2017 dhcp
-rwxr-xr-x 1 root root  2814104 Aug 17  2017 flannel
-rwxr-xr-x 1 root root  2991965 Aug 17  2017 host-local
-rwxr-xr-x 1 root root  3475802 Aug 17  2017 ipvlan
-rwxr-xr-x 1 root root  3026388 Aug 17  2017 loopback
-rwxr-xr-x 1 root root  3520724 Aug 17  2017 macvlan
-rwxr-xr-x 1 root root  3470464 Aug 17  2017 portmap
-rwxr-xr-x 1 root root  3877986 Aug 17  2017 ptp
-rwxr-xr-x 1 root root  2605279 Aug 17  2017 sample
-rwxr-xr-x 1 root root  2808402 Aug 17  2017 tuning
-rwxr-xr-x 1 root root  3475750 Aug 17  2017 vlan
```
这些CNI的基础可执行文件，按照功能可以分为三类：
**第一类，叫作Main插件，它是用来创建具体网络设备的二进制文件。**
**第二类，叫作IPAM (IP Address Management) 插件，它是负责分配IP地址的二进制文件。**
**第三类，是由CNI社区维护的内置CNI插件。**
从这些二进制文件中，我们可以看到，如果要实现一个给Kubernetes用的容器网络方案，其实需要做两部分工作，以Flannel为例：
首先，实现这个网络方案本身。这一部分需要编写的，其实就是flannld进程里的主要逻辑。比如，创建和配置flannel.1设备、配置宿主机路由、配置ARP和FDB表里的信息等等。
然后，实现网络方案对应的CNI插件。这一部分主要需要做的，就是配置Infra容器里面的网络栈，并把它连接在CNI网桥上。

接下来，需要在宿主机上安装flanneld。而在这个过程中，flanneld启动后会在每台宿主机上生成它对应的CNI配置文件(它其实是一个ConfigMap)，从而告诉Kubernetes，这个集群要使用Flannel作为容器网络方案。
这个CNI配置文件的内容如下所示：
```bash
$ cat /etc/cni/net.d/10-flannel.conflist 
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
```
需要注意的是，在Kubernetes中，处理容器网络相关的逻辑并不会在kubelet主干代码里执行，而是会在具体的CRI (Container Runtime Interface，容器运行时接口)实现里完成。对于Docker项目来说，它的CRI实现叫作dockershim，你可以在kubelet的代码里找到它。
**dockershim 会把这个CNI配置文件加载起来，并且把列表里的第一个插件、也就是flannel插件，设置为默认插件。** 而在后面的执行过程中，flannel和portmap插件会按照定义顺序被调用，从而依次完成"配置容器网络"和"配置端口映射"这两步操作。
CNI插件的工作原理：
当kubelet组件需要创建Pod的时候，它第一个创建的一定是Infra容器。所以在这一步，dockershim就会先调用Docker API创建并启动Infra容器，紧接着执行一个叫作SetUpPod的方法。这个方法的作用就是：为CNI插件准备参数，然后调用CNI插件为Infra容器配置网络。
调用CNI插件所需要的参数分为两部分，分别为：
**第一部分，是由dockershim设置的一组CNI环境变量。** 最重要的环境变量参数叫作：CNI_COMMAND。它的取值只有两种：ADD和DEL。这个ADD和DEL操作，就是CNI插件唯一需要实现的两个方法。ADD操作：把容器添加到CNI网络里；DEL操作的含义是：把容器从CNI网络里移除掉。
**第二部分，则是dockershim从CNI配置文件里加载到的、默认插件的配置信息。** 
这个配置信息在CNI中被叫作Network Configuration，可以参考[https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration]()。dockershim会把Network Configuration 以 JSON数据的格式，通过标准输入的方式传递给Flannel CNI插件。

有了这两部分参数，Flannel会将ADD操作代理给CNI bridge插件，真正执行将容器加入到CNI网络里的这一步操作。
- 首先，CNI bridge插件会在宿主机上检查CNI网桥是否存在。如果没有的话，那就创建它。这相当于在宿主机上执行：
```bash
# 在宿主机上
$ ip link add cni0 type bridge
$ ip link set cni0 up
```
- 接下来，CNI bridge插件会通过Infra容器的Network Namespace文件，进入到这个Network Namespace里面，然后创建一对Veth Pair设备。紧接着，它会把这个Veth Pair的其中一端，"移动"到宿主机上。这相当于在容器里执行如下所示的命令：
```bash
# 在容器里
 
# 创建一对 Veth Pair 设备。其中一个叫作 eth0，另一个叫作 vethb4963f3
$ ip link add eth0 type veth peer name vethb4963f3
 
# 启动 eth0 设备
$ ip link set eth0 up 
 
# 将 Veth Pair 设备的另一端（也就是 vethb4963f3 设备）放到宿主机（也就是 Host Namespace）里
$ ip link set vethb4963f3 netns $HOST_NS
 
# 通过 Host Namespace，启动宿主机上的 vethb4963f3 设备
$ ip netns exec $HOST_NS ip link set vethb4963f3 up 
```
- 接下来，CNI bridge插件就可以把vethb4963f3设备连接在CNI网桥上。这相当于在宿主机上执行：
```bash
# 在宿主机上
$ ip link set vethb4963f3 master cni0
```
在将vethb4963f3设备连接在CNI网桥之后，CNI bridge插件还会为它设置**Hairpin Mode（发夹模式)**。这是因为，在默认情况下，网桥设备是不允许一个数据包从一个端口进来后，再从这个端口发出去的。但是，它允许你为这个端口开启Hairpin Mode，从而取消这个限制。
- 接下来，CNI bridge插件会调用CNI ipam插件，从ipam.subnet字段规定的网段里为容器分配一个可用的IP地址。然后，CNI bridge插件就会把这个IP地址添加在容器的eth0网卡上，同时为容器设置默认路由。这相当于在容器里执行：
```bash
# 在容器里
$ ip addr add 10.244.0.2/24 dev eth0
$ ip route add default via 10.244.0.1 dev eth0
```
- 最后，CNI bridge插件会为CNI网桥添加IP地址。这相当于在宿主机上执行：
```bash
# 在宿主机上
$ ip addr add 10.244.0.1/24 dev cni0
```
- 执行玩上述操作之后，CNI插件会把容器的IP地址等信息返回给dockershim，然后被kuelet添加到Pod的Status字段。
## 总结
Kubernetes网络模型：
1. 所有容器都可以直接使用IP地址与其他容器通信，而无需使用NAT。
2. 所有宿主机都可以直接使用IP地址与所有容器通信，而无需使用NAT。反之依然。
3. 容器自己"看到"的自己的IP地址，和别人 (宿主机或者容器) 看到的地址是完全一样的。

## Kubernetes 三层网络方案
Flannel 的 host-gw模式的原理如下图所示：
![[Pasted image 20240710180705.png]]
当设置Flannel使用host-gw模式后，flanneld会在宿主机上创建这样一条规则，以Node 1为例：
```bash
$ ip route
...
10.244.1.0/24 via 10.168.0.3 dev eth0
```
**host-gw模式的工作原理，其实就是将每个Flannel子网(Flannel Subset，比如：10.244.1.0/24)的"下一跳", 设置成了该子网对应的宿主机的IP地址。**
也就是说，这台"主机"会充当这条容器通信路径里的"网关"（Gateway）。这也正式"host-gw"的含义。Flannel子网和主机的信息，都是保存在Etcd中的。flanneld只需要WATCH这些数据的变化，然后实时更新路由表即可。在这种模式下，容器的通信过程就免除了额外的封包和解包带来的性能损耗。**但是，Flannel host-gw模式必须要求集群宿主机之间是二层连桶的。**

不同于Flannel通过etcd和宿主机上的flanneld来维护路由信息的做法，Calico项目使用了一个"重型武器"(BGP)来自动地在整个集群中分发路由信息。 
BGP的全称是Border Gateway Protocol，即：边界网关协议。它是一个Linux内核原生就支持的、专门用在大规模数据中心里维护不同的"自治系统"之间路由信息的、无中心的路由协议。
在使用了BGP之后，可以认为，在每个边界网关上都会运行这一个小程序，它们会将各自的路由表信息，通过TCP传输给其他的边界网关。而其他边界网关上的这个小程序，则会对收到的这些数据进行分析，然后将需要的信息添加到自己的路由表里。
所以说，**所谓BGP，就是在大规模网络中实现节点路由信息共享的一种协议。**
>需要注意的是，BGP协议实际上是最复杂的一种路由协议。这里的讲述和所举的例子，仅是为了能够帮助你建立对BGP的感性认识，并不代表BGP真正的实现方式。

Calico项目的架构由三个部分组成：
1. Calico的CNI插件。这是Calico与Kubernetes对接的部分。
2. Felix。它是一个DaemonSet，负责在宿主机上插入路由规则，以及维护Calico所需的网络设备等工作。
3. BIRD。它就是BGP的客户端，专门负责在集群中分发路由规则信息。
![[Pasted image 20240710095635.png]]
Calico不会在宿主机上创建任何网桥设备。
可以看到，Calico的CNI插件会为每个容器设置一个Veth Pair设备，然后把其中的一端放置在宿主机上(它的名字以cali前缀开头)。
此外，由于Calico没有使用CNI的网桥模式，Calico的CNI插件还需要在宿主机上为每个容器的Veth Pair设备配置一条路由规则，用于接收传入的IP包。比如，宿主机Node2上的Container 4对应的路由规则，如下所示：
```bash
10.233.2.3 dev cali5863f3 scode link
```
不难发现，Calico项目实际上将集群里的所有节点，都当做边界路由器来处理，它们一起组成了一个全连同的网络，互相之间通过BGP协议交换路由规则。这些节点，我们称之为BGP Peer。
```bash
[BGP 消息]
我是宿主机 192.168.1.3
10.233.2.0/24 网段的容器都在我这里
这些容器的下一跳地址是我
```
**Calico维护的网络在默认配置下，是一个被称为"Node-to-Node Mesh" 的模式。** 但是这种模式下，随着节点数N的增加，这些client之间的连接的数量就会以N^2的规模快速增长，因此，这种模式一般推荐用在少于100个节点的鸡群里。而在更大规模的集群中，需要用到一个叫作Route Reflector的模式。在这种模式下，Calico会指定一个或者几个专门的节点，来负责跟所有节点建立BGP连接从而学习到全局的路由规则。而其他节点，只需要跟这几个专门的节点交换路由信息，就可以获得整个集群的路由规则信息了。
**Calico要保证集群宿主机之间是二层连同的，需要为Calico打开IPIP模式。** 如下图所示：
![[Pasted image 20240710102525.png]]
在Calico的IPIP模式下，Felix进程在Node1上添加的路由规则，会稍微不同，如下所示：
```bash
10.233.2.0/24 via 192.168.2.2 tunl0
```
Calico使用的的这个tunl0设备，是一个IP隧道(IP tunnel)设备。
在上面的例子中，IP包进入IP隧道设备之后，就会被Linux内核的IPIP驱动接管。IPIP驱动会将这个IP包封装在一个宿主机网络的IP包中，如下所示：
![[Pasted image 20240710103055.png]]
如果Calico项目能够让宿主机之间的路由设备(也就是网关)，也通过BGP协议"学习"Calico网络里的路由规则，那么从容器发出的IP包，不就可以直接通过这些设备路由到目的宿主机了么？
遗憾的是，上述流程在Kubernetes被广泛使用的公有云场景里，完全不可行，原因在于：公有云环境下，宿主机之间的网关，肯定不允许用户进行干预和设置。
> 当然，在大多数公有云环境下，宿主机(公有云提供的虚拟机)本身往往就是二层连桶的，所以这个需求也不强烈。

不过，在私有部署的环境下，宿主机属于不同子网 (VLAN) 反而是更加常见的部署状态。这时候，想办法将宿主机网关也加入到BGP Mesh里从而避免使用IPIP，就成了一个非常迫切的需求。

==而在Calico项目中，它已经为你提供了两种将宿主机网关设置成BGP Peer的解决方案。==
**第一种方案，** 就是所有宿主机都跟宿主机网关建立BGP Peer关系。
**第二种方案(更加推荐的方案)，** 使用一个或多个独立组件负责搜集整个集群里的所有路由信息，然后通过BGP协议同步给网关。而在前面提到，在大规模急群中，Calico本身就推荐使用Route Reflector节点的方式进行组网。所以，这里负责跟宿主机网关进行沟通的独立组件，直接由Route Reflector兼任即可。

## Kubernetes网络隔离
在Kubernetes中，网络隔离依赖NetworkPolicyAPI对象来描述，如下为一个完整的NetworkPolicy对象实例：
```bash
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```
**Kubernetes里的Pod默认都是"允许所有" (Accept All) 的，** 即：Pod可以接收来自任何发送方的请求，或者，向任何接收方发送请求。
spec.podSelector字段的作用就是滴定义这个NetworkPolicy的限制范围，比如：当前Namespace里携带了role=db标签的Pod。而如果想要这个NetworkPolicy作用于当前Namespace下的所有Pod，需要向像下面这样设置：
```yml
spec:
 podSelector: {}
```
而一旦Pod被NetworkPolicy选中，**那么这个Pod就会进入"拒绝所有" (Deny All)的状态**
**而NetworkPolicy定义的规则，其实就是"白名单"。**

注意下面两个配置的规则完全不同：
```yml
# 这里namespaceSelector和podSelector是or的关系
  ...
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          user: alice
    - podSelector:
        matchLabels:
          role: client
  ...
```

```yml
# 这里namespaceSelector和podSelector是and的关系
...
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          user: alice
      podSelector:
        matchLabels:
          role: client
  ...
```
在 Kubernetes 生态里，目前已经实现了 NetworkPolicy 的网络插件包括 Calico、Weave 和 kube-router 等多个项目，但是并不包括 Flannel 项目。
**Kubernetes网络插件对Pod进行隔离，其实是靠在宿主机上生成NetworkPolicy对应的iptable规则来实现的。**


## iptables简介
iptables只是一个操作Linux内核Netfilter子系统的"界面"。顾名思义，Netfilter子系统的作用，就是Linux内核里挡在"网卡"和"用户态进程"之间的一道"防火墙"。如下图所示：
![[Pasted image 20240715095206.png]]
![[Pasted image 20240715095712.png]]
可以看到，当一个IP包通过网卡进入主机之后，它就进入了Netfilter定义的流入路径里(InputPath)里。
在这个路径中，IP包要经过路由表路由来决定下一步的去向。而在这次路由之前，Netfilter设置了一个名叫PREROUTING的"检查点"。在Linux内核的实现里，所谓"检查点"实际上就是内核网络协议栈代码里的Hook(比如，在执行路由判断的代码之前，内核会先调用PREROUTING的Hook)。
而在经过路由之后，IP包的去向就分为了两种：
- 第一种，继续在本机处理(IP包继续向上层协议栈流动。)；
- 第二种，被转发到其他目的地(IP包继续在网络层流动，从而进入到转发路径(FORWARD Path)。
iptables表的作用，就是在某个具体的"检查点"(比如Output)上，按顺序执行几个不同的检查动作(比如，先执行nat，再执行filter)。

```bash
iptables -A FORWARD -d $podIP -m physdev --physdev-is-bridged -j KUBE-POD-SPECIFIC-FW-CHAIN
iptables -A FORWARD -d $podIP -j KUBE-POD-SPECIFIC-FW-CHAIN
```
上面第一条iptables FORWARD链"拦截"的是一种特殊情况：它对应的是一台宿主机上容器之间经过CNI网桥进行通信的流入数据包。
而向Calico这样的非网桥模式的CNI插件，就不存在这个情况了。
第二条FORWARD链"拦截"的则是最普遍的情况，即：容器跨主机通信。这时候，流入容器的数据包都要经过路由转发(FORWARD检查点)来的。

而这个KUBE-POD-SPECIFIC-FW-CHAIN 的作用，就是做出"允许"或者"拒绝"的判断。这部分功能的实现，可以简单描述为下面这样的iptables规则：
```bash
iptables -A KUBE-POD-SPECIFIC-FW-CHAIN -j KUBE-NWPLCY-CHAIN
iptables -A KUBE-POD-SPECIFIC-FW-CHAIN -j REJECT --reject-with icmp-port-unreachable
```
在第一条规则里，我们会把IP包转交给前面定义的KUBE-NWPLCY-CHAIN规则去进行匹配。如果匹配成功，那么IP包就会被"允许通过"。
如果匹配事变，IP包就会来到第二条规则上。而这条规则是REJECT规则。即不满足NetworkPolicy定义的请求就会被拒绝掉，从而实现了对该容器的"隔离"。

![[Netfilter-packet-flow.svg]]
## 小结
Kubernetes对Pod进行"隔离"的手段：NetworkPolicy。而NetworkPolicy实际上只是宿主机上的一些列iptables规则。这跟传统IaaS里面安全组(Security Group)其实是非常类似的。
Kubernetes从底层的设计和实现上，更倾向于假设你已经有了一套完整的物理基础设施。然后，Kubernetes负责在此基础上提供一个"弱多租户"(soft multi-tenancy)的能力。
## Service、DNS与服务发现
**Service是由kube-proxy组件，加上iptables来共同实现的。**
一旦Service API yaml文件被提交给Kubernetes，那么kube-proxy就可以通过Service的Informer感知到这样一个Service对象的添加。而作为对这个事件的响应，它就会在宿主机上创建这样一条iptables规则(你可以通过iptables-save看到它)，如下所示：
```bash
-A KUBE-SERVICES -d 10.0.1.175/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-SVC-NWV5X2332I4OT4T3
```
10.0.1.175正是这个Service的VIP。所以这一条规则，就为这个Service设置了一个固定的入口地址。并且，由于10.0.1.175只是一条iptables规则上的配置，并没有真正的网络设备，所以你ping这个地址，是不会有任何响应的。而这条规则即将跳转到的KUBE-SVC-NWV5X2333I4OT4T3规则，实际上是一组规则的集合，如下所示：
```bash
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-WNBA2IHDGP2BOBGZ
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-X3P2623AGDH6CDF3
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -j KUBE-SEP-57KPRZ3JQVENLNBR
```
而这三条链指向的最终目的地，其实就是这个Service代理的三个Pod。所以这一组规则，就是Service实现负载均衡的位置。
**一直以来，基于iptables的Service实现，都是制约Kubernetes项目承载更多量级的Pod的主要障碍。** 因为kube-proxy通过iptables处理Service的过程，其实需要在宿主机上设置相当多的iptables规则。而且，kube-proxy还需要在控制循环里不断地刷新这些规则来确保它们始终是正确的。从而会大量占用该宿主机的CPU资源，甚至会让宿主机"卡"在这个过程中。

而IPVS模式的Service，就是解决上述问题的一个行之有效的方法。
IPVS的工作原理，其实跟iptables模式类似。当我们创建了前面的service之后，kube-proxy首先会在宿主机上创建一个虚拟网卡(叫作：kube-ipvs0)，并为它分配Service VIP作为IP地址。
而接下来，kube-proxy就会通过Linux的IPVS模块，为这个IP地址设置三个IPVS虚拟主机，并设置这三个虚拟主机之间使用轮询模式(rr)来作为负载均衡策略。
相比于iptables，IPVS在内核中的实现其实也是基于Netfilter的NAT模式，所以在转发这一层上，理论上IPVS并没有显著的性能提升。但是，IPVS并不需要在宿主机上为每个Pod设置iptables规则，而是把对这些"规则"的处理放到了内核态，从而极大地降低了维护这些规则的代价。
所以，在大规模集群里，通常建议为kube-proxy设置--proxy-mode=ipvs来开启这个功能。它为Kubernetes集群规模带来的提升，还是非常巨大对 。
## Service与DNS的关系
对于Cluster模式的Service来说，它的A记录的格式是：...svc.cluster.local。当你访问这条A记录的时候，它解析到的就是该Service的VIP地址。
而对于指定了clusterIP=none的Healess Service来说，它的A记录的格式也是：..svc.cluster.local。但是，当你访问这条A记录的时候，它返回的是所有被代理的Pod的IP地址的集合。
此外，对于ClusterIP模式的Service来说，它代理的Pod被自动分配的A记录的格式是：..pod.cluster.local。这条记录指向Pod的IP地址。
而对Headless Service来说，它代理的Pod被自动分配的A记录的格式是：...svc.cluster.local。这条记录也指向Pod的IP地址。
但如果你为Pod指定了Headless Service，并且Pod本身声明了hostname和subdomain字段，那么这个时候Pod的A记录就会变成：`<pod的hostname>.<pod的subdomain>.svc.cluster.local`。
## 小结
我该如何通过一个固定的方式访问到这个Pod呢？
ClusterIP模式的Service为你提供的，就是一个Pod的稳定的IP地址，即VIP。并且，这里Pod和Service的关系是可以通过Label确定的。
而Headless Service为你提供的，则是一个Pod的稳定的DNS名字，并且，这个名字是可以通过Pod名字和Service名字拼接出来的。

## 从外界联通Service与Service调试
如何从外部(Kubernetes集群之外)，访问到Kubernetes里创建的Service？
最常用的一种方式就是：NodePort。配置示例如下所示：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    run: my-nginx
spec:
  type: NodePort
  ports:
  - nodePort: 8080
    targetPort: 80
    protocol: TCP
    name: http
  - nodePort: 443
    protocol: TCP
    name: https
  selector:
    run: my-nginx
```
那么这个时候，要访问这个Service，你只需要访问：
```bash
<任何一台宿主机IP地址(minikube的internal ip)>:8080
```
对于上述NodePort的实现，kube-proxy要做的，就是在每台宿主机上生成一条iptable规则：
```bash
-A KUBE-NODEPORTS -p tcp -m comment --comment "default/my-nginx: nodePort" -m tcp --dport 8080 -j KUBE-SVC-67RL4FN6JRUPOJYM
```
KUBE-SVC-67RL4FN6JRUPOJYM其实就是一组随机模式的iptables规则，所以接下来的流程，就跟ClusterIP模式完全一样了。
需要注意的是，在NodePort方式下，Kubenetes会在IP包离开宿主机发往目的Pod时，对这个IP包做一次SNAT操作，如下所示：
```bash
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE
```
这个SNAT操作只需要对Service转发出来的IP包进行，否则普通的IP包就被影响了。
如果想保证所有Pod通过Service请求之后，一定可以看到真正的、外部client的源地址，需要将**Service的spec.externalTrafficPolicy字段设置为local**。
可以通过下面的命令获取node对应宿主机的内部ip:
```bash
[wftapp@kubespray ~]$ kubectl get node -o wide

NAME STATUS ROLES AGE VERSION INTERNAL-IP EXTERNAL-IP OS-IMAGE KERNEL-VERSION CONTAINER-RUNTIME

node1 Ready,SchedulingDisabled control-plane,master 312d v1.23.7 192.168.4.61 CentOS Linux 7 (Core) 3.10.0-1160.95.1.el7.x86_64 docker://20.10.11

node10 Ready 290d v1.23.7 192.168.4.70 CentOS Linux 7 (Core) 3.10.0-1160.95.1.el7.x86_64 docker://20.10.11

node11 Ready 290d v1.23.7 192.168.4.71 CentOS Linux 7 (Core) 3.10.0-1160.95.1.el7.x86_64 docker://20.10.11

node12 Ready 290d v1.23.7 192.168.4.72 CentOS Linux 7 (Core) 3.10.0-1160.95.1.el7.x86_64 docker://20.10.11

node13 Ready 290d v1.23.7 192.168.4.73 CentOS Linux 7 (Core) 3.10.0-1160.95.1.el7.x86_64 docker://20.10.11
```
## 从外部访问Service的第二种方式，适用于公有云上的Kubernetes服务，这时候，可以指定一个LoadBalancer类型的Service
```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: example-service
spec:
  ports:
  - port: 8765
    targetPort: 9376
  selector:
    app: example
  type: LoadBalancer
```
在公有云提供的Kubernetes服务里，都使用了一个叫作CloudProvider的转接层，来跟公有云本身的API进行对接。所以，在上述LoadBalancer类型的Service被提交后，Kubernetes就会调用CloudProvider在公有云上为你创建一个负载均衡服务，并且把被代理的Pod的IP地址配置给负载均衡服务做后端。
## 第三种方式，是Kubernetes在1.7之后支持的一个新特性，叫作ExternalName。
```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  type: ExternalName
  externalName: my.database.example.com
```
注意，这个YAML文件里不需要指定selector。ExternalName类型的Service，其实是在kube-dns里为你添加了一条CNAME记录。

还可以通过spec.externalIPs字段为Service分配共有IP地址，不过这里kubernetes要求externalIPs必须是至少能够路由到一个Kubernetes节点。
```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 9376
  externalIPs:
  - 80.11.12.10
```
## 小结
Service其实就是Kubernetes为Pod分配的、固定的、基于iptables(或者IPVS)的访问入口。而这些访问入口代理的Pod信息，则来自于etcd，由kube-proxy通过控制循环来维护。
## Ingress
Kubernetes里的Ingress服务的作用，就是全局的、代理不同后端Service而设置的负载均衡器。如下所示为ingress的配置示例：
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cafe-ingress
spec:
  tls:
  - hosts:
    - cafe.example.com
    secretName: cafe-secret
  rules:
  - host: cafe.example.com
    http:
      paths:
      - path: /tea
        backend:
          serviceName: tea-svc
          servicePort: 80
      - path: /coffee
        backend:
          serviceName: coffee-svc
          servicePort: 80
```
在上面这个文件中，rules字段在Kubernetes里，这个字段叫作：IngressRule。IngressRule的Key，就叫作host。它必须是一个标准的域名格式字符串，而不能是IP地址。而host字段定义的值，就是这个Ingress的入口。而接下来IngressRule规则的定义，则依赖于path字段。你可以简单地理解为，这里的每一个path都对应一个后端Service。在上面的例子中，我们定义了两个path，它们分别对应coffe和tea这两个Deployment的Service(即：coffee-svc和tea-svc)。
**所谓Ingress对象，其实就是Kubernetes项目对"反向代理"的一种抽象。** 一个Ingress对象主要内容，实际上就是一个"反向代理"服务(比如：Nginx)的配置文件的描述。而这个代理服务对应的转发规则，就是IngressRule。
在实际的使用中，只需要从社区里选择一个具体的Ingress Controller，把它部署在Kubernetes集群里即可。然后，这个Ingress Controller会根据你定义的Ingress对象，提供对应的代理能力。目前，业界常用的各种反向代理项目，比如Nginx、HAProxy、Envoy、Traefik等，都已经为Kubernetes专门维护了对应的Ingress Controller。
[nginx-ingress-controller启动文件](https://raw.githubusercontent.com/mohanpedala/k8s-ingress/master/mandatory.yaml) 
根据这个配置文件启动一个Pod，这个Pod本身就是一个监听Ingress对象以及它所代理的后端Service变化的控制器。但一个新的Ingress对象由用户创建后，nginx-ingress-controller就会根据Ingress对象里定义的内容，生成一份对应的Nginx配置文件(/etc/nginx/nginx.conf)，并使用这个配置文件启动以个Nginx服务。
**一个Nginx Ingress Controller为你提供的服务，其实是一个可以根据Ingress对象和被代理后端Service的变化，来自动进行更新的Nginx负载均衡器。**
当然，为了让用户能够用到这个Nginx，我们就需要创建一个Service来把Nginx Ingress Controller管理的Nginx服务暴露出去，如下所示：
```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml
```
## 小结
目前，Ingress只能工作在七层，而Service只能工作在四层。所以你想要在Kubernetes里为应用进行TLS配置等HTTP相关的操作时，都必须通过Ingress来进行。
当然，正如同很多负载均衡项目可以同时提供七层和四层代理一样，将来Ingress的进化中，也会加入四层代理的能力。这样，一个比较完善的"反向代理"机制就比较成熟了。
而Kubernetes提出Ingress概念的原因其实也非常容器理解，有了Ingress这个抽象，用户就可以根据自己的需求来自由选择Ingress Controller。比如，如果你的应用对代理服务的中断非常敏感，那么你就应该考虑选择类似于Traefik这样支持"热加载"的Ingress Controller实现。
更重要的是，一旦你对社区里现有的Ingress方案感到不满意，或者你已经有了自己的负载均衡方案时，你只需要做很少的编程工作，就可以实现一个自己的Ingress Controller。