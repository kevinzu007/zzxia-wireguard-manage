#!/bin/bash
#############################################################################
# Create By: ZZXia
# License: GNU GPLv3
# Test On: RockyLinux 9
#############################################################################
#
# 每1分钟运行一次
# * * * * *  /root/zzxia-wireguard-manage/wg-login-alert-cron.sh
#
# 等待日报完成统计并重启清零
sleep 30


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
#TODAY_WG_USER_LATEST_LOGIN_FILE=


# 本地env
TIME=${TIME:-$(date +%Y-%m-%dT%H:%M:%S)}
#TIME_START=${TIME}
#DATE_TIME=$(date -d "${TIME}" +%Y%m%dt%H%M%S)
CURRENT_DATE=$(date -d "${TIME}" +%Y-%m-%d)
WG_LOGIN_STATUS_FILE=$(mktemp /tmp/wg-login-status.XXXXXX)
trap 'rm -f "${WG_LOGIN_STATUS_FILE}"' EXIT
#
NOTIFICATION_SH="${SH_PATH}/send-markdown-msg.sh"


# 必须软件jq
if ! command -v jq > /dev/null 2>&1; then
    echo -e "猪猪侠警告：${SH_NAME} - 请安装软件jq"
    if [ -f "${NOTIFICATION_SH}" ]; then
        "${NOTIFICATION_SH}" \
            --title "【Info:wg用户登录:$(hostname -s)】" \
            --message "$( echo -e "### 请安装软件jq" )" 2>/dev/null || true
    fi
    exit 1
fi



# 登录消息
F_LOGIN_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg登录:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )" 2>/dev/null || true
}

# 新IP消息
F_NEW_IP_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg登录:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 新远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )" 2>/dev/null || true
}

# 离线消息
F_OFFLINE_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg用户离线:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n\n" )" 2>/dev/null || true
}


# 获取IP位置，用法： F_IP_AREA {IP}
F_IP_AREA()
{
    local F_IP="$1"
    local F_AREA
    F_AREA=$( (curl -s --connect-timeout 5 --max-time 10 "http://www.cip.cc/${F_IP}" 2>/dev/null || true) | (grep '数据二' || true) | awk -F ":" '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | awk '{gsub(/\s+/, ""); print}')
    if [ -z "${F_AREA}" ] || [ "${F_AREA}" = "null" ]; then
        F_AREA="获取失败：${F_IP}"
    fi
    F_AREA=$(echo "${F_AREA}" | sed -e 's/\"//g' -e 's/|//g')
    echo "${F_AREA}"
    return 0
}



# 搜索用户用户名，找到，则返回行号
# 用法：F_SEARCH_USER_NAME  用户名
F_SEARCH_USER_NAME()
{
    local F_USER_NAME="$1"
    local N=0      #--- 记录行号
    #
    while read LINE
    do
        (( N++ ))
        local F_LINE_USER_NAME
        F_LINE_USER_NAME=$(echo "$LINE" | cut -d '|' -f 3)
        F_LINE_USER_NAME=$(echo ${F_LINE_USER_NAME})
        #
        if [[ "${F_USER_NAME}" = "${F_LINE_USER_NAME}" ]]; then
            echo "$N"
            return 0
        fi
    done < "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
    #
    # 未找到
    return 1
}



# 写入今日登录状态记录
F_RECORD_USER_STATE()
{
    local status="$1"
    local area="$2"
    echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${area} | ${status} |" >> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
}

# 场景 1：今日首次登录
F_HANDLE_FIRST_LOGIN()
{
    USER_ENDPOINT_AREA=$(F_IP_AREA "${USER_ENDPOINT_IP}")
    F_RECORD_USER_STATE "已登录" "${USER_ENDPOINT_AREA}"
    F_LOGIN_SEND_MSG
    F_LOG "INFO" "用户登录：${USER_NAME}，IP：${USER_ENDPOINT_IP}，位置：${USER_ENDPOINT_AREA}"
}

# 场景 2：远程 IP 变更
F_HANDLE_IP_CHANGE()
{
    local line_num="$1"
    sed -i "${line_num}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
    USER_ENDPOINT_AREA=$(F_IP_AREA "${USER_ENDPOINT_IP}")
    F_RECORD_USER_STATE "已登录" "${USER_ENDPOINT_AREA}"
    F_NEW_IP_SEND_MSG
    F_LOG "INFO" "用户IP变更：${USER_NAME}，新IP：${USER_ENDPOINT_IP}，位置：${USER_ENDPOINT_AREA}"
}

# 场景 3：心跳状态（在线/离线）检查
F_HANDLE_HEARTBEAT()
{
    local line_num="$1"
    local area="$2"
    local last_status="$3"

    local current_second
    current_second=$(date +%s)
    local time_interval=$(( current_second - USER_LATEST_HAND_SECOND ))

    if [ "${time_interval}" -gt 300 ]; then
        # 超过300秒无握手：若此前为“已登录”则标记“已离线”
        if [[ "${last_status}" = "已登录" ]]; then
            sed -i "${line_num}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
            F_RECORD_USER_STATE "已离线" "${area}"
            F_OFFLINE_SEND_MSG
            F_LOG "INFO" "用户离线：${USER_NAME}"
        fi
    else
        # 300秒内有握手：若此前为“已离线”则标记重新“已登录”
        if [[ "${last_status}" = "已离线" ]]; then
            sed -i "${line_num}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
            F_RECORD_USER_STATE "已登录" "${area}"
            F_LOGIN_SEND_MSG
            F_LOG "INFO" "用户重新上线：${USER_NAME}，IP：${USER_ENDPOINT_IP}"
        fi
    fi
}



# 采集
wg show "${WG_IF}" dump > "${WG_LOGIN_STATUS_FILE}"
sed -i '1d' "${WG_LOGIN_STATUS_FILE}"
#
touch "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
while read -r LINE
do
    F_PARSE_WG_DUMP_LINE "${LINE}"
    F_LOOKUP_USER "${USER_PEER}" "${SERVER_CONF_FILE}"

    # 忽略无握手记录的 Peer
    [ "${USER_LATEST_HAND_SECOND}" -eq 0 ] && continue

    USER_LATEST_HAND_SECOND_TIME=$(date -d "@${USER_LATEST_HAND_SECOND}" +%H:%M:%S)
    LINE_NUM=$(F_SEARCH_USER_NAME "${USER_NAME}" || true)

    if [[ ! ${LINE_NUM} =~ ^[0-9]+$ ]]; then
        # 场景 1：今日首次登录
        F_HANDLE_FIRST_LOGIN
    else
        # 提取已有记录信息
        USER_ENDPOINT_IP_LAST=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $4}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
        USER_ENDPOINT_AREA_LAST=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $6}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
        USER_LOGIN_STATUS_LAST=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $7}' | awk '{gsub(/^\s+|\s+$/, ""); print}')

        if [ "${USER_ENDPOINT_IP}" != "${USER_ENDPOINT_IP_LAST}" ]; then
            # 场景 2：远程 IP 变更
            F_HANDLE_IP_CHANGE "${LINE_NUM}"
        else
            # 场景 3：在线 / 离线心跳检测
            F_HANDLE_HEARTBEAT "${LINE_NUM}" "${USER_ENDPOINT_AREA_LAST}" "${USER_LOGIN_STATUS_LAST}"
        fi
    fi
done < "${WG_LOGIN_STATUS_FILE}"



