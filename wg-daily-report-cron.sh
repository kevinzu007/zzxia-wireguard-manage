#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每天00:00运行
# 0 0 * * *  /root/zzxia-wireguard-manage/wg-daily-report-cron.sh


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}


# env
. /etc/profile         #--- 计划任务需要
. ${SH_PATH}/env.sh
#WG_IF=
#TODAY_WG_USER_LATEST_LOGIN_FILE=


# 本地env
#TIME=${TIME:-`date +%Y-%m-%dT%H:%M:%S`}
#TIME_START=${TIME}
#DATE_TIME=`date -d "${TIME}" +%Y%m%dt%H%M%S`
YESTERDAY_DATE=`date -d "yesterday" +%Y-%m-%d`
WG_DAILY_STATUS_FILE="/tmp/wg-daily-status.txt"
#
[ -d "${SH_PATH}/report" ] || mkdir "${SH_PATH}/report"
YESTERDAY_WG_REPORT_FILE="${SH_PATH}/report/wg-daily-report---${YESTERDAY_DATE}.md"
WG_REPORT_FILE="${SH_PATH}/report/wg-report.list"
# sh
FORMAT_TABLE_SH="${SH_PATH}/format_table.sh"


# 采集
wg show "${WG_IF}" dump > "${WG_DAILY_STATUS_FILE}"
sed -i '1d' "${WG_DAILY_STATUS_FILE}"


echo '|日期|用户名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|'  > ${YESTERDAY_WG_REPORT_FILE}
#echo '| -- | -- | ------- | ------- | -------- | ---- | ---- |'  >> ${YESTERDAY_WG_REPORT_FILE}
#
while read LINE
do
    USER_PEER=`echo $LINE | awk '{print $1}'`
    USER_PRESHARED_KEY=`echo $LINE | awk '{print $2}'`
    #
    USER_ENDPOINT=`echo $LINE | awk '{print $3}'`
    USER_ENDPOINT_IP=`echo ${USER_ENDPOINT} | cut -d ':' -f 1`
    USER_ENDPOINT_UDP_PORT=`echo ${USER_ENDPOINT} | cut -d ':' -f 2`
    #
    USER_ALLOWED_IPS=`echo $LINE | awk '{print $4}'`
    USER_LATEST_HAND_SECOND=`echo $LINE | awk '{print $5}'`
    USER_NET_IN=`echo $LINE | awk '{print $6}'`
    USER_NET_OUT=`echo $LINE | awk '{print $7}'`
    USER_KEEPALIVE=`echo $LINE | awk '{print $8}'`
    # 计算MiB
    USER_NET_IN_MiB=`echo "scale=1; ${USER_NET_IN} / 1024 / 1024" | bc -l`
    USER_NET_OUT_MiB=`echo "scale=1; ${USER_NET_OUT} / 1024 / 1024" | bc -l`
    USER_NET_TOTAL_MiB=`echo "scale=1; ${USER_NET_IN_MiB} + ${USER_NET_OUT_MiB}" | bc -l`
    #
    # 查用户
    USER_NAME=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $2}'`
    USER_IP=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $3}'`
    # 是否有握手信息
    if [ ${USER_LATEST_HAND_SECOND} -ne 0 ]; then
        # 有握手信息
        USER_LATEST_HAND_SECOND_TIME=`date -d @${USER_LATEST_HAND_SECOND} +%H:%M:%S`
        # 昨日报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> ${YESTERDAY_WG_REPORT_FILE}
        # 写入总报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> ${WG_REPORT_FILE}
    fi
done < ${WG_DAILY_STATUS_FILE}
#
echo "昨日wg用户使用报告："
#${FORMAT_TABLE_SH}  --delimeter '|'  --title '|日期|用户名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|'  --file ${YESTERDAY_WG_REPORT_FILE}
${FORMAT_TABLE_SH}  --delimeter '|'  --file ${YESTERDAY_WG_REPORT_FILE}


# 重启wg
wg-quick down ${WG_IF}
wg-quick up ${WG_IF}

# clean
> ${TODAY_WG_USER_LATEST_LOGIN_FILE}


