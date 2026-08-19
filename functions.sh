#!/bin/bash
#############################################################################
# Create By: ZZXia
# License: GNU GPLv3
# Test On: RockyLinux 9
# Description: 公共函数库
#############################################################################


# --- 权限检查 ---
F_CHECK_ROOT()
{
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        echo -e "\n猪猪侠错误：此脚本需要 root 权限才能运行！\n" >&2
        exit 1
    fi
}

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


# --- WireGuard dump 解析 ---

# 解析 wg show dump 单行数据，设置全局变量
# 用法：F_PARSE_WG_DUMP_LINE "dump行内容"
F_PARSE_WG_DUMP_LINE()
{
    local line="$1"
    USER_PEER=$(echo "${line}" | awk '{print $1}')
    USER_PRESHARED_KEY=$(echo "${line}" | awk '{print $2}')
    USER_ENDPOINT=$(echo "${line}" | awk '{print $3}')
    if [[ "${USER_ENDPOINT}" =~ ^\[([0-9a-fA-F:]+)\]:([0-9]+)$ ]]; then
        USER_ENDPOINT_IP="${BASH_REMATCH[1]}"
        USER_ENDPOINT_UDP_PORT="${BASH_REMATCH[2]}"
    elif [[ "${USER_ENDPOINT}" =~ ^([^:]+):([0-9]+)$ ]]; then
        USER_ENDPOINT_IP="${BASH_REMATCH[1]}"
        USER_ENDPOINT_UDP_PORT="${BASH_REMATCH[2]}"
    else
        USER_ENDPOINT_IP="${USER_ENDPOINT}"
        USER_ENDPOINT_UDP_PORT=""
    fi
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


# --- 输入校验 ---

# 用户名合法性校验：拒绝含有 sed/grep 危险字符的用户名
# 允许：中文、英文字母、数字、下划线、中横线、点
# 用法：F_VALIDATE_USERNAME "用户名"
F_VALIDATE_USERNAME()
{
    local name="$1"
    if [ -z "${name}" ]; then
        echo -e "\n猪猪侠警告：用户名不能为空\n" >&2
        return 1
    fi
    # 拒绝包含 sed/grep/shell 危险字符的用户名：/ \ & * ? [ ] ^ $ . | ( ) { } ! ; ` " ' # 空格 制表符
    if echo "${name}" | grep -qP '[/\\&*?\[\]^$|(){}!;`"'"'"'#\s]'; then
        echo -e "\n猪猪侠警告：用户名【${name}】包含非法字符\n" >&2
        echo -e "允许的字符：中文、英文字母、数字、下划线(_)、中横线(-)、点(.)\n" >&2
        return 1
    fi
    return 0
}

# 转义 sed 正则中的特殊字符（防御性措施）
# 用法：escaped=$(F_SED_ESCAPE "字符串")
F_SED_ESCAPE()
{
    printf '%s' "$1" | sed -e 's/[]\/$*.^&[]/\\&/g'
}


# --- IP 地理位置查询 ---

# 获取 IP 地理位置（支持 IPv4 / IPv6）
# 用法：F_IP_AREA "IP地址"
F_IP_AREA()
{
    local ip="$1"
    local area=""
    local resp=""

    if [ -z "${ip}" ] || [ "${ip}" = "(none)" ]; then
        echo "未知"
        return 0
    fi

    # 优先使用 ip-api.com
    resp=$(curl -s --connect-timeout 5 --max-time 10 "http://ip-api.com/json/${ip}?lang=zh-CN" 2>/dev/null || true)
    if [ -n "${resp}" ] && echo "${resp}" | jq -e '.status == "success"' >/dev/null 2>&1; then
        area=$(echo "${resp}" | jq -r '
            [.country, .regionName, .city, .isp] 
            | map(select(. != null and . != "")) 
            | join(" ")
        ' 2>/dev/null || true)
    fi

    # 备用方案：ipwho.is
    if [ -z "${area}" ]; then
        resp=$(curl -s --connect-timeout 5 --max-time 10 "https://ipwho.is/${ip}?lang=zh-CN" 2>/dev/null || true)
        if [ -n "${resp}" ] && echo "${resp}" | jq -e '.success == true' >/dev/null 2>&1; then
            area=$(echo "${resp}" | jq -r '
                [.country, .region, .city, .connection.isp] 
                | map(select(. != null and . != "")) 
                | join(" ")
            ' 2>/dev/null || true)
        fi
    fi

    if [ -z "${area}" ] || [ "${area}" = "null" ]; then
        area="获取失败：${ip}"
    fi

    # 过滤可能影响 Markdown 表格或引号的字符
    area=$(echo "${area}" | sed -e 's/\"//g' -e 's/|//g')
    echo "${area}"
    return 0
}

