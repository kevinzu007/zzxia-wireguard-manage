#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}


# env
. ${SH_PATH}/env.sh
#......


# 本地env
SERVER_PUBKEY=`wg pubkey < ${SERVER_PRIVATE_KEY}`  #--- wireguard服务器公钥
# user_config
USER_CONFIG_PATH="${SH_PATH}/user_config_info"
[ ! -d ${USER_CONFIG_PATH} ] && mkdir ${USER_CONFIG_PATH}
#
WG_CURRENT_STATUS_FILE="/tmp/wg-current-status.txt"
WG_STATUS_REPORT_FILE="/tmp/wg-status-report.list"
# sh
FORMAT_TABLE_SH="${SH_PATH}/format_table.sh"



F_HELP()
{
    echo "
    用途：用于wireguard的用户管理
    依赖：./env.sh
          qrencode
    注意：
    用法：
        $0  [-h|--help]
        $0  [-l|--list]
        $0  [-a|--add {用户名}]  <{IP第4段}>
        $0  [-r|--rm|-o|--output-config  {用户名}]
        $0  [-R|--reload]
        $0  [-s|--status]
    参数说明：
        \$0   : 代表脚本本身
        []   : 代表是必选项
        <>   : 代表是可选项
        |    : 代表左右选其一
        {}   : 代表参数值，请替换为具体参数值
        %    : 代表通配符，非精确值，可以被包含
        #
        -h|--help      此帮助
        -l|--list      列出现有用户
        -a|--add       添加用户
        -r|--rm        删除用户
        -o|--output-config 输出用户配置文件
        -R|--reload    重启服务器
        -s|--status    服务器状态
    示例:
        #
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



TEMP=`getopt -o hla:r:o:Rs  -l help,list,add:,rm:,output-config:,reload,status -- "$@"`
if [ $? != 0 ]; then
    echo -e "\n峰哥说：参数不合法，请查看帮助【$0 --help】\n"
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
            grep '^##' ${SERVER_CONF_FILE}
            exit
            ;;
        -a|--add)
            USER_NAME=$2
            shift 2
            shift         #--- 去掉'--'
            IP_SUFFIX=$1
            # 是否提供ip尾号
            if [ -z "${IP_SUFFIX}" ]; then
                BASE_IP_SUFFIX=`grep '##' ${SERVER_CONF_FILE} | tail -n 1 | cut -d ' ' -f 3 | cut -d '.' -f 4`
                [ -z "${BASE_IP_SUFFIX}" ] && BASE_IP_SUFFIX=10
                let IP_SUFFIX=${BASE_IP_SUFFIX}+1
            else
                grep '##' ${SERVER_CONF_FILE} | grep "${IP_SUFFIX}" | cut -d ' ' -f 3 | cut -d '.' -f 4 | grep "${IP_SUFFIX}" > /tmp/${SH_NAME}-search-ip.list
                while read LINE; do
                    if [ "x${LINE}" = "x${IP_SUFFIX}" ]; then
                        echo -e "\n峰哥说：IP尾号【${IP_SUFFIX}】已经存在，请换一个！\n"
                        exit 1
                    fi
                done < /tmp/${SH_NAME}-search-ip.list
            fi
            USER_IP=${IP_PREFIX}.${IP_SUFFIX}
            # 用户是否已存在
            if [ `grep -q "## ${USER_NAME}" ${SERVER_CONF_FILE}; echo $?` -eq 0 ]; then
                echo -e "\n峰哥说：用户【${USER_NAME}】已存在\n"
                exit
            fi
            #
            SERVER_ALOWED_IPs="${USER_IP}/32"
            #
            USER_PRIVATEKEY=`wg genkey`
            USER_PUBKEY=`echo ${USER_PRIVATEKEY} | wg pubkey`
            SERVER_PRE_SHARED_KEY=`wg genpsk`
            #
            echo "服务器端配置信息："
            echo '------------------------------'
            F_SERVER_CONF | tee -a ${SERVER_CONF_FILE}
            echo '------------------------------'
            echo 'OK'
            echo
            echo "用户端配置信息："
            echo '------------------------------'
            F_USER_CONF | tee ${USER_CONFIG_PATH}/${USER_NAME}.conf.out
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK
            if [ `which qrencode > /dev/null 2>&1 ; echo $?` -eq 0 ]; then
                qrencode -t ANSIUTF8  < ${USER_CONFIG_PATH}/${USER_NAME}.conf.out
            else
                echo -e "\n峰哥说：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
            echo "OK"
            echo
            echo "服务器端：需要reload后才会生效"
            echo "用户端  ：请将上面【用户端配置信息】给到用户"
            echo
            #
            exit
            ;;
        -r|--rm)
            USER_NAME=$2
            shift 2
            # 删除${USER_CONFIG_PATH}目录下用户信息
            rm -f  ${USER_CONFIG_PATH}/${USER_NAME}.*
            # 删除wgN.conf中的配置
            if [ `grep -q "## ${USER_NAME}" ${SERVER_CONF_FILE}; echo $?` -ne 0 ]; then
                echo -e "\n峰哥说：用户【${USER_NAME}】不存在\n"
                exit 1
            fi
            sed -i "/^## ${USER_NAME}/,/^ *$/d" ${SERVER_CONF_FILE}
            # 删除文件末尾的空行
            sed -i ':n;/^\n*$/{N;$d;bn}'  ${SERVER_CONF_FILE}
            echo "OK，你需要reload服务器才能生效"
            exit
            ;;
        -o|--output-config)
            USER_NAME=$2
            shift 2
            if [ `grep -q "## ${USER_NAME}" ${SERVER_CONF_FILE}; echo $?` -ne 0 ]; then
                echo -e "\n峰哥说：用户【${USER_NAME}】不存在\n"
                exit 1
            fi
            #
            echo "【${USER_NAME}】用户配置信息如下："
            echo '------------------------------'
            cat  ${USER_CONFIG_PATH}/${USER_NAME}.conf.out
            echo '------------------------------'
            read -p '输出用户配置二维码，请按任意键......' ACK
            if [ `which qrencode > /dev/null 2>&1 ; echo $?` -eq 0 ]; then
                qrencode -t ANSIUTF8  < ${USER_CONFIG_PATH}/${USER_NAME}.conf.out
            else
                echo -e "\n峰哥说：没有找到软件【qrencode】，建议安装，这可以以二维码的方式输出配置信息，方便手机用户配置!\n"
            fi
            echo "OK"
            exit
            ;;
        -R|--reload)
            shift
            wg-quick down ${WG_IF}
            wg-quick up   ${WG_IF}
            exit
            ;;
        -s|--status)
            shift
            # 采集
            wg show "${WG_IF}" dump > "${WG_CURRENT_STATUS_FILE}"
            sed -i '1d' "${WG_CURRENT_STATUS_FILE}"
            # clean
            > ${WG_STATUS_REPORT_FILE}
            while read LINE
            do
                USER_PEER=`echo $LINE | awk '{print $1}'`
                USER_PRESHARED_KEY=`echo $LINE | awk '{print $2}'`
                USER_ENDPOINT=`echo $LINE | awk '{print $3}'`
                USER_ENDPOINT_IP=`echo ${USER_ENDPOINT} | cut -d ':' -f 1`
                USER_ALLOWED_IPS=`echo $LINE | awk '{print $4}'`
                USER_LATEST_HAND=`echo $LINE | awk '{print $5}'`
                USER_NET_IN=`echo $LINE | awk '{print $6}'`
                USER_NET_OUT=`echo $LINE | awk '{print $7}'`
                USER_KEEPALIVE=`echo $LINE | awk '{print $8}'`
                # 计算MiB
                USER_NET_IN_MiB=`echo "scale=1; ${USER_NET_IN} / 1024 / 1024" | bc -l`
                USER_NET_OUT_MiB=`echo "scale=1; ${USER_NET_OUT} / 1024 / 1024" | bc -l`
                USER_NET_TOTAL_MiB=`echo "scale=1; ${USER_NET_IN_MiB} + ${USER_NET_OUT_MiB}" | bc -l`
                #
                # 查用户
                USER_XINGMING=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $2}'`
                USER_IP=`grep -B 2 ${USER_PEER} ${SERVER_CONF_FILE} | head -n 1 | awk '{print $3}'`
                # 是否有握手信息
                if [ ${USER_LATEST_HAND} -ne 0 ]; then
                    USER_LATEST_HAND_TIME=`date -d @${USER_LATEST_HAND} +%H:%M:%S`
                    # 有握手信息
                    echo "| ${USER_XINGMING} | ${USER_LATEST_HAND_TIME} | ${USER_NET_TOTAL_MiB} | ${USER_NET_IN_MiB} | ${USER_NET_OUT_MiB} | ${USER_IP} | ${USER_ENDPOINT_IP} | " >> ${WG_STATUS_REPORT_FILE}
                fi
            done < ${WG_CURRENT_STATUS_FILE}
            ${FORMAT_TABLE_SH}  --delimeter '|'  --title '|姓名|最后握手时间|总流量MiB|IN流量MiB|OUT流量MiB|用户IP|远程IP|'  --file ${WG_STATUS_REPORT_FILE}
            exit
            ;;
        --)
            shift
            exit
            break
            ;;
        *)
            echo -e "\n峰哥说：未知参数，请查看帮助【$0 --help】\n"
            exit 1
            ;;
    esac
done

