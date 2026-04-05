# OV13855 Validation Captures

该目录用于保存 Phase 2A 的少量验证性抓图，不作为正式数据集目录。

默认产物:

- `*.yuv` 或 `*.raw`: 原始单帧验证图
- `*.jpg`: 可选预览图
- `*.json`: 每张验证图的 sidecar 元数据
- `manifest.jsonl`: 全部验证抓图的汇总清单

说明:

- 这些文件由 `scripts/camera_capture.sh baseline-shot` 或 `baseline-series` 生成
- 产物仅用于安装确认、分辨率对比、图像质量基线和参数摸底
- 仓库默认只保留目录说明，不提交验证抓图二进制和运行期 manifest
