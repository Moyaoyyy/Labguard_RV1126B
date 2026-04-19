# Logs

该目录用于保存 bring-up 和测试脚本输出的日志文件。

默认日志:

- `bringup_ov13855_*.log`
- `test_ov13855_*.log`
- `camera_capture_*.log`
- `controls_*.log`
- `pca9685_probe_*.log`
- `test_pca9685_*.log`
- `minimal_linkage_*.log`
- `dmesg_before_*.log`
- `dmesg_after_*.log`
- `dmesg_delta_*.log`
- `dmesg_errors_*.log`

说明:

- `camera_capture_*.log` 记录统一采集脚本的运行日志
- `controls_*.log` 记录 `v4l2-ctl -L` 与 `v4l2-ctl --all` 的控制项摸底快照

Phase 2A 板端 auto_baseline 会话至少应保留:

- `1` 个 `camera_capture_*.log` 对应 `oneshot`
- `1` 个 `camera_capture_*.log` 对应 `stress preview frames 300`
- `1` 个 `controls_*.log`
- `6` 组 `camera_capture_*.log` 对应 `baseline-series`
- `1` 个 `camera_capture_*.log` 对应 `stress preview seconds 300`

若本轮中途判定为 `inconclusive`，不要覆盖原日志，保留失败时的 `camera_capture_*.log` 与 `controls_*.log` 作为故障定位输入。
