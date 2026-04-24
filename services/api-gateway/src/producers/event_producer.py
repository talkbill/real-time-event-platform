import os
import json
from confluent_kafka import Producer, error

class EventProducer:
    def __init__(self):
        self.bootstrap_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'event-cluster-kafka-bootstrap.kafka:9092')
        self.topic    = os.getenv('KAFKA_TOPIC', 'user-events')
        self.producer = None
        self._connect()

    def _connect(self):
        try:
            self.producer = Producer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                acks='all',
                retries=3,
                max_in_flight_requests_per_connection=5,
                compression_type='gzip'
            )
        except error.NoBrokersAvailable:
            print("Warning: Kafka brokers not available yet")
            self.producer = None

    def send_event(self, event):
        if not self.producer:
            self._connect()
        if not self.producer:
            raise Exception("Kafka producer not available")
        return self.producer.send(self.topic, value=event)

    def is_connected(self):
        return self.producer is not None