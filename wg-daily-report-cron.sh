#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每天23:59运行
#
# 重启wg
wg-quick down ${WG_IF} && wg-quick down ${WG_IF}


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}


# env
. ${SH_PATH}/env.sh
#WG_STATUS_CONLLECT_FILE=
#WG_REPORT_FILE=


# 本地env
TIME=${TIME:-`date +%Y-%m-%dT%H:%M:%S`}
TIME_START=${TIME}
DATE_TIME=`date -d "${TIME}" +%Y%m%dt%H%M%S`
CURRENT_DATE=`date -d "${TIME}" +%Y-%m-%d`
#
TODAY_WG_REPORT_FILE="/tmp/wg-report-today---${CURRENT_DATE}.md"
FORMAT_TABLE_SH="${SH_PATH}/format_table.sh"


echo '|日期|姓名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|用户公钥|远程IP|'  > ${TODAY_WG_REPORT_FILE}
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
        # 写入总报表
        echo "| ${CURRENT_DATE} | ${USER_XINGMING} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_PEER} | ${USER_ENDPOINT_IP} | " >> ${WG_REPORT_FILE}
        # 今日报表
        echo "| ${CURRENT_DATE} | ${USER_XINGMING} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_PEER} | ${USER_ENDPOINT_IP} | " >> ${TODAY_WG_REPORT_FILE}
    fi
done < ${WG_STATUS_CONLLECT_FILE}
#
${FORMAT_TABLE_SH}  --delimeter '|'  --title '|姓名|最后握手时间|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|'  --file ${TODAY_WG_REPORT_FILE}


