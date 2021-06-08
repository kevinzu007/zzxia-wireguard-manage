#!/bin/bash


## sever env
# 根据自己的服务器信息填写
SERVER_CONF_FILE='/etc/wireguard/wg0.conf'
SERVER_CONNECT_INFO='服务器IP:51820'
WG_IF='wg0'
IP_PREFIX='172.30.0'
IP_NETMASK='24'
SERVER_PUBKEY='4hgy39g5jUKU/KPzy28lQnIWEiV5xxxxxxxxxxxxxx='
SERVER_PRE_SHARED_KEY='2AbQpQnokHG5ta/vkwNolnKexxxxxxyyyyyyyyyyyyy='


## user env
# 用户的DNS
USER_DNSs='192.168.11.3,192.168.11.4'
# 用户端走VPN链路的网络地址范围
USER_ALOWED_IPs="${IP_PREFIX}.0/${IP_NETMASK},0.0.0.0/0"


