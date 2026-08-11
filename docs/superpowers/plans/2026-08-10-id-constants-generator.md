# ID 常量生成器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写一个 Python 生成器 `tools/gen_id_constants.py`，扫描 `data/messages/messages_zh.json`（键即 id）与 `data/audio/**/*.tres`（`AudioBgmTrack.track_name` / `AudioSfxEvent.event_name`），生成两个 GDScript 常量类：`Public/ids/message_ids.gd`（`class_name MessageId`）与 `Public/ids/audio_ids.gd`（`class_name AudioId`），让代码里引用 id 时获得编译期检查与 IDE 补全。

**Architecture:** 纯 Python 标准库脚本（json + 正则解析 .tres），无第三方依赖，与 `tools/message_exporter/export_messages.py` 同目录惯例。核心逻辑拆成可单测的纯函数（命名转换 / JSON 解析 / .tres 解析 / 重复校验 / 类内容生成），CLI 入口 `main()` 只做编排。GDScript 输出用 `const XXX: StringName = &"xxx"` 常量类形态（message id 是字符串，GDScript enum 是整型装不下）。

**Tech Stack:** Python 3.12（Codex runtime 解释器，PATH 无 python）+ 标准库 `unittest`（不引入 pytest）。验证走 Godot headless。

## Global Constraints

- 解释器绝对路径：`C:\Users\31391\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
  （本机 PATH 无 python，WindowsApps 仅为 stub；所有命令用此绝对路径，不依赖 PATH。）
- 所有命令在项目根 `D:\Dev\Godot\无聊的飞` 下运行（工作目录=该目录）。
- 纯 Python 标准库，禁止第三方依赖（不装包）。
- 输出文件头必须含"自动生成，勿手改"注释；常量命名 snake_case → SCREAMING_SNAKE_CASE。
- 重复 id / 常量名冲突 → 报错退出（非零 exit code），绝不静默去重。
- 幂等：重复运行输出一致（排序输出，不依赖扫描顺序）。
- 中文注释，只解释设计意图。
- 不自动 commit（Git 纪律）；每个 Task 末尾的 commit 命令为可选项，由执行者/用户决定。
- Godot exe：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`。
- 分支：开工前确认。建议从 `develop`（本地 `a03c34d`，远程不可达则用本地）新建 `feature/id-constants-generator`，避免污染当前 `feature/bullet-system-redo`（弹幕工具线）。

---

### Task 1: 脚本骨架 + 命名转换函数 `to_constant_name`（TDD）

**Files:**
- Create: `tools/gen_id_constants.py`
- Create: `tools/tests/__init__.py`（空文件，让 unittest discover 识别包）
- Create: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: 无（本任务只建骨架 + 一个纯函数）。
- Produces: `to_constant_name(source: str) -> str`（snake_case → SCREAMING_SNAKE_CASE，非字母数字分段用下划线连接并大写）。

- [ ] **Step 1: 写测试文件**（`tools/tests/test_gen_id_constants.py`）

```python
"""gen_id_constants 单元测试：命名转换。"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gen_id_constants as gen


class TestToConstantName(unittest.TestCase):
    def test_snake_case(self) -> None:
        self.assertEqual(gen.to_constant_name("eye_intro_warning"), "EYE_INTRO_WARNING")

    def test_plain_name(self) -> None:
        self.assertEqual(gen.to_constant_name("test_boss"), "TEST_BOSS")

    def test_single_word(self) -> None:
        self.assertEqual(gen.to_constant_name("test"), "TEST")

    def test_with_digits(self) -> None:
        self.assertEqual(gen.to_constant_name("bgm_2_layer"), "BGM_2_LAYER")

    def test_with_dash_separator(self) -> None:
        self.assertEqual(gen.to_constant_name("test-boss"), "TEST_BOSS")


if __name__ == "__main__":
    unittest.main()
```

同时创建空包标记：`tools/tests/__init__.py`（空文件）。

- [ ] **Step 2: 运行测试确认失败**

