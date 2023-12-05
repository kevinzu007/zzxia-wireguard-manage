#!/bin/bash
#############################################################################
# Create By: 猪猪侠
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
#cd "${SH_PATH}"


# 引入/etc/profile


# 引入env.sh
#. env.sh
dingding_api_url=${DINGDING_API_URL_FOR_LOGIN}
#dingding_api_url="https://oapi.dingtalk.com/robot/send?access_token=你自己的钉钉机器人token"


# 本地env
HOSTNAME=$(hostname)    #-- 获取主机名
DATETIME=$(date "+%Y-%m-%d %H:%M:%S %z")    #-- 小时时间标记
send_title=""
send_message=""


# 用法：
F_HELP()
{
    echo "
    用途：将markdown格式的文本通过钉钉机器人发送出去
    依赖：
    注意：输入命令时，参数顺序不分先后
    用法:
        $0  [-h|--help]
        $0  [-t|--title 标题  -m|--message ]
    参数说明：
        \$0   : 代表脚本本身
        []   : 代表是必选项
        <>   : 代表是可选项
        |    : 代表左右选其一
        {}   : 代表参数值，请替换为具体参数值
        %    : 代表通配符，非精确值，可以被包含
        #
        -h|--help        此帮助
        -t|--title       项目列表
        -m|--message     发布
    示例:
        $0  -t 'sssss'       -m \"\`cat xxx.md\`\"
        $0  --title 'sssss'  --message \"\`cat xxx.md\`\"        #-- 从文件获取
        $0  --title 'sssss'  --message "### 用户：${USER}"   #-- 简单输出
        $0  --title 'sssss'  --message "$( echo -e "### 用户：${USER} \n### 时间：`date` \n\n" )"
    "
}



# 参数检查
TEMP=`getopt -o ht:m:  -l help,title:,message: -- "$@"`
if [ $? != 0 ]; then
    echo -e "\n猪猪侠警告：参数不合法，请查看帮助【$0 --help】\n"
    exit 51
fi
#
eval set -- "${TEMP}"



while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            shift
            F_HELP
            ;;
        -t|--title)
            send_title="$2"
            shift 2
            ;;
        -m|--message)
            send_message="$2"
            #shift 2     #-- 如果不够两个将会失败，造成死循环
            shift
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo -e "\n猪猪侠警告：未知参数，请查看帮助【$0 --help】\n"
            exit 51
            ;;
    esac
done

if [[ -z $send_title || -z $send_message ]]; then
    echo -e "\n猪猪侠警告：参数不足，请查看帮助【$0 --help】\n"
    exit 51
fi

send_message="### ${send_title} \n---\n${send_message} \n\n---\n\n*发自: ${HOSTNAME}*\n\n*时间: ${DATETIME}*\n\n"

send_header="Content-Type: application/json; charset=utf-8"

send_data=$(cat <<EOF
{
  "msgtype": "markdown",
  "markdown": {
    "title": "${send_title}",
    "text": "${send_message}"
  }
}
EOF
)

curl -s -X POST -H "${send_header}" -d "${send_data}" "${dingding_api_url}" || { echo "Error sending message"; exit 1; }


