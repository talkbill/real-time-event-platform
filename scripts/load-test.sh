#!/bin/bash
BASE_URL="${1:-http://localhost:5000}"
echo "Running load test against $BASE_URL"
for i in $(seq 1 100); do
  curl -s -X POST "$BASE_URL/api/events" \
    -H "Content-Type: application/json" \
    -d "{"user_id":"user-$i","event_type":"click","payload":{"page":"home"}}" &
done
wait
echo "Load test complete"
