#!/bin/bash
#############################################################################
# Create By: 猪猪侠
# License: GNU GPLv3
# Test On: CentOS 7
# Description: 通过微信公众号（服务号）发送模板消息/客服消息
#############################################################################

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )

# 本地env
HOSTNAME=$(hostname)    #-- 获取主机名
DATETIME=$(date "+%Y-%m-%d %H:%M:%S %z")    #-- 时间标记

# 参数变量
touser=""
template_id=""
kv_data=""
send_message=""

# 用法：
F_HELP()
{
    echo "
    用途：通过微信公众号（服务号）发送模板消息或客服消息
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
        curl
        ./env.sh
    注意：
        - 模板消息需要用户已授权订阅该模板
        - 客服消息需用户在48小时内与公众号有过交互
        - 发送前需在公众号后台配置IP白名单
    用法：
        \$0  --help|-h                                                                                 #-- 帮助
        \$0  {--touser|-u <openid>}  {--template-id|-i <模板ID>}  [--data|-d <key=val,...>]  #-- 发送模板消息
        \$0  {--touser|-u <openid>}  {--message|-m <内容>}                                     #-- 发送客服消息
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
        --help|-h                            # 帮助
        --touser|-u <openid>                 # 用户OpenID
        --template-id|-i <模板ID>            # 模板ID（用于模板消息）
        --data|-d <key=val,key2=val2>        # 模板数据，逗号分隔的key=value（用于模板消息）
        --message|-m <内容>                  # 消息内容（用于客服消息）
    环境变量：
        WECHAT_APPID                         公众号AppID（管理后台 → 开发 → 基本配置）
        WECHAT_SECRET                        公众号AppSecret（管理后台 → 开发 → 基本配置）
    示例：
        # 发送模板消息
        \$0  -u oXXXXX  -i '模板ID'  -d 'thing1=通知标题,thing2=内容摘要,time3=2026-01-01'
        #
        # 发送客服文本消息
        \$0  -u oXXXXX  -m '这是一条客服消息'
        #
        # 从文件发送模板消息数据
        \$0  -u oXXXXX  -i '模板ID'  -d \"\$(cat data.txt)\"
    "
}

