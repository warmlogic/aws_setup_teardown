#!/bin/bash

# This script should be invoked via setup_ec2_instance.sh; that script
# will export the right environment variables for this to succeed.

# uncomment for debugging
# set -x

if [ -z "$AWS_PROFILE" ] && [ -z "$AWS_DEFAULT_PROFILE" ]; then
    echo "Missing \$AWS_PROFILE or \$AWS_DEFAULT_PROFILE; export before"
    echo "running this script!"
    exit 1
fi

if [ -z "$ami" ]; then
    echo "Missing \$ami; this script should be called from"
    echo "setup_ec2_instance.sh!"
    exit 1
fi

if [ -z "$volumeSize" ]; then
    echo "Missing \$volumeSize; this script should be called from"
    echo "setup_ec2_instance.sh!"
    exit 1
fi

if [ -z "$instanceName" ]; then
    echo "Missing \$instanceName; this script should be called from"
    echo "setup_ec2_instance.sh!"
    exit 1
fi

if [ -z "$instanceType" ]; then
    echo "Missing \$instanceType; this script should be called from"
    echo "setup_ec2_instance.sh!"
    exit 1
fi

# settings
export cidr="0.0.0.0/0"
export volumeType="gp2"

hash aws 2>/dev/null
if [ $? -ne 0 ]; then
    echo >&2 "'aws' command line tool required, but not installed. Aborting."
    exit 1
fi

if [ -z "$(aws configure get aws_access_key_id)" ]; then
    echo "AWS credentials not configured. Aborting"
    exit 1
fi

