#!/usr/bin/env bats
# 测试 functions.sh 公共函数

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # 设置 SH_PATH 供 functions.sh 使用
    export SH_PATH="${SH_DIR}"
    source "${SH_DIR}/functions.sh"
}

@test "F_PARSE_WG_DUMP_LINE 正确解析 IPv4 dump 数据" {
    local line="abc123pubkey== psk123== 1.2.3.4:51820 10.0.0.2/32 1700000000 1048576 2097152 25"
    F_PARSE_WG_DUMP_LINE "${line}"
    [ "${USER_PEER}" = "abc123pubkey==" ]
    [ "${USER_PRESHARED_KEY}" = "psk123==" ]
    [ "${USER_ENDPOINT}" = "1.2.3.4:51820" ]
    [ "${USER_ENDPOINT_IP}" = "1.2.3.4" ]
    [ "${USER_ENDPOINT_UDP_PORT}" = "51820" ]
    [ "${USER_ALLOWED_IPS}" = "10.0.0.2/32" ]
    [ "${USER_LATEST_HAND_SECOND}" = "1700000000" ]
    [ "${USER_NET_IN}" = "1048576" ]
    [ "${USER_NET_OUT}" = "2097152" ]
    [ "${USER_KEEPALIVE}" = "25" ]
}

@test "F_PARSE_WG_DUMP_LINE 正确解析 IPv6 dump 数据" {
    local line="abc123pubkey== psk123== [2408:8256:c8:1bdd:ab10:372f:19de:115d]:52524 10.0.0.2/32 1700000000 1048576 2097152 25"
    F_PARSE_WG_DUMP_LINE "${line}"
    [ "${USER_PEER}" = "abc123pubkey==" ]
    [ "${USER_PRESHARED_KEY}" = "psk123==" ]
    [ "${USER_ENDPOINT}" = "[2408:8256:c8:1bdd:ab10:372f:19de:115d]:52524" ]
    [ "${USER_ENDPOINT_IP}" = "2408:8256:c8:1bdd:ab10:372f:19de:115d" ]
    [ "${USER_ENDPOINT_UDP_PORT}" = "52524" ]
    [ "${USER_ALLOWED_IPS}" = "10.0.0.2/32" ]
    [ "${USER_LATEST_HAND_SECOND}" = "1700000000" ]
    [ "${USER_NET_IN}" = "1048576" ]
    [ "${USER_NET_OUT}" = "2097152" ]
    [ "${USER_KEEPALIVE}" = "25" ]
}

@test "F_PARSE_WG_DUMP_LINE 处理无握手数据" {
    local line="abc123pubkey== psk123== (none) 10.0.0.2/32 0 0 0 off"
    F_PARSE_WG_DUMP_LINE "${line}"
    [ "${USER_ENDPOINT}" = "(none)" ]
    [ "${USER_LATEST_HAND_SECOND}" = "0" ]
    [ "${USER_NET_IN}" = "0" ]
    [ "${USER_NET_OUT}" = "0" ]
}

@test "F_CALC_MIB 正确计算 MiB" {
    F_CALC_MIB "1048576" "2097152"
    [ "${USER_NET_IN_MiB}" = "1.0" ]
    [ "${USER_NET_OUT_MiB}" = "2.0" ]
    [ "${USER_NET_TOTAL_MiB}" = "3.0" ]
}

@test "F_CALC_MIB 处理零值" {
    F_CALC_MIB "0" "0"
    [ "${USER_NET_IN_MiB}" = "0" ] || [ "${USER_NET_IN_MiB}" = "0.0" ]
    [ "${USER_NET_OUT_MiB}" = "0" ] || [ "${USER_NET_OUT_MiB}" = "0.0" ]
}

@test "F_LOOKUP_USER 正确反查用户" {
    # 创建临时配置文件
    local tmp_conf
    tmp_conf=$(mktemp)
    cat > "${tmp_conf}" << 'EOF'
## 猪猪侠 172.30.0.11
[Peer]
PublicKey = testkey123==
PresharedKey = psk456==
AllowedIPs = 172.30.0.11/32

## 大侠 172.30.0.12
[Peer]
PublicKey = testkey456==
PresharedKey = psk789==
AllowedIPs = 172.30.0.12/32
EOF
    F_LOOKUP_USER "testkey123==" "${tmp_conf}"
    [ "${USER_NAME}" = "猪猪侠" ]
    [ "${USER_IP}" = "172.30.0.11" ]

    F_LOOKUP_USER "testkey456==" "${tmp_conf}"
    [ "${USER_NAME}" = "大侠" ]
    [ "${USER_IP}" = "172.30.0.12" ]

    rm -f "${tmp_conf}"
}

@test "F_LOG 创建日志文件并写入内容" {
    # 使用临时目录
    export SH_PATH=$(mktemp -d)
    source "${SH_DIR}/functions.sh"

    F_LOG "INFO" "测试日志消息"
    [ -f "${SH_PATH}/log/wg-manage.log" ]
    grep -q "INFO.*测试日志消息" "${SH_PATH}/log/wg-manage.log"

    rm -rf "${SH_PATH}"
}

@test "F_VALIDATE_USERNAME 接受合法用户名" {
    run F_VALIDATE_USERNAME "猪猪侠"
    [ "$status" -eq 0 ]
    run F_VALIDATE_USERNAME "user_01"
    [ "$status" -eq 0 ]
    run F_VALIDATE_USERNAME "test-user"
    [ "$status" -eq 0 ]
    run F_VALIDATE_USERNAME "张三"
    [ "$status" -eq 0 ]
}

@test "F_VALIDATE_USERNAME 拒绝空用户名" {
    run F_VALIDATE_USERNAME ""
    [ "$status" -ne 0 ]
}

@test "F_VALIDATE_USERNAME 拒绝含危险字符的用户名" {
    run F_VALIDATE_USERNAME "user/name"
    [ "$status" -ne 0 ]
    run F_VALIDATE_USERNAME 'user&name'
    [ "$status" -ne 0 ]
    run F_VALIDATE_USERNAME 'user;name'
    [ "$status" -ne 0 ]
    run F_VALIDATE_USERNAME 'user name'
    [ "$status" -ne 0 ]
    run F_VALIDATE_USERNAME 'user*'
    [ "$status" -ne 0 ]
}

@test "F_SED_ESCAPE 正确转义特殊字符" {
    local result
    result=$(F_SED_ESCAPE "normal")
    [ "${result}" = "normal" ]
    result=$(F_SED_ESCAPE "a.b")
    [ "${result}" = 'a\.b' ]
}

@test "F_IP_AREA 处理空值和 (none)" {
    local result
    result=$(F_IP_AREA "")
    [ "${result}" = "未知" ]
    result=$(F_IP_AREA "(none)")
    [ "${result}" = "未知" ]
}

@test "F_IP_AREA 查询有效 IPv4 和 IPv6" {
    local result
    result=$(F_IP_AREA "114.114.114.114")
    [ -n "${result}" ]
    [[ ! "${result}" =~ "获取失败" ]]

    result=$(F_IP_AREA "2408:8256:c8:1bdd:ab10:372f:19de:115d")
    [ -n "${result}" ]
    [[ ! "${result}" =~ "获取失败" ]]
}

