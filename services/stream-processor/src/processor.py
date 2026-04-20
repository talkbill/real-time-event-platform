import os, json
from kafka import KafkaConsumer

class StreamProcessor:
    def __init__(self):
        self.consumer = KafkaConsumer(
            os.getenv("KAFKA_TOPIC", "user-events"),
            bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "event-cluster-kafka-bootstrap.kafka:9092"),
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            group_id="stream-processor-group",
            auto_offset_reset="earliest",
        )

    def run(self):
        print("Stream processor running...")
        for message in self.consumer:
            self.process(message.value)

    def process(self, event):
        print(f"Processing event: {event}")
