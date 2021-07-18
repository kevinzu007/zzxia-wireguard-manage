#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 请参考官网安装wireguard软件
# https://www.wireguard.com/install/


umask 0077

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}

# env
. ${SH_PATH}/env.sh



if [ -e ${SERVER_CONF_FILE} ]; then
    echo -e "\n峰哥说：服务器配置文件已存在，请勿重复设置，退出\n"
    exit
fi


# mod
modprobe wireguard
if [ "`lsmod | grep wireguard ; echo $?`" != '0' ]; then
    echo "内核模块【wireguard】未加载，请检查！"
    exit 1
fi


# 私钥与公钥
wg genkey > ${SERVER_PRIVATE_KEY}   # 生成私钥


# 设置服务器信息
ip link add ${WG_IF} type wireguard
ip address add ${IP_PREFIX}.1/${IP_NETMASK} dev ${WG_IF}
wg  set ${WG_IF}  listen-port 51820  private-key ${SERVER_PRIVATE_KEY}

# 启动服务
ip link set ${WG_IF} up

# 保存配置到/etc/wireguard/wgN.conf
wg-quick save ${WG_IF}

# 重启
wg-quick down ${WG_IF}  &&  wg-quick up ${WG_IF}



## 防火墙开启
#firewall-cmd --zone=public --add-interface=${WG_IF}  --permanent
#firewall-cmd --zone=public --add-port=51820/udp --permanent
#
### 全开
##firewall-cmd --direct --add-rule   ipv4 filter FORWARD 1 -p tcp  -s 172.30.5.11 -j ACCEPT
### 开指定端口
##firewall-cmd --direct --add-rule   ipv4 filter FORWARD 1 -p tcp  -s 172.30.5.15 -j ACCEPT  -d 10.1.1.182 --dport 5432
#
#firewall-cmd --reload


