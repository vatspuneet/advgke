#!/bin/bash

echo "=== Team1-Support in app1 (read-only access) ==="
echo -n "Can list pods? (expect: yes) -> "
kubectl auth can-i list pods -n app1 --as=system:serviceaccount:app1:team1-support
echo -n "Can view logs? (expect: yes) -> "
kubectl auth can-i get pods/log -n app1 --as=system:serviceaccount:app1:team1-support
echo -n "Can delete pods? (expect: no) -> "
kubectl auth can-i delete pods -n app1 --as=system:serviceaccount:app1:team1-support

echo ""
echo "=== Team1-Support in app2 (no access - wrong namespace) ==="
echo -n "Can list pods? (expect: no) -> "
kubectl auth can-i list pods -n app2 --as=system:serviceaccount:app1:team1-support

echo ""
echo "=== Team1-Dev in app1 (full edit access) ==="
echo -n "Can list pods? (expect: yes) -> "
kubectl auth can-i list pods -n app1 --as=system:serviceaccount:app1:team1-dev
echo -n "Can create deployments? (expect: yes) -> "
kubectl auth can-i create deployments -n app1 --as=system:serviceaccount:app1:team1-dev
echo -n "Can delete pods? (expect: yes) -> "
kubectl auth can-i delete pods -n app1 --as=system:serviceaccount:app1:team1-dev
echo -n "Can scale deployments? (expect: yes) -> "
kubectl auth can-i patch deployments/scale -n app1 --as=system:serviceaccount:app1:team1-dev

echo ""
echo "=== Team1-Dev in app2 (no access - wrong namespace) ==="
echo -n "Can list pods? (expect: no) -> "
kubectl auth can-i list pods -n app2 --as=system:serviceaccount:app1:team1-dev

echo ""
echo "=== Team2-Support in app2 (read-only access) ==="
echo -n "Can list pods? (expect: yes) -> "
kubectl auth can-i list pods -n app2 --as=system:serviceaccount:app2:team2-support
echo -n "Can delete pods? (expect: no) -> "
kubectl auth can-i delete pods -n app2 --as=system:serviceaccount:app2:team2-support

echo ""
echo "=== Team2-Support in app1 (no access - wrong namespace) ==="
echo -n "Can list pods? (expect: no) -> "
kubectl auth can-i list pods -n app1 --as=system:serviceaccount:app2:team2-support

echo ""
echo "=== Team2-Dev in app2 (full edit access) ==="
echo -n "Can list pods? (expect: yes) -> "
kubectl auth can-i list pods -n app2 --as=system:serviceaccount:app2:team2-dev
echo -n "Can create deployments? (expect: yes) -> "
kubectl auth can-i create deployments -n app2 --as=system:serviceaccount:app2:team2-dev
echo -n "Can scale deployments? (expect: yes) -> "
kubectl auth can-i patch deployments/scale -n app2 --as=system:serviceaccount:app2:team2-dev

echo ""
echo "=== Team2-Dev in app1 (no access - wrong namespace) ==="
echo -n "Can list pods? (expect: no) -> "
kubectl auth can-i list pods -n app1 --as=system:serviceaccount:app2:team2-dev