```powershell
& "C:\Users\31391\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m unittest discover -s tools/tests -v
```

Expected: FAIL —— `ModuleNotFoundError: No module named 'gen_id_constants'`（脚本尚未创建）。

- [ ] **Step 3: 写脚本骨架 + 实现 `to_constant_name`**

创建 `tools/gen_id_constants.py`：

```python
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestToConstantName` 5 个用例全部 PASS。

- [ ] **Step 5: Commit（可选，仅用户要求）**

```bash
git add tools/gen_id_constants.py tools/tests/
git commit -m "feat: ID 常量生成器骨架与命名转换函数"
```

---

### Task 2: message id 解析 `load_message_ids`（TDD）

**Files:**
- Modify: `tools/gen_id_constants.py`
- Modify: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: `MESSAGES_JSON`（模块常量，Task 1 已定义）。
- Produces: `load_message_ids(json_path: Path = MESSAGES_JSON) -> list[str]`
  —— 读 JSON 顶层键，排序返回；文件不存在抛 `FileNotFoundError`；JSON 解析失败抛 `json.JSONDecodeError`。

- [ ] **Step 1: 加测试**（追加到 `TestToConstantName` 之后）

```python
class TestLoadMessageIds(unittest.TestCase):
    def test_returns_sorted_keys(self) -> None:
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "messages_zh.json"
            p.write_text(
                json.dumps({"eye_phase_2": {}, "eye_intro_warning": {}, "eye_defeated": {}}),
                encoding="utf-8",
            )
            self.assertEqual(
                gen.load_message_ids(p),
                ["eye_defeated", "eye_intro_warning", "eye_phase_2"],
            )

    def test_missing_file_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            gen.load_message_ids(Path("nonexistent_messages.json"))
```

- [ ] **Step 2: 运行测试确认失败**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: FAIL —— `AttributeError: module 'gen_id_constants' has no attribute 'load_message_ids'`。

- [ ] **Step 3: 实现 `load_message_ids`**（在 `to_constant_name` 之后追加）

