#!/bin/bash

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd "${SH_PATH}"

# env
. "${SH_PATH}/env.sh"

echo "现有计划任务如下："
echo "------------------------------"
crontab -l 2>/dev/null
echo "------------------------------"
echo

CRON_MARKER="# zzxia-wireguard-manage之【${SH_PATH}】："

TMP_CRON=$(mktemp)
crontab -l 2>/dev/null > "${TMP_CRON}" || true

# 由于新老计划任务的执行路径以及新版标记都必然包含 ${SH_PATH}
# 直接通过匹配项目目录，极简也更安全地清理当前项目相关的所有旧任务
if grep -q -F "${SH_PATH}" "${TMP_CRON}"; then
    echo "猪猪侠提示：发现当前项目目录 ${SH_PATH} 相关的旧计划任务，将清除重新添加..."
    
    grep -v -F "${SH_PATH}" "${TMP_CRON}" > "${TMP_CRON}.new"
    mv "${TMP_CRON}.new" "${TMP_CRON}"
fi

echo "即将追加wg相关计划任务"
read -p '按任意键继续'

(cat "${TMP_CRON}"; echo "${CRON_MARKER}
@reboot    . ${SH_PATH}/env.sh; /usr/bin/wg-quick up ${WG_IF}
0 0 * * *  ${SH_PATH}/wg-daily-report-cron.sh
* * * * *  ${SH_PATH}/wg-login-alert-cron.sh") | crontab -

rm -f "${TMP_CRON}"

echo "计划任务添加后如下："
echo "------------------------------"
crontab -l
echo "------------------------------"

