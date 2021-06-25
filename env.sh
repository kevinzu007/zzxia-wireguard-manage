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

