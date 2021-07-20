#!/bin/bash
#############################################################################
# Create By: zhf_sy
# License: GNU GPLv3
# Test On: CentOS 7
#############################################################################
#
# 每分钟采集一次
# * * * * *  /root/zzxia-wireguard-manage/wg-status-collector-cron.sh


# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
cd ${SH_PATH}

# env
. /etc/profile         #--- 计划任务需要
. ${SH_PATH}/env.sh
#WG_IF=
#WG_STATUS_CONLLECT_FILE=


wg show "${WG_IF}" dump > "${WG_STATUS_CONLLECT_FILE}"
sed -i '1d' "${WG_STATUS_CONLLECT_FILE}"


