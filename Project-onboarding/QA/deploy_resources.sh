#!/bin/bash

# Ensure that two arguments (MainAccountID and ProjectAccountID) are passed
if [[ $# -ne 2 ]]; then
    echo "❌ Usage: $0 <Main AWS Account ID> <Project AWS Account ID>"
    exit 1
fi

# Assign input arguments to variables
MAIN_ACCOUNT_ID=$1
PROJECT_ACCOUNT_ID=$2

# Set AWS Region (Modify if needed)
AWS_REGION="us-east-1"

# User Input for Main and Project Account IDs
read -p "Enter Main AWS Account ID: " MAIN_ACCOUNT_ID
read -p "Enter Project AWS Account ID: " PROJECT_ACCOUNT_ID

# Fetch the VPC ID from The Project Account
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $AWS_REGION)

# Check if VPC ID was retrieved
if [[ -z "$VPC_ID" ]]; then
    echo "❌ Error: No VPC found in region $AWS_REGION. Exiting..."
    exit 1
fi

echo "✅ VPC ID Retrieved: $VPC_ID"

#########################################################################################
# Deploy the Network Security Group CloudFormation Stack

STACK_NAME="RG-Network-SecurityGroup"

echo "🚀 Deploying CloudFormation stack: $STACK_NAME..."
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://$HOME/Project-onboarding/QA/networksg.yaml \
    --parameters ParameterKey=VpcId,ParameterValue=$VPC_ID \
                 ParameterKey=MainAccount,ParameterValue=$MAIN_ACCOUNT_ID \
                 ParameterKey=ProjectAccount,ParameterValue=$PROJECT_ACCOUNT_ID \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION

# Wait for stack to complete
echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region $AWS_REGION

if [[ $? -ne 0 ]]; then
    echo "❌ Error: CloudFormation stack creation failed!"
    exit 1
fi

echo "✅ CloudFormation stack $STACK_NAME created successfully!"

#########################################################################################
# Get the Network details of project account and save them as a JSON file

# Fetch Private Subnets (First three private subnets)
PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" \
    --query "Subnets[*].SubnetId" --output text --region $AWS_REGION))

# Retrieve Security Group IDs based on Security Group Names
ENTRYPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=entrypointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
WORKSPACE_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=workspaceSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
INTERFACE_ENDPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=interfaceEndpointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

# Assign subnet values (ensure at least three subnets exist)
PUBLIC_SUBNET1="${PRIVATE_SUBNET_IDS[0]:-N/A}"
PUBLIC_SUBNET2="${PRIVATE_SUBNET_IDS[1]:-N/A}"
PRIVATE_SUBNET="${PRIVATE_SUBNET_IDS[2]:-N/A}"

# Create a JSON file with the extracted values
cat <<EOF > network.json
{
  "vpc": "$VPC_ID",
  "publicSubnet1": "$PUBLIC_SUBNET1",
  "publicSubnet2": "$PUBLIC_SUBNET2",
  "privateSubnet": "$PRIVATE_SUBNET",
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

echo "Creating S3 bucket: $S3_BUCKET..."
aws s3 mb s3://$S3_BUCKET --region $AWS_REGION

if [[ $? -ne 0 ]]; then
    echo "❌ Error: Failed to create S3 bucket!"
    exit 1
fi

echo "✅ S3 bucket $S3_BUCKET created successfully!"

# Upload ZIP file to S3 (Modify ZIP file name as required)
ZIP_FILE="/$home//SRE/Egress/egress-zip-copy.zip"

if [[ -f "$ZIP_FILE" ]]; then
    echo "🚀 Uploading ZIP file to S3..."
    aws s3 cp "$ZIP_FILE" s3://$S3_BUCKET/
    echo "✅ ZIP file uploaded successfully!"
else
    echo "❌ Error: ZIP file not found at $ZIP_FILE!"
    exit 1
fi

#########################################################################################
# Deploy the Egress Resources CloudFormation Stack (No Input Required)

EGRESS_STACK_NAME="RG-Egress-Resources"

echo "🚀 Deploying CloudFormation stack: $EGRESS_STACK_NAME..."
aws cloudformation create-stack \
    --stack-name "$EGRESS_STACK_NAME" \
    --template-body file://$HOME/Project-onboarding/PROD/egressresource.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION

# Wait for stack to complete
echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$EGRESS_STACK_NAME" --region $AWS_REGION

echo "✅ CloudFormation stack $EGRESS_STACK_NAME created successfully!"

# Fetch Egress Stack Outputs
EGRESS_RESOURCES=$(aws cloudformation describe-stacks \
    --stack-name "$EGRESS_STACK_NAME" \
    --query "Stacks[0].Outputs" \
    --output json \
    --region $AWS_REGION)

# Save Output to JSON File
echo $EGRESS_RESOURCES | jq '.' > egress-resources.json

echo "✅ Egress resources details saved in egress-resources.json"
cat egress-resources.json

#########################################################################################
# Deploy the Lambda CloudFormation Stack

LAMBDA_STACK_NAME="RG-Lambda-Deployment"

echo "🚀 Deploying CloudFormation stack: $LAMBDA_STACK_NAME..."
aws cloudformation create-stack \
    --stack-name "$LAMBDA_STACK_NAME" \
    --template-body file://$HOME/Project-onboarding/PROD/lambda-deployment.yaml \
    --parameters ParameterKey=LambdaFunctionName,ParameterValue=egress-zip-copy \
                 ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET \
                 ParameterKey=S3ObjectKey,ParameterValue=egress-zip-copy.zip \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION

# Wait for stack to complete
echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$LAMBDA_STACK_NAME" --region $AWS_REGION

echo "✅ CloudFormation stack $LAMBDA_STACK_NAME created successfully!"

# Fetch Lambda Stack Outputs and Add to egress-resources.json
LAMBDA_RESOURCES=$(aws cloudformation describe-stacks \
    --stack-name "$LAMBDA_STACK_NAME" \
    --query "Stacks[0].Outputs" \
    --output json \
    --region $AWS_REGION)

jq -s '.[0] + .[1]' egress-resources.json <(echo "$LAMBDA_RESOURCES") > temp.json && mv temp.json egress-resources.json

echo "✅ Updated egress-resources.json with Lambda stack outputs!"
cat egress-resources.json

#########################################################################################

# Deploy the SNS Topic CloudFormation Stack

SNS_STACK_NAME="RG-SNS-Topic"

echo "🚀 Deploying CloudFormation stack: $SNS_STACK_NAME..."
aws cloudformation create-stack \
    --stack-name "$SNS_STACK_NAME" \
    --template-body file://$HOME/Project-onboarding/PROD/sns-topic.yaml \
    --parameters ParameterKey=MainAccount,ParameterValue=$MAIN_ACCOUNT_ID \
                 ParameterKey=ProjectAccount,ParameterValue=$PROJECT_ACCOUNT_ID \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION

# Wait for stack to complete
echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$SNS_STACK_NAME" --region $AWS_REGION

echo "✅ CloudFormation stack $SNS_STACK_NAME created successfully!"
