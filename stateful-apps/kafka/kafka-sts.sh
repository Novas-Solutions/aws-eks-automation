#!/bin/bash

helm repo add bitnami https://charts.bitnami.com/bitnami

helm install zookeeper bitnami/zookeeper   --set replicaCount=3   --set auth.enabled=false   --set allowAnonymousLogin=true --set persistence.storageClass=efs-sc
helm install kafka bitnami/kafka   --set zookeeper.enabled=false   --set replicaCount=3   --set externalZookeeper.servers=zookeeper.default.svc.cluster.local --set persistence.storageClass=efs-sc


kubectl expose pod kafka-0 kafka-1 kafka-2 --type=ClusterIP


