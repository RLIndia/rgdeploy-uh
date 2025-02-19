#!/bin/bash

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it before running the script."
    exit 1
fi

# Prompt user for VPC ID
read -p "Enter the VPC ID: " VPCid

# Validate input
if [[ -z "$VPCid" ]]; then
    echo "VPC ID cannot be empty. Exiting."
    exit 1
fi

# Route 53 VPC Association Authorization
echo "Running Route 53 VPC association authorization..."
AUTH_OUTPUT=$(aws route53 create-vpc-association-authorization --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=$VPCid --region us-east-1 2>&1)

if [[ $? -eq 0 ]]; then
    echo "Route 53 VPC association authorization successful."
else
    echo "Error executing Route 53 command: $AUTH_OUTPUT"
    exit 1
fi

# IAM User Creation
IAM_USER="RGuser"
echo "Creating IAM user: $IAM_USER..."

USER_CREATION=$(aws iam create-user --user-name $IAM_USER 2>&1)
if [[ $? -ne 0 ]]; then
    echo "Error creating IAM user: $USER_CREATION"
    exit 1
fi

# Attach Admin Policy
aws iam attach-user-policy --user-name $IAM_USER --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
if [[ $? -ne 0 ]]; then
    echo "Failed to attach Admin policy to user $IAM_USER"
    exit 1
fi

# Create IAM Access Key
ACCESS_KEYS=$(aws iam create-access-key --user-name $IAM_USER 2>&1)
if [[ $? -ne 0 ]]; then
    echo "Error generating access key: $ACCESS_KEYS"
    exit 1
fi

# Extract Access Key and Secret Key
AWS_ACCESS_KEY_ID=$(echo "$ACCESS_KEYS" | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$ACCESS_KEYS" | jq -r '.AccessKey.SecretAccessKey')

# Ensure jq is installed
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "Error extracting IAM credentials. Ensure 'jq' is installed."
    exit 1
fi

# Store credentials securely
SECURITY_FILE="./security_credentials.txt"
echo "Saving IAM credentials to $SECURITY_FILE..."
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" > $SECURITY_FILE
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> $SECURITY_FILE
chmod 600 $SECURITY_FILE  # Secure the file

echo "Script execution completed successfully."
echo "IAM credentials stored securely in: $SECURITY_FILE"

