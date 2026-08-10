#!/usr/bin/env python3
"""生成 GDScript ID 常量类（MessageId / AudioId）。

扫描 data/messages/messages_zh.json（键即 id）与 data/audio/**/*.tres
（AudioBgmTrack.track_name / AudioSfxEvent.event_name），生成：
  Public/ids/message_ids.gd  (class_name MessageId)
  Public/ids/audio_ids.gd    (class_name AudioId)
"""

from __future__ import annotations

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MESSAGES_JSON = PROJECT_ROOT / "data" / "messages" / "messages_zh.json"
AUDIO_DIR = PROJECT_ROOT / "data" / "audio"
OUT_DIR = PROJECT_ROOT / "Public" / "ids"

HEADER = "# 自动生成，勿手改 —— 由 tools/gen_id_constants.py 生成\n"


def to_constant_name(source: str) -> str:
    """snake_case → SCREAMING_SNAKE_CASE；非字母数字分段用下划线连接并大写。"""
    parts = re.findall(r"[A-Za-z0-9]+", source)
    return "_".join(parts).upper()
