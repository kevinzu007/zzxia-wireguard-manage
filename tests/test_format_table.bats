#!/usr/bin/env bats
# 测试 format_table.sh

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "format_table.sh -h 显示帮助" {
    run bash "${SH_DIR}/format_table.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"用途："* ]]
    [[ "$output" == *"特征码："* ]]
    [[ "$output" == *"权限要求："* ]]
    [[ "$output" == *"参数规范："* ]]
}

@test "format_table.sh 使用 -r 参数生成表格" {
    run bash "${SH_DIR}/format_table.sh" -d '|' -t 'A|B|C' -r 'aa|bb|cc'
    [ "$status" -eq 0 ]
    [[ "$output" == *"+"* ]]
    [[ "$output" == *"aa"* ]]
    [[ "$output" == *"bb"* ]]
    [[ "$output" == *"cc"* ]]
}

@test "format_table.sh 从文件读取数据" {
    local tmp_file
    tmp_file=$(mktemp)
    echo '|日期|用户|流量|' > "${tmp_file}"
    echo '|2024-01-01|猪猪侠|100|' >> "${tmp_file}"
    echo '|2024-01-02|大侠|200|' >> "${tmp_file}"

    run bash "${SH_DIR}/format_table.sh" -d '|' -f "${tmp_file}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"猪猪侠"* ]]
    [[ "$output" == *"大侠"* ]]

    rm -f "${tmp_file}"
}

@test "format_table.sh 默认逗号分隔符" {
    run bash "${SH_DIR}/format_table.sh" -t 'A,B,C' -r 'x,y,z'
    [ "$status" -eq 0 ]
    [[ "$output" == *"x"* ]]
    [[ "$output" == *"y"* ]]
}
