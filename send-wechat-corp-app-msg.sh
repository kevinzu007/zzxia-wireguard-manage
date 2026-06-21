#!/bin/bash
#############################################################################
# Create By: 猪猪侠
# License: GNU GPLv3
# Test On: CentOS 7
# Description: 通过企业微信自建应用发送应用消息（Markdown格式）
#############################################################################

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )

# 本地env
HOSTNAME=$(hostname)    #-- 获取主机名
DATETIME=$(date "+%Y-%m-%d %H:%M:%S %z")    #-- 时间标记

# 参数变量
touser=""
toparty=""
totag=""
send_title=""
send_message=""

# 用法：
F_HELP()
{
    echo "
    用途：通过企业微信自建应用发送Markdown应用消息
    特征码：
        ${GAN_WHAT_FUCK:-'未命名'}
    权限要求：
        ${NEED_PRIVILEGES:-'未指定'}
    依赖：
        curl
        ./env.sh
    注意：
        - touser / toparty / totag 三者不能同时为空
        - 发送前确保已在企业微信管理后台配置好应用的可信IP
    用法：
        \$0  --help|-h                                                         #-- 帮助
        \$0  {--touser|-u <UserID>}  {--title|-t <标题>}  {--message|-m <内容>}  #-- 发送消息
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
        --touser|-u <UserID>         # 成员ID，多个用 | 分隔
        --toparty|-p <PartyID>       # 部门ID，多个用 | 分隔（可选）
        --totag|-g <TagID>           # 标签ID，多个用 | 分隔（可选）
        --title|-t <标题>            # 消息标题
        --message|-m <内容>          # 消息内容（支持markdown格式）
    环境变量：
        WECOM_CORP_ID               # 企业ID（管理后台 → 我的企业 → 企业信息）
        WECOM_AGENT_SECRET          # 应用Secret（管理后台 → 应用管理 → 自建应用）
        WECOM_AGENT_ID              # 应用AgentId（管理后台 → 应用管理 → 自建应用）
    示例：
        # 发送给单个用户
        \$0  -u zhangsan  -t '通知'  -m '### 测试消息\n> 这是一条引用'
        #
        # 发送给多个用户
        \$0  -u 'zhangsan|lisi'  -t '通知'  -m '**重要提醒**'
        #
        # 从文件读取内容
        \$0  -u zhangsan  -t 'Report'  -m \"\$(cat report.md)\"
    "
}

# 获取 access_token
F_GET_TOKEN()
{
    local corpid="$1"
    local corpsecret="$2"
    local url="https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=${corpid}&corpsecret=${corpsecret}"
    local resp
    resp=$(curl -s "${url}") || { echo "Error: 获取 access_token 失败" >&2; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local errcode
        errcode=$(echo "${resp}" | jq -r '.errcode')
        if [ "${errcode}" -ne 0 ]; then
            echo "Error: 获取 access_token 失败，errcode=${errcode}" >&2
            return 1
        fi
        echo "${resp}" | jq -r '.access_token'
    else
        # fallback: 用 grep 提取
        echo "${resp}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
    fi
}

# 发送应用消息
F_SEND_MSG()
{
    local token="$1"
    local agentid="$2"
    local touser="$3"
    local toparty="$4"
    local totag="$5"
    local title="$6"
    local message="$7"

    local send_header="Content-Type: application/json; charset=utf-8"
    local url="https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=${token}"

    # 使用 %b 而不是 %s，这样就能自动将输入字符串里的 \n 转换成真正的换行符
    printf -v content '# %s\n\n---\n\n%b\n\n---\n\n发自: **%s**\n时间: %s' \
        "${title}" "${message}" "${HOSTNAME}" "${DATETIME}"

    if command -v jq > /dev/null 2>&1; then
        send_data=$(jq -n \
            --arg touser "${touser}" \
            --arg toparty "${toparty}" \
            --arg totag "${totag}" \
            --arg agentid "${agentid}" \
            --arg content "${content}" \
            '{
                touser: $touser,
                toparty: $toparty,
                totag: $totag,
                msgtype: "markdown",
                agentid: ($agentid | tonumber),
                markdown: {content: $content},
                enable_duplicate_check: 0
            }')
    else
        _escaped_content=$(printf '%s' "${content}" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_data="{\"touser\":\"${touser}\",\"toparty\":\"${toparty}\",\"totag\":\"${totag}\",\"msgtype\":\"markdown\",\"agentid\":${agentid},\"markdown\":{\"content\":\"${_escaped_content}\"},\"enable_duplicate_check\":0}"
    fi

    local resp
    resp=$(curl -s -X POST -H "${send_header}" -d "${send_data}" "${url}") || { echo "Error: 发送消息失败" >&2; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local errcode
        errcode=$(echo "${resp}" | jq -r '.errcode')
        if [ "${errcode}" -ne 0 ]; then
            echo "Error: 发送消息失败，errcode=${errcode}" >&2
            echo "响应: ${resp}" >&2
            return 1
        fi
    fi
    echo "消息发送成功" >&2
}

# 参数解析
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
        -p|--toparty)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-p|--toparty 参数缺少值\n" >&2; exit 51
            fi
            toparty="$2"
            shift 2
            ;;
        -g|--totag)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo -e "\n猪猪侠警告：-g|--totag 参数缺少值\n" >&2; exit 51
            fi
            totag="$2"
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
if [[ -z "${send_title}" || -z "${send_message}" ]]; then
    echo -e "\n猪猪侠警告：缺少必需参数 -t|--title 和 -m|--message\n" >&2
    exit 51
fi
if [[ -z "${touser}" && -z "${toparty}" && -z "${totag}" ]]; then
    echo -e "\n猪猪侠警告：touser / toparty / totag 三者不能同时为空\n" >&2
    exit 51
fi

# 读取环境变量
WECOM_CORP_ID=${WECOM_CORP_ID:-''}
WECOM_AGENT_SECRET=${WECOM_AGENT_SECRET:-''}
WECOM_AGENT_ID=${WECOM_AGENT_ID:-''}

if [[ -z "${WECOM_CORP_ID}" || -z "${WECOM_AGENT_SECRET}" || -z "${WECOM_AGENT_ID}" ]]; then
    echo -e "\n猪猪侠警告：请设置环境变量 WECOM_CORP_ID、WECOM_AGENT_SECRET、WECOM_AGENT_ID\n" >&2
    echo "可以在 env.sh 中添加以下配置："
    echo "  export WECOM_CORP_ID='你的企业ID'"
    echo "  export WECOM_AGENT_SECRET='你的应用Secret'"
    echo "  export WECOM_AGENT_ID='你的应用AgentId'"
    exit 51
fi

# 获取 token
echo "获取 access_token..." >&2
TOKEN=$(F_GET_TOKEN "${WECOM_CORP_ID}" "${WECOM_AGENT_SECRET}") || exit 1

# 发送消息
F_SEND_MSG "${TOKEN}" "${WECOM_AGENT_ID}" "${touser}" "${toparty}" "${totag}" "${send_title}" "${send_message}"
