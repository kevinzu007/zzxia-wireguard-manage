#!/bin/bash
#############################################################################
# Create By: ZZXia
# License: GNU GPLv3
# Test On: RockyLinux 9
#############################################################################


set -eo pipefail

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd "${SH_PATH}"


# env
. "${SH_PATH}/env.sh"
. "${SH_PATH}/functions.sh"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    F_HELP()
    {
        echo "
    用途：WireGuard 用户管理（添加、删除、查看用户及服务器状态）
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
        ./env.sh
        ./functions.sh
        qrencode            #-- 二维码生成（可选）
    注意：
        修改用户后需 reload 才能生效
    用法：
        \$0  --help|-h                                        #-- 帮助
        \$0  --list|-l                                        #-- 列出用户清单
        \$0  {--add|-a <用户名>}  [<IP第4段>]                 #-- 添加用户（自动生成 IPv4 及 IPv6 配置）
        \$0  {--rm|-r <用户名>}                               #-- 删除用户
        \$0  {--output-config|-o <用户名>}  [--ipv4|-4|--ipv6|-6] #-- 输出用户配置
        \$0  --reload|-R                                      #-- 重启服务器
        \$0  --status|-s                                      #-- 查看状态
    参数规范：
        |          : val1|val2|<valn>  : 多选一
        <>         : <val>             : 需替换的具体值（用户必须提供）
        %%         : %val%             : 双边通配符（包含匹配，如'%error%'匹配'os_error_code'）
        %          : val%              : 单边通配符（包含匹配，如'error%'匹配'error_code'，'%error%'匹配'os_error'）
        []         : [-a]              : 可选
                   : [-a val val2]     : 可选，必须成组出现，且保持顺序
        {}         : {-a}              : 必选
                   : {-a val val2}     : 必选，必须成组出现，且保持顺序
        无{}[]包围 : -a                : 必选
                   : -a val val2       : 必选，且不分先后顺序
        [{}]       : [{-a val1} val2]  : 总体可选，使用此项时，必选'-a val1'，可选'val2'，必须成组出现，且保持顺序
        {[]}       : {[-a val1] val2}  : 总体必选，使用此项时，可选'-a val1'，必选'val2'，必须成组出现，且保持顺序
        arg1[,...argn] : val1,val2,var3=val3 : 有一个参数或多个参数，用','分隔
    参数说明：
        --help|-h                    # 帮助
        --list|-l                    # 列出用户清单
        --add|-a <用户名>            # 添加用户（可选指定IP尾号）
        --rm|-r <用户名>             # 删除用户
        --output-config|-o <用户名>  # 输出用户配置文件
        --ipv4|-4                    # 配合 -o 使用，仅输出 IPv4 配置
        --ipv6|-6                    # 配合 -o 使用，仅输出 IPv6 配置
        --reload|-R                  # 重启服务器
        --status|-s                  # 查看服务器状态
    示例：
        \$0  -l              #-- 列出用户清单
        #
        \$0  -a 猪猪侠 11    #-- 添加用户【猪猪侠】，IP地址尾号设为11
        \$0  -a 猪猪侠       #-- 添加用户【猪猪侠】，IP地址尾号自动分配
        #
        \$0  -r 猪猪侠       #-- 删除用户【猪猪侠】
        #
        \$0  -o 猪猪侠       #-- 输出用户【猪猪侠】的 IPv4 及 IPv6 配置文件
        \$0  -o 猪猪侠 -4    #-- 仅输出用户【猪猪侠】的 IPv4 配置文件
        \$0  -o 猪猪侠 -6    #-- 仅输出用户【猪猪侠】的 IPv6 配置文件
        #
        \$0  -R              #-- 重启服务器
        #
        \$0  -s              #-- 查看服务器状态
"
    }
    F_HELP
    exit 0
fi

F_CHECK_ROOT
#......


# 本地env
if [ -f "${SERVER_PRIVATE_KEY}" ]; then
    SERVER_PUBKEY=$(wg pubkey < "${SERVER_PRIVATE_KEY}" 2>/dev/null || true)
else
    SERVER_PUBKEY=""
