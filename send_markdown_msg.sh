#!/bin/bash
#############################################################################
# Create By: 猪猪侠
# License: GNU GPLv3
# Test On: CentOS 7
# Description: 统一的Markdown消息发送脚本，支持钉钉、企业微信、飞书
#############################################################################

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )

# export引入使用（可选）：
#DINGDING_WEBHOOK_API=
#WEIXIN_WEBHOOK_API=
#FEISHU_WEBHOOK_API=
#DEFAULT_NOTIFICATION_PLATFORM

# 本地env
HOSTNAME=$(hostname)    #-- 获取主机名
DATETIME=$(date "+%Y-%m-%d %H:%M:%S %z")    #-- 时间标记

# 参数变量
platform=""
webhook_url=""
send_title=""
send_message=""

# 用法：
F_HELP()
{
    echo "
    用途：将markdown格式的文本通过多平台机器人发送出去
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
    注意：
        - 如果不指定平台，脚本会尝试从webhook URL自动检测
        - 企业微信的markdown支持有限（仅支持标题、加粗、链接、代码块）
        - 飞书使用富文本格式，会自动转换基础markdown语法
    用法:
        $0 -h|--help
        $0 [{-p|--platform dingding|weixin|feishu}] [{-w|--webhook <Webhook地址>}] {-t|--title <消息标题>} {-m|--message <消息内容>}
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
        -p|--platform    指定平台：dingding(钉钉)、weixin(企业微信)、feishu(飞书)
                        如不指定，将从webhook URL自动检测，或使用环境变量 DEFAULT_NOTIFICATION_PLATFORM
        -w|--webhook     Webhook地址，可选，默认从环境变量中继承：
                        钉钉：DINGDING_WEBHOOK_API
                        企业微信：WEIXIN_WEBHOOK_API
                        飞书：FEISHU_WEBHOOK_API
        -t|--title       消息标题
        -m|--message     消息内容（支持markdown格式）
    环境变量：
        DINGDING_WEBHOOK_API                              钉钉webhook地址
        WEIXIN_WEBHOOK_API                                企业微信webhook地址
        FEISHU_WEBHOOK_API                                飞书webhook地址
        DEFAULT_NOTIFICATION_PLATFORM                     默认平台(dingding/weixin/feishu)
    示例:
        # 使用钉钉发送
        $0  -p dingding  -t 'Test Title'  -m '### 测试消息'
        # 使用企业微信发送
        $0  -p weixin  -t 'Test Title'  -m '### 测试消息'
        # 使用飞书发送
        $0  -p feishu  -t 'Test Title'  -m '### 测试消息'
        # 自动检测平台（从webhook URL）
        $0  -w 'https://oapi.dingtalk.com/robot/send?access_token=xxx'  -t 'Title'  -m 'Content'
        # 从文件读取内容
        $0  -p dingding  -t 'Report'  -m \"\$(cat report.md)\"
        # 使用环境变量
        export DINGDING_WEBHOOK_API='https://oapi.dingtalk.com/robot/send?access_token=xxx'
        $0  -p dingding  -t 'Title'  -m 'Content'
    "
}

# 自动检测平台
F_DETECT_PLATFORM()
{
    local url="$1"
    
    if [[ "$url" =~ oapi\.dingtalk\.com ]]; then
        echo "dingding"
    elif [[ "$url" =~ qyapi\.weixin\.qq\.com ]]; then
        echo "weixin"
    elif [[ "$url" =~ open\.feishu\.cn ]] || [[ "$url" =~ open\.larksuite\.com ]]; then
        echo "feishu"
    else
        echo ""
    fi
}

# 发送钉钉消息
F_SEND_DINGDING()
{
    local webhook="$1"
    local title="$2"
    local message="$3"
    
    local send_header="Content-Type: application/json; charset=utf-8"
    printf -v full_message '### %s \n---\n%s \n\n---\n\n*发自: %s*\n\n*时间: %s*\n\n' \
        "${title}" "${message}" "${HOSTNAME}" "${DATETIME}"
    
    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg title "${title}" \
            --arg text "${full_message}" \
            '{msgtype: "markdown", markdown: {title: $title, text: $text}}')
    else
        _escaped_title=$(printf '%s' "${title}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        _escaped_message=$(printf '%s' "${full_message}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_data="{\"msgtype\": \"markdown\", \"markdown\": {\"title\": \"${_escaped_title}\", \"text\": \"${_escaped_message}\"}}"
    fi
    
    curl -s -X POST -H "${send_header}" -d "${send_data}" "${webhook}" || { echo "Error sending DingTalk message" >&2 ; return 1; }
}

