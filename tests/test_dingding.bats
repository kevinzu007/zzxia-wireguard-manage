#!/usr/bin/env bats
# 测试 dingding_send_markdown.sh

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "dingding_send_markdown.sh -h 显示帮助" {
    run bash "${SH_DIR}/dingding_send_markdown.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"用途："* ]]
    [[ "$output" == *"特征码："* ]]
    [[ "$output" == *"权限要求："* ]]
    [[ "$output" == *"参数规范："* ]]
}

@test "dingding_send_markdown.sh 缺少参数时报错" {
    run bash "${SH_DIR}/dingding_send_markdown.sh" -t "test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"参数不足"* ]] || [[ "$stderr" == *"参数不足"* ]]
}

@test "dingding_send_markdown.sh 缺少 -m 参数值时报错" {
    run bash "${SH_DIR}/dingding_send_markdown.sh" -t "test" -m
    [ "$status" -ne 0 ]
}

@test "dingding_send_markdown.sh 无参数时报错" {
    run bash "${SH_DIR}/dingding_send_markdown.sh"
    [ "$status" -ne 0 ]
}
