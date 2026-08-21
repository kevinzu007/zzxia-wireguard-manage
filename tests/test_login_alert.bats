#!/usr/bin/env bats
# 测试 wg-login-alert-cron.sh 的搜索与状态逻辑

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export SH_PATH="${SH_DIR}"
    export TODAY_WG_USER_LATEST_LOGIN_FILE=$(mktemp)
}

teardown() {
    rm -f "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
}

# 引入 F_SEARCH_USER_NAME 函数定义
F_SEARCH_USER_NAME()
{
    local F_USER_NAME="$1"
    local N=0
    while read -r LINE
    do
        N=$(( N + 1 ))
        local F_LINE_USER_NAME
        F_LINE_USER_NAME=$(echo "$LINE" | awk -F '|' '{print $3}' | awk '{gsub(/^\s+|\s+$/, ""); print}')
        if [[ "${F_USER_NAME}" = "${F_LINE_USER_NAME}" ]]; then
            echo "$N"
            return 0
        fi
    done < "${TODAY_WG_USER_LATEST_LOGIN_FILE}"
    return 1
}

@test "F_SEARCH_USER_NAME 正确匹配带空格的表格行用户" {
    cat > "${TODAY_WG_USER_LATEST_LOGIN_FILE}" << 'EOF'
| 2026-08-21 | ros250 | 2408:8256:c82:1bdd:2e0:67ff:fe21:b444 | 16:39:41 | 中国 广东 广州市 China Unicom | 已登录 |
| 2026-08-21 | y13 | 2408:8256:c82:1bdd:2e0:67ff:fe21:b444 | 16:31:57 | 中国 广东 广州市 China Unicom | 已离线 |
EOF

    run F_SEARCH_USER_NAME "ros250"
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]

    run F_SEARCH_USER_NAME "y13"
    [ "$status" -eq 0 ]
    [ "$output" -eq 2 ]

    run F_SEARCH_USER_NAME "nonexistent"
    [ "$status" -ne 0 ]
}