```python
def load_message_ids(json_path: Path = MESSAGES_JSON) -> list[str]:
    """读取 messages_zh.json 顶层键（即消息 id），排序后返回。"""
    if not json_path.exists():
        raise FileNotFoundError(f"messages json 不存在: {json_path}")
    import json

    data = json.loads(json_path.read_text(encoding="utf-8"))
    return sorted(data.keys())
```

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestLoadMessageIds` 2 个用例 PASS。

- [ ] **Step 5: Commit（可选）**

```bash
git add tools/gen_id_constants.py tools/tests/
git commit -m "feat: 生成器支持从 messages_zh.json 提取消息 id"
```

---

### Task 3: audio .tres 解析 `load_audio_entries`（TDD）

**Files:**
- Modify: `tools/gen_id_constants.py`
- Modify: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: `AUDIO_DIR`（模块常量）、`AudioEntry`（本任务定义）。
- Produces:
  - `@dataclass AudioEntry`：字段 `name: str`、`kind: str`（`"bgm" | "sfx"`）、`source: Path`。
  - `load_audio_entries(audio_dir: Path = AUDIO_DIR) -> list[AudioEntry]`
    —— 递归扫描全部 `*.tres`；按 `script_class` 只认 `AudioBgmTrack`（读 `track_name`）与 `AudioSfxEvent`（读 `event_name`）；其余跳过；按名字排序返回；目录不存在或无 .tres 返回空列表。

- [ ] **Step 1: 加测试**

```python
class TestLoadAudioEntries(unittest.TestCase):
    @staticmethod
    def _write_tres(path: Path, script_class: str, name_field: str, name: str) -> None:
        path.write_text(
            f'[gd_resource type="Resource" script_class="{script_class}" format=3]\n'
            "\n[resource]\n"
            f'{name_field} = "{name}"\n',
            encoding="utf-8",
        )

    def test_parses_bgm_and_sfx(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "audio"
            (audio / "test").mkdir(parents=True)
            self._write_tres(audio / "test" / "boss.tres", "AudioBgmTrack", "track_name", "test_boss")
            self._write_tres(audio / "test" / "hit.tres", "AudioSfxEvent", "event_name", "test_hit")
            entries = gen.load_audio_entries(audio)
            self.assertEqual(
                [(e.name, e.kind) for e in entries],
                [("test_boss", "bgm"), ("test_hit", "sfx")],
            )

    def test_skips_unrelated_tres(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            audio = Path(tmp) / "audio"
            audio.mkdir(parents=True)
            (audio / "unrelated.tres").write_text('[gd_resource type="Resource" format=3]\n', encoding="utf-8")
            (audio / "other.tres").write_text(
                '[gd_resource type="Resource" script_class="SomeOtherClass" format=3]\n',
                encoding="utf-8",
            )
            self.assertEqual(gen.load_audio_entries(audio), [])

    def test_missing_dir_returns_empty(self) -> None:
        self.assertEqual(gen.load_audio_entries(Path("nonexistent_audio_dir")), [])
```

- [ ] **Step 2: 运行测试确认失败**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: FAIL —— `AttributeError: ... no attribute 'load_audio_entries'`。

- [ ] **Step 3: 实现 `AudioEntry` + `load_audio_entries`**（模块顶部加 import，函数追加到 `load_message_ids` 之后）

先在文件头部 import 区补：

```python
from dataclasses import dataclass
import json  # 挪到顶部统一管理（Task 2 的局部 import 一并上移）
```

并在 `to_constant_name` 之后定义解析用的正则与 dataclass：

```python
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
```

同时把 Task 2 里 `load_message_ids` 内的局部 `import json` 上移到文件顶部（与 dataclass import 合并），保持整洁。

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestLoadAudioEntries` 3 个用例 PASS（前两个 Task 的用例仍 PASS）。

- [ ] **Step 5: Commit（可选）**

```bash
git add tools/gen_id_constants.py tools/tests/
git commit -m "feat: 生成器支持从 audio .tres 解析 BGM/SFX 名字"
```

---

### Task 4: 重复校验 `check_duplicates`（TDD）

**Files:**
- Modify: `tools/gen_id_constants.py`
- Modify: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: `message_ids: list[str]`、`audio_entries: list[AudioEntry]`、`to_constant_name`。
- Produces: `check_duplicates(message_ids: list[str], audio_entries: list[AudioEntry]) -> None`
  —— 原始 id 重复（message 内 / audio 内 / 跨类型同名）或常量名冲突（不同源名转换后相同）时抛 `ValueError`，带来源描述；无冲突时静默返回。

- [ ] **Step 1: 加测试**

```python
class TestCheckDuplicates(unittest.TestCase):
    def test_message_duplicate(self) -> None:
        with self.assertRaises(ValueError):
            gen.check_duplicates(["a", "a"], [])

    def test_cross_type_duplicate(self) -> None:
        entries = [gen.AudioEntry(name="dup", kind="bgm", source=Path("x.tres"))]
        with self.assertRaises(ValueError):
            gen.check_duplicates(["dup"], entries)

    def test_const_name_collision(self) -> None:
        entries = [gen.AudioEntry(name="test-boss", kind="bgm", source=Path("a.tres"))]
        with self.assertRaises(ValueError):
            gen.check_duplicates(["test_boss"], entries)

    def test_ok_no_duplicates(self) -> None:
        entries = [gen.AudioEntry(name="test_boss", kind="bgm", source=Path("x.tres"))]
        # 不抛异常即通过
        gen.check_duplicates(["eye_intro_warning"], entries)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: FAIL —— `AttributeError: ... no attribute 'check_duplicates'`。

- [ ] **Step 3: 实现 `check_duplicates`**（追加到 `load_audio_entries` 之后）

```python
def check_duplicates(message_ids: list[str], audio_entries: list[AudioEntry]) -> None:
    """校验 id 全空间无重复、常量名转换无冲突；有则抛 ValueError。"""
    raw_seen: dict[str, str] = {}
    for mid in message_ids:
        raw_seen[mid] = "messages_zh.json"
    for entry in audio_entries:
        prev = raw_seen.get(entry.name)
        if prev is not None:
            raise ValueError(f"重复 id: '{entry.name}'（{entry.source} 与 {prev}）")
        raw_seen[entry.name] = str(entry.source)

    const_seen: dict[str, str] = {}
    for name in message_ids + [entry.name for entry in audio_entries]:
        const_name = to_constant_name(name)
        prev = const_seen.get(const_name)
        if prev is not None and prev != name:
            raise ValueError(f"常量名冲突: '{name}' 与 '{prev}' 都转换为 '{const_name}'")
        const_seen[const_name] = name
```

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestCheckDuplicates` 4 个用例 PASS。

- [ ] **Step 5: Commit（可选）**

```bash
git add tools/gen_id_constants.py tools/tests/
git commit -m "feat: 生成器重复 id 与常量名冲突校验"
```

---

### Task 5: GDScript 类内容生成 `build_message_class` / `build_audio_class`（TDD）

**Files:**
- Modify: `tools/gen_id_constants.py`
- Modify: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: `message_ids: list[str]`、`audio_entries: list[AudioEntry]`、`to_constant_name`、`HEADER`。
- Produces:
  - `build_message_class(message_ids: list[str]) -> str` —— `MessageId` 类文本（常量按输入顺序）。
  - `build_audio_class(audio_entries: list[AudioEntry]) -> str` —— `AudioId` 类文本，BGM 段注释 `# BGM`、SFX 段注释 `# SFX`，组内按名字排序。

- [ ] **Step 1: 加测试**

```python
class TestBuildClasses(unittest.TestCase):
    def test_message_class(self) -> None:
        content = gen.build_message_class(["eye_intro_warning"])
        self.assertIn("class_name MessageId", content)
        self.assertIn('const EYE_INTRO_WARNING: StringName = &"eye_intro_warning"', content)
        self.assertIn("自动生成，勿手改", content)

    def test_audio_class_sections(self) -> None:
        entries = [
            gen.AudioEntry(name="test_hit", kind="sfx", source=Path("h.tres")),
            gen.AudioEntry(name="test_stage", kind="bgm", source=Path("s.tres")),
            gen.AudioEntry(name="test_boss", kind="bgm", source=Path("b.tres")),
        ]
        content = gen.build_audio_class(entries)
        self.assertIn("class_name AudioId", content)
        self.assertIn("# BGM", content)
        self.assertIn("# SFX", content)
        self.assertIn('const TEST_STAGE: StringName = &"test_stage"', content)
        self.assertIn('const TEST_BOSS: StringName = &"test_boss"', content)
        self.assertIn('const TEST_HIT: StringName = &"test_hit"', content)
        # BGM 组内按名字排序：TEST_BOSS 在 TEST_STAGE 之前
        self.assertLess(content.index("TEST_BOSS"), content.index("TEST_STAGE"))

    def test_audio_class_empty(self) -> None:
        content = gen.build_audio_class([])
        self.assertIn("class_name AudioId", content)
        self.assertNotIn("# BGM", content)
        self.assertNotIn("# SFX", content)
```

- [ ] **Step 2: 运行测试确认失败**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: FAIL —— `AttributeError: ... no attribute 'build_message_class'`。

- [ ] **Step 3: 实现两个 build 函数**（追加到 `check_duplicates` 之后）

```python
def build_message_class(message_ids: list[str]) -> str:
    """生成 MessageId 常量类文本。"""
    lines = [HEADER, "class_name MessageId", ""]
    for mid in message_ids:
        lines.append(f'const {to_constant_name(mid)}: StringName = &"{mid}"')
    return "\n".join(lines) + "\n"


def build_audio_class(audio_entries: list[AudioEntry]) -> str:
    """生成 AudioId 常量类文本：BGM 段与 SFX 段分注释，组内按名字排序。"""
    bgm = sorted((e for e in audio_entries if e.kind == "bgm"), key=lambda e: e.name)
    sfx = sorted((e for e in audio_entries if e.kind == "sfx"), key=lambda e: e.name)
    lines = [HEADER, "class_name AudioId", ""]
    if bgm:
        lines.append("# BGM")
        for entry in bgm:
            lines.append(f'const {to_constant_name(entry.name)}: StringName = &"{entry.name}"')
        lines.append("")
    if sfx:
        lines.append("# SFX")
        for entry in sfx:
            lines.append(f'const {to_constant_name(entry.name)}: StringName = &"{entry.name}"')
    return "\n".join(lines) + "\n"
```

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestBuildClasses` 3 个用例 PASS。

- [ ] **Step 5: Commit（可选）**

```bash
git add tools/gen_id_constants.py tools/tests/
git commit -m "feat: 生成器输出 MessageId/AudioId 常量类文本"
```

---

### Task 6: CLI 入口 `main()`（生成 + `--check`）+ 端到端验证

**Files:**
- Modify: `tools/gen_id_constants.py`
- Modify: `tools/tests/test_gen_id_constants.py`

**Interfaces:**
- Consumes: 全部前序函数 + `OUT_DIR`。
- Produces: `main(argv: list[str] | None = None) -> int` —— `--check` 只校验 stale 不写文件；无参全量生成并写盘。返回 0 成功 / 1 失败。

- [ ] **Step 1: 加 CLI 测试**（用 monkeypatch 指向临时目录验证 `--check` 逻辑）

```python
class TestMain(unittest.TestCase):
    def test_check_reports_stale_when_missing(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            original = gen.OUT_DIR
            gen.OUT_DIR = out  # monkeypatch 输出目录
            try:
                code = gen.main(["--check"])
            finally:
                gen.OUT_DIR = original
            self.assertEqual(code, 1)

    def test_generate_writes_files(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            original = gen.OUT_DIR
            gen.OUT_DIR = out
            try:
                code = gen.main([])
                self.assertEqual(code, 0)
                self.assertTrue((out / "message_ids.gd").exists())
                self.assertTrue((out / "audio_ids.gd").exists())
                # 幂等：再跑一次内容一致
                content1 = (out / "message_ids.gd").read_text(encoding="utf-8")
                code2 = gen.main([])
                self.assertEqual(code2, 0)
                content2 = (out / "message_ids.gd").read_text(encoding="utf-8")
                self.assertEqual(content1, content2)
            finally:
                gen.OUT_DIR = original
```

> 注：这两个用例依赖真实 `data/` 文件存在（monkeypatch 只换输出目录），属于轻量集成测试，在项目根运行。

- [ ] **Step 2: 运行测试确认失败**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: FAIL —— `TypeError: 'module' object is not callable` 或 `AttributeError: no attribute 'main'`。

- [ ] **Step 3: 实现 `main()`**（追加到文件末尾 + `if __name__` 块）

```python
def main(argv: list[str] | None = None) -> int:
    """CLI 入口：全量生成或 --check 校验。返回 0 成功 / 1 失败。"""
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="生成 GDScript ID 常量类（MessageId / AudioId）")
    parser.add_argument("--check", action="store_true", help="只检查是否 stale，不写文件")
    args = parser.parse_args(argv)

    try:
        message_ids = load_message_ids()
        audio_entries = load_audio_entries()
        check_duplicates(message_ids, audio_entries)
        outputs = {
            OUT_DIR / "message_ids.gd": build_message_class(message_ids),
            OUT_DIR / "audio_ids.gd": build_audio_class(audio_entries),
        }
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if args.check:
        stale = [
            path
            for path, content in outputs.items()
            if not path.exists() or path.read_text(encoding="utf-8") != content
        ]
        if stale:
            print(f"stale: {', '.join(str(p) for p in stale)}（请先运行全量生成）", file=sys.stderr)
            return 1
        print("up to date")
        return 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path, content in outputs.items():
        path.write_text(content, encoding="utf-8")
        print(f"generated {path}")
    return 0


if __name__ == "__main__":
    import sys

    raise SystemExit(main(sys.argv[1:]))
```

- [ ] **Step 4: 运行测试确认通过**

Run: `& "...python.exe" -m unittest discover -s tools/tests -v`
Expected: `TestMain` 2 个用例 PASS，全部用例 PASS。

- [ ] **Step 5: 真实运行生成两个文件**

```powershell
& "C:\Users\31391\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/gen_id_constants.py
```

Expected stdout:
```
generated D:\Dev\Godot\无聊的飞\Public\ids\message_ids.gd
generated D:\Dev\Godot\无聊的飞\Public\ids\audio_ids.gd
```

- [ ] **Step 6: 核对生成内容（真实数据预期）**

`Public/ids/message_ids.gd` 应含 3 个常量（顺序按字典序）：
```gdscript
const EYE_DEFEATED: StringName = &"eye_defeated"
const EYE_INTRO_WARNING: StringName = &"eye_intro_warning"
const EYE_PHASE_2: StringName = &"eye_phase_2"
```

`Public/ids/audio_ids.gd` 应含 8 个常量：BGM 段 `TEST_BOSS` / `TEST_BOSS_INTRO` / `TEST_STAGE`，SFX 段 `TEST_FOLLOW_LOOP` / `TEST_HIT` / `TEST_INTERRUPT` / `TEST_ONCE_PER_FRAME` / `TEST_PING`。

用 `git diff --stat` 确认两个新文件已生成（未跟踪状态）。

- [ ] **Step 7: `--check` 幂等验证**

```powershell
& "...python.exe" tools/gen_id_constants.py --check
```

Expected: `up to date`，exit code 0。连续跑两次结果一致（幂等成立）。

- [ ] **Step 8: Godot headless 验证两个类可解析**

在项目根创建临时验证脚本 `tmp_verify_id_classes.gd`：

```gdscript
extends SceneTree

func _init() -> void:
	var msg_script: GDScript = load("res://Public/ids/message_ids.gd")
	var audio_script: GDScript = load("res://Public/ids/audio_ids.gd")
	if msg_script == null or audio_script == null:
		printerr("ID 常量类加载失败")
		quit(1)
		return
	print("ID 常量类解析 OK")
	quit(0)
```

运行：

```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --script tmp_verify_id_classes.gd
```

Expected: 输出 `ID 常量类解析 OK`，exit code 0。之后**删除** `tmp_verify_id_classes.gd`（临时文件，不提交）。

- [ ] **Step 9: 负向验证（重复 id 报错）**

临时在 `data/audio/test/` 复制一个 .tres 改名为不冲突但同名的文件不可行（同名文件不存在）——改为验证方式：手动在测试里已覆盖。可额外做：临时把 `messages_zh.json` 备份后复制一份到临时路径不可行（固定路径）。**跳过额外负向验证**（Task 4 单元测试已覆盖重复场景），记录说明即可。

- [ ] **Step 10: 清理 + 最终确认**

```powershell
git status --short
```

Expected: 仅新增 `Public/ids/message_ids.gd`、`Public/ids/audio_ids.gd`（+ `.uid` 文件待 Godot 编辑器扫描生成）与 `tools/gen_id_constants.py`、`tools/tests/`；无临时文件残留。

- [ ] **Step 11: Commit（可选）**

```bash
git add tools/gen_id_constants.py tools/tests/ Public/ids/
git commit -m "feat: ID 常量生成器，生成 MessageId/AudioId 常量类（自动扫描消息与音频资源）"
```

---

### 收尾验收（非独立任务）

- [ ] 全部 `unittest` 用例 PASS（Task 1-6 累计）。
- [ ] 真实运行生成两个文件，内容与预期一致（3 个消息常量 + 8 个音频常量）。
- [ ] `--check` 幂等：连续运行输出 `up to date`。
- [ ] Godot headless 加载两个常量类无解析错误（临时脚本已删）。
- [ ] `git status` 无临时文件残留。
- [ ] （用户要求时）写 `docs/` 下工具说明；默认不写（按项目纪律）。
