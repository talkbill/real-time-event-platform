import os, json, time
from kafka import KafkaProducer

class KafkaClient:
    def __init__(self):
        self.producer = KafkaProducer(
            bootstrap_servers=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "event-cluster-kafka-bootstrap.kafka:9092"),
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )
        self.topic = os.getenv("KAFKA_TOPIC", "user-events")

    def run(self):
        print("Event producer running...")
        while True:
            time.sleep(1)
