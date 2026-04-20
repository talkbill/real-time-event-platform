#!/bin/bash
echo "Port-forwarding api-gateway to localhost:5000"
kubectl port-forward svc/api-gateway 5000:5000 -n real-time-platform &
echo "Port-forwarding websocket-server to localhost:8080"
kubectl port-forward svc/websocket-server 8080:8080 -n real-time-platform &
wait