fi
# user_config
USER_CONFIG_PATH="${SH_PATH}/user_config_info"
[ ! -d "${USER_CONFIG_PATH}" ] && mkdir "${USER_CONFIG_PATH}"
#
# 临时文件（使用临时目录统一管理）
TEMP_DIR=$(mktemp -d /tmp/wg-manage.XXXXXX)
trap 'rm -rf "${TEMP_DIR}"' EXIT
WG_CURRENT_STATUS_FILE="${TEMP_DIR}/current-status.txt"
WG_STATUS_REPORT_FILE="${TEMP_DIR}/status-report.list"
EXIST_IP_FILE="${TEMP_DIR}/exist-ip.list"
SEARCH_IP_FILE="${TEMP_DIR}/search-ip.list"
EXIST_USER_FILE="${TEMP_DIR}/exist-user.list"
# sh
FORMAT_TABLE_SH="${SH_PATH}/format-table.sh"



F_HELP()
{
    echo "
    用途：WireGuard 用户管理（添加、删除、查看用户及服务器状态）
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
        ./env.sh
        ./functions.sh
        qrencode            #-- 二维码生成（可选）
    注意：
        修改用户后需 reload 才能生效
    用法：
        \$0  --help|-h                                        #-- 帮助
        \$0  --list|-l                                        #-- 列出用户清单
        \$0  {--add|-a <用户名>}  [<IP第4段>]                 #-- 添加用户（自动生成 IPv4 及 IPv6 配置）
        \$0  {--rm|-r <用户名>}                               #-- 删除用户
        \$0  {--output-config|-o <用户名>}  [--ipv4|-4|--ipv6|-6] #-- 输出用户配置
        \$0  --reload|-R                                      #-- 重启服务器
        \$0  --status|-s                                      #-- 查看状态
    参数规范：
        |          : val1|val2|<valn>  : 多选一
        <>         : <val>             : 需替换的具体值（用户必须提供）
        %%         : %val%             : 双边通配符（包含匹配，如'%error%'匹配'os_error_code'）
        %          : val%              : 单边通配符（包含匹配，如'error%'匹配'error_code'，'%error%'匹配'os_error'）
        []         : [-a]              : 可选
                   : [-a val val2]     : 可选，必须成组出现，且保持顺序
        {}         : {-a}              : 必选
                   : {-a val val2}     : 必选，必须成组出现，且保持顺序
        无{}[]包围 : -a                : 必选
                   : -a val val2       : 必选，且不分先后顺序
        [{}]       : [{-a val1} val2]  : 总体可选，使用此项时，必选'-a val1'，可选'val2'，必须成组出现，且保持顺序
        {[]}       : {[-a val1] val2}  : 总体必选，使用此项时，可选'-a val1'，必选'val2'，必须成组出现，且保持顺序
        arg1[,...argn] : val1,val2,var3=val3 : 有一个参数或多个参数，用','分隔
    参数说明：
        --help|-h                    # 帮助
        --list|-l                    # 列出用户清单
        --add|-a <用户名>            # 添加用户（可选指定IP尾号）
        --rm|-r <用户名>             # 删除用户
        --output-config|-o <用户名>  # 输出用户配置文件
        --ipv4|-4                    # 配合 -o 使用，仅输出 IPv4 配置
        --ipv6|-6                    # 配合 -o 使用，仅输出 IPv6 配置
        --reload|-R                  # 重启服务器
        --status|-s                  # 查看服务器状态
    示例：
        \$0  -l              #-- 列出用户清单
        #
        \$0  -a 猪猪侠 11    #-- 添加用户【猪猪侠】，IP地址尾号设为11
        \$0  -a 猪猪侠       #-- 添加用户【猪猪侠】，IP地址尾号自动分配
        #
        \$0  -r 猪猪侠       #-- 删除用户【猪猪侠】
        #
        \$0  -o 猪猪侠       #-- 输出用户【猪猪侠】的 IPv4 及 IPv6 配置文件
        \$0  -o 猪猪侠 -4    #-- 仅输出用户【猪猪侠】的 IPv4 配置文件
        \$0  -o 猪猪侠 -6    #-- 仅输出用户【猪猪侠】的 IPv6 配置文件
        #
        \$0  -R              #-- 重启服务器
        #
        \$0  -s              #-- 查看服务器状态
"
}



