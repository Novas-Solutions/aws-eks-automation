#!/bin/bash

. ./env.sh
echo "Creating DB dump."

mongodump 

echo "Removing EKS cluster, LB, DB, EFS"

