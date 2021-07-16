#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}

# env
. ${SH_PATH}/env.sh

# 本地env
TIME=${TIME:-`date +%Y-%m-%dT%H:%M:%S`}
TIME_START=${TIME}
DATE_TIME=`date -d "${TIME}" +%Y%m%dt%H%M%S`
CURRENT_DATE=`date -d "${TIME}" +%Y-%m-%d`

DINGDING_MARKDOWN_PY="/usr/local/bin/dingding_markdown.py"



# 每2分钟运行一次，采集数据
TODAY_WG_USER_FIRST_LOGIN_FILE="./wg-user-first-login-today.txt---${CURRENT_DATE}"
touch  ${TODAY_WG_USER_FIRST_LOGIN_FILE}


#WG_STATUS_FILE="/tmp/wg-status.txt"
#touch ${WG_STATUS_FILE}
#wg | grep -B 5 'transfer' > ${WG_STATUS_FILE}



WG_LATEST_CONN_FILE="/tmp/wg-latest-conn.txt"
wg show ${WG_IF} dump > ${WG_LATEST_CONN_FILE}
sed -i '1d' ${WG_LATEST_CONN_FILE}
#
while read LINE
do
    USER_PEER=`echo $LINE | awk '{print $1}'`
    USER_PRESHARED_KEY=`echo $LINE | awk '{print $2}'`
    USER_ENDPOINT=`echo $LINE | awk '{print $3}'`
    USER_ENDPOINT_IP=`echo ${USER_ENDPOINT} | cut -d ':' -f 1`
    USER_ALLOWED_IPS=`echo $LINE | awk '{print $4}'`
    USER_LATEST_HAND=`echo $LINE | awk '{print $5}'`
    USER_LATEST_HAND_TIME=`date -d @${USER_LATEST_HAND} +%H:%M:%S`
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
        # 是否已记录（如果远程地址换了会怎样？）
        if [ `grep -q ${USER_XINGMING} ${TODAY_WG_USER_FIRST_LOGIN_FILE} ; echo $?` -ne 0 ]; then
            # 未记录
            #echo "| ${TIME} | ${USER_XINGMING} | ${USER_IP} | ${USER_NET_TOTAL_MiB} | ${USER_PEER} | ${USER_PRESHARED_KEY} | ${USER_ENDPOINT_IP} | ${USER_ALLOWED_IPS} | ${USER_LATEST_HAND_TIME} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_KEEPALIVE} |" >> ${TODAY_WG_REPORT_FILE}
            echo "| ${CURRENT_DATE} | ${USER_LATEST_HAND_TIME} | ${USER_XINGMING} | ${USER_ENDPOINT} |" >> ${TODAY_WG_USER_FIRST_LOGIN_FILE}
            #
            ${DINGDING_MARKDOWN_PY} "【Info:wg登录:`hostname -s`】" "用户：${USER_XINGMING}" "最近握手时间：${USER_LATEST_HAND_TIME}" "WG_IP：${USER_IP}" "远程IP：${USER_ENDPOINT_IP}" > /dev/null
        fi
    fi
done < ${WG_LATEST_CONN_FILE}





            
