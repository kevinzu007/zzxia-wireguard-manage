#!/bin/bash
#############################################################################
# Create By: ZZXia
# License: GNU GPLv3
# Test On: RockyLinux 9
#############################################################################
#
# 每天00:00运行
# 0 0 * * *  /root/zzxia-wireguard-manage/wg-daily-report-cron.sh

set -eo pipefail

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd "${SH_PATH}"


# env
. /etc/profile         #--- 计划任务需要
. "${SH_PATH}/env.sh"
. "${SH_PATH}/functions.sh"

F_CHECK_ROOT
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
FORMAT_TABLE_SH="${SH_PATH}/format-table.sh"
NOTIFICATION_SH="${SH_PATH}/send-markdown-msg.sh"


# 采集
wg show "${WG_IF}" dump > "${WG_DAILY_STATUS_FILE}"
sed -i '1d' "${WG_DAILY_STATUS_FILE}"


echo '|日期|用户名|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|' > "${YESTERDAY_WG_REPORT_FILE}"
#
USER_CARDS=""
TOTAL_ACTIVE_USERS=0
TOTAL_BYTES_IN=0
TOTAL_BYTES_OUT=0

while read -r LINE
do
    F_PARSE_WG_DUMP_LINE "${LINE}"
    F_LOOKUP_USER "${USER_PEER}" "${SERVER_CONF_FILE}"
    F_CALC_MIB "${USER_NET_IN}" "${USER_NET_OUT}"
    # 是否有握手信息
    if [ "${USER_LATEST_HAND_SECOND}" -ne 0 ]; then
        USER_LATEST_HAND_SECOND_TIME=$(date -d "@${USER_LATEST_HAND_SECOND}" +%H:%M:%S)
        # 昨日报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> "${YESTERDAY_WG_REPORT_FILE}"
        # 写入总报表
        echo "| ${YESTERDAY_DATE} | ${USER_NAME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> "${WG_REPORT_FILE}"

        # 统计
        (( TOTAL_ACTIVE_USERS++ ))
        TOTAL_BYTES_IN=$(( TOTAL_BYTES_IN + USER_NET_IN ))
        TOTAL_BYTES_OUT=$(( TOTAL_BYTES_OUT + USER_NET_OUT ))

        # 移动端卡片条目
        USER_CARDS+=$'\n'"👤 **${USER_NAME}** (\`${USER_IP}\`)"$'\n'"- 📶 总流量：**${USER_NET_TOTAL_MiB} MiB**（↓ ${USER_NET_IN_MiB} / ↑ ${USER_NET_OUT_MiB}）"$'\n'"- 🌐 远程IP：\`${USER_ENDPOINT_IP}\`"$'\n'
    fi
done < "${WG_DAILY_STATUS_FILE}"
#
echo "昨日wg用户使用报告："
"${FORMAT_TABLE_SH}" --delimeter '|' --file "${YESTERDAY_WG_REPORT_FILE}"

# 组装移动端卡片式消息并推送
if [ "${TOTAL_ACTIVE_USERS}" -eq 0 ]; then
    MSG_BODY="*昨日无活跃用户连接*"
else
    TOTAL_ALL_IN_MIB=$(echo "scale=1; ${TOTAL_BYTES_IN} / 1024 / 1024" | bc -l)
    TOTAL_ALL_OUT_MIB=$(echo "scale=1; ${TOTAL_BYTES_OUT} / 1024 / 1024" | bc -l)
    TOTAL_ALL_MIB=$(echo "scale=1; ${TOTAL_ALL_IN_MIB} + ${TOTAL_ALL_OUT_MIB}" | bc -l)

    MSG_BODY="### 📊 昨日流量明细：${USER_CARDS}"$'\n\n'"---"$'\n'"📌 **汇总统计**：共 **${TOTAL_ACTIVE_USERS}** 位活跃用户，累计流量 **${TOTAL_ALL_MIB} MiB**（↓ ${TOTAL_ALL_IN_MIB} / ↑ ${TOTAL_ALL_OUT_MIB}）"
fi

if [ -f "${NOTIFICATION_SH}" ]; then
    "${NOTIFICATION_SH}" \
        --title "【WireGuard流量日报:$(hostname -s)】${YESTERDAY_DATE}" \
        --message "${MSG_BODY}" >/dev/null 2>&1 || true
fi

F_LOG "INFO" "日报生成完成：${YESTERDAY_WG_REPORT_FILE}"

# 重启wg
wg-quick down "${WG_IF}"
wg-quick up "${WG_IF}"

# clean
> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"



