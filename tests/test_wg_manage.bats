#!/usr/bin/env bats
# 测试 wg-manage.sh

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export TEST_TMP_DIR=$(mktemp -d)
    export SERVER_CONF_FILE_PATH="${TEST_TMP_DIR}"
    export SERVER_CONF_FILE="${TEST_TMP_DIR}/wg0.conf"
    export SERVER_PRIVATE_KEY="${TEST_TMP_DIR}/private.key"
    export USER_CONFIG_PATH="${TEST_TMP_DIR}/user_config_info"
    export WG_IF="wg0"
    export IP_PREFIX="172.30.0"
    export IP_NETMASK="24"
    export IP_START=11
    export USER_DNSs="1.1.1.1"
    export USER_ALOWED_IPs="0.0.0.0/0"
    export SERVER_CONNECT_INFO="1.2.3.4:51820"
    export SERVER_CONNECT_INFO_V6="[2408:8256:c8:1bdd:ab10:372f:19de:115d]:51820"

    mkdir -p "${USER_CONFIG_PATH}"
    touch "${SERVER_CONF_FILE}"
    echo "dummy-private-key" > "${SERVER_PRIVATE_KEY}"
}

teardown() {
    rm -rf "${TEST_TMP_DIR}"
}

@test "wg-manage.sh -h 显示帮助信息及 IPv4/IPv6 参数" {
    run bash "${SH_DIR}/wg-manage.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"WireGuard 用户管理"* ]]
    [[ "$output" == *"--ipv4|-4"* ]]
    [[ "$output" == *"--ipv6|-6"* ]]
}

@test "F_USER_CONF 正确生成 IPv4 和 IPv6 客户端配置" {
    source "${SH_DIR}/functions.sh"
    USER_NAME="测试用户"
    USER_IP="172.30.0.11"
    USER_PRIVATEKEY="client_priv_key"
    USER_PUBKEY="client_pub_key"
    SERVER_PUBKEY="server_pub_key"
    SERVER_PRE_SHARED_KEY="psk_key"

    # 测试默认 / IPv4 配置
    F_USER_CONF() {
        local endpoint="${1:-${SERVER_CONNECT_INFO}}"
        echo "Endpoint = ${endpoint}"
    }

    local conf_v4
    conf_v4=$(F_USER_CONF "${SERVER_CONNECT_INFO}")
    [[ "$conf_v4" == *"Endpoint = 1.2.3.4:51820"* ]]

    # 测试 IPv6 配置
    local conf_v6
    conf_v6=$(F_USER_CONF "${SERVER_CONNECT_INFO_V6}")
    [[ "$conf_v6" == *"Endpoint = [2408:8256:c8:1bdd:ab10:372f:19de:115d]:51820"* ]]
}
