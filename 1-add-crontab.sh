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

# 检查是否已添加过
if crontab -l 2>/dev/null | grep -q "wg-login-alert-cron.sh"; then
    echo "猪猪侠提示：wg相关计划任务已存在，跳过添加"
    exit 0
fi

echo "即将追加wg相关计划任务"
read -p '按任意键继续'

(crontab -l 2>/dev/null; echo "
@reboot    . ${SH_PATH}/env.sh; /usr/bin/wg-quick up ${WG_IF}
0 0 * * *  ${SH_PATH}/wg-daily-report-cron.sh
* * * * *  ${SH_PATH}/wg-login-alert-cron.sh
") | crontab -

echo "计划任务添加后如下："
echo "------------------------------"
crontab -l
echo "------------------------------"
echo
echo "提示：如需管理多个WireGuard接口，手动添加如下cron条目："
echo "  @reboot    WG_IF=wg1 . ${SH_PATH}/env.sh; /usr/bin/wg-quick up wg1"
echo "  0 0 * * *  WG_IF=wg1 ${SH_PATH}/wg-daily-report-cron.sh"
echo "  * * * * *  WG_IF=wg1 ${SH_PATH}/wg-login-alert-cron.sh"
