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

    def test_invalid_empty_name_raises(self) -> None:
        # 全空/全非拉丁字母 → 转换后常量为空字符串，非法 GDScript 标识符
        self.assertEqual(gen.to_constant_name(""), "")
        with self.assertRaises(ValueError):
            gen.check_duplicates([""], [])

    def test_invalid_digit_leading_name_raises(self) -> None:
        # 转换后以数字开头（如 "2D_BOSS"），非法 GDScript 标识符
        self.assertEqual(gen.to_constant_name("2d_boss"), "2D_BOSS")
        with self.assertRaises(ValueError):
            gen.check_duplicates(["2d_boss"], [])


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

    def test_check_reports_stale_when_content_differs(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            original = gen.OUT_DIR
            gen.OUT_DIR = out
            try:
                # 先全量生成，再故意写入错误内容模拟本地被改动
                self.assertEqual(gen.main([]), 0)
                (out / "message_ids.gd").write_text("garbage", encoding="utf-8")
                self.assertEqual(gen.main(["--check"]), 1)
            finally:
                gen.OUT_DIR = original

    def test_check_returns_0_when_up_to_date(self) -> None:
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            original = gen.OUT_DIR
            gen.OUT_DIR = out
            try:
                # 全量生成后内容一致，--check 应为 0
                self.assertEqual(gen.main([]), 0)
                self.assertEqual(gen.main(["--check"]), 0)
            finally:
                gen.OUT_DIR = original


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


if __name__ == "__main__":
    unittest.main()
