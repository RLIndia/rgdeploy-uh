#!/bin/bash

set -e  # Exit immediately if any command fails

localhome=$(pwd)

# Automatically detect AWS Region
AWS_REGION="us-east-1"


# User Input for Main and Project Account IDs
read -p "Enter Main AWS Account ID: " MAIN_ACCOUNT_ID
read -p "Enter Project AWS Account ID: " PROJECT_ACCOUNT_ID

# Fetch the VPC ID from the Project Account
VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $AWS_REGION 2>/dev/null)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
    echo "❌ ERROR: No VPC found in region $AWS_REGION. Exiting..."
    exit 1
fi

echo "✅ VPC ID Retrieved: $VPC_ID"

#########################################################################################
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
PRIVATE_SUBNET_IDS=($(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=false" --query "Subnets[*].SubnetId" --output text --region $AWS_REGION))
ENTRYPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=entrypointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
WORKSPACE_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=workspaceSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)
INTERFACE_ENDPOINT_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=interfaceEndpointSG" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION)

cat <<EOF > network.json
{
  "vpc": "$VPC_ID",
  "publicSubnet1": "${PRIVATE_SUBNET_IDS[0]:-N/A}",
  "publicSubnet2": "${PRIVATE_SUBNET_IDS[1]:-N/A}",
  "privateSubnet": "${PRIVATE_SUBNET_IDS[2]:-N/A}",
  "entryPointSG": "$ENTRYPOINT_SG",
  "workspaceSG": "$WORKSPACE_SG",
  "interfaceEndpointSG": "$INTERFACE_ENDPOINT_SG"
}
EOF

echo "✅ Network details saved in network.json"
cat network.json

#########################################################################################
# Create an S3 Bucket for Lambda Deployment
S3_BUCKET="egress-zip-copytest"
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
check_and_create_stack "RG-Egress-Resources" "egressresource.yaml" ""

#########################################################################################
# Deploy Lambda Stack
check_and_create_stack "RG-Lambda-Deployment" "lambda-deployment.yaml" "--parameters ParameterKey=LambdaFunctionName,ParameterValue=egress-zip-copy ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET ParameterKey=S3ObjectKey,ParameterValue=egress-zip-copy.zip"

#########################################################################################
# Deploy SNS Topic Stack
check_and_create_stack "RG-SNS-Topic" "snstopic.yaml" "--parameters ParameterKey=MainAccount,ParameterValue=$MAIN_ACCOUNT_ID ParameterKey=ProjectAccount,ParameterValue=$PROJECT_ACCOUNT_ID"

#########################################################################################
# Deploy Template Version Stack
check_and_create_stack "RG-Template-Version" "launchtemplate.yaml" ""

echo "🎉 RG Project Account resources Deployment completed successfully!"

# Initialize an empty array for stack names
STACK_NAMES=()

# Extract stack names dynamically from the script where stacks are created
while IFS= read -r line; do
    if [[ $line =~ aws\ cloudformation\ (create-stack|deploy).*--stack-name\ ([^[:space:]]+) ]]; then
        STACK_NAMES+=("${BASH_REMATCH[2]}")
    fi
done < "$0"  # Reads the current script itself

# Check if any stack names were found
if [[ ${#STACK_NAMES[@]} -eq 0 ]]; then
    echo "No stack names found in the script."
    exit 1
fi

echo -e "\nStacks found in the script:"
printf "%s\n" "${STACK_NAMES[@]}"

# Initialize JSON output file
OUTPUT_FILE="output.json"
echo "[]" > "$OUTPUT_FILE"

# Loop through each stack name and fetch outputs
for STACK_NAME in "${STACK_NAMES[@]}"; do
    echo -e "\nFetching CloudFormation Stack Outputs for stack: $STACK_NAME"

    # Get stack outputs in JSON format
    STACK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output json 2>/dev/null)

    # Check if AWS CLI command was successful
    if [[ $? -ne 0 ]]; then
        echo "Error fetching outputs for stack: $STACK_NAME. Skipping..."
        continue
    fi

    # Check if there are outputs
    if [[ -z "$STACK_OUTPUTS" || "$STACK_OUTPUTS" == "[]" ]]; then
        echo "No outputs found for stack: $STACK_NAME."
    else
        echo -e "\nCloudFormation Stack Outputs for $STACK_NAME:"
        echo "--------------------------------------------------"
        echo -e "OutputKey		OutputValue"
        echo "--------------------------------------------------"
        
        echo "$STACK_OUTPUTS" | jq -r '.[] | "\(.OutputKey)		\(.OutputValue)"'

        # Append outputs to JSON file
        jq --argjson new "$STACK_OUTPUTS" '. + $new' "$OUTPUT_FILE" > tmp.json && mv tmp.json "$OUTPUT_FILE"
    fi
done

echo -e "\nCloudFormation outputs have been saved to $OUTPUT_FILE"

