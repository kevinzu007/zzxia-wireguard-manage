#!/bin/bash

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}

# env
CRONTAB_FILE='/var/spool/cron/root'

echo "现有计划任务如下："
echo "------------------------------"
crontab -l
echo "------------------------------"
echo
echo "即将覆盖现有计划任务！"
read -p '按任意键继续'

echo "
0 0 * * *  ${SH_PATH}/wg-daily-report-cron.sh
* * * * *  ${SH_PATH}/wg-login-alert-cron.sh
" > ${CRONTAB_FILE}

echo "计划任务添加如下："
echo "------------------------------"
crontab -l
echo "------------------------------"

