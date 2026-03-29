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
cd "${SH_PATH}"


# env
. /etc/profile         #--- 计划任务需要
. "${SH_PATH}/env.sh"
. "${SH_PATH}/functions.sh"
#WG_IF=
#TODAY_WG_USER_LATEST_LOGIN_FILE=


# 本地env
YESTERDAY_DATE=$(date -d "yesterday" +%Y-%m-%d)
WG_DAILY_STATUS_FILE=$(mktemp /tmp/wg-daily-status.XXXXXX)
trap 'rm -f "${WG_DAILY_STATUS_FILE}"' EXIT
#
[ -d "${SH_PATH}/report" ] || mkdir "${SH_PATH}/report"
YESTERDAY_WG_REPORT_FILE="${SH_PATH}/report/wg-daily-report-${WG_IF}---${YESTERDAY_DATE}.md"
WG_REPORT_FILE="${SH_PATH}/report/wg-report-${WG_IF}.list"
# sh
FORMAT_TABLE_SH="${SH_PATH}/format_table.sh"


# 采集
wg show "${WG_IF}" dump > "${WG_DAILY_STATUS_FILE}"
sed -i '1d' "${WG_DAILY_STATUS_FILE}"


echo '|日期|用户名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|' > "${YESTERDAY_WG_REPORT_FILE}"
#
while read LINE
do
    F_PARSE_WG_DUMP_LINE "${LINE}"
    F_LOOKUP_USER "${USER_PEER}" "${SERVER_CONF_FILE}"
    F_CALC_MIB "${USER_NET_IN}" "${USER_NET_OUT}"
    # 是否有握手信息
    if [ "${USER_LATEST_HAND_SECOND}" -ne 0 ]; then
        # 有握手信息
        USER_LATEST_HAND_SECOND_TIME=$(date -d "@${USER_LATEST_HAND_SECOND}" +%H:%M:%S)
        # 昨日报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> "${YESTERDAY_WG_REPORT_FILE}"
        # 写入总报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> "${WG_REPORT_FILE}"
    fi
done < "${WG_DAILY_STATUS_FILE}"
#
echo "昨日wg用户使用报告："
#${FORMAT_TABLE_SH}  --delimeter '|'  --title '|日期|用户名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|'  --file ${YESTERDAY_WG_REPORT_FILE}
"${FORMAT_TABLE_SH}" --delimeter '|' --file "${YESTERDAY_WG_REPORT_FILE}"

F_LOG "INFO" "日报生成完成：${YESTERDAY_WG_REPORT_FILE}"

# 重启wg
wg-quick down "${WG_IF}"
wg-quick up "${WG_IF}"

# clean
> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"


