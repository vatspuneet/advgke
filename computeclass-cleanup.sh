#!/bin/bash
set -e

CLUSTER_NAME="cc-cluster"
ZONE="us-central1-a"

gcloud container clusters delete $CLUSTER_NAME --zone $ZONE --quiet



#gcloud container clusters update cc-cluster \
#  --zone us-central1-a \
#  --autoscaling-profile optimize-utilization


# Flow is as follows : create cluster, create compute class, deploy normal pod, deploy pod with special hardware need, wait till cluster get new node. then delete deployment with special hardware requiremment, issue optimize cluster command - it should remove special need node from cluster. 
