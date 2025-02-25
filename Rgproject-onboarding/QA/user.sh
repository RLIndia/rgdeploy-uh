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

# Step 5: Identify Extracted File Names
CERTIFICATE_FILE=$(find "$EXTRACT_DIR" -type f -name "*.crt" -o -name "*.pem" | grep -E 'certificate|cert' | head -n 1)
PRIVATE_KEY_FILE=$(find "$EXTRACT_DIR" -type f -name "*.pem" | grep -E 'private|key' | head -n 1)
CERTIFICATE_CHAIN_FILE=$(find "$EXTRACT_DIR" -type f -name "*.pem" | grep -E 'chain' | head -n 1)

# Rename files to expected names if necessary
if [[ -f "$CERTIFICATE_FILE" ]]; then
    mv "$CERTIFICATE_FILE" "$EXTRACT_DIR/certificate.pem"
    CERTIFICATE_FILE="$EXTRACT_DIR/certificate.pem"
fi

if [[ -f "$PRIVATE_KEY_FILE" ]]; then
    mv "$PRIVATE_KEY_FILE" "$EXTRACT_DIR/private_key.pem"
    PRIVATE_KEY_FILE="$EXTRACT_DIR/private_key.pem"
fi

if [[ -f "$CERTIFICATE_CHAIN_FILE" ]]; then
    mv "$CERTIFICATE_CHAIN_FILE" "$EXTRACT_DIR/certificate_chain.pem"
    CERTIFICATE_CHAIN_FILE="$EXTRACT_DIR/certificate_chain.pem"
fi

# Step 6: Verify Extracted Files
if [[ ! -f "$CERTIFICATE_FILE" || ! -f "$PRIVATE_KEY_FILE" || ! -f "$CERTIFICATE_CHAIN_FILE" ]]; then
    echo "Error: One or more certificate files are missing after extraction!"
    ls -l "$EXTRACT_DIR"
    exit 1
fi

echo "Certificate files extracted successfully."

# Step 7: Upload Certificate to AWS ACM
echo "Uploading certificate to AWS ACM..."
ACM_ARN=$(aws acm import-certificate --region "$REGION" \
    --certificate fileb://"$CERTIFICATE_FILE" \
    --private-key fileb://"$PRIVATE_KEY_FILE" \
    --certificate-chain fileb://"$CERTIFICATE_CHAIN_FILE" \
    --query "CertificateArn" --output text)

# Step 8: Verify ACM Upload
if [[ -z "$ACM_ARN" ]]; then
    echo "Error: ACM certificate upload failed!"
    exit 1
else
    echo "ACM certificate uploaded successfully!"
    echo "Certificate ARN: $ACM_ARN"
fi
