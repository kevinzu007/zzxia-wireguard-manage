#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每2分钟运行一次
# */2 * * * *  /root/zzxia-wireguard-manage/wg-login-alert.sh
#
# 等待日报完成统计并重启清零
sleep 30


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}


# env
. /etc/profile         #--- 计划任务需要
. ${SH_PATH}/env.sh
#TODAY_WG_USER_LATEST_LOGIN_FILE=


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
    echo -e "猪猪侠警告：${SH_NAME} - 请安装软件jq"
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg用户登录:`hostname -s`】"  \
        --message "$( echo -e "### 请安装软件jq" )"
    exit 1
fi



# 登录钉钉消息
F_LOGIN_SEND_DINGDING()
{
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg登录:`hostname -s`】"  \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )"
}

# 登录钉钉消息
F_NEW_IP_SEND_DINGDING()
{
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg登录:`hostname -s`】"  \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 新远程IP：${USER_ENDPOINT_IP} \n### 地理位置：${USER_ENDPOINT_AREA} \n\n" )"
}

# 离线钉钉消息
F_OFFLINE_SEND_DINGDING()
{
    ${DINGDING_MARKDOWN_PY}  \
        --title "【Info:wg用户离线:`hostname -s`】"  \
        --message "$( echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n\n" )"
}


## 邮件
#F_SEND_MAIL()
#{
#    echo -e "### 用户：${USER_NAME} \n### 最近握手时间：${USER_LATEST_HAND_SECOND_TIME} \n### WG_IP：${USER_IP} \n### 远程IP：${USER_ENDPOINT_IP} \n\n" | mailx  -s "【wg登录:`hostname -s`}】用户：${USER_NAME}"  ${EMAIL}  >/dev/null 2>&1
#}


# 获取IP位置，用法： F_IP_AREA {IP}
F_IP_AREA()
{
    F_IP=$1
    F_AREA=` curl -s "http://www.cip.cc/${F_IP}" | grep '数据二' | awk -F ":" '{print $2}' | awk '{gsub(/^\s+|\s+$/, ""); print}' | awk '{gsub(/\s+/, ""); print}' `
    #F_AREA=` curl -s https://api.ip.sb/geoip/${F_IP} | jq '.country,.region,.city' 2>/dev/null | sed -n 's/\"/ /gp' | awk 'NR == 1{printf "%s->",$0} NR == 2{printf "%s->",$0} NR == 3{printf "%s\n",$0}' `
    if [ "x${F_AREA}" = "x" -o "x${F_AREA}" = "xnull" ]; then
        F_AREA="获取失败：${F_IP}"
    fi
    F_AREA=`echo ${F_AREA} | sed -e 's/\"//g' -e 's/|//g'`
    echo "${F_AREA}"
    return 0
}



# 搜索用户用户名，找到，则返回行号
# 用法：F_SEARCH_USER_NAME  用户名
F_SEARCH_USER_NAME()
{
    F_USER_NAME=$1
    N=0      #--- 记录行号
    #
    while read LINE
    do
        let N=$N+1
        F_LINE_USER_NAME=$(echo $LINE | cut -d '|' -f 3)
        F_LINE_USER_NAME=$(echo ${F_LINE_USER_NAME})
        #
        if [[ ${F_USER_NAME} = ${F_LINE_USER_NAME} ]]; then
            echo $N
            return 0
        fi
    done < ${TODAY_WG_USER_LATEST_LOGIN_FILE}
    #
    # 未找到
    return 1
}



# 采集
wg show "${WG_IF}" dump > "${WG_LOGIN_STATUS_FILE}"
sed -i '1d' "${WG_LOGIN_STATUS_FILE}"
#
touch ${TODAY_WG_USER_LATEST_LOGIN_FILE}
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
    #
    # 是否有握手信息
    if [ ${USER_LATEST_HAND_SECOND} -ne 0 ]; then
        # 有握手信息
        USER_LATEST_HAND_SECOND_TIME=`date -d @${USER_LATEST_HAND_SECOND} +%H:%M:%S`
        #
        LINE_NUM=$(F_SEARCH_USER_NAME  ${USER_NAME})
        if [[ ${LINE_NUM} =~ ^[0-9]+$ ]]; then
            # 找到，代表用户登录过
            USER_ENDPOINT_IP_LAST=$(sed -n "${LINE_NUM}}p"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}  |  awk -F '|' '{print $4}')
            USER_ENDPOINT_IP_LAST=$(echo ${USER_ENDPOINT_IP_LAST})
            USER_ENDPOINT_AREA=$(sed -n "${LINE_NUM}}p"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}  |  awk -F '|' '{print $6}')
            USER_ENDPOINT_AREA=$(echo ${USER_ENDPOINT_IP_LAST})
            #
            if [ "${USER_ENDPOINT_IP}" != "${USER_ENDPOINT_IP_LAST}" ]; then
                # 和上次登录IP不一样
                # 删除旧的
                sed -i "${LINE_NUM}d"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                USER_LOGIN_STATUS='已登录'
                # 重新获取地理位置
                USER_ENDPOINT_AREA=`F_IP_AREA ${USER_ENDPOINT_IP}`
                echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                F_NEW_IP_SEND_DINGDING > /dev/null
                continue
            fi
            #
            CURRENT_SECOND=$(date +%s)
            let TIME_INTERVAL=${CURRENT_SECOND}-${USER_LATEST_HAND_SECOND}
            USER_LOGIN_STATUS_LAST=$(sed -n "${LINE_NUM}}p"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}  |  awk -F '|' '{print $7}')
            USER_LOGIN_STATUS_LAST=$(echo ${USER_LOGIN_STATUS_LAST})
            if [ ${TIME_INTERVAL} -gt 300 ]; then
                # 最后登录时间超过300秒
                if [[ "${USER_LOGIN_STATUS_LAST}" = "已登录" ]]; then
                    sed -i "${LINE_NUM}d"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                    USER_LOGIN_STATUS='已离线'
                    echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                    F_OFFLINE_SEND_DINGDING > /dev/null
                fi
            else
                # 最后登录时间小于300秒
                if [[ "${USER_LOGIN_STATUS_LAST}" = "已离线" ]]; then
                    sed -i "${LINE_NUM}d"  ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                    USER_LOGIN_STATUS='已登录'
                    echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> ${TODAY_WG_USER_LATEST_LOGIN_FILE}
                    F_LOGIN_SEND_DINGDING > /dev/null
                fi
            fi
        else
            # 未找到，代表用户未登录过
            USER_LOGIN_STATUS='已登录'
            # 获取地理位置
            USER_ENDPOINT_AREA=`F_IP_AREA ${USER_ENDPOINT_IP}`
            echo "| ${CURRENT_DATE} | ${USER_NAME} | ${USER_ENDPOINT_IP} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_ENDPOINT_AREA} | ${USER_LOGIN_STATUS} |" >> ${TODAY_WG_USER_LATEST_LOGIN_FILE}
            F_LOGIN_SEND_DINGDING > /dev/null
        fi
    fi
done < ${WG_LOGIN_STATUS_FILE}


