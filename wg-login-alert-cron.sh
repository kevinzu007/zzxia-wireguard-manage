#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每1分钟运行一次
# * * * * *  /root/zzxia-wireguard-manage/wg-login-alert-cron.sh
#
# 等待日报完成统计并重启清零
sleep 30


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd "${SH_PATH}"


# env
. /etc/profile         #--- 计划任务需要
. "${SH_PATH}/env.sh"
. "${SH_PATH}/functions.sh"
#TODAY_WG_USER_LATEST_LOGIN_FILE=


# 本地env
TIME=${TIME:-$(date +%Y-%m-%dT%H:%M:%S)}
#TIME_START=${TIME}
#DATE_TIME=$(date -d "${TIME}" +%Y%m%dt%H%M%S)
CURRENT_DATE=$(date -d "${TIME}" +%Y-%m-%d)
WG_LOGIN_STATUS_FILE=$(mktemp /tmp/wg-login-status.XXXXXX)
trap 'rm -f "${WG_LOGIN_STATUS_FILE}"' EXIT
#
NOTIFICATION_SH="${SH_PATH}/send_markdown_msg.sh"


# 必须软件jq
if ! command -v jq > /dev/null 2>&1; then
    echo -e "猪猪侠警告：${SH_NAME} - 请安装软件jq"
    "${NOTIFICATION_SH}" \
        --title "【Info:wg用户登录:$(hostname -s)】" \
        --message "$( echo -e "### 请安装软件jq" )"
    exit 1
fi



# 登录消息
F_LOGIN_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg登录:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )"
}

# 新IP消息
F_NEW_IP_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg登录:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 新远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )"
}

# 离线消息
F_OFFLINE_SEND_MSG()
{
    "${NOTIFICATION_SH}" \
        --title "【Info:wg用户离线:$(hostname -s)】" \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n\n" )"
}


## 邮件
#F_SEND_MAIL()
#{
#    echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n\n" | mailx  -s "【wg登录:$(hostname -s)}】用户：${USER_NAME}"  ${EMAIL}  >/dev/null 2>&1
#}


# 获取IP位置，用法： F_IP_AREA {IP}
F_IP_AREA()
{
    local F_IP="$1"
    local F_AREA
    F_AREA=$(curl -s --connect-timeout 5 --max-time 10 "http://www.cip.cc/${F_IP}" | grep '数据二' | awk -F ":" '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | awk '{gsub(/\s+/, ""); print}')
    #F_AREA=$(curl -s --connect-timeout 5 --max-time 10 "https://api.ip.sb/geoip/${F_IP}" | jq '.country,.region,.city' 2>/dev/null | sed -n 's/\"/ /gp' | awk 'NR == 1{printf "%s->",$0} NR == 2{printf "%s->",$0} NR == 3{printf "%s\n",$0}')
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



# 采集
wg show "${WG_IF}" dump > "${WG_LOGIN_STATUS_FILE}"
sed -i '1d' "${WG_LOGIN_STATUS_FILE}"
#
touch "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
while read LINE
do
    F_PARSE_WG_DUMP_LINE "${LINE}"
    F_LOOKUP_USER "${USER_PEER}" "${SERVER_CONF_FILE}"
    #
    # 是否有握手信息
    if [ "${USER_LATEST_HAND_SECOND}" -ne 0 ]; then
        # 有握手信息
        USER_LATEST_HAND_SECOND_TIME=$(date -d "@${USER_LATEST_HAND_SECOND}" +%H:%M:%S)
        #
        LINE_NUM=$(F_SEARCH_USER_NAME "${USER_NAME}")
        if [[ ${LINE_NUM} =~ ^[0-9]+$ ]]; then
            # 找到，代表用户登录过
            USER_ENDPOINT_IP_LAST=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $4}')
            USER_ENDPOINT_IP_LAST=$(echo ${USER_ENDPOINT_IP_LAST})
            USER_ENDPOINT_AREA=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $6}')
            USER_ENDPOINT_AREA=$(echo ${USER_ENDPOINT_AREA})
            #
            if [ "${USER_ENDPOINT_IP}" != "${USER_ENDPOINT_IP_LAST}" ]; then
                # 和上次登录IP不一样
                # 删除旧的
                sed -i "${LINE_NUM}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                USER_LOGIN_STATUS='已登录'
                # 重新获取地理位置
                USER_ENDPOINT_AREA=$(F_IP_AREA "${USER_ENDPOINT_IP}")
                echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                F_NEW_IP_SEND_MSG > /dev/null
                F_LOG "INFO" "用户IP变更：${USER_NAME}，新IP：${USER_ENDPOINT_IP}，位置：${USER_ENDPOINT_AREA}"
                continue
            fi
            #
            CURRENT_SECOND=$(date +%s)
            (( TIME_INTERVAL = CURRENT_SECOND - USER_LATEST_HAND_SECOND ))
            USER_LOGIN_STATUS_LAST=$(sed -n "${LINE_NUM}p" "${TODAY_WG_USER_LATEST_LOGIN_FILE}" | awk -F '|' '{print $7}')
            USER_LOGIN_STATUS_LAST=$(echo ${USER_LOGIN_STATUS_LAST})
            if [ ${TIME_INTERVAL} -gt 300 ]; then
                # 最后登录时间超过300秒
                if [[ "${USER_LOGIN_STATUS_LAST}" = "已登录" ]]; then
                    sed -i "${LINE_NUM}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                    USER_LOGIN_STATUS='已离线'
                    echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                    F_OFFLINE_SEND_MSG > /dev/null
                    F_LOG "INFO" "用户离线：${USER_NAME}"
                fi
            else
                # 最后登录时间小于300秒
                if [[ "${USER_LOGIN_STATUS_LAST}" = "已离线" ]]; then
                    sed -i "${LINE_NUM}d" "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                    USER_LOGIN_STATUS='已登录'
                    echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
                    F_LOGIN_SEND_MSG > /dev/null
                    F_LOG "INFO" "用户重新上线：${USER_NAME}，IP：${USER_ENDPOINT_IP}"
                fi
            fi
        else
            # 未找到，代表用户未登录过
            USER_LOGIN_STATUS='已登录'
            # 获取地理位置
            USER_ENDPOINT_AREA=$(F_IP_AREA "${USER_ENDPOINT_IP}")
            echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
            F_LOGIN_SEND_MSG > /dev/null
            F_LOG "INFO" "用户登录：${USER_NAME}，IP：${USER_ENDPOINT_IP}，位置：${USER_ENDPOINT_AREA}"
        fi
    fi
done < "${WG_LOGIN_STATUS_FILE}"


