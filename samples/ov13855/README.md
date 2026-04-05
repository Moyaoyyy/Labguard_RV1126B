# OV13855 Samples

该目录用于保存 OV13855 bring-up 与 Phase 2A 基线验证产物。

默认产物:

- `ov13855_1920x1080_nv12.yuv`
- `ov13855_1920x1080.jpg`
- `validation/*.yuv` 或 `validation/*.raw`
- `validation/*.jpg`
- `validation/*.json`
- `validation/manifest.jsonl`

说明:

- 这些文件由 `tests/test_ov13855.sh` 或 `scripts/camera_capture.sh` 在目标板运行时生成
- 仓库默认只保留目录和说明，不预置二进制样张
- `validation/` 仅保存少量验证性抓图，用于固定工位场景下的画质基线与调参对比
- 当前不做正式数据集采集和样本整理
