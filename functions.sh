#!/bin/bash
#############################################################################
# 公共函数库
# License: GNU GPLv3
#############################################################################


# --- 日志 ---
LOG_DIR="${SH_PATH}/log"
LOG_FILE="${LOG_DIR}/wg-manage.log"

F_LOG()
{
    local level="$1"
    shift
    local msg="$*"
    [ -d "${LOG_DIR}" ] || mkdir -p "${LOG_DIR}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${level}] ${msg}" >> "${LOG_FILE}"
}


# --- 多接口支持 ---

# 切换 WG_IF 后重新计算衍生路径
# 用法：WG_IF=wg1; F_REFRESH_WG_PATHS
F_REFRESH_WG_PATHS()
{
    SERVER_CONF_FILE="${SERVER_CONF_FILE_PATH}/${WG_IF}.conf"
    # 尝试接口专用密钥，不存在则回退到通用 private.key
    local iface_key="${SERVER_CONF_FILE_PATH}/${WG_IF}-private.key"
    local generic_key="${SERVER_CONF_FILE_PATH}/private.key"
    if [ -f "${iface_key}" ]; then
        SERVER_PRIVATE_KEY="${iface_key}"
    elif [ -f "${generic_key}" ]; then
        SERVER_PRIVATE_KEY="${generic_key}"
    else
        # 新接口：使用接口专用路径（init-setup 将创建此文件）
        SERVER_PRIVATE_KEY="${iface_key}"
    fi
    TODAY_WG_USER_LATEST_LOGIN_FILE="/tmp/wg-user-latest-login-today-${WG_IF}.txt"
}


# --- WireGuard dump 解析 ---

# 解析 wg show dump 单行数据，设置全局变量
# 用法：F_PARSE_WG_DUMP_LINE "dump行内容"
F_PARSE_WG_DUMP_LINE()
{
    local line="$1"
    USER_PEER=$(echo "${line}" | awk '{print $1}')
    USER_PRESHARED_KEY=$(echo "${line}" | awk '{print $2}')
    USER_ENDPOINT=$(echo "${line}" | awk '{print $3}')
    USER_ENDPOINT_IP=$(echo "${USER_ENDPOINT}" | cut -d ':' -f 1)
    USER_ENDPOINT_UDP_PORT=$(echo "${USER_ENDPOINT}" | cut -d ':' -f 2)
    USER_ALLOWED_IPS=$(echo "${line}" | awk '{print $4}')
    USER_LATEST_HAND_SECOND=$(echo "${line}" | awk '{print $5}')
    USER_NET_IN=$(echo "${line}" | awk '{print $6}')
    USER_NET_OUT=$(echo "${line}" | awk '{print $7}')
    USER_KEEPALIVE=$(echo "${line}" | awk '{print $8}')
}


# 根据 PublicKey 反查用户名和 IP
# 用法：F_LOOKUP_USER "PublicKey" "配置文件路径"
F_LOOKUP_USER()
{
    local peer="$1"
    local conf="$2"
    USER_NAME=$(grep -B 2 "${peer}" "${conf}" | head -n 1 | awk '{print $2}')
    USER_IP=$(grep -B 2 "${peer}" "${conf}" | head -n 1 | awk '{print $3}')
}


# 字节转 MiB 计算
# 用法：F_CALC_MIB "IN字节" "OUT字节"
F_CALC_MIB()
{
    local bytes_in="$1"
    local bytes_out="$2"
    USER_NET_IN_MiB=$(echo "scale=1; ${bytes_in} / 1024 / 1024" | bc -l)
    USER_NET_OUT_MiB=$(echo "scale=1; ${bytes_out} / 1024 / 1024" | bc -l)
    USER_NET_TOTAL_MiB=$(echo "scale=1; ${USER_NET_IN_MiB} + ${USER_NET_OUT_MiB}" | bc -l)
}
