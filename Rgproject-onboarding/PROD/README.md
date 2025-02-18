# RG Project Account Onboarding on PROD

## Introduction

Welcome to the RLCatalyst Research Gateway Project Account onboarding. This guide provides documentation for onboarding a new project account on the Research Gateway product.

## Step-1. VPC Association & Resources Creation

### Pre-requisites:

a. Get Hosted Zone ID of RG Main Account
   - QA: `qa.researchsre.miami.edu` - `Z070671526HXR9ZO8WWAK`
   - Prod: `prod.researchsre.miami.edu` - `Z07179521FVHYWQT4X38T`

b. VPC ID of the Newly Created Project Account

### A. Associate VPC with Hosted Zone

Run the following commands on the RG Deployed Account from the Cloud Shell service:

1. List hosted zones:
   ```sh
   aws route53 list-hosted-zones
   ```
2. List VPC association authorizations:
   ```sh
   aws route53 list-vpc-association-authorizations --hosted-zone-id "/hostedzone/<hostedzone-id>"
   ```
   Example:
   ```sh
   aws route53 list-vpc-association-authorizations --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK"
   ```
3. Create VPC association authorization:
   ```sh
   aws route53 create-vpc-association-authorization --hosted-zone-id "/hostedzone/<hostedzone-id>" --vpc VPCRegion=us-east-1,VPCId=<vpc-id> --region us-east-1
   ```
   Example:
   ```sh
   aws route53 create-vpc-association-authorization --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=vpc-05ca88b256fe8b2fc --region us-east-1
   ```
4. Run the following command on the Network Account:
   ```sh
   aws route53 associate-vpc-with-hosted-zone --hosted-zone-id "/hostedzone/<hosted-zoneid>" --vpc VPCRegion=us-east-1,VPCId=<vpc-id> --region us-east-1
   ```
   Example:
   ```sh
   aws route53 associate-vpc-with-hosted-zone --hosted-zone-id "/hostedzone/Z070671526HXR9ZO8WWAK" --vpc VPCRegion=us-east-1,VPCId=vpc-05ca88b256fe8b2fc --region us-east-1
   ```

**Note:** RG Main Accounts on UHealth AWS Accounts:
   - QA: `UHIT-HIPAA-NonProd-SRE-QA`
   - Prod: `UHIT-HIPAA-Prod-SRE`

### B. Associate Project Account Transit Gateway Attachment ID to the Network Account

Associating the transit gateway attachment ID of a child account with the network account in AWS ensures secure and centralized network connectivity.

---

## Step-2. Create ACM Certificate

### Steps:

1. **Prepare Certificate Files:**
   - Ensure the following files from the network team are available (`.pfx` or `.pem` source):
     - **Certificate Body**
     - **Private Key**
     - **Certificate Chain**

2. **Enter Certificate Details:**
   - In the **Certificate Body** field, paste the contents of `certificate.crt`.
   - In the **Certificate Private Key** field, paste the contents of `privatekey.pem`.
   - In the **Certificate Chain** field, paste the contents of `certificate_chain.pem` (including intermediate and root certificates in order provided by the CA).

3. **Review and Import:**
   - Click **Next** after pasting all contents.
   - Review the entries and click **Import** if everything is correct.

---

## Step-3. Create RG User

When setting up a new account on RG, access keys and a secret key must be passed. Follow these steps:

### Sign in to the AWS Management Console from the Project Account:

1. **Go to the IAM Console.**
2. **Create a New User:**
   - Navigate to **Users** and select **Add Users**.
   - Enter a **Username** for the new user.
3. **Set User Permissions:**
   - Under **Set Permissions**, select **Attach Policies Directly**.
   - Search for and select `AdministratorAccess`.
4. **Review and Create User:**
   - Review the settings and click **Create User**.
5. **Download Access and Secret Keys:**
   - Click on the created user and go to **Security Credentials**.
   - Select **Create Access Keys**, choose **Other**, and enter a description.
   - Securely save the generated access keys.

---

## Step-4. KMS Policy Update for AMI Copy to Project Accounts

When creating AMIs via the EC2 Image Builder pipeline in the RG Deployed Main Account, they need to be copied to the Project Account. To enable this, the EBS KMS key should include account permissions to share AMIs.

### Steps to Add Project Account to KMS Policy:

1. **Navigate to the KMS Console in the RG Deployed Account.**
2. **Select the Customer Managed Key associated with EBS encryption.**
   - KMS Key Name: `accelerator/ebs/default-encryption/key`
