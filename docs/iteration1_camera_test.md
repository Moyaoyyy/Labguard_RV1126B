# Iteration 1 Camera Test Report

## 1. 测试范围

仅验证 OV13855 在 RV1126B 上的 Phase 1 bring-up。

## 2. 测试环境

- Board: RV1126B
- OS: Debian GNU/Linux 12 (bookworm)
- Kernel: Linux 6.1.141
- Sensor: OV13855
- Date: 2026-03-31

## 3. 测试结果

| Item | Command | Expected | Actual | Result |
|---|---|---|---|---|
| Sensor recognized | `v4l2-ctl --list-devices` | rkcif / rkisp 节点存在 | 节点存在 | PASS |
| Media topology | `media-ctl -p -d /dev/media1` | topology 中出现 OV13855 | `m03_b_ov13855 3-0036` 已出现 | PASS |
| Main node mapping | `v4l2-ctl -d /dev/video23 -D` | 找到主节点 | 主节点锁定为 `/dev/video23` | PASS |
| Raw fallback node | `v4l2-ctl -d /dev/video1 -D` | 找到 raw 节点 | raw 节点锁定为 `/dev/video1` | PASS |
| Single capture | `v4l2-ctl -d /dev/video23 ... --stream-count=1` | 能真实取流 | 连续出帧，约 `29.95 fps` | PASS |
| Sample saved | `gst-launch-1.0 ... filesink location=...jpg` | 样张文件生成 | `ov13855_1920x1080.jpg` 已生成 | PASS |
| Stability | `v4l2-ctl -d /dev/video23 ... --stream-count=300` | 连续完成 300 帧 | 完成，耗时约 `10.595s` | PASS |

## 4. 样张与产物

- Raw sample: `samples/ov13855/ov13855_1920x1080_nv12.yuv`
- JPG sample: `samples/ov13855/ov13855_1920x1080.jpg`

## 5. 日志观察

非阻塞日志:

- `rkcif-mipi-lvds2 ... get remote terminal sensor failed -19`
- `rkisp-vir1 ... Not active sensor`

已知 warning:

- `rkcif-mipi-lvds: Warning: vblank need >= 1000us if isp work in online, cur 808 us`

说明:

- 上述前两类日志来自未接入的第二路链路，不影响当前 OV13855 主链路验收
- `vblank` warning 先记录，后续如果出现长稳问题再继续分析

## 6. 最终结论

Iteration 1 结论: `PASS`

OV13855 已完成第一阶段 bring-up，满足“能识别、能取流、能保存样张、短时运行稳定”的当前目标。
