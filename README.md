# labguard_rv1126b

## 当前阶段

项目当前进入 Phase 2 递进开发，分为 3 个紧耦合但独立验收的小阶段:

- Phase 2A: 主相机可用数据基线
- Phase 2B: PCA9685 单独 bring-up
- Phase 2C: 主相机 + 机械臂最小联动

当前重点是把 OV13855 从 bring-up 状态推进到“能稳定、可重复、带元数据地为后续视觉任务供数”的工程基线。

本阶段只围绕固定工位场景推进，允许少量验证性抓图，但不做正式数据集采集、样本整理或训练任务。

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

- `main_profile=preview`
  - `video_node=/dev/video23`
  - `width=1920`
  - `height=1080`
  - `pixfmt=NV12`
  - `fps=30`
- `raw_debug` 继续保留给 raw 链路核查
  - `video_node=/dev/video1`
  - `width=4224`
  - `height=3136`
  - `pixfmt=BG10`
- 固定安装基线已进入配置
  - `mount_id=workbench_main_v1`
  - `status=fixed`
  - `orientation=landscape`
  - `height_mm/tilt_deg/work_distance_mm=pending_measurement`
- 验证抓图目录
  - `samples/ov13855/validation`
  - `manifest=samples/ov13855/validation/manifest.jsonl`
- 当前 presets
  - `auto_baseline`: 自动模式参考档
  - `workbench_balanced`: 固定工位主候选 preset
  - `workbench_lowlight`: 实验 preset，默认禁用
- 当前分辨率决策规则
  - 先以 `1920x1080 NV12 @ 30fps` 为基线
  - 再从 ISP 主输出中选 1 个更高分辨率候选做对比
  - 只有当候选同时满足“细节更好 + 300 帧无异常 + 成本可接受”时才替换主档

### Phase 2A 出口条件

- 固定安装形态已确认并文档化
- 主工作 profile 已冻结
- 控制项摸底完成并形成记录
- 6 组验证场景已完成少量抓图
- 最终推荐 preset 已通过 `300` 秒压力测试

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
│  ├─ camera_data_baseline.md
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
│  ├─ test_camera_capture_mock.sh
│  └─ test_pca9685.sh
├─ samples/
│  └─ ov13855/
│     └─ validation/
└─ logs/
```

## 关键文件

- `docs/ov13855_bringup.md`: Phase 1 bring-up 记录
- `docs/iteration1_camera_test.md`: Phase 1 测试报告
- `docs/camera_engineering_baseline.md`: Phase 2A 工程入口与脚本说明
- `docs/camera_data_baseline.md`: Phase 2A 可用数据基线文档
- `docs/pca9685_wiring.md`: PCA9685 与 RV1126B 默认接线方案
- `docs/minimal_linkage_interface.md`: Phase 2C 最小联动接口定义
- `configs/ov13855.yaml`: 主相机基线配置
- `configs/pca9685.yaml`: PCA9685 默认 bring-up 配置
- `scripts/camera_capture.sh`: 主相机统一采集与验证脚本
- `scripts/pca9685_probe.sh`: PCA9685 I2C 探测脚本
- `tests/test_ov13855.sh`: 主相机 smoke test
- `tests/test_camera_capture_mock.sh`: 主相机脚本 mock 回归测试
- `tests/test_pca9685.sh`: 单舵机保守动作测试

## 当前排除项

当前阶段暂不做:

- XW500 接入
- 正式数据集采集与样本整理
- 检测训练与抓取定位实现
- PCA9685 联动控制
- 多舵机协调动作
- 复杂抓取策略
- RKNN 模型部署
- Web 页面
- 手眼标定
- 完整状态机