F_SERVER_CONF()
{
    #
    echo "
## ${USER_NAME} ${USER_IP}
[Peer]
PublicKey = ${USER_PUBKEY}
PresharedKey = ${SERVER_PRE_SHARED_KEY}
AllowedIPs = ${SERVER_ALOWED_IPs}
"
}



F_USER_CONF()
{
    local endpoint="${1:-${SERVER_CONNECT_INFO}}"
    #
    echo "
## ${USER_NAME} ${USER_IP}
[Interface]
Address = ${USER_IP}/${IP_NETMASK}
PrivateKey = ${USER_PRIVATEKEY}
DNS = ${USER_DNSs}

[Peer]
PublicKey = ${SERVER_PUBKEY}
PresharedKey = ${SERVER_PRE_SHARED_KEY}
Endpoint = ${endpoint}
PersistentKeepalive = 25
AllowedIPs = ${USER_ALOWED_IPs}
"
}



if ! TEMP=$(getopt -o 46hla:r:o:Rs  -l ipv4,ipv6,help,list,add:,rm:,output-config:,reload,status -- "$@"); then
    echo -e "\n猪猪侠警告：参数不合法，请查看帮助【$0 --help】\n"
    exit 1
fi
#
eval set -- "${TEMP}"

ACTION=""
USER_NAME=""
IP_SUFFIX=""
SHOW_PROTO="all"

while true
do
    case "$1" in
        -h|--help)
            F_HELP
            exit 0
            ;;
        -4|--ipv4)
            SHOW_PROTO="ipv4"
            shift
            ;;
        -6|--ipv6)
            SHOW_PROTO="ipv6"
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -a|--add)
            ACTION="add"
            USER_NAME=$2
            shift 2
            ;;
        -r|--rm)
            ACTION="rm"
            USER_NAME=$2
            shift 2
            ;;
        -o|--output-config)
            ACTION="output"
            USER_NAME=$2
            shift 2
            ;;
        -R|--reload)
            ACTION="reload"
            shift
            ;;
        -s|--status)
            ACTION="status"
            shift
            ;;
        --)
            shift
            if [ -n "$1" ]; then
                IP_SUFFIX="$1"
                shift
            fi
            break
            ;;
        *)
            echo -e "\n猪猪侠警告：未知参数，请查看帮助【$0 --help】\n"
            exit 1
            ;;
    esac
done

