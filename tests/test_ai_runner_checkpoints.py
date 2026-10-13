import unittest
from datetime import datetime, timedelta, timezone
from tools.ai_runner.checkpoints import make_record, render, parse, latest, stalled, trusted

AT = datetime(2026, 10, 14, tzinfo=timezone.utc)

class CheckpointTests(unittest.TestCase):
    def test_round_trip_korean(self):
        r = make_record(12, "running", "낙인 효과", at=AT)
        self.assertEqual(parse(render(r)), r)

    def test_invalid_comment_not_trusted(self):
        self.assertIsNone(parse("someone said done"))
        self.assertIsNone(parse("<!-- ND_AI_CHECKPOINT_V1 --> not JSON"))

    def test_latest_ignores_other_issue(self):
        a = make_record(12, "ready", "one", at=AT)
        b = make_record(12, "checkpoint", "two", at=AT)
        c = make_record(99, "complete", "three", at=AT)
        self.assertEqual(latest([{"body": render(x)} for x in (a,b,c)], 12)["step"], "two")

    def test_stale_only_running(self):
        a = make_record(12, "running", "step", at=AT)
        self.assertIsNone(stalled(a, AT + timedelta(minutes=89)))
        self.assertEqual(stalled(a, AT + timedelta(minutes=90)), "recoverable")
        b = make_record(12, "checkpoint", "done", at=AT)
        self.assertIsNone(stalled(b, AT + timedelta(days=3)))

    def test_retry_limit(self):
        a = make_record(12, "running", "step", attempt=3, at=AT)
        self.assertEqual(stalled(a, AT + timedelta(hours=2)), "blocked")

    def test_owner_only(self):
        i = dict(state="open", title="[AI 작업] 상태", user={"login":"gamja121"})
        self.assertTrue(trusted(i, "gamja121"))
        self.assertFalse(trusted({**i, "user":{"login":"outsider"}}, "gamja121"))
        self.assertFalse(trusted({**i, "pull_request":{"url":"x"}}, "gamja121"))

    def test_invalid_data_rejected(self):
        with self.assertRaises(ValueError):
            make_record(0, "running", "work")
        with self.assertRaises(ValueError):
            make_record(1, "running", " ")

if __name__ == "__main__":
    unittest.main()
