#!/bin/bash
#############################################################################
# Create By: 猪猪侠
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################

# sh
#SH_NAME=${0##*/}
#SH_PATH=$( cd "$( dirname "$0" )" && pwd )
#cd "${SH_PATH}"

# 引入env
#DINGDING_WEBHOOK_API=
dingding_api_url=${DINGDING_WEBHOOK_API}

# 本地env
_hostname=$(hostname)    #-- 获取主机名
_datetime=$(date "+%Y-%m-%d %H:%M:%S %z")    #-- 小时时间标记
send_title=""
send_message=""


# 用法：
F_HELP()
{
    echo "
    用途：将markdown格式的文本通过钉钉机器人发送出去
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
    注意：推荐使用新的统一通知脚本 send_markdown_msg.sh，支持多平台（钉钉、企业微信、飞书）
          本脚本将继续维护以保持向后兼容性
    用法:
        $0  -h|--help
        $0  [{-w|--webhook <Webhook地址>}]  {-t|--title <消息标题>}  {-m|--message <消息内容>}
    参数规范：
        无包围符号 ：-a                : 必选【选项】
                   ：val               : 必选【参数值】
                   ：val1 val2 -a -b   : 必选【选项或参数值】，且不分先后顺序
        []         ：[-a]              : 可选【选项】
                   ：[val]             : 可选【参数值】
        <>         ：<val>             : 需替换的具体值（用户必须提供）
        %%         ：%val%             : 通配符（包含匹配，如%error%匹配error_code）
        |          ：val1|val2|<valn>  : 多选一
        {}         ：{-a <val>}        : 必须成组出现【选项+参数值】
                   ：{val1 val2}       : 必须成组的【参数值组合】，且必须按顺序提供
    参数说明：
        #
        -h|--help        此帮助
        -w|--webhook     钉钉webhook地址，如果未设置，则从从环境变量中继承（\${DINGDING_WEBHOOK_API}）
        -t|--title       消息标题
        -m|--message     消息内容
    示例:
        $0  -t 'sssss'       -m \"\$(cat xxx.md)\"
        $0  --title 'sssss'  --message \"\$(cat xxx.md)\"                                                   #-- 从文件获取
        $0  --title 'sssss'  --message \"### 用户：\${USER}\"                                                #-- 简单输出
        $0  --title 'sssss'  --message \"\$( echo -e \"### 用户：\${USER} \n### 时间：\$(date) \n\n\" )\"     #-- 从命令获取
        $0  -w 'https://oapi.dingtalk.com/robot/send?access_token=你的token'  -t 'sssss'  -m \"### 用户：\${USER}\"
        export DINGDING_WEBHOOK_API='https://oapi.dingtalk.com/robot/send?access_token=你的token'; $0 -t 'sssss'  -m \"### 用户：\${USER}\"
    "
}



# 参数检查
# 检查参数是否符合要求，会对参数进行重新排序，列出的参数会放在其他参数的前面，这样你在输入脚本参数时，不需要关注脚本参数的输入顺序，例如：'$0 aa bb -w wwww ccc'
# 但除了参数列表中指定的参数之外，脚本参数中不能出现以'-'开头的其他参数，例如按照下面的参数要求，这个命令是不能正常运行的：'$0 -w wwww  aaa --- bbb ccc'
# 如果想要在命令中正确运行上面以'-'开头的其他参数，你可以在'-'参数前加一个'--'参数，这个可以正确运行：'$0 -w wwww  aaa -- --- bbb ccc'
# 你可以通过'bash -x'方式运行脚本观察'--'的运行规律
#
#TEMP=`getopt -o hw:t:m:  -l help,webhook:,title:,message: -- "$@"`
#if [ $? != 0 ]; then
#    echo -e "\n猪猪侠警告：参数不合法，请查看帮助【$0 --help】\n"  >&2
#    exit 51
#fi
##
#eval set -- "${TEMP}"
#
# 因为输入参数可能有以'-'开头的，必须关闭参数检查



while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            shift
            F_HELP
            exit 0
            ;;
        -w|--webhook)
            dingding_api_url="$2"
            shift 2
            ;;
        -t|--title)
            send_title="$2"
            shift 2
            ;;
        -m|--message)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-m|--message 参数缺少值，请查看帮助【$0 --help】\n" >&2
                exit 51
            fi
            send_message="$2"
            shift 2
            ;;
#        --)
#            shift
#            break
#            ;;
        *)
            break
            ;;
    esac
done



if [[ -z $send_title || -z $send_message ]]; then
    echo -e "\n猪猪侠警告：参数不足，请查看帮助【$0 --help】\n"  >&2
    exit 51
fi

if [[ -z ${dingding_api_url} ]]; then
    echo -e "\n猪猪侠警告：参数dingding_api_url为空，请引入变量或使用【-w|--webhook】参数设置\n"  >&2
    exit 51
fi



send_header="Content-Type: application/json; charset=utf-8"

# 使用 printf 产生真实换行符，jq 会将其正确编码为 JSON 的 \n
printf -v send_message '### %s \n---\n%s \n\n---\n\n*发自: %s*\n\n*时间: %s*\n\n' \
    "${send_title}" "${send_message}" "${_hostname}" "${_datetime}"

# 使用jq安全构建JSON，避免特殊字符破坏JSON结构
if command -v jq > /dev/null 2>&1; then
    send_data=$(jq -n \
        --arg title "${send_title}" \
        --arg text "${send_message}" \
        '{msgtype: "markdown", markdown: {title: $title, text: $text}}')
else
    # fallback: 转义反斜杠、双引号，并将真实换行符替换为 JSON 转义的 \n
    _escaped_title=$(printf '%s' "${send_title}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    _escaped_message=$(printf '%s' "${send_message}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    send_data="{\"msgtype\": \"markdown\", \"markdown\": {\"title\": \"${_escaped_title}\", \"text\": \"${_escaped_message}\"}}"
fi

_http_code=$(curl -s -o /tmp/dingding_resp.$$ -w '%{http_code}' -X POST -H "${send_header}" -d "${send_data}" "${dingding_api_url}") || { echo "Error: curl request failed" >&2; rm -f /tmp/dingding_resp.$$; exit 1; }
_resp=$(cat /tmp/dingding_resp.$$)
rm -f /tmp/dingding_resp.$$
if [[ "${_http_code}" -ne 200 ]]; then
    echo -e "\n猪猪侠警告：HTTP请求失败，状态码: ${_http_code}，响应: ${_resp}\n" >&2
    exit 1
fi
if command -v jq > /dev/null 2>&1; then
    _errcode=$(echo "${_resp}" | jq -r '.errcode // 0')
    if [[ "${_errcode}" -ne 0 ]]; then
        echo -e "\n猪猪侠警告：钉钉API返回错误码: ${_errcode}，响应: ${_resp}\n" >&2
        exit 1
    fi
fi
echo "${_resp}"


