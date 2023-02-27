#!/bin/bash

for nodes in $(kubectl get nodes | awk '{print $6}'| grep '^[0-9]' )
do
        echo "$nodes "
done



