#!/bin/bash

echo "=== Network Policy Tests ==="

echo ""
echo "[Test 1] Frontend -> Backend API (SHOULD SUCCEED)"
kubectl run test1 --rm -it --restart=Never -n frontend --image=curlimages/curl -- curl -s --max-time 5 http://api.backend.svc.cluster.local || echo "BLOCKED"

echo ""
echo "[Test 2] Frontend -> Restricted DB (SHOULD FAIL)"
kubectl run test2 --rm -it --restart=Never -n frontend --image=curlimages/curl -- curl -s --max-time 5 http://db.restricted.svc.cluster.local || echo "BLOCKED"

echo ""
echo "[Test 3] Backend -> Restricted DB (SHOULD SUCCEED)"
kubectl run test3 --rm -it --restart=Never -n backend --image=curlimages/curl -- curl -s --max-time 5 http://db.restricted.svc.cluster.local || echo "BLOCKED"

echo ""
echo "[Test 4] Restricted -> Backend API (SHOULD FAIL)"
kubectl run test4 --rm -it --restart=Never -n restricted --image=curlimages/curl -- curl -s --max-time 5 http://api.backend.svc.cluster.local || echo "BLOCKED"

echo ""
echo "=== Tests Complete ==="
