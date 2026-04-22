import json
from unittest.mock import MagicMock, patch, call
from src.processor import StreamProcessor


def _make_processor():
    """Build a StreamProcessor with all external dependencies mocked."""
    mock_consumer = MagicMock()
    mock_redis    = MagicMock()

    with patch("src.processor.KafkaConsumer", return_value=mock_consumer), \
         patch("src.processor.redis.Redis",   return_value=mock_redis), \
         patch("src.processor.init_schema"), \
         patch("src.db_client._get_pool"):
        processor = StreamProcessor()

    processor.consumer = mock_consumer
    processor.redis    = mock_redis
    return processor, mock_consumer, mock_redis


def test_process_saves_to_db_and_updates_cache():
    processor, _, mock_redis = _make_processor()

    event = {
        "user_id":    "user_1",
        "event_type": "click",
        "payload":    {"page": "home"},
        "timestamp":  "2026-01-01T00:00:00",
    }

    with patch.object(processor, "_save_to_db") as mock_save, \
         patch.object(processor, "_update_cache") as mock_cache:
        processor.process(event)

    mock_save.assert_called_once_with(event)
    mock_cache.assert_called_once_with(event)


def test_update_cache_increments_correct_key():
    processor, _, mock_redis = _make_processor()

    processor._update_cache({"event_type": "purchase"})

    mock_redis.incr.assert_called_once_with("event_count:purchase")


def test_run_skips_bad_message_and_continues():
    """A single bad message should not crash the consumer loop."""
    processor, mock_consumer, _ = _make_processor()

    bad_message       = MagicMock()
    bad_message.value  = {"event_type": "click", "user_id": "u1"}
    bad_message.offset = 0

    call_count = 0
    def side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return {"tp1": [bad_message]}
        processor._running = False
        return {}

    mock_consumer.poll.side_effect = side_effect

    with patch.object(processor, "process", side_effect=Exception("db error")):
        processor.run() 

    mock_consumer.close.assert_called_once()

def test_process_continues_if_redis_fails():
    processor, _, mock_redis = _make_processor()

    mock_redis.incr.side_effect = Exception("Redis connection lost")

    event = {
        "user_id":    "user_1",
        "event_type": "click",
        "payload":    {},
        "timestamp":  "2026-01-01T00:00:00",
    }

    with patch.object(processor, "_save_to_db"):
        processor.process(event)