#!/usr/bin/env python3
"""生成 GDScript ID 常量类（MessageId / AudioId）。

扫描 data/messages/messages_zh.json（键即 id）与 data/audio/**/*.tres
（AudioBgmTrack.track_name / AudioSfxEvent.event_name），生成：
  Public/ids/message_ids.gd  (class_name MessageId)
  Public/ids/audio_ids.gd    (class_name AudioId)
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
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


_TRES_CLASS_RE = re.compile(r'script_class="([^"]+)"')
_TRES_FIELD_RE = re.compile(r'^\s*(track_name|event_name)\s*=\s*"([^"]*)"', re.MULTILINE)
_BGM_CLASS = "AudioBgmTrack"
_SFX_CLASS = "AudioSfxEvent"


@dataclass
class AudioEntry:
    """一个音频条目：名字、类别（bgm/sfx）、来源 .tres 文件路径。"""

    name: str
    kind: str
    source: Path


def load_message_ids(json_path: Path = MESSAGES_JSON) -> list[str]:
    """读取 messages_zh.json 顶层键（即消息 id），排序后返回。"""
    if not json_path.exists():
        raise FileNotFoundError(f"messages json 不存在: {json_path}")
    data = json.loads(json_path.read_text(encoding="utf-8"))
    return sorted(data.keys())


def load_audio_entries(audio_dir: Path = AUDIO_DIR) -> list[AudioEntry]:
    """递归扫描 audio 目录下所有 .tres，解析 BGM/SFX 条目，按名字排序。"""
    entries: list[AudioEntry] = []
    if not audio_dir.exists():
        return entries
    for tres_path in sorted(audio_dir.rglob("*.tres")):
        text = tres_path.read_text(encoding="utf-8")
        class_match = _TRES_CLASS_RE.search(text)
        if class_match is None:
            continue
        script_class = class_match.group(1)
        if script_class not in (_BGM_CLASS, _SFX_CLASS):
            continue
        field_match = _TRES_FIELD_RE.search(text)
        if field_match is None:
            continue
        name = field_match.group(2)
        if not name:
            continue
        kind = "bgm" if script_class == _BGM_CLASS else "sfx"
        entries.append(AudioEntry(name=name, kind=kind, source=tres_path))
    return sorted(entries, key=lambda entry: entry.name)
