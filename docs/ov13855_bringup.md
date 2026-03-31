# OV13855 Bring-up Record

## 1. 目标

在 RV1126B 上完成 OV13855 主相机 bring-up，确认设备识别、节点映射、真实取流、样张保存和短时稳定性。

## 2. 硬件与软件基线

- Board: RV1126B
- Sensor: OV13855, MIPI
- OS: Debian GNU/Linux 12 (bookworm)
- Kernel: Linux 6.1.141
- Date: 2026-03-31

## 3. 核心结论

- OV13855 已被系统识别，sensor entity 为 `m03_b_ov13855 3-0036`
- 主链路确认:
  - `m03_b_ov13855 3-0036`
  - `rockchip-csi2-dphy0`
  - `rockchip-mipi-csi2`
  - `rkcif-mipi-lvds`
  - `rkisp-vir0`
  - `/dev/video23`
- 主 bring-up 节点: `/dev/video23`
- Raw 调试节点: `/dev/video1`
- 不使用 `/dev/video31` 或 `/dev/video-camera0` 作为 OV13855 主节点

## 4. 关键命令与结果

### 4.1 设备枚举

命令:

```bash
v4l2-ctl --list-devices
ls -l /dev/video* /dev/media* 2>/dev/null
```

结果摘要:

- `rkcif-mipi-lvds`、`rkisp-vir0`、`/dev/video*`、`/dev/media*` 均存在
- `rkcif-mipi-lvds2` 对应第二路未接 sensor 链路

### 4.2 media topology

命令:

```bash
media-ctl -p -d /dev/media1
media-ctl -p -d /dev/media3
```

结果摘要:

- `/dev/media1` 中可见 `m03_b_ov13855 3-0036 -> rockchip-csi2-dphy0 -> rockchip-mipi-csi2`
- `/dev/media3` 中可见 `rkcif-mipi-lvds -> rkisp-isp-subdev -> rkisp_mainpath`

### 4.3 真实取流

命令:

```bash
v4l2-ctl -d /dev/video23 \
  --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
  --stream-mmap=4 \
  --stream-skip=10 \
  --stream-count=1 \
  --stream-to=samples/ov13855/ov13855_1920x1080_nv12.yuv \
  --verbose
```

结果摘要:

- `VIDIOC_STREAMON returned 0`
- 连续出帧正常
- 实测帧率约 `29.95 fps`
- 输出文件大小约 `3110400` 字节

### 4.4 样张保存

命令:

```bash
gst-launch-1.0 -e \
  v4l2src device=/dev/video23 num-buffers=1 io-mode=mmap ! \
  video/x-raw,format=NV12,width=1920,height=1080 ! \
  jpegenc ! \
  filesink location=samples/ov13855/ov13855_1920x1080.jpg
```

结果摘要:

- pipeline 正常结束
- 输出 `samples/ov13855/ov13855_1920x1080.jpg`
- 文件大小约 `247K`

### 4.5 短时稳定性

命令:

```bash
v4l2-ctl -d /dev/video23 \
  --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
  --stream-mmap=4 \
  --stream-skip=10 \
  --stream-count=300 \
  --stream-to=/dev/null \
  --verbose
```

结果摘要:

- `300` 帧测试完成
- 用时约 `10.595s`
- 主链路 stream on / stream off 正常
- 未见 `ov13855/csi/rkcif/rkisp` 致命错误

## 5. 已知日志说明

以下日志记录为非阻塞项:

- `rkcif-mipi-lvds2: ... get remote terminal sensor failed -19`
- `rkisp-vir1: rkisp_enum_frameintervals Not active sensor`

原因:

- 对应板上第二路未接入传感器的链路
- 不属于当前 OV13855 主链路 bring-up 失败

以下日志记录为已知 warning:

- `rkcif-mipi-lvds: Warning: vblank need >= 1000us if isp work in online, cur 808 us`

处理策略:

- Phase 1 仅记录，不修改驱动或时序
- 如后续出现丢帧、曝光异常或长稳问题，再单独分析

## 6. 第一阶段验收结论

- 设备识别: `PASS`
- media / video 节点存在: `PASS`
- 正确视频节点锁定: `PASS`
- 真实取流: `PASS`
- 样张保存: `PASS`
- 短时稳定性: `PASS`

## 7. 当前阶段边界

本阶段不处理以下内容:

- XW500
- PCA9685
- 机械臂控制
- RKNN
- Web UI
- 标定
- 状态机扩展
