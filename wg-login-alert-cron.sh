#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每2分钟运行一次
# */2 * * * *  /root/zzxia-wireguard-manage/wg-login-alert.sh


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}


# env
. /etc/profile         #--- 计划任务需要
. ${SH_PATH}/env.sh
#TODAY_WG_USER_FIRST_LOGIN_FILE=


# 本地env
TIME=${TIME:-`date +%Y-%m-%dT%H:%M:%S`}
#TIME_START=${TIME}
#DATE_TIME=`date -d "${TIME}" +%Y%m%dt%H%M%S`
CURRENT_DATE=`date -d "${TIME}" +%Y-%m-%d`
WG_LOGIN_STATUS_FILE="/tmp/wg-login-status.txt"
#
DINGDING_MARKDOWN_PY="${SH_PATH}/dingding_by_markdown_file-login.py"


# 必须软件jq
if [ "`which jq >/dev/null 2>&1 ; echo $?`" != "0" ]; then
    echo -e "峰哥说：${SH_NAME} - 请安装软件jq"
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg用户登录:`hostname -s`】"  \
        --message "$( echo -e "### 请安装软件jq" )"
    exit 1
fi



# 钉钉
F_SEND_DINGDING()
{
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg用户登录:`hostname -s`】"  \
        --message "$( echo -e "### 用户：${USER_XINGMING} \n### 最近握手时间：${USER_LATEST_HAND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )"
}


## 邮件
#F_SEND_MAIL()
#{
#    echo -e "### 用户：${USER_XINGMING} \n### 最近握手时间：${USER_LATEST_HAND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n\n" | mailx  -s "【wg登录:`hostname -s`}】用户：${USER_XINGMING}"  ${EMAIL}  >/dev/null 2>&1
#}


# 获取IP位置，用法： F_IP_AREA {IP}
F_IP_AREA()
{
    F_IP=$1
    F_AREA=` curl -s "http://www.cip.cc/${F_IP}" | grep '数据二' | awk -F ":" '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | awk '{gsub(/\s+/, ""); print}' `
    #F_AREA=` curl -s https://api.ip.sb/geoip/${F_IP} | jq '.country,.region,.city' 2>/dev/null | sed -n 's/\"/ /gp' | awk 'NR == 1{printf "%s->",$0} NR == 2{printf "%s->",$0} NR == 3{printf "%s\n",$0}' `
    if [ "x${F_AREA}" = "x" -o "x${F_AREA}" = "xnull" ]; then
        F_AREA="获取地理位置失败【IP：${F_IP}】"
    fi
    F_AREA=`echo ${F_AREA} | sed 's/\"//g'`
    echo "${F_AREA}"
    return 0
}


# 采集
wg show "${WG_IF}" dump > "${WG_LOGIN_STATUS_FILE}"
sed -i '1d' "${WG_LOGIN_STATUS_FILE}"
#
touch ${TODAY_WG_USER_FIRST_LOGIN_FILE}
while read LINE
do
    USER_PEER=`echo $LINE | awk '{print $1}'`
    USER_PRESHARED_KEY=`echo $LINE | awk '{print $2}'`
    USER_ENDPOINT=`echo $LINE | awk '{print $3}'`
    USER_ENDPOINT_IP=`echo ${USER_ENDPOINT} | cut -d ':' -f 1`
    USER_ALLOWED_IPS=`echo $LINE | awk '{print $4}'`
    USER_LATEST_HAND=`echo $LINE | awk '{print $5}'`
    USER_NET_IN=`echo $LINE | awk '{print $6}'`
    USER_NET_OUT=`echo $LINE | awk '{print $7}'`
    USER_KEEPALIVE=`echo $LINE | awk '{print $8}'`
    # 计算MiB
    USER_NET_IN_MiB=`echo "scale=1; ${USER_NET_IN} / 1024 / 1024" | bc -l`
    USER_NET_OUT_MiB=`echo "scale=1; ${USER_NET_OUT} / 1024 / 1024" | bc -l`
    USER_NET_TOTAL_MiB=`echo "scale=1; ${USER_NET_IN_MiB} + ${USER_NET_OUT_MiB}" | bc -l`
    #
    # 查用户
    USER_XINGMING=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $2}'`
    USER_IP=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $3}'`
    # 是否有握手信息
    if [ ${USER_LATEST_HAND} -ne 0 ]; then
        # 有握手信息
        USER_LATEST_HAND_TIME=`date -d @${USER_LATEST_HAND} +%H:%M:%S`
        # 是否已记录（如果远程地址换了会怎样？）
        if [ `grep -q ${USER_XINGMING} ${TODAY_WG_USER_FIRST_LOGIN_FILE} ; echo $?` -ne 0 ]; then
            # 未记录
            echo "| ${CURRENT_DATE} | ${USER_XINGMING} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_TIME} |" >> ${TODAY_WG_USER_FIRST_LOGIN_FILE}
            #
            USER_ENDPOINT_AREA=`F_IP_AREA ${USER_ENDPOINT_IP}`
            F_SEND_DINGDING > /dev/null
        fi
    fi
done < ${WG_LOGIN_STATUS_FILE}


