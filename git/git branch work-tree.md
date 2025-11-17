### 名称
git-worktree - 管理多个工作区
```ad-summary
$ git worktree add -b emergency-fix ../temp master
$ pushd ../temp
# ... hack hack hack ...
$ git commit -a -m 'emergency fix for boss'
$ popd
$ git worktree remove ../temp
```

git worktree add -b KSA_DEV_20230828_21.4_1106943_hyperpayRecon ../hyperpayRecon