#!/usr/bin/env bats
# 测试 wg-daily-report-cron.sh

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export SH_PATH="${SH_DIR}"
}

@test "wg-daily-report-cron.sh 语法正确" {
    run bash -n "${SH_DIR}/wg-daily-report-cron.sh"
    [ "$status" -eq 0 ]
}

@test "set -eo pipefail 下累加器不触发提前退出" {
    run bash -c '
        set -eo pipefail
        TOTAL_ACTIVE_USERS=0
        TOTAL_BYTES_IN=0
        TOTAL_BYTES_OUT=0
        USER_NET_IN=1048576
        USER_NET_OUT=2097152

        # 模拟进入循环第一次累加
        TOTAL_ACTIVE_USERS=$(( TOTAL_ACTIVE_USERS + 1 ))
        TOTAL_BYTES_IN=$(( TOTAL_BYTES_IN + USER_NET_IN ))
        TOTAL_BYTES_OUT=$(( TOTAL_BYTES_OUT + USER_NET_OUT ))

        [ "$TOTAL_ACTIVE_USERS" -eq 1 ]
        [ "$TOTAL_BYTES_IN" -eq 1048576 ]
        [ "$TOTAL_BYTES_OUT" -eq 2097152 ]
    '
    [ "$status" -eq 0 ]
}
