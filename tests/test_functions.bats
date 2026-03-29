#!/usr/bin/env bats
# 测试 functions.sh 公共函数

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # 设置 SH_PATH 供 functions.sh 使用
    export SH_PATH="${SH_DIR}"
    source "${SH_DIR}/functions.sh"
}

@test "F_PARSE_WG_DUMP_LINE 正确解析 dump 数据" {
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

@test "F_REFRESH_WG_PATHS 正确更新衍生路径" {
    export SH_PATH=$(mktemp -d)
    export SERVER_CONF_FILE_PATH=$(mktemp -d)
    source "${SH_DIR}/functions.sh"

    # 模拟默认接口
    WG_IF="wg0"
    # 创建通用密钥文件
    touch "${SERVER_CONF_FILE_PATH}/private.key"

    F_REFRESH_WG_PATHS

    [ "${SERVER_CONF_FILE}" = "${SERVER_CONF_FILE_PATH}/wg0.conf" ]
    [ "${SERVER_PRIVATE_KEY}" = "${SERVER_CONF_FILE_PATH}/private.key" ]
    [[ "${TODAY_WG_USER_LATEST_LOGIN_FILE}" == *"wg0"* ]]

    # 切换到 wg1
    WG_IF="wg1"
    F_REFRESH_WG_PATHS

    [ "${SERVER_CONF_FILE}" = "${SERVER_CONF_FILE_PATH}/wg1.conf" ]
    # 无接口专用密钥时回退到通用密钥
    [ "${SERVER_PRIVATE_KEY}" = "${SERVER_CONF_FILE_PATH}/private.key" ]
    [[ "${TODAY_WG_USER_LATEST_LOGIN_FILE}" == *"wg1"* ]]

    # 创建接口专用密钥后优先使用
    touch "${SERVER_CONF_FILE_PATH}/wg1-private.key"
    F_REFRESH_WG_PATHS
    [ "${SERVER_PRIVATE_KEY}" = "${SERVER_CONF_FILE_PATH}/wg1-private.key" ]

    rm -rf "${SH_PATH}" "${SERVER_CONF_FILE_PATH}"
}
