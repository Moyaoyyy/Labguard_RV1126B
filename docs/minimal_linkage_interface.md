# Minimal Linkage Interface

## 1. 目标

Phase 2C 先只保留“主相机输出二维目标中心 -> 固定抓取动作入口”的最小接口。

当前不做:

- 手眼标定
- 三维位姿估计
- 真实抓取验收

## 2. 输入接口

输入采用 JSON line，每行一个目标结果:

```json
{"frame_id":123,"width":1920,"height":1080,"cx":960,"cy":540,"score":0.98}
```

字段定义:

- `frame_id`: 帧号
- `width`: 图像宽度
- `height`: 图像高度
- `cx`: 目标中心 x 像素坐标
- `cy`: 目标中心 y 像素坐标
- `score`: 目标置信度

## 3. 输出接口

当前只触发固定套路动作占位，不做真实机械臂控制。

默认输出格式:

```json
{"event":"fixed_grab_stub","frame_id":123,"cx":960,"cy":540,"action":"trigger_fixed_grab_stub"}
```

## 4. 当前脚本

使用 `scripts/minimal_linkage_stub.sh` 作为 Phase 2C 占位接口。

示例:

```bash
echo '{"frame_id":123,"width":1920,"height":1080,"cx":960,"cy":540,"score":0.98}' | \
  bash scripts/minimal_linkage_stub.sh
```

## 5. 进入真实联动前的前置条件

- Phase 2A 已通过
- Phase 2B 已通过
- PCA9685 与单舵机控制稳定
- 目标物已经到位