# 获取 access_token
F_GET_TOKEN()
{
    local appid="$1"
    local secret="$2"
    local url="https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${appid}&secret=${secret}"
    local resp
    resp=$(curl -s "${url}") || { echo "Error: 获取 access_token 失败" >&2; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local errcode
        errcode=$(echo "${resp}" | jq -r '.errcode // 0')
        if [ "${errcode}" -ne 0 ]; then
            echo "Error: 获取 access_token 失败，errcode=${errcode}" >&2
            echo "响应: ${resp}" >&2
            return 1
        fi
        echo "${resp}" | jq -r '.access_token'
    else
        echo "${resp}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
    fi
}

# 发送模板消息（订阅通知）
F_SEND_TEMPLATE()
{
    local token="$1"
    local touser="$2"
    local template_id="$3"
    local kv_data="$4"

    local send_header="Content-Type: application/json; charset=utf-8"
    local url="https://api.weixin.qq.com/cgi-bin/message/subscribe/send?access_token=${token}"

    # 解析 data 参数：thing1=xxx,thing2=yyy → JSON
    local data_json="{}"
    if command -v jq > /dev/null 2>&1; then
        local obj="{}"
        IFS=',' read -ra pairs <<< "${kv_data}"
        for pair in "${pairs[@]}"; do
            key="${pair%%=*}"
            val="${pair#*=}"
            # 去除首尾空格
            key=$(echo "${key}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            val=$(echo "${val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            obj=$(echo "${obj}" | jq --arg k "${key}" --arg v "${val}" '.[$k] = {value: $v}')
        done
        data_json="${obj}"
    else
        # fallback: 手动构建 JSON
        local items=""
        IFS=',' read -ra pairs <<< "${kv_data}"
        for pair in "${pairs[@]}"; do
            key="${pair%%=*}"
            val="${pair#*=}"
            key=$(echo "${key}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            val=$(echo "${val}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/\\/\\\\/g; s/"/\\"/g')
            [ -n "${items}" ] && items="${items},"
            items="${items}\"${key}\":{\"value\":\"${val}\"}"
        done
        data_json="{${items}}"
    fi

    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg touser "${touser}" \
            --arg template_id "${template_id}" \
            --argjson data "${data_json}" \
            '{touser: $touser, template_id: $template_id, data: $data}')
    else
        send_data="{\"touser\":\"${touser}\",\"template_id\":\"${template_id}\",\"data\":${data_json}}"
    fi

    local resp
    resp=$(curl -s -X POST -H "${send_header}" -d "${send_data}" "${url}") || { echo "Error: 发送模板消息失败" >&2; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local errcode
        errcode=$(echo "${resp}" | jq -r '.errcode')
        if [ "${errcode}" -ne 0 ]; then
            echo "Error: 发送模板消息失败，errcode=${errcode}" >&2
            echo "响应: ${resp}" >&2
            return 1
        fi
    fi
    echo "模板消息发送成功" >&2
}

# 发送客服文本消息
F_SEND_CUSTOM_TEXT()
{
    local token="$1"
    local touser="$2"
    local content="$3"

    local send_header="Content-Type: application/json; charset=utf-8"
    local url="https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=${token}"

    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg touser "${touser}" \
            --arg content "${content}" \
            '{touser: $touser, msgtype: "text", text: {content: $content}}')
    else
        _escaped_content=$(printf '%s' "${content}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_data="{\"touser\":\"${touser}\",\"msgtype\":\"text\",\"text\":{\"content\":\"${_escaped_content}\"}}"
    fi

    local resp
    resp=$(curl -s -X POST -H "${send_header}" -d "${send_data}" "${url}") || { echo "Error: 发送客服消息失败" >&2; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local errcode
        errcode=$(echo "${resp}" | jq -r '.errcode')
        if [ "${errcode}" -ne 0 ]; then
            echo "Error: 发送客服消息失败，errcode=${errcode}" >&2
            echo "响应: ${resp}" >&2
            return 1
        fi
    fi
    echo "客服消息发送成功" >&2
}

# 参数解析
mode=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            shift
            F_HELP
            exit 0
            ;;
        -u|--touser)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-u|--touser 参数缺少值\n" >&2; exit 51
            fi
            touser="$2"
            shift 2
            ;;
        -i|--template-id)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-i|--template-id 参数缺少值\n" >&2; exit 51
            fi
            template_id="$2"
            mode="template"
            shift 2
            ;;
        -d|--data)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-d|--data 参数缺少值\n" >&2; exit 51
            fi
            kv_data="$2"
            shift 2
            ;;
        -m|--message)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-m|--message 参数缺少值\n" >&2; exit 51
            fi
            send_message="$2"
            mode="custom"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

# 参数验证
if [[ -z "${touser}" ]]; then
    echo -e "\n猪猪侠警告：缺少必需参数 -u|--touser\n" >&2
    exit 51
fi
if [[ "${mode}" == "template" ]]; then
    if [[ -z "${template_id}" ]]; then
        echo -e "\n猪猪侠警告：模板消息需要 -i|--template-id 参数\n" >&2
        exit 51
    fi
elif [[ "${mode}" == "custom" ]]; then
    if [[ -z "${send_message}" ]]; then
        echo -e "\n猪猪侠警告：客服消息需要 -m|--message 参数\n" >&2
        exit 51
    fi
else
    echo -e "\n猪猪侠警告：请指定模式，-i|--template-id 发送模板消息，-m|--message 发送客服消息\n" >&2
    exit 51
fi

# 读取环境变量
WECHAT_APPID=${WECHAT_APPID:-''}
WECHAT_SECRET=${WECHAT_SECRET:-''}

if [[ -z "${WECHAT_APPID}" || -z "${WECHAT_SECRET}" ]]; then
    echo -e "\n猪猪侠警告：请设置环境变量 WECHAT_APPID 和 WECHAT_SECRET\n" >&2
    echo "可以在 env.sh 中添加以下配置："
    echo "  export WECHAT_APPID='你的公众号AppID'"
    echo "  export WECHAT_SECRET='你的公众号AppSecret'"
    exit 51
fi

# 获取 token
echo "获取 access_token..." >&2
TOKEN=$(F_GET_TOKEN "${WECHAT_APPID}" "${WECHAT_SECRET}") || exit 1

# 发送
case "${mode}" in
    template)
        F_SEND_TEMPLATE "${TOKEN}" "${touser}" "${template_id}" "${kv_data}"
        ;;
    custom)
        F_SEND_CUSTOM_TEXT "${TOKEN}" "${touser}" "${send_message}"
        ;;
esac
