#!/bin/bash

# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}

# env
CRONTAB_FILE='/var/spool/cron/root'


echo "将会覆盖现有【crontab -l】中的计划任务！"
read -p '按任意键继续'


echo "* * * * *  ${SH_PATH}/wg-status-collector-cron.sh
*/2 * * * *  ${SH_PATH}/wg-login-alert.sh
0 0 * * *  ${SH_PATH}/wg-daily-report-cron.sh
" > ${CRONTAB_FILE}