export vpcId=$(aws ec2 create-vpc --cidr-block 10.0.0.0/28 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $vpcId --tags --tags Key=Name,Value=$instanceName
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\"Value\":true}"

export internetGatewayId=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $internetGatewayId --tags --tags Key=Name,Value=$instanceName-gateway
aws ec2 attach-internet-gateway --internet-gateway-id $internetGatewayId --vpc-id $vpcId

export subnetId=$(aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.0.0/28 --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $subnetId --tags --tags Key=Name,Value=$instanceName-subnet

export routeTableId=$(aws ec2 create-route-table --vpc-id $vpcId --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $routeTableId --tags --tags Key=Name,Value=$instanceName-route-table
export routeTableAssoc=$(aws ec2 associate-route-table --route-table-id $routeTableId --subnet-id $subnetId --output text)
aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId

export securityGroupId=$(aws ec2 create-security-group --group-name $instanceName-security-group --description "SG for $instanceName $instanceType machine" --vpc-id $vpcId --query 'GroupId' --output text)
# ssh
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr $cidr
# jupyter notebook
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8888-8898 --cidr $cidr

if [ ! -d ~/.ssh ]; then
	mkdir ~/.ssh
fi

if [ ! -f ~/.ssh/aws-key-$instanceName.pem ]; then
	aws ec2 create-key-pair --key-name aws-key-$instanceName --query 'KeyMaterial' --output text > ~/.ssh/aws-key-$instanceName.pem
	chmod 400 ~/.ssh/aws-key-$instanceName.pem
fi

export instanceId=$(aws ec2 run-instances --image-id $ami --count 1 --instance-type $instanceType --key-name aws-key-$instanceName --security-group-ids $securityGroupId --subnet-id $subnetId --associate-public-ip-address --block-device-mapping "[ { \"DeviceName\": \"/dev/sda1\", \"Ebs\": { \"VolumeSize\": $volumeSize, \"VolumeType\": \"$volumeType\" } } ]" --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $instanceId --tags --tags Key=Name,Value=$instanceName
export allocAddr=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

if [ -z "$allocAddr" ]; then
    echo "No address allocated. Check AWS EC2 console to ensure you have not"
    echo "reached your Elastic IP address limit. Continuing setup..."
fi

echo "Waiting for instance start..."
aws ec2 wait instance-running --instance-ids $instanceId
sleep 10 # wait for ssh service to start running too
export assocId=$(aws ec2 associate-address --instance-id $instanceId --allocation-id $allocAddr --query 'AssociationId' --output text)
export instanceUrl=$(aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicDnsName' --output text)
export instanceIp=$(aws ec2 describe-instances --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
#export ebsVolume=$(aws ec2 describe-instance-attribute --instance-id $instanceId --attribute  blockDeviceMapping  --query BlockDeviceMappings[0].Ebs.VolumeId --output text)

# reboot instance, because I was getting "Failed to initialize NVML: Driver/library version mismatch"
# error when running the nvidia-smi command
# see also http://forums.fast.ai/t/no-cuda-capable-device-is-detected/168/13
aws ec2 reboot-instances --instance-ids $instanceId

# save commands to file
echo '# Connect to your instance:' > $instanceName-commands.txt # overwrite existing file
echo 'ssh -i $HOME/.ssh/aws-key-'$instanceName'.pem ubuntu@'$instanceUrl >> $instanceName-commands.txt
echo '# Stop your instance:' : >> $instanceName-commands.txt
echo 'aws ec2 stop-instances --instance-ids' $instanceId  >> $instanceName-commands.txt
echo '# Start your instance:' >> $instanceName-commands.txt
echo 'aws ec2 start-instances --instance-ids' $instanceId  >> $instanceName-commands.txt
echo '# Reboot your instance:' >> $instanceName-commands.txt
echo 'aws ec2 reboot-instances --instance-ids' $instanceId  >> $instanceName-commands.txt
echo ""
# export vars for future usage
if [ -n "$AWS_PROFILE" ]; then
    echo 'export AWS_PROFILE='$AWS_PROFILE';' > $instanceName-export.sh # overwrite existing file
elif [ -n "$AWS_DEFAULT_PROFILE" ]; then
    echo 'export AWS_DEFAULT_PROFILE='$AWS_DEFAULT_PROFILE';' > $instanceName-export.sh # overwrite existing file
fi
echo 'export instanceId='$instanceId';' >> $instanceName-export.sh
echo 'export subnetId='$subnetId';' >> $instanceName-export.sh
echo 'export securityGroupId='$securityGroupId';' >> $instanceName-export.sh
echo 'export instanceUrl='$instanceUrl';' >> $instanceName-export.sh
echo 'export instanceIp='$instanceIp';' >> $instanceName-export.sh
echo 'export routeTableId='$routeTableId';' >> $instanceName-export.sh
echo 'export instanceName='$instanceName';' >> $instanceName-export.sh
echo 'export vpcId='$vpcId';' >> $instanceName-export.sh
echo 'export internetGatewayId='$internetGatewayId';' >> $instanceName-export.sh
echo 'export subnetId='$subnetId';' >> $instanceName-export.sh
echo 'export allocAddr='$allocAddr';' >> $instanceName-export.sh
echo 'export assocId='$assocId';' >> $instanceName-export.sh
echo 'export routeTableAssoc='$routeTableAssoc';' >> $instanceName-export.sh

chmod +x $instanceName-export.sh

# save delete commands for cleanup
echo '#!/bin/bash' > $instanceName-remove.sh # overwrite existing file
echo 'read -r -p "Removing instance! Are you sure? [y/N] " response' >> $instanceName-remove.sh
echo $'response=$(echo "$response" | tr '[:upper:]' '[:lower:]')' >> $instanceName-remove.sh
echo 'if [[ "$response" =~ ^(yes|y)$ ]]; then' >> $instanceName-remove.sh
echo '    aws ec2 disassociate-address --association-id' $assocId >> $instanceName-remove.sh
echo '    aws ec2 release-address --allocation-id' $allocAddr >> $instanceName-remove.sh

# volume gets deleted with the instance automatically
echo '    aws ec2 terminate-instances --instance-ids' $instanceId >> $instanceName-remove.sh
echo '    aws ec2 wait instance-terminated --instance-ids' $instanceId >> $instanceName-remove.sh
echo '    aws ec2 delete-security-group --group-id' $securityGroupId >> $instanceName-remove.sh

echo '    aws ec2 disassociate-route-table --association-id' $routeTableAssoc >> $instanceName-remove.sh
echo '    aws ec2 delete-route-table --route-table-id' $routeTableId >> $instanceName-remove.sh

echo '    aws ec2 detach-internet-gateway --internet-gateway-id' $internetGatewayId '--vpc-id' $vpcId >> $instanceName-remove.sh
echo '    aws ec2 delete-internet-gateway --internet-gateway-id' $internetGatewayId >> $instanceName-remove.sh
echo '    aws ec2 delete-subnet --subnet-id' $subnetId >> $instanceName-remove.sh

echo '    aws ec2 delete-vpc --vpc-id' $vpcId >> $instanceName-remove.sh
echo '    echo If you want to delete the key-pair, please do it manually.' >> $instanceName-remove.sh
echo '    echo Remember to ensure the Elastic IP address was released, by checking the AWS EC2 dashboard.' >> $instanceName-remove.sh
echo 'else' >> $instanceName-remove.sh
echo '    echo "Removal cancelled."' >> $instanceName-remove.sh
echo 'fi' >> $instanceName-remove.sh

chmod +x $instanceName-remove.sh

echo 'All done. Find all you need to connect in' $instanceName'-commands.txt,' $instanceName'-export.sh, and aws-alias.sh (source the latter 2 to set environment variables and aliases)'
echo 'To remove the stack call' $instanceName'-remove.sh'
echo 'Connect to your instance: ssh -i $HOME/.ssh/aws-key-'$instanceName'.pem ubuntu@'$instanceUrl