3. **Edit Key Policy.**
4. **Modify the Principal Section to Include the Project Account ARN:**
   ```json
   {
       "Effect": "Allow",
       "Principal": { "AWS": "arn:aws:iam::<PROJECT_ACCOUNT_ID>:root" },
       "Action": "kms:*",
       "Resource": "*"
   }
   ```
5. **Save the Updated Policy.**
6. **Verify Permissions by Testing Access in the Project Account.**

---

## Step-5. Modify RG Deploy Template Bucket Policy

After successfully setting up a new account in RG, update the bucket policy before project creation:

1. **Log in to the RG Main Account via AWS Console.**
2. **Select the RG Deployed Template Bucket:**
   - QA: `rgqa-sec-templates1`
   - Prod: `rgprod-cft-template`
3. **Modify the Existing Bucket Policy to Include the Project Account.**

4. **Sample bucket policy.**
```json
{ 

    "Version": "2012-10-17", 

    "Statement": [ 

        { 

            "Sid": "Get:Artifacts", 

            "Effect": "Allow", 

            "Principal": { 

                "AWS": [ 

                    "arn:aws:iam::418272783600:role/RG-Portal-ProjectRole-PROD-zzyi", 

                    "arn:aws:iam::381492012479:role/RG-Portal-ProjectRole-PROD-zzyi" 

                ] 

            }, 

            "Action": "s3:GetObject", 

            "Resource": "arn:aws:s3:::rgprod-cft-template/*" 

        }, 

        { 

            "Sid": "Get:BootstrapScripts", 

            "Effect": "Allow", 

            "Principal": { 

                "AWS": [ 

                    "arn:aws:iam::418272783600:root", 

                    "arn:aws:iam::381492012479:root" 

                ] 

            }, 

            "Action": "s3:GetObject", 

            "Resource": "arn:aws:s3:::rgprod-cft-template/bootstrap-scripts/*" 

        }, 

        { 

            "Sid": "List:BootstrapScripts", 

            "Effect": "Allow", 

            "Principal": { 

                "AWS": [ 

                    "arn:aws:iam::418272783600:root", 

                    "arn:aws:iam::381492012479:root" 

                ] 

            }, 

            "Action": "s3:ListBucket", 

            "Resource": "arn:aws:s3:::rgprod-cft-template", 

            "Condition": { 

                "StringLike": { 

                    "s3:prefix": "bootstrap-scripts*" 

                } 

            } 

        }, 

        { 

            "Sid": "Deny requests that do not use TLS", 

            "Effect": "Deny", 

            "Principal": "*", 

            "Action": "s3:*", 

            "Resource": "arn:aws:s3:::rgprod-cft-template/*", 

            "Condition": { 

                "Bool": { 

                    "aws:SecureTransport": "false" 

                } 

            } 

        }, 

        { 

            "Sid": "Deny requests that do not use SigV4", 

            "Effect": "Deny", 

            "Principal": "*", 

            "Action": "s3:*", 

            "Resource": "arn:aws:s3:::rgprod-cft-template/*", 

            "Condition": { 

                "StringNotEquals": { 

                    "s3:signatureversion": "AWS4-HMAC-SHA256" 

                } 

            } 

        } 

    ] 

} 
```

---

## Step-6. Run Deploy Resources Script

To create network security groups, egress resources, Lambda, and launch templates:

1. **Log in to AWS and open CloudShell.**
2. **Clone the repository:**
   ```sh
   git clone https://github.com/RLIndia/rgdeploy-uh.git
   ```
3. **Navigate to the Project Onboarding Directory:**
   ```sh
   cd rgdeploy-uh/Rgproject-onboarding
   ```
4. **Switch to the Environment Folder (e.g., QA):**
   ```sh
   cd PROD
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

## Step-7: Add KMS Policy to Project Role in the Project Account

After onboarding a new account on RG with the above steps, a new IAM role is created in the project account. We need to add a KMS policy to that role by following these steps:

### 1. Log in to the Project Account from the AWS Management Console

- Navigate to the **IAM** service and select **Roles**.
- Search for the project role with the prefix: `RG-Portal-ProjectRole`.
- Once the role is located, select the role to open its details.

### 2. Add a Permission

- Click on **Add permissions** and select **Create inline policy**.
- Copy and paste the following policy block to enable access to the KMS key:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:DescribeKey",
                "kms:ReEncrypt*",
                "kms:CreateGrant",
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:kms:us-east-1:730335491778:key/<KeyID>"
            ]
        }
    ]
}
```

### 3. Retrieve the KMS Key ARN from the Main Account

 - Go to AWS Key Management Service (KMS) in the Main Account.
 - Locate the Customer Managed Key designated for EBS encryption and copy its ARN.




