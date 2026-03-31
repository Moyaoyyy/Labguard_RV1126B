# labguard_rv1126b

## 当前阶段

项目当前进入 Phase 2 递进开发，分为 3 个紧耦合但独立验收的小阶段:

- Phase 2A: 主相机工程化
- Phase 2B: PCA9685 单独 bring-up
- Phase 2C: 主相机 + 机械臂最小联动

当前只把主相机从 bring-up 状态收敛为可重复执行的工程基线，不做新的样张采集和数据集建设。

## 当前状态

### Phase 1 已完成

- 平台: RV1126B
- 系统: Debian 12 (bookworm)
- 内核: Linux 6.1.141
- Sensor entity: `m03_b_ov13855 3-0036`
- 主链路: `OV13855 -> rockchip-csi2-dphy0 -> rockchip-mipi-csi2 -> rkcif-mipi-lvds -> rkisp-vir0 -> /dev/video23`
- 主 bring-up 节点: `/dev/video23`
- Raw 调试节点: `/dev/video1`
- 已验证工作档: `1920x1080 NV12 @ 30fps`
- 已完成单帧取流、样张保存、300 帧短稳验证

### Phase 2A 当前基线

- 日常工作 profile: `preview`
  - `video_node=/dev/video23`
  - `width=1920`
  - `height=1080`
  - `pixfmt=NV12`
  - `fps=30`
- Raw 调试 profile: `raw_debug`
  - `video_node=/dev/video1`
  - `width=4224`
  - `height=3136`
  - `pixfmt=BG10`
- 当前不做人为图像风格调参:
  - `ae=auto`
  - `awb=auto`
  - `gain/exposure=record_only`

### Phase 2B 当前前提

- PCA9685 与 RV1126B 还未连接
- 默认按 `40-pin GPIO` 接线
- 默认使用独立 `5V` 给舵机侧供电

### Phase 2C 当前边界

- 仅预留目标中心 JSON line 接口
- 当前不做真实抓取验收
- 需等待 PCA9685 接通且目标物到位后再执行

## 简化后的目录

```text
labguard_rv1126b/
├─ README.md
├─ docs/
│  ├─ ov13855_bringup.md
│  ├─ iteration1_camera_test.md
│  ├─ camera_engineering_baseline.md
│  ├─ pca9685_wiring.md
│  └─ minimal_linkage_interface.md
├─ configs/
│  ├─ ov13855.yaml
│  └─ pca9685.yaml
├─ scripts/
│  ├─ check_camera.sh
│  ├─ camera_capture.sh
│  ├─ pca9685_probe.sh
│  └─ minimal_linkage_stub.sh
├─ tests/
│  ├─ test_ov13855.sh
│  └─ test_pca9685.sh
├─ samples/
│  └─ ov13855/
└─ logs/
```

## 关键文件

- `docs/ov13855_bringup.md`: Phase 1 bring-up 记录
- `docs/iteration1_camera_test.md`: Phase 1 测试报告
- `docs/camera_engineering_baseline.md`: Phase 2A 主相机工程基线说明
- `docs/pca9685_wiring.md`: PCA9685 与 RV1126B 默认接线方案
- `docs/minimal_linkage_interface.md`: Phase 2C 最小联动接口定义
- `configs/ov13855.yaml`: 主相机工程基线配置
- `configs/pca9685.yaml`: PCA9685 默认 bring-up 配置
- `scripts/camera_capture.sh`: 主相机工程化脚本
- `scripts/pca9685_probe.sh`: PCA9685 I2C 探测脚本
- `tests/test_pca9685.sh`: 单舵机保守动作测试

## 当前排除项

以下内容暂不做:

- XW500 接入
- 多舵机协调动作
- 复杂抓取策略
- RKNN 模型部署
- Web 页面
- 手眼标定
- 完整状态机
