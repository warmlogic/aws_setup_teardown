#!/bin/bash

# Configure an AWS EC2 instance

# example usage: ./setup_ec2_instance.sh t2.micro my-instance-name [128] [ami-name]

# volume size (GB) is an optional third argument (default 128)
# AMI name is an optional fourth argument (default latest Ubuntu Cloud image owned by Canonical)

if [ -z "$AWS_PROFILE" ] && [ -z "$AWS_DEFAULT_PROFILE" ]; then
    echo "Missing \$AWS_PROFILE or \$AWS_DEFAULT_PROFILE; export before"
    echo "running this script!"
    exit 1
fi

export instanceType="$1"
export instanceName="$2"

if [ "$#" -eq 4 ]; then
    # for a custom AMI: AWS console > Choose correct region > EC2 > Launch Instance > Community AMIs
    # e.g., fastai-part1v2-p2 US West (Oregon): ami-8c4288f4
    export ami="$4"
    echo "Using custom AMI: $ami"
    export volumeSize=$3
elif [ "$#" -eq 3 ]; then
    # get the ami string for latest Ubuntu Cloud image owned by Canonical
    # https://gist.github.com/vancluever/7676b4dafa97826ef0e9
    export ami=`aws ec2 describe-images \
        --owners 099720109477 \
        --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-* \
        --query 'reverse(sort_by(Images, &CreationDate))[0].ImageId'`
    echo "Using Ubuntu AMI: $ami"
    export volumeSize=$3
elif [ "$#" -eq 2 ]; then
    # get the ami string for latest Ubuntu Cloud image owned by Canonical
    # https://gist.github.com/vancluever/7676b4dafa97826ef0e9
    export ami=`aws ec2 describe-images \
        --owners 099720109477 \
        --filters Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-* \
        --query 'reverse(sort_by(Images, &CreationDate))[0].ImageId'`
    echo "Using Ubuntu AMI: $ami"
    export volumeSize=128
else
    echo "Arguments not supplied correctly. Exiting."
    exit 1
fi

if [ -n "$AWS_PROFILE" ]; then
    echo "Using AWS profile: $AWS_PROFILE"
elif [ -n "$AWS_DEFAULT_PROFILE" ]; then
    echo "Using AWS profile: $AWS_DEFAULT_PROFILE"
fi

echo "    Instance type: $instanceType"
echo "    Name: $instanceName"
echo "    Local volume size (GB): $volumeSize"
echo "    AMI: $ami"

read -r -p "Provisioning instance! Are you sure? [y/N] " response
response=$(echo "$response" | tr [:upper:] [:lower:])
if [[ "$response" =~ ^(yes|y)$ ]]; then
    . $(dirname "$0")/setup_instance.sh
else
    echo "Provisioning cancelled."
fi
