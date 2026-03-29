#!/usr/bin/env bats
# 测试 send_markdown_msg.sh

SH_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "send_markdown_msg.sh -h 显示帮助" {
    run bash "${SH_DIR}/send_markdown_msg.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"用途："* ]]
    [[ "$output" == *"特征码："* ]]
    [[ "$output" == *"权限要求："* ]]
    [[ "$output" == *"参数规范："* ]]
}

@test "send_markdown_msg.sh 缺少参数时报错" {
    run bash "${SH_DIR}/send_markdown_msg.sh" -t "test"
    [ "$status" -ne 0 ]
    [[ "$output" == *"参数不足"* ]] || [[ "$stderr" == *"参数不足"* ]]
}

@test "send_markdown_msg.sh 缺少 -m 参数值时报错" {
    run bash "${SH_DIR}/send_markdown_msg.sh" -t "test" -m
    [ "$status" -ne 0 ]
}

@test "send_markdown_msg.sh 无参数时报错" {
    run bash "${SH_DIR}/send_markdown_msg.sh"
    [ "$status" -ne 0 ]
}
