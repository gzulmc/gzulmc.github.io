```java
1.直接拉去远程分支到本地
    1.1 git clone -b dev 代码仓库地址
          git clone -b dev http://546974895%40qq.com:lmc546974895@gitlab.jiayou9.com:8247/jiangtao/spd-web.git
    1.2  git init 进行初始化
        与远程代码仓库建立连接：git remote add origin 代码仓库地址
    1.3 将远程分支拉到本地：git fetch origin dev（dev即分支名）
    1.4 git checkout -b LocalDev origin/dev (LocalDev 为本地分支名，dev为远程分支名)
    1.5 git pull 更新本地代码
2.删除本地分支
    git branch -d dev
3.查看所有分支
    git branch -a
4.查看当前使用分支(结果列表中前面标*号的表示当前使用分支)
    git branch
5.切换分支
    git checkout 分支名
6.查看提交记录
git log --pretty=format:"%h - %an, %ar : %s" –date=short
git log --pretty=format:"%h | %an | %ad | %s" --date=format:"%Y/%m/%d %H:%M:%S"
    
git config --global http.sslVerify false
-- idea项目修改提交用户名,修改.git下config文件添加配置
[user]
name = gzulmc
email = 546974895@qq.com
代码回滚 --hard方式不保留本地缓存，git status查看工作区也没有记录。所以需要留好备份 
git log --pretty=format:"%h - %an,%cd:%s" 查看代码提交记录 
git reset --hard commit_id 重置到某次提交记录 
git push origin HEAD --force 强制提交到远程覆盖 代码恢复 
git reflog 查看所有提交记录 找到要回滚的commit_id或者时间记录 
git reset --hard commit_id 恢复带该head处 
git push origin HEAD --force 强制推送到远端

```

