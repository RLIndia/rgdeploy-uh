# RG Project Account Onboarding on QA

## Introduction

Welcome to the RLCatalyst Research Gateway Project Account onboarding. This guide provides documentation for onboarding a new project account on the Research Gateway product.

| Step No. | Step                                      | Account         |  Method   |
|----------|-------------------------------------------|-----------------|-----------|
| 1 a.     | Associate VPC with Hosted Zone            | Orchestration   |  Manual   |
| 1 b.     | Associate VPC Transit Gateway with N/W A/c| Network         |  Manual   |
| 2        | KMS Policy Update                         | Orchestration   |  Manual   |
| 3        | Template Bucket Policy Update             | Orchestration   |  Manual   |
| 4        | Run Deploy Resources Script               | Project         |  Automated|




## Step-1. VPC Association

### Pre-requisites:

A. VPC ID of the Newly Created Project Account

### A. Associate VPC with Hosted Zone

Run the following command with replace of VPC ID on the RG Deployed Account from the Cloud Shell service:

**Note:** RG Orchestration Accounts on UHealth AWS Accounts:
   - QA: `UHIT-HIPAA-NonProd-SRE-QA`

1. Create VPC association authorization:
   ```sh
   aws route53 create-vpc-association-authorization --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=<vpc-id> --region us-east-1
   ```
   Example:
   ```sh
   aws route53 create-vpc-association-authorization --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=vpc-05ca88b256fe8b2fc --region us-east-1
   ```
2. Run the following command on the Network Account:
   ```sh
   aws route53 associate-vpc-with-hosted-zone --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=<vpc-id> --region us-east-1
   ```
   Example:
   ```sh
   aws route53 associate-vpc-with-hosted-zone --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=vpc-05ca88b256fe8b2fc --region us-east-1
   ```



### B. Associate Project Account Transit Gateway Attachment ID to the Network Account

Associating the transit gateway attachment ID of a child account with the network account in AWS ensures secure and centralized network connectivity.

#### How to get Transit Gateway Attachment ID on Project Account :
Open the **AWS VPC Console**  on Project Account → Click on **"Transit Gateway Attachments"** in the left pane → Locate the **VPC** attachment type → Match the **VPC ID** with yours → Find the **Transit Gateway Attachment ID** in the respective column.

---

## Step-2. KMS Policy Update for AMI Copy to Project Accounts

When creating AMIs via the EC2 Image Builder pipeline in the RG Deployed Orchestration Account, they need to be copied to the Project Account. To enable this, the EBS KMS key should include account permissions to share AMIs.

### Steps to Add Project Account to KMS Policy:

1. **Log in to the RG Orchestration Account via AWS Console.**
2. **Navigate to the KMS Console in the RG Deployed Account.**
3. **Select the Customer Managed Key associated with EBS encryption.**
   - KMS Key Name: `accelerator/ebs/default-encryption/key`
4. **Edit Key Policy.**
5. **Modify the Principal Section to Include the Project Account ARN:**
   ```json
   {
       "Effect": "Allow",
       "Principal": { "AWS": "arn:aws:iam::<PROJECT_ACCOUNT_ID>:root" },
       "Action": "kms:*",
       "Resource": "*"
   }
   ```
6. **Save the Updated Policy.**

---

## Step-3. Modify RG Deploy Template Bucket Policy

1. **Log in to the RG Orchestration Account via AWS Console.**
2. **Select the RG Deployed Template Bucket:**
   - QA: `rgqa-sec-templates1`
3. **Modify the Existing Bucket Policy (For that Go to the S3 bucket - > Permsiions - > Bucket policy - > Edit - > Modify the policy - > Save Chnages) to Include the Project Account in the follwing blocks : 1.Get:Artifacts 2.Get:BootstrapScripts 3.List:BootstrapScripts**

---

## Step-4. Run Deploy Resources Script

To create network security groups,ACM certificate creation,RG User creation,egress resources, Lambda, and launch templates:

1. **Log in to AWS and open CloudShell.**
2. **Clone the repository:**
   ```sh
   git clone https://github.com/RLIndia/rgdeploy-uh.git
   ```
3. **Navigate to the Project Onboarding Directory:**
   ```sh
   cd rgdeploy-uh/Rgproject-onboarding/QA
   ```
4. **Switch to the Environment Folder (e.g., QA):**
   ```sh
   cd QA
   ```
5. **Make the Deployment Script Executable:**
   ```sh
   chmod +x deploy_resources.sh
   ```
6. **Run the Deployment Script:**
   ```sh
   ./deploy_resources.sh
   ```
7. **it will create RG network details and store those details under network.json under same folder and egress details were stored under egress.json file**

---

> **Note:** After successfully creating the `RG-Template-Versions` stack, log in to the **AWS Console**  using the **project account**, navigate to **Launch Templates**, select **`RG-IMDSv2`**, go to **Actions > Modify (Create New Version)**, keep the default values, and click **Create Template Version** to generate a new version of the template.