# 发送企业微信消息
F_SEND_WEIXIN()
{
    local webhook="$1"
    local title="$2"
    local message="$3"
    
    local send_header="Content-Type: application/json; charset=utf-8"
    printf -v full_message '### %s\n---\n%s\n\n---\n\n发自: **%s**\n时间: %s' \
        "${title}" "${message}" "${HOSTNAME}" "${DATETIME}"
    
    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg text "${full_message}" \
            '{msgtype: "markdown", markdown: {content: $text}}')
    else
        _escaped_message=$(printf '%s' "${full_message}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_data="{\"msgtype\": \"markdown\", \"markdown\": {\"content\": \"${_escaped_message}\"}}"
    fi
    
    curl -s -X POST -H "${send_header}" -d "${send_data}" "${webhook}" || { echo "Error sending WeChat Work message" >&2 ; return 1; }
}

# 发送飞书消息
F_SEND_FEISHU()
{
    local webhook="$1"
    local title="$2"
    local message="$3"
    
    local send_header="Content-Type: application/json; charset=utf-8"
    
    # 飞书文本格式
    printf -v full_message '%s\n---\n%s\n\n---\n\n发自: %s\n时间: %s' \
        "${title}" "${message}" "${HOSTNAME}" "${DATETIME}"
    
    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg text "${full_message}" \
            '{msg_type: "text", content: {text: $text}}')
    else
        _escaped_message=$(printf '%s' "${full_message}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_data="{\"msg_type\": \"text\", \"content\": {\"text\": \"${_escaped_message}\"}}"
    fi
    
    curl -s -X POST -H "${send_header}" -d "${send_data}" "${webhook}" || { echo "Error sending Feishu message" >&2 ; return 1; }
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            shift
            F_HELP
            exit 0
            ;;
        -p|--platform)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-p|--platform 参数缺少值\n" >&2; exit 51
            fi
            platform="$2"
            shift 2
            ;;
        -w|--webhook)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-w|--webhook 参数缺少值\n" >&2; exit 51
            fi
            webhook_url="$2"
            shift 2
            ;;
        -t|--title)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-t|--title 参数缺少值\n" >&2; exit 51
            fi
            send_title="$2"
            shift 2
            ;;
        -m|--message)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-m|--message 参数缺少值\n" >&2; exit 51
            fi
            send_message="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# 参数验证
if [[ -z $send_title || -z $send_message ]]; then
    echo -e "\n猪猪侠警告：参数不足，请查看帮助【$0 --help】\n" >&2
    exit 51
fi

# 确定webhook URL
if [[ -z ${webhook_url} ]]; then
    # 如果指定了平台，从对应环境变量获取
    if [[ -n ${platform} ]]; then
        case "${platform}" in
            dingding)
                webhook_url=${DINGDING_WEBHOOK_API}
                ;;
            weixin)
                webhook_url=${WEIXIN_WEBHOOK_API}
                ;;
            feishu)
                webhook_url=${FEISHU_WEBHOOK_API}
                ;;
            *)
                echo -e "\n猪猪侠警告：不支持的平台【${platform}】，支持的平台：dingding、weixin、feishu\n" >&2
                exit 52
                ;;
        esac
    else
        # 未指定平台，尝试使用默认平台或从环境变量自动检测
        if [[ -n ${DEFAULT_NOTIFICATION_PLATFORM} ]]; then
            platform=${DEFAULT_NOTIFICATION_PLATFORM}
            case "${platform}" in
                dingding)
                    webhook_url=${DINGDING_WEBHOOK_API}
                    ;;
                weixin)
                    webhook_url=${WEIXIN_WEBHOOK_API}
                    ;;
                feishu)
                    webhook_url=${FEISHU_WEBHOOK_API}
                    ;;
            esac
        else
            # 尝试从环境变量中查找可用的webhook URL
            if [[ -n ${DINGDING_WEBHOOK_API} ]]; then
                webhook_url=${DINGDING_WEBHOOK_API}
                platform="dingding"
            elif [[ -n ${WEIXIN_WEBHOOK_API} ]]; then
                webhook_url=${WEIXIN_WEBHOOK_API}
                platform="weixin"
            elif [[ -n ${FEISHU_WEBHOOK_API} ]]; then
                webhook_url=${FEISHU_WEBHOOK_API}
                platform="feishu"
            fi
        fi
    fi
fi

if [[ -z ${webhook_url} ]]; then
    echo -e "\n猪猪侠警告：webhook_url为空，请使用【-w|--webhook】参数设置或配置环境变量\n" >&2
    exit 51
fi

# 自动检测平台（如果未指定）
if [[ -z ${platform} ]]; then
    platform=$(F_DETECT_PLATFORM "${webhook_url}")
    if [[ -z ${platform} ]]; then
        echo -e "\n猪猪侠警告：无法从webhook URL自动检测平台，请使用【-p|--platform】参数指定\n" >&2
        exit 53
    fi
    echo "检测到平台: ${platform}" >&2
fi

# 发送消息
case "${platform}" in
    dingding)
        F_SEND_DINGDING "${webhook_url}" "${send_title}" "${send_message}"
        ;;
    weixin)
        F_SEND_WEIXIN "${webhook_url}" "${send_title}" "${send_message}"
        ;;
    feishu)
        F_SEND_FEISHU "${webhook_url}" "${send_title}" "${send_message}"
        ;;
    *)
        echo -e "\n猪猪侠警告：不支持的平台【${platform}】\n" >&2
        exit 52
        ;;
esac

exit_code=$?
if [[ ${exit_code} -eq 0 ]]; then
    echo "消息发送成功 (平台: ${platform})" >&2
fi

exit ${exit_code}
