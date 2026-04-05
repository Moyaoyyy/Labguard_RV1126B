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
