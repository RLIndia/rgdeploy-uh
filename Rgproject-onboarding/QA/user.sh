#!/bin/bash

# Set Variables
IAM_USER="RG-project1"
POLICY_NAME="AdministratorAccess"
REGION="us-east-1"
ZIP_FILE="acm_certificates.zip"
EXTRACT_DIR="acm_certificates"
CREDENTIALS_FILE="credentials.json"

# Step 1: Create IAM User
echo "Creating IAM user: $IAM_USER..."
aws iam create-user --user-name "$IAM_USER"

# Step 2: Attach AdministratorAccess Policy
aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn "arn:aws:iam::aws:policy/$POLICY_NAME"

# Step 3: Create Access & Secret Keys
ACCESS_KEYS=$(aws iam create-access-key --user-name "$IAM_USER")
echo "$ACCESS_KEYS" | jq . > "$CREDENTIALS_FILE"

echo "IAM user $IAM_USER created successfully with AdministratorAccess."
echo "Access and secret keys are stored in $CREDENTIALS_FILE."

# Step 4: Unzip the ACM Certificate Files
if [[ ! -f "$ZIP_FILE" ]]; then
    echo "Error: ZIP file $ZIP_FILE not found!"
    exit 1
fi

echo "Unzipping $ZIP_FILE..."
mkdir -p "$EXTRACT_DIR"
unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR"

# Define certificate file paths
CERTIFICATE_FILE="$EXTRACT_DIR/certificate.pem"
PRIVATE_KEY_FILE="$EXTRACT_DIR/private_key.pem"
CERTIFICATE_CHAIN_FILE="$EXTRACT_DIR/certificate_chain.pem"

# Step 5: Verify Extracted Files
if [[ ! -f "$CERTIFICATE_FILE" || ! -f "$PRIVATE_KEY_FILE" || ! -f "$CERTIFICATE_CHAIN_FILE" ]]; then
    echo "Error: One or more certificate files are missing after extraction!"
    exit 1
fi

echo "Certificate files extracted successfully."

# Step 6: Upload Certificate to AWS ACM
echo "Uploading certificate to AWS ACM..."
ACM_ARN=$(aws acm import-certificate --region "$REGION" \
    --certificate fileb://"$CERTIFICATE_FILE" \
    --private-key fileb://"$PRIVATE_KEY_FILE" \
    --certificate-chain fileb://"$CERTIFICATE_CHAIN_FILE" \
    --query "CertificateArn" --output text)

# Step 7: Verify ACM Upload
if [[ -z "$ACM_ARN" ]]; then
    echo "Error: ACM certificate upload failed!"
    exit 1
else
    echo "ACM certificate uploaded successfully!"
    echo "Certificate ARN: $ACM_ARN"
fi

