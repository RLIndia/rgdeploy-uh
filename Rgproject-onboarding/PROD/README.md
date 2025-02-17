# RG Project Account Onboarding on PROD

## Introduction

Welcome to the RLCatalyst Research Gateway Project Account onboarding. This guide is designed to provide documentation for users who will be onboarding a new project account on the Research Gateway product.

## 1. VPC Association & Resources Creation

### Pre-requisites:

a. Get Hosted Zone ID of RG Main Account
   - QA: `qa.researchsre.miami.edu` - `Z070671526HXR9ZO8WWAK`
   - Prod: `prod.researchsre.miami.edu` - `Z07179521FVHYWQT4X38T`

b. VPC ID of the Newly Created Project Account

### A. Associate VPC with Hosted Zone

Run the below commands on the RG Deployed Account from the Cloud Shell service:

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

Attaching the transit gateway attachment ID of a child account to the network account in AWS is essential for enabling secure and centralized network connectivity.

---

## 2. Create ACM Certificate

### Steps:

1. **Prepare Certificate Files:**
   - Ensure we have the following files ready from the network team (`.pfx` or `.pem` source):
     - **Certificate Body**
     - **Private Key**
     - **Certificate Chain**

2. **Enter Certificate Details:**
   - In the **Certificate Body** field, paste the contents of your certificate body file (e.g., `certificate.crt`).
   - In the **Certificate Private Key** field, paste the contents of your private key file (e.g., `privatekey.pem`).
   - In the **Certificate Chain** field, paste the contents of your certificate chain file (e.g., `certificate_chain.pem`).
   - The certificate chain typically includes intermediate and root certificates in the order provided by your certificate authority (CA).

3. **Review and Import:**
   - After pasting all the contents, click **Next**.
   - Review your entries, and if everything looks correct, click **Import**.

---

## 3. Create RG User

When creating a new account on RG, we need to pass access keys and a secret key. Follow these steps:

### Sign in to the AWS Management Console from the Project Account:

1. **Go to the IAM Console.**
2. **Create a New User:**
   - In the IAM Console, go to **Users** and select **Add Users**.
   - Enter a **Username** for the new user.
3. **Set User Permissions:**
   - Under **Set Permissions**, select **Attach Policies Directly**.
   - In the list of policies, search for `AdministratorAccess`.
4. **Review and Create User:**
   - Review the settings, then click **Create User**.
5. **Download Access and Secret Keys:**
   - Click on the created user and navigate to **Security Credentials**.
   - Select **Create Access Keys**, choose **Other** as the option, and enter a description for the keys.
   - The access keys will then be generated—save them securely.

