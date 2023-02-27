#!/bin/bash
. ../env.sh

aws eks update-kubeconfig --name "$cluster_name" --region "$region_code"

echo -e "Installation EFS Storage Class....\n Creating CSI-DRIVER policy...."

aws iam create-policy --policy-name AmazonEKS_EFS_CSI_Driver_Policy  --policy-document file://iam-policy-example.json

oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

if [[ $(echo $oidc_id | tr '[:upper:]' '[:lower:]') == 'none' ]]
then
	echo "OIDC ID not found please start with ingress installation...."
	exit 1;
fi	

sed -i "s/oidc_id/$oidc_id/g" trust-policy.json
sed -i "s/ap-south-1/$region_code/g"  trust-policy.json

sleep 10 
echo "Creating CSI_DRIVER Role."
aws iam create-role --role-name "AmazonEKS_EFS_CSI_DriverRole-$cluster_name"  --assume-role-policy-document file://"trust-policy.json"


echo "Attching role policy"

sleep 10 
aws iam attach-role-policy  --policy-arn arn:aws:iam::832700671038:policy/AmazonEKS_EFS_CSI_Driver_Policy --role-name "AmazonEKS_EFS_CSI_DriverRole-$cluster_name"


sed -i "s/AmazonEKS_EFS_CSI_DriverRole/AmazonEKS_EFS_CSI_DriverRole-$cluster_name/g" efs-service-account.yaml

echo "Creating EFS Service Account."
kubectl apply -f efs-service-account.yaml
sleep 10 
echo "Installing ECR Driver"

kubectl apply -f public-ecr-driver.yaml

sleep 10 
echo "Creating EFS in $region_code"

vpc_id=$(aws eks describe-cluster  --name $cluster_name  --query "cluster.resourcesVpcConfig.vpcId"  --output text)

cidr_range=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query "Vpcs[].CidrBlock"  --output text  --region $region_code)


security_group_id=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$vpc_id Name=group-name,Values="EfsSecurityGroup-$cluster_name" --query 'SecurityGroups[*].[GroupId]' --output text )
if [[ -z $security_group_id ]]
then
	echo "EFS-SG isn't available....Createing SG"
	security_group_id=$(aws ec2 create-security-group --group-name "EfsSecurityGroup-$cluster_name"  --description "EFS security group"  --vpc-id $vpc_id  --output text)

fi

aws ec2 authorize-security-group-ingress --group-id $security_group_id  --protocol tcp --port 2049 --cidr $cidr_range
# if [[ ! -z "security_group_id" ]]
# then

# fi

sleep 10


#file_system_id=$(aws efs describe-file-systems --query 'FileSystemId' --output text)
file_system_id=$(aws efs describe-file-systems --query 'FileSystems[?Name != '\"sc-efs\"'].FileSystemId' --output text)

if [[ -z $file_system_id ]]
then 
	echo "EFS Not found.... Creating EFS"
	file_system_id=$(aws efs create-file-system --region $region_code --performance-mode generalPurpose --tags "Key=Name, Value=sc-efs" --query 'FileSystemId' --output text)

fi

for nodes in $(kubectl get nodes -o wide | awk '{print $6}' | grep '^[0-9]')
do
	echo "nodes ip :: $nodes"
	subnet_r1=$(echo $nodes | awk -F'.' '{print $3}')
	subnet_id=$(aws ec2 describe-subnets     --filters "Name=vpc-id,Values=$vpc_id"     --query 'Subnets[*].{SubnetId: SubnetId,AvailabilityZone: AvailabilityZone,CidrBlock: CidrBlock}' --output text  | grep -i "10.0.$subnet_r1.0" | awk '{print $NF}')
	sleep 10 
	aws efs create-mount-target  --file-system-id $file_system_id  --subnet-id "$subnet_id"  --security-groups $security_group_id
done


echo "Creating Dynamic Storage Class"

#efs_id=$(aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text )

sed -i "s/fs-abcd/$file_system_id/g" storageclass.yaml

sleep 10

kubectl apply -f storageclass.yaml

kubectl apply -f pod.yaml


kubectl get pvc


kubectl get pv