case "${ACTION}" in
    list)
        (grep '^##' "${SERVER_CONF_FILE}" 2>/dev/null || true)
        exit 0
        ;;
    add)
        F_VALIDATE_USERNAME "${USER_NAME}" || exit 1
        # 是否提供ip尾号
        if [ -z "${IP_SUFFIX}" ]; then
            # 未提供
            (grep '##' "${SERVER_CONF_FILE}" 2>/dev/null || true) | cut -d ' ' -f 3 | cut -d '.' -f 4 | sort > "${EXIST_IP_FILE}"
            sed -i 's/^/S/; s/$/E/' "${EXIST_IP_FILE}"
            # 普通用户IP从IP_START开始分配
            for i in $(seq "${IP_START}" 254); do
                if ! grep -q "S${i}E" "${EXIST_IP_FILE}"; then
                    IP_SUFFIX=$i
                    break
                fi
            done
            if [ -z "${IP_SUFFIX}" ]; then
                echo -e "\n猪猪侠警告：我艹，IP地址【${IP_PREFIX}.[${IP_START}~254]】已经用完了！\n"
                exit 9
            fi
        else
            # 已提供
            (grep '##' "${SERVER_CONF_FILE}" 2>/dev/null || true) | (grep "${IP_SUFFIX}" || true) | cut -d ' ' -f 3 | cut -d '.' -f 4 > "${SEARCH_IP_FILE}"
            sed -i 's/^/S/; s/$/E/' "${SEARCH_IP_FILE}"
            if grep -q "S${IP_SUFFIX}E" "${SEARCH_IP_FILE}"; then
                echo -e "\n猪猪侠警告：IP尾号【${IP_SUFFIX}】已经存在，请换一个！\n"
                exit 1
            fi
        fi
        USER_IP=${IP_PREFIX}.${IP_SUFFIX}
        # 用户是否已存在
        (grep "##" "${SERVER_CONF_FILE}" 2>/dev/null || true) | (grep "${USER_NAME}" || true) | cut -d ' ' -f 2 > "${EXIST_USER_FILE}"
        sed -i 's/^/S/; s/$/E/' "${EXIST_USER_FILE}"
        if grep -q "S${USER_NAME}E" "${EXIST_USER_FILE}"; then
            echo -e "\n猪猪侠警告：用户【${USER_NAME}】已存在\n"
            exit 1
        fi
        #
        SERVER_ALOWED_IPs="${USER_IP}/32"
        #
        USER_PRIVATEKEY=$(wg genkey)
        USER_PUBKEY=$(echo "${USER_PRIVATEKEY}" | wg pubkey)
        SERVER_PRE_SHARED_KEY=$(wg genpsk)
        #
        echo "服务器端配置信息："
        echo '------------------------------'
        F_SERVER_CONF | tee -a "${SERVER_CONF_FILE}"
        echo '------------------------------'
        echo 'OK'
        echo
        # 生成 IPv4 配置
        F_USER_CONF "${SERVER_CONNECT_INFO}" > "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
        # 如果配置了 SERVER_CONNECT_INFO_V6，则生成 IPv6 配置
        if [ -n "${SERVER_CONNECT_INFO_V6}" ]; then
            F_USER_CONF "${SERVER_CONNECT_INFO_V6}" > "${USER_CONFIG_PATH}/${USER_NAME}-ipv6.conf.out"
        fi
        echo "用户端配置信息 (IPv4)："
        echo '------------------------------'
        cat "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
        echo '------------------------------'
        if [ -n "${SERVER_CONNECT_INFO_V6}" ]; then
            echo
            echo "用户端配置信息 (IPv6)："
            echo '------------------------------'
            cat "${USER_CONFIG_PATH}/${USER_NAME}-ipv6.conf.out"
            echo '------------------------------'
        fi
        read -p '输出用户配置二维码，请按任意键......' ACK || true
        if command -v qrencode > /dev/null 2>&1; then
            echo
            echo "【IPv4 配置二维码】"
            qrencode -t ANSIUTF8 < "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
            if [ -n "${SERVER_CONNECT_INFO_V6}" ]; then
                echo
                echo "【IPv6 配置二维码】"
                qrencode -t ANSIUTF8 < "${USER_CONFIG_PATH}/${USER_NAME}-ipv6.conf.out"
            fi
        else
            echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
        fi
        echo "OK"
        echo
        echo "服务器端：需要reload后才会生效"
        echo "用户端  ：请将上面【用户端配置信息】给到用户"
        echo
        F_LOG "INFO" "添加用户：${USER_NAME}，IP：${USER_IP}"
        exit 0
        ;;
    rm)
        F_VALIDATE_USERNAME "${USER_NAME}" || exit 1
        # 删除${USER_CONFIG_PATH}目录下用户信息
        rm -f "${USER_CONFIG_PATH}/${USER_NAME}."* "${USER_CONFIG_PATH}/${USER_NAME}-ipv6."*
        # 删除wgN.conf中的配置
        SAFE_USER_NAME=$(F_SED_ESCAPE "${USER_NAME}")
        if ! grep -qF "## ${USER_NAME} " "${SERVER_CONF_FILE}"; then
            echo -e "\n猪猪侠警告：用户【${USER_NAME}】不存在\n"
            exit 1
        fi
        sed -i "/^## ${SAFE_USER_NAME} /,/^ *$/d" "${SERVER_CONF_FILE}"
        # 删除文件末尾的空行
        sed -i ':n;/^\n*$/{N;$d;bn}' "${SERVER_CONF_FILE}"
        F_LOG "INFO" "删除用户：${USER_NAME}"
        echo "OK，你需要reload服务器才能生效"
        exit 0
        ;;
    output)
        F_VALIDATE_USERNAME "${USER_NAME}" || exit 1
        if ! grep -qF "## ${USER_NAME} " "${SERVER_CONF_FILE}"; then
            echo -e "\n猪猪侠警告：用户【${USER_NAME}】不存在\n"
            exit 1
        fi

        V4_CONF="${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
        V6_CONF="${USER_CONFIG_PATH}/${USER_NAME}-ipv6.conf.out"

        # 兼容已有用户：若配置了 SERVER_CONNECT_INFO_V6 且存在 V4 配置但缺少 V6 文件，自动派生
        if [ -n "${SERVER_CONNECT_INFO_V6}" ] && [ ! -f "${V6_CONF}" ] && [ -f "${V4_CONF}" ]; then
            sed "s|^Endpoint = .*|Endpoint = ${SERVER_CONNECT_INFO_V6}|" "${V4_CONF}" > "${V6_CONF}"
        fi

        if [ "${SHOW_PROTO}" = "ipv4" ]; then
            if [ ! -f "${V4_CONF}" ]; then
                echo -e "\n猪猪侠警告：未找到用户【${USER_NAME}】的 IPv4 配置文件\n"
                exit 1
            fi
            echo "【${USER_NAME}】用户 IPv4 配置信息如下："
            echo '------------------------------'
            cat "${V4_CONF}"
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK || true
            if command -v qrencode > /dev/null 2>&1; then
                qrencode -t ANSIUTF8 < "${V4_CONF}"
            else
                echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
        elif [ "${SHOW_PROTO}" = "ipv6" ]; then
            if [ ! -f "${V6_CONF}" ]; then
                echo -e "\n猪猪侠警告：未找到用户【${USER_NAME}】的 IPv6 配置文件，请检查 env.sh 中是否配置了 SERVER_CONNECT_INFO_V6\n"
                exit 1
            fi
            echo "【${USER_NAME}】用户 IPv6 配置信息如下："
            echo '------------------------------'
            cat "${V6_CONF}"
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK || true
            if command -v qrencode > /dev/null 2>&1; then
                qrencode -t ANSIUTF8 < "${V6_CONF}"
            else
                echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
        else
            echo "【${USER_NAME}】用户 IPv4 配置信息如下："
            echo '------------------------------'
            if [ -f "${V4_CONF}" ]; then
                cat "${V4_CONF}"
            else
                echo "（无 IPv4 配置文件）"
            fi
            echo '------------------------------'

            if [ -f "${V6_CONF}" ]; then
                echo
                echo "【${USER_NAME}】用户 IPv6 配置信息如下："
                echo '------------------------------'
                cat "${V6_CONF}"
                echo '------------------------------'
            fi

            read -p '输出用户配置二维码，请按任意键......' ACK || true
            if command -v qrencode > /dev/null 2>&1; then
                if [ -f "${V4_CONF}" ]; then
                    echo
                    echo "【IPv4 配置二维码】"
                    qrencode -t ANSIUTF8 < "${V4_CONF}"
                fi
                if [ -f "${V6_CONF}" ]; then
                    echo
                    echo "【IPv6 配置二维码】"
                    qrencode -t ANSIUTF8 < "${V6_CONF}"
                fi
            else
                echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
        fi
        echo "OK"
        exit 0
        ;;
    reload)
        wg-quick down "${WG_IF}"
        wg-quick up "${WG_IF}"
        F_LOG "INFO" "重启服务器：接口=${WG_IF}"
        exit 0
        ;;
    status)
        # 采集
        wg show "${WG_IF}" dump > "${WG_CURRENT_STATUS_FILE}"
        sed -i '1d' "${WG_CURRENT_STATUS_FILE}"
        # clean
        > "${WG_STATUS_REPORT_FILE}"
        while read LINE
        do
            F_PARSE_WG_DUMP_LINE "${LINE}"
            F_LOOKUP_USER "${USER_PEER}" "${SERVER_CONF_FILE}"
            F_CALC_MIB "${USER_NET_IN}" "${USER_NET_OUT}"
            # 是否有握手信息
            if [ "${USER_LATEST_HAND_SECOND}" -ne 0 ]; then
                USER_LATEST_HAND_SECOND_TIME=$(date -d "@${USER_LATEST_HAND_SECOND}" +%H:%M:%S)
                # 有握手信息
                echo "| ${USER_NAME} | ${USER_LATEST_HAND_SECOND_TIME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> "${WG_STATUS_REPORT_FILE}"
            fi
        done < "${WG_CURRENT_STATUS_FILE}"
        "${FORMAT_TABLE_SH}" --delimeter '|' --title '|用户名|最后握手时间|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|' --file "${WG_STATUS_REPORT_FILE}"
        exit 0
        ;;
    *)
        F_HELP
        exit 0
        ;;
esac


