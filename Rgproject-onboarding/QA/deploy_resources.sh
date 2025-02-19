#!/bin/bash

set -e  # Exit immediately if any command fails
start_time=$(date +%s)

localhome=$(pwd)

# Automatically detect AWS Region
AWS_REGION="us-east-1"

# Fixed Main AWS Account ID
MAIN_ACCOUNT_ID="533266995550"

# Get Project AWS Account ID dynamically
PROJECT_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "✅ Using Main Account ID: $MAIN_ACCOUNT_ID"
echo "✅ Using Project Account ID: $PROJECT_ACCOUNT_ID"

# Fetch the VPC ID from the Project Account
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $AWS_REGION 2>/dev/null)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
    echo "❌ ERROR: No VPC found in region $AWS_REGION. Exiting..."
    exit 1
fi

echo "✅ VPC ID Retrieved: $VPC_ID"

#########################################################################################

#########################################################################################
# Function to select three private subnets from different Availability Zones
select_private_subnets() {
    declare -A SELECTED_SUBNETS
    local SUBNETS_INFO
    SUBNETS_INFO=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" --query "Subnets[*].[SubnetId, AvailabilityZone]" --output text --region $AWS_REGION)

    if [[ -z "$SUBNETS_INFO" ]]; then
        echo "❌ ERROR: No private subnets found in the VPC. Exiting..."
        exit 1
    fi

    while read -r SUBNET_ID AZ; do
        if [[ -z "${SELECTED_SUBNETS[$AZ]}" ]]; then
            SELECTED_SUBNETS[$AZ]="$SUBNET_ID"
        fi
        if [[ ${#SELECTED_SUBNETS[@]} -ge 3 ]]; then
            break  # Stop once we have three distinct AZs
        fi
    done <<< "$SUBNETS_INFO"

    echo "${SELECTED_SUBNETS[@]}"
}

# Select three private subnets from different AZs
PRIVATE_SUBNETS=($(select_private_subnets))

# Validate we have enough subnets
if [[ ${#PRIVATE_SUBNETS[@]} -lt 3 ]]; then
    echo "❌ ERROR: Less than three private subnets found. Need at least three distinct AZs."
    exit 1
fi

PRIVATE_SUBNET1="${PRIVATE_SUBNETS[0]}"
PRIVATE_SUBNET2="${PRIVATE_SUBNETS[1]}"
PRIVATE_SUBNET3="${PRIVATE_SUBNETS[2]}"


# Function to check stack status and skip already completed stacks
check_and_create_stack() {
    local STACK_NAME=$1
    local TEMPLATE_FILE=$2
    local PARAMETERS=$3

    echo "🔍 Checking if stack $STACK_NAME already exists..."
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].StackStatus" --output text --region $AWS_REGION 2>/dev/null || echo "NOT_EXIST")

    if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
        echo "✅ Stack $STACK_NAME already exists. Skipping..."
        return 0
    fi

    echo "🚀 Deploying CloudFormation stack: $STACK_NAME..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://$localhome/$TEMPLATE_FILE \
        $PARAMETERS \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION

    echo "⏳ Waiting for stack creation to complete..."
    if ! aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region $AWS_REGION; then
        echo "❌ ERROR: Stack $STACK_NAME creation failed. Check CloudFormation logs."
        exit 1
    fi

    echo "✅ CloudFormation stack $STACK_NAME created successfully!"
}

#########################################################################################
# Deploy the Network Security Group Stack
check_and_create_stack "RG-Network-SecurityGroup" "networksg.yaml" "--parameters ParameterKey=VpcId,ParameterValue=$VPC_ID"

#########################################################################################
# Fetch Network Details and Save as JSON
#PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION))
ENTRYPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=entrypointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
WORKSPACE_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=workspaceSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
INTERFACE_ENDPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=interfaceEndpointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

cat <<EOF > network.json
{
  "vpc": "$VPC_ID",
  "publicSubnet1": "$PRIVATE_SUBNET1",
  "publicSubnet2": "$PRIVATE_SUBNET2",
  "privateSubnet": "$PRIVATE_SUBNET3",
  "entryPointSG": "$ENTRYPOINT_SG",
  "workspaceSG": "$WORKSPACE_SG",
  "interfaceEndpointSG": "$INTERFACE_ENDPOINT_SG"
}
EOF

echo "✅ Network details saved in network.json"
cat network.json

#########################################################################################
# Create an S3 Bucket for Lambda Deployment
S3_BUCKET="egress-zip-copy"
echo "🔍 Checking if S3 bucket $S3_BUCKET exists..."
if aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1; then
    echo "✅ S3 bucket $S3_BUCKET already exists. Skipping creation..."
else
    echo "🚀 Creating S3 bucket: $S3_BUCKET..."
    aws s3 mb s3://$S3_BUCKET --region $AWS_REGION || { echo "❌ ERROR: Failed to create S3 bucket!"; exit 1; }
fi

# Upload ZIP file to S3
ZIP_FILE="$localhome/egress-zip-copy.zip"
if [[ -f "$ZIP_FILE" ]]; then
    echo "🚀 Uploading ZIP file to S3..."
    aws s3 cp "$ZIP_FILE" s3://$S3_BUCKET/ || { echo "❌ ERROR: Failed to upload ZIP file!"; exit 1; }
    echo "✅ ZIP file uploaded successfully!"
else
    echo "❌ ERROR: ZIP file not found at $ZIP_FILE!"
    exit 1
fi

#########################################################################################
# Deploy Egress Resources Stack
check_and_create_stack "RG-Egress-Resources" "egressresources.yml" "--parameters ParameterKey=RGDomain,ParameterValue=QA"
#########################################################################################
# Deploy Lambda Stack
check_and_create_stack "RG-Lambda-Deployment" "lambda-deployment.yaml" "--parameters ParameterKey=LambdaFunctionName,ParameterValue=egress-zip-copy ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET ParameterKey=S3ObjectKey,ParameterValue=egress-zip-copy.zip"

#########################################################################################
# Fetch Outputs of Egress Resources and Lambda Deployment Stacks
EGRESS_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "RG-Egress-Resources" --query "Stacks[0].Outputs" --output json --region $AWS_REGION)
LAMBDA_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "RG-Lambda-Deployment" --query "Stacks[0].Outputs" --output json --region $AWS_REGION)

# Store details in egress.json
cat <<EOF > egress.json
{
  "EgressResourcesOutputs": $EGRESS_OUTPUTS,
  "LambdaDeploymentOutputs": $LAMBDA_OUTPUTS
}
EOF

echo "✅ Egress details saved in egress.json"
cat egress.json

#########################################################################################
# Deploy SNS Topic Stack
check_and_create_stack "RG-SNS-Topic" "snstopic.yaml" "--parameters ParameterKey=MainAccount,ParameterValue=$MAIN_ACCOUNT_ID ParameterKey=ProjectAccount,ParameterValue=$PROJECT_ACCOUNT_ID"

#########################################################################################
# Deploy Template Version Stack
check_and_create_stack "RG-Template-Version" "launchtemplate.yaml" ""

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "🎉 RG Project Account resources Creation completed successfully!"
echo "⏳ Total Execution Time: $execution_time seconds"
