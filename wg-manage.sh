#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd "${SH_PATH}"


# env
. "${SH_PATH}/env.sh"
. "${SH_PATH}/functions.sh"

F_CHECK_ROOT
#......


# 本地env
SERVER_PUBKEY=$(wg pubkey < "${SERVER_PRIVATE_KEY}")  #--- wireguard服务器公钥
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
FORMAT_TABLE_SH="${SH_PATH}/format_table.sh"



F_HELP()
{
    echo "
    用途：用于wireguard的用户管理
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：./env.sh
          ./functions.sh
          qrencode
    注意：
    用法：
        $0  -h|--help
        $0  -l|--list
        $0  {-a|--add <用户名>}  [<IP第4段>]
        $0  {-r|--rm <用户名>}
        $0  {-o|--output-config <用户名>}
        $0  -R|--reload
        $0  -s|--status
    参数规范：
        无包围符号 ：-a                : 必选【选项】
                   ：val               : 必选【参数值】
                   ：val1 val2 -a -b   : 必选【选项或参数值】，且不分先后顺序
        []         ：[-a]              : 可选【选项】
                   ：[val]             : 可选【参数值】
        <>         ：<val>             : 需替换的具体值（用户必须提供）
        %%         ：%val%             : 通配符（包含匹配，如%error%匹配error_code）
        |          ：val1|val2|<valn>  : 多选一
        {}         ：{-a <val>}        : 必须成组出现【选项+参数值】，且保持顺序
                   ：{val1 val2}       : 必须成组的【参数值组合】，且必须按顺序提供
    参数说明：
        -h|--help                    此帮助
        -l|--list                    列出现有用户
        -a|--add <用户名>            添加用户
        -r|--rm <用户名>             删除用户
        -o|--output-config <用户名>  输出用户配置文件
        -R|--reload                  重启服务器
        -s|--status                  服务器状态
    示例:
        $0  -l              #--- 列出用户清单
        #
        $0  -a 猪猪侠 11    #--- 添加用户【猪猪侠】，IP地址尾号为【11】
        $0  -a 猪猪侠       #--- 添加用户【猪猪侠】，IP地址尾号自动分配
        #
        $0  -r 猪猪侠       #--- 删除用户【猪猪侠】
        #
        $0  -o 猪猪侠       #--- 输出用户【猪猪侠】的配置文件
        #
        $0  -R              #--- 重启服务器
        #
        $0  -s              #--- 查看服务器状态
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
Endpoint = ${SERVER_CONNECT_INFO}
PersistentKeepalive = 25
AllowedIPs = ${USER_ALOWED_IPs}
"
}



TEMP=$(getopt -o hla:r:o:Rs  -l help,list,add:,rm:,output-config:,reload,status -- "$@")
if [ $? != 0 ]; then
    echo -e "\n猪猪侠警告：参数不合法，请查看帮助【$0 --help】\n"
    exit 1
fi
#
eval set -- "${TEMP}"



while true
do
    case "$1" in
        -h|--help)
            shift
            F_HELP
            exit
            ;;
        -l|--list)
            shift
            grep '^##' "${SERVER_CONF_FILE}"
            exit
            ;;
        -a|--add)
            USER_NAME=$2
            shift 2
            shift         #--- 去掉'--'
            IP_SUFFIX=$1
            # 是否提供ip尾号
            if [ -z "${IP_SUFFIX}" ]; then
                # 未提供
                grep '##' "${SERVER_CONF_FILE}" | cut -d ' ' -f 3 | cut -d '.' -f 4 | sort > "${EXIST_IP_FILE}"
                sed -i 's/^/S/; s/$/E/' "${EXIST_IP_FILE}"
                # 普通用户IP从IP_START开始分配
                for i in $(seq "${IP_START}" 254); do
                    grep -q "S${i}E" "${EXIST_IP_FILE}"
                    if [ $? -ne 0 ]; then
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
                grep '##' "${SERVER_CONF_FILE}" | grep "${IP_SUFFIX}" | cut -d ' ' -f 3 | cut -d '.' -f 4 > "${SEARCH_IP_FILE}"
                sed -i 's/^/S/; s/$/E/' "${SEARCH_IP_FILE}"
                grep -q "S${IP_SUFFIX}E" "${SEARCH_IP_FILE}"
                if [ $? -eq 0 ]; then
                    echo -e "\n猪猪侠警告：IP尾号【${IP_SUFFIX}】已经存在，请换一个！\n"
                    exit 1
                fi
            fi
            USER_IP=${IP_PREFIX}.${IP_SUFFIX}
            # 用户是否已存在
            grep "##" "${SERVER_CONF_FILE}" | grep "${USER_NAME}" | cut -d ' ' -f 2 > "${EXIST_USER_FILE}"
            sed -i 's/^/S/; s/$/E/' "${EXIST_USER_FILE}"
            grep -q "S${USER_NAME}E" "${EXIST_USER_FILE}"
            if [ $? -eq 0 ]; then
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
            echo "用户端配置信息："
            echo '------------------------------'
            F_USER_CONF | tee "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK
            if command -v qrencode > /dev/null 2>&1; then
                qrencode -t ANSIUTF8 < "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
            else
                echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
            echo "OK"
            echo
            echo "服务器端：需要reload后才会生效"
            echo "用户端  ：请将上面【用户端配置信息】给到用户"
            echo
            F_LOG "INFO" "添加用户：${USER_NAME}，IP：${USER_IP}"
            #
            exit
            ;;
        -r|--rm)
            USER_NAME=$2
            shift 2
            # 删除${USER_CONFIG_PATH}目录下用户信息
            rm -f "${USER_CONFIG_PATH}/${USER_NAME}."*
            # 删除wgN.conf中的配置
            if ! grep -q "## ${USER_NAME} " "${SERVER_CONF_FILE}"; then
                echo -e "\n猪猪侠警告：用户【${USER_NAME}】不存在\n"
                exit 1
            fi
            sed -i "/^## ${USER_NAME} /,/^ *$/d" "${SERVER_CONF_FILE}"
            # 删除文件末尾的空行
            sed -i ':n;/^\n*$/{N;$d;bn}' "${SERVER_CONF_FILE}"
            F_LOG "INFO" "删除用户：${USER_NAME}"
            echo "OK，你需要reload服务器才能生效"
            exit
            ;;
        -o|--output-config)
            USER_NAME=$2
            shift 2
            if ! grep -q "## ${USER_NAME} " "${SERVER_CONF_FILE}"; then
                echo -e "\n猪猪侠警告：用户【${USER_NAME}】不存在\n"
                exit 1
            fi
            #
            echo "【${USER_NAME}】用户配置信息如下："
            echo '------------------------------'
            cat "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK
            if command -v qrencode > /dev/null 2>&1; then
                qrencode -t ANSIUTF8 < "${USER_CONFIG_PATH}/${USER_NAME}.conf.out"
            else
                echo -e "\n猪猪侠警告：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
            echo "OK"
            exit
            ;;
        -R|--reload)
            shift
            wg-quick down "${WG_IF}"
            wg-quick up "${WG_IF}"
            F_LOG "INFO" "重启服务器：接口=${WG_IF}"
            exit
            ;;
        -s|--status)
            shift
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
            exit
            ;;
        --)
            shift
            break
            ;;
        *)
            echo -e "\n猪猪侠警告：未知参数，请查看帮助【$0 --help】\n"
            exit 1
            ;;
    esac
done


