### rebase 和 merge的区别如下图
![[Pasted image 20230817161647.png]]merge/rebase之前的提交记录

![[Pasted image 20230817161647.png]]merge之后的提交记录

![[Pasted image 20230817162005.png]]rebase之后的提交记录
### 基本的rebase操作
```shell
$ git checkout experiment
$ git rebase master
First, rewinding head to replay your work on top of it...
Applying: added staged command
```
它的原理是首先找到这两个分支（即当前分支`experiment`、rebase操作的目标基底分支`master`) 的最近共同祖先`C2`, 然后对比当前分支相对于祖先的历次提交，提取相应的修改并存为临时文件，然后将当前分支指向目标基底C3, 最后以此将之前另存为临时文件的修改依次应用。

现在切回到master分支，进行一次快进合并
```shell
$ git checkout master
$ git merge experiment
```
![[Pasted image 20230817174044.png]]master 分支的快进合并

### 从一个主体分支再分出一个主题分支，将后面分出的分支rebase到主体分支
```shell
git rebase --onto master server client
```
以上命令的意思是：“取出client分支，找出它从server分支分叉之后的补丁，然后把这些补丁在master分支上重放一遍，让client看起来像直接基于master修改一样”。
![[Pasted image 20230817174440.png]]从一个主题分支再分出一个主题分支的提交历史
![[Pasted image 20230817174515.png]]截取主题分支上的另一个主题分支，然后rebase到其他分支

最后进行快进合并master分支。
```shell
git checkout master
git merge client
```

可以使用`git rebase <base-branch> <topic-branch>`命令直接将主题分支rebase到目标分支上。这样可以省去先切到主题分支的时间。
```shell
git rebase master sever
```

### rebase的风险
rebase操作的实质是丢弃一些现有的提交，然后相应地新建一些内容一样但实际上不同的提交。如果你已经将提交推送至某些仓库，而其他人也已经从该仓库拉取提交并进行了后续工作，此时，如果你用`git rebase` 命令重新整理了提交并再次推送，你的同伴将不得不再次将他们手头的工作与你的提交进行整合，如果接下来你还要拉取并整合他们修改过的提交，事情将会变成一团糟。或者你已经rebase之后，其他人又强制修改了你所基于的那些提交，并强制推送了，这时候几有可能出现两次一样的提交历史，如果你又pull了他们的代码的话。
![[Pasted image 20230817184713.png]]
### 用rebase解决rebase问题
在上例中可以使用`git rebase teamone/master`,来用rebase来解决rebase外，还可以有另一种简单的方法就是使用`git pull --rebase`而不是直接使用`git pull`。又或者你可以自己手动完成这个过程，先`git fetch`, 再 `git rebase teamone/master`。
也可以对`git pull` 的默认配置进行修改，采用`git config --global pull.rebase true`来将这个合并操作配置为`git pull` 的默认行为。
如果你只对不会离开你电脑的提交执行rebase，那就不会有事。但是对于远程仓库的分支，必须要求每个人在`git pull`时，必须都执行`git pull --rebase`命令，这样尽管不能避免伤害，但能有所缓解。

### 总结
到底是merge好还是rebase好，有一种观点认为，仓库的提交历史即是**记录实际发生过什么**(即认为使用merge更好，但是因此产生的提交历史可能是一团糟)，另一种观点则正好相反，他们认为提交历史是**项目过程中发生的事**(即认为使用rebase及filter-branch)等工具来编写故事，怎么方便后来的读者即怎么写。
总的原则是，只对未推送或分享给别人的本地修改执行rebase操作清理历史，从不对已推送至别处的提交执行rebase操作，这样我们才能享受到两种方式带来的便利。