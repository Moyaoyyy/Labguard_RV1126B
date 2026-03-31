# Camera Engineering Baseline

## 1. 目标

将 OV13855 从 Phase 1 bring-up 状态收敛为 Phase 2A 可重复执行的工程基线。

本阶段不新增样张采集任务，不做人为图像风格调参，只冻结传输与工作分辨率基线。

## 2. 默认工作档

### 2.1 preview

- `video_node=/dev/video23`
- `width=1920`
- `height=1080`
- `pixfmt=NV12`
- `fps=30`
- `stream_skip=10`

选择原因:

- `/dev/video23` 是已验证通过的 ISP 主输出节点
- `1920x1080 NV12` 带宽、调试便利性和后续视觉处理成本更平衡
- 该组合已经通过真实取流和短时间稳定性验证

### 2.2 raw_debug

- `video_node=/dev/video1`
- `width=4224`
- `height=3136`
- `pixfmt=BG10`

保留原因:

- 用于 raw 链路核查
- 用于排查 ISP 路径与 sensor/CIF 路径的分界问题
- 不作为日常运行分辨率

## 3. 相机控制策略

本阶段策略是“冻结传输基线，不做图像风格调参”。

- `ae=auto`
- `awb=auto`
- `gain=record_only`
- `exposure=record_only`

原因:

- 当前没有稳定目标物与样张采集任务
- 当前优先保证工程链路稳定，而不是图像参数优化

## 4. 已知风险

- `rkcif-mipi-lvds: Warning: vblank need >= 1000us if isp work in online, cur 808 us`

当前处理:

- 记录为已知 warning
- Phase 2A 不修改驱动或 sensor 时序
- 若后续长稳、曝光或掉帧异常出现，再单独分析

## 5. 工程化脚本

使用 `scripts/camera_capture.sh` 管理主相机工程基线。

支持子命令:

- `info`
- `preview`
- `oneshot`
- `stress`

示例:

```bash
bash scripts/camera_capture.sh info preview
bash scripts/camera_capture.sh preview preview /dev/null 300
bash scripts/camera_capture.sh oneshot preview
bash scripts/camera_capture.sh stress preview frames 9000
```

## 6. 当前边界

- 不做新样张采集计划
- 不做数据集整理
- 不做自动曝光/白平衡风格固化
- 不做目标检测或坐标输出实现
