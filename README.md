# zzxia-wireguard-manage

## 1 介绍
wireguard VPN 服务器管理工具。提供用的列出、添加、删除、配置、重启功能

### 1.1 功能：
1. 列出账号
1. 添加删除账号
1. 导出用户配置信息
1. 重启

### 1.2 喜欢她，就满足她：
1. 【Star】她，让她看到你是爱她的；
2. 【Watching】她，时刻感知她的动态；
2. 【Fork】她，为她增加新功能，修Bug，让她更加卡哇伊；
3. 【Issue】她，告诉她有哪些小脾气，她会改的，手动小绵羊；
4. 【打赏】她，为她买jk；
<img src="https://img-blog.csdnimg.cn/20210429155627295.jpg?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3poZl9zeQ==,size_16,            color_FFFFFF,t_70#pic_center" alt="打赏" style="zoom:50%;" />


## 2 软件架构
Linux shell


## 3 安装教程

克隆下来即可
然后看帮助

## 4 使用说明
请使用-h|--help参数运行sh脚本即可看到使用帮助

### 4.1 创建修改环境变量文件

基于`env.sh.sample`创建环境变量文件`env.sh`，并根据自己的环境修改它：
```bash
$ cat env.sh 
#!/bin/bash

## sever env
# 根据自己的服务器信息填写
SERVER_CONF_FILE='/etc/wireguard/wg0.conf'    #--- 如果本程序运行在非wireguard服务器上，可以将服务器配置文件指到任意你想要的位置
SERVER_CONNECT_INFO='服务器IP:端口51820'
WG_IF='wg0'                                   #--- wireguard服务器网卡
IP_PREFIX='172.30.0'                          #--- wireguard服务器网络地址前3节
IP_NETMASK='24'                               #--- wireguard服务器IP掩码
SERVER_PUBKEY='4hgy39g5jUKU/KPzy28lQnIWEiV5xxxxxxxxxxxxxx='           #--- wireguard服务器公钥
SERVER_PRE_SHARED_KEY='2AbQpQnokHG5ta/vkwNolnKexxxxxxyyyyyyyyyyyyy='  #--- wireguard服务器与用户之间的预共享秘钥

## user env
USER_DNSs='192.168.11.3,192.168.11.4'                       #--- 用户的DNS
USER_ALOWED_IPs="${IP_PREFIX}.0/${IP_NETMASK},0.0.0.0/0"    #--- 用户端走VPN链路的网络地址范围（用来设置用户端路由）
```

### 4.2 wireguard-manage.sh使用帮助

```bash
$ ./wireguard-manage.sh -h

    用途：用于wireguard的用户管理
    依赖：/home/kevin/git_project/zhf_sy/zzxia-wireguard-manage/env.sh
    注意：
        1、如果使用参数【-R|--reload】，请确保你的wireguard服务器已经在本地安装配置完成
        2、修改环境变量文件【/home/kevin/git_project/zhf_sy/zzxia-wireguard-manage/env.sh】
        3、如果本程序运行在非wireguard服务器上，可以将服务器配置文件指到任意你想要的位置（修改/home/kevin/git_project/zhf_sy/zzxia-wireguard-manage/env.sh 中 SERVER_CONF_FILE 变量的值即可）
    用法：
        ./wireguard-manage.sh  [-h|--help]
        ./wireguard-manage.sh  [-l|--list]
        ./wireguard-manage.sh  [-a|--add {用户名}]  <{IP第4段}>
        ./wireguard-manage.sh  [-r|--rm|-o|--output-config  {用户名}]
        ./wireguard-manage.sh  [-R|--reload]
    参数说明：
        $0   : 代表脚本本身
        []   : 代表是必选项
        <>   : 代表是可选项
        |    : 代表左右选其一
        {}   : 代表参数值，请替换为具体参数值
        %    : 代表通配符，非精确值，可以被包含
        #
        -h|--help      此帮助
        -l|--list      列出现有用户
        -a|--add       添加用户
        -r|--rm        删除用户
        -o|--output-config 输出用户配置文件
        -R|--reload    重启服务器
    示例:
        #
        ./wireguard-manage.sh  -l              #--- 列出用户清单
        #
        ./wireguard-manage.sh  -a 猪猪侠 11    #--- 添加用户【猪猪侠】，IP地址尾号为【11】
        ./wireguard-manage.sh  -a 猪猪侠       #--- 添加用户【猪猪侠】，IP地址尾号自动分配
        #
        ./wireguard-manage.sh  -r 猪猪侠       #--- 删除用户【猪猪侠】
        #
        ./wireguard-manage.sh  -o 猪猪侠       #--- 输出用户【猪猪侠】的配置文件
        #
        ./wireguard-manage.sh  -R              #--- 重启服务器
```


## 5 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request


## 6 特技

1.  使用 Readme\_XXX.md 来支持不同的语言，例如 Readme\_en.md, Readme\_zh.md
2.  Gitee 官方博客 [blog.gitee.com](https://blog.gitee.com)
3.  你可以 [https://gitee.com/explore](https://gitee.com/explore) 这个地址来了解 Gitee 上的优秀开源项目
4.  [GVP](https://gitee.com/gvp) 全称是 Gitee 最有价值开源项目，是综合评定出的优秀开源项目
5.  Gitee 官方提供的使用手册 [https://gitee.com/help](https://gitee.com/help)
6.  Gitee 封面人物是一档用来展示 Gitee 会员风采的栏目 [https://gitee.com/gitee-stars/](https://gitee.com/gitee-stars/)
