#!/bin/bash

. ../env.sh

aws eks update-kubeconfig --name "$cluster_name" --region "$region_code"

echo "Installing INGRESS"

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json 
eksctl utils associate-iam-oidc-provider --cluster "$cluster_name" --approve
sleep 10 
oidc_id=$(aws eks describe-cluster --name "$cluster_name" --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

# if [[ -z $oidc_id ]] || [[ $(echo $oidc_id | tr '[:upper:]' '[:lower:]') == 'none' ]]
# then
# 	sleep 10 ;
# 	echo "Creating OIDC ID..."
# 	eksctl utils associate-iam-oidc-provider --cluster "$cluster_name" --approve
# 	oidc_id=$(aws eks describe-cluster --name "$cluster_name" --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
# 	echo "oidc_id ::::: $oidc_id"
# fi

echo "Creating IAM EKSLB controller ROLE....."

sed -i "s/ap-south-1/$region_code/g" load-balancer-role-trust-policy.json
sed -i "s/oidc_id/$oidc_id/g" load-balancer-role-trust-policy.json


aws iam create-role  --role-name "AmazonEKSLoadBalancerControllerRole-$cluster_name"  --assume-role-policy-document file://"load-balancer-role-trust-policy.json"

echo "Attaching Role policy" 

aws iam attach-role-policy --policy-arn arn:aws:iam::acc-id:policy/AWSLoadBalancerControllerIAMPolicy  --role-name "AmazonEKSLoadBalancerControllerRole-$cluster_name"


echo "Creating ServiceAccount...."

sed -i "s/AmazonEKSLoadBalancerControllerRole/AmazonEKSLoadBalancerControllerRole-$cluster_name/g" aws-load-balancer-controller-service-account.yaml

kubectl apply -f aws-load-balancer-controller-service-account.yaml

sleep 10
echo "Createing/Installing Cert-Manager"

kubectl apply --validate=false  -f cert-manager.yaml

sleep 10

echo "Install Controller"

sed -i.bak -e "s/my-cluster/$cluster_name/g" v2_4_4_full.yaml

kubectl apply -f v2_4_4_full.yaml

sleep 10 

kubectl apply -f v2_4_4_ingclass.yaml

sleep 30;

#kubectl apply -f 2048_full.yaml


#sleep 30 ; 
#

#if [[ -z $(kubectl get ingress -A | grep -i 'amazonaws.com' | awk '{print $1}') ]]
#then
#	echo -e "Ingress Installation error..... \nPlease check the logs and restart the process."
#	exit 1;
#fi
