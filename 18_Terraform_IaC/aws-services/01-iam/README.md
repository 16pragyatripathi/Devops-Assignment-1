# AWS IAM (Identity and Access Management) – Research

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

IAM is the security front door of an AWS account. Every request, whether from the console, the CLI, an SDK or Terraform, is checked by IAM first. The check asks two questions:

1. **Authentication**: who is making this call? (a user's password or access key, or a role's temporary token)
2. **Authorization**: is that identity allowed to do *this action* on *this resource*? (answered by policies)

IAM is a **global** service, not tied to a region, and it costs nothing.

## The building blocks

| Thing | What it is | Has its own credentials? | Example |
|---|---|---|---|
| **Root user** | The email login that created the account. It can do everything, including closing the account. | Yes (password, optional keys) | Used once to set up MFA and an admin, then locked away |
| **User** | A permanent identity for one person or one program | Yes: console password and/or access key pair | `pragya-dev` |
| **Group** | A bag of users. Policies attached to the group apply to every member. | No | `pragya-developers` |
| **Role** | A set of permissions that someone or something *assumes* for a short time | No: STS hands out temporary keys | An EC2 instance reading S3 |
| **Policy** | A JSON document listing allowed or denied actions | n/a | "may read objects in bucket X" |

### Users
A user is meant for a human, or for an old-style application. It can have:
- a **console password** (for the web UI), plus MFA
- up to two **access keys** (`AKIA...` ID + secret) for the CLI/SDK/Terraform

Access keys do not expire on their own. That is why leaked keys in GitHub repos are one of the most common ways AWS accounts get abused.

### Groups
A group is only a way to manage permissions for many people at once. When a new developer joins, I add them to `developers` instead of attaching ten policies to them one by one. Groups cannot contain other groups, and a group cannot be used as a principal in a policy.

### Roles
A role has **no password and no permanent keys**. A trusted entity *assumes* it and gets temporary credentials from STS (Security Token Service), usually valid for 1 hour. A role has two policies:

- **Trust policy**: *who* is allowed to assume the role (for example the EC2 service, a Lambda function, another AWS account, or GitHub Actions through OIDC)
- **Permission policy**: *what* the role can do once assumed

Typical uses:

| Situation | Solution |
|---|---|
| App on EC2 needs to read S3 | Role + instance profile attached to the instance (no keys on the server) |
| Lambda writes to DynamoDB | Lambda execution role |
| GitHub Actions deploys to AWS | OIDC role, so no AWS key is stored in GitHub secrets |
| A user in account A works in account B | Cross-account role |

### Policies
A policy is JSON with one or more statements. Each statement has an **Effect** (Allow/Deny), **Action** (API calls like `s3:GetObject`), **Resource** (ARNs) and an optional **Condition**. This is the policy I used below. It only allows reading one bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "ReadOneBucket",
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::pragya-reports",
      "arn:aws:s3:::pragya-reports/*"
    ]
  }]
}
```

`ListBucket` applies to the bucket ARN and `GetObject` applies to the objects (`/*`). That is why both ARNs are listed.

Kinds of policies:
- **AWS managed** (e.g. `ReadOnlyAccess`): written by AWS, broad
- **Customer managed**: written by me, reusable, versioned (my `pragya-s3-read-reports` above)
- **Inline**: embedded in a single user/group/role and deleted with it
- **Resource-based**: attached to the resource itself, e.g. an S3 bucket policy

### How IAM decides
1. Everything starts as **implicitly denied**.
2. If any policy has an explicit **Deny** that matches, the answer is **deny**, whatever else says.
3. Otherwise, if some policy **Allows** it, the answer is **allow**.
4. Otherwise it stays denied.

So a missing Allow and an explicit Deny both block the call, but an explicit Deny cannot be overridden.

## Least privilege
Give each identity only the actions and resources it really needs, and nothing more. In practice:
- start from nothing and add permissions when something fails, instead of starting from `AdministratorAccess`
- limit `Resource` to specific ARNs, not `*`
- use conditions (source IP, MFA present, tags)
- review unused permissions with IAM Access Analyzer / "last accessed" data

## Best practices
- Enable **MFA** on root and on every human user; never create root access keys.
- People should log in through **IAM Identity Center (SSO)** and get short-lived credentials.
- Use **roles** for workloads (EC2, Lambda, CI) instead of long-lived access keys.
- If access keys must exist, rotate them and never commit them. Tools like `gitleaks` (session 17) catch this.
- Manage permissions with **groups**, not per-user policies.
- Turn on **CloudTrail** so every API call is logged with who made it.

## Hands-on (LocalStack)

I have no real AWS account credentials on this machine, so I ran the commands against **LocalStack 3.8** (community edition) in Docker. For every command in these research pages the shell had:

```text
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=ap-south-1
export AWS_ENDPOINT_URL=http://localhost:4566     # send every aws call to LocalStack
```

`AWS_ENDPOINT_URL` makes the normal `aws` CLI (v1.46.1) talk to LocalStack, so the commands below are exactly what I would type for real AWS. Account `000000000000` is LocalStack's fake account.

```text
$ aws sts get-caller-identity
{
    "UserId": "AKIAIOSFODNN7EXAMPLE",
    "Account": "000000000000",
    "Arn": "arn:aws:iam::000000000000:root"
}

$ aws iam create-group --group-name pragya-developers --query 'Group.[GroupName,Arn]' --output text
pragya-developers	arn:aws:iam::000000000000:group/pragya-developers

$ aws iam create-user --user-name pragya-dev --query 'User.[UserName,Arn]' --output text
pragya-dev	arn:aws:iam::000000000000:user/pragya-dev

$ aws iam add-user-to-group --group-name pragya-developers --user-name pragya-dev

$ aws iam create-policy --policy-name pragya-s3-read-reports --policy-document file://s3-read-policy.json --query 'Policy.[PolicyName,Arn,DefaultVersionId]' --output text
pragya-s3-read-reports	arn:aws:iam::000000000000:policy/pragya-s3-read-reports	v1

$ aws iam attach-group-policy --group-name pragya-developers --policy-arn arn:aws:iam::000000000000:policy/pragya-s3-read-reports

$ aws iam list-attached-group-policies --group-name pragya-developers --output table
-----------------------------------------------------------------------------
|                         ListAttachedGroupPolicies                         |
+---------------------------------------------------------------------------+
||                            AttachedPolicies                             ||
|+------------+------------------------------------------------------------+|
||  PolicyArn |  arn:aws:iam::000000000000:policy/pragya-s3-read-reports   ||
||  PolicyName|  pragya-s3-read-reports                                    ||
|+------------+------------------------------------------------------------+|

$ aws iam get-group --group-name pragya-developers --query 'Users[].UserName' --output text
pragya-dev
```

Now a **role** for EC2. The trust policy (`trust-ec2.json`) says that only the EC2 service may assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

```text
$ aws iam create-role --role-name pragya-ec2-s3-reader --assume-role-policy-document file://trust-ec2.json --query 'Role.[RoleName,Arn]' --output text
pragya-ec2-s3-reader	arn:aws:iam::000000000000:role/pragya-ec2-s3-reader

$ aws iam attach-role-policy --role-name pragya-ec2-s3-reader --policy-arn arn:aws:iam::000000000000:policy/pragya-s3-read-reports

$ aws iam create-instance-profile --instance-profile-name pragya-ec2-s3-reader --query 'InstanceProfile.Arn' --output text
arn:aws:iam::000000000000:instance-profile/pragya-ec2-s3-reader

$ aws iam add-role-to-instance-profile --instance-profile-name pragya-ec2-s3-reader --role-name pragya-ec2-s3-reader

$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/pragya-ec2-s3-reader --role-session-name pragya-test --query 'Credentials.[AccessKeyId,Expiration]' --output text
LSIAQAAAAAAAIBGMFJ5R	2026-10-07T19:26:25.116000Z
```

`assume-role` returned **temporary** keys with an expiry time one hour ahead. This is the whole point of roles: nothing permanent to leak.

### What LocalStack could not do
I tried to ask IAM "would `pragya-dev` be allowed to read / delete this object?":

```text
$ aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::000000000000:user/pragya-dev --action-names s3:GetObject s3:DeleteObject --resource-arns arn:aws:s3:::pragya-reports/q1.csv --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text

An error occurred (InternalError) when calling the SimulatePrincipalPolicy operation (reached max retries: 4): exception while calling iam.SimulatePrincipalPolicy: 404 Not Found: <?xml version="1.0" encoding="UTF-8"?>
<ErrorResponse xmlns="https://iam.amazonaws.com/doc/2010-05-08/">
    <Error>
        <Code>NoSuchEntity</Code>
        <Message><![CDATA[Policy arn:aws:iam::000000000000:user/pragya-dev not found]]></Message>
        ...
    </Error>
</ErrorResponse>

$ aws iam simulate-custom-policy --policy-input-list file://s3-read-policy.json --action-names s3:GetObject s3:DeleteObject --resource-arns arn:aws:s3:::pragya-reports/q1.csv --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text

An error occurred (InternalFailure) when calling the SimulateCustomPolicy operation: The simulate_custom_policy action has not been implemented
```

(I trimmed three empty lines from the XML in the first error.) LocalStack community **stores** IAM users, groups, roles and policies, but does not **evaluate** them. It treats the user ARN as a policy ARN, and `simulate-custom-policy` is not implemented at all. On real AWS, the expected answer is `s3:GetObject allowed` and `s3:DeleteObject implicitDeny`, because the policy only allows reads. I could not prove that here.

## Relevance to this course
- Terraform on real AWS runs as an IAM identity. Its permissions decide what `terraform apply` is allowed to create.
- In session 16 (GitHub Actions) the safe way to deploy to AWS is an **OIDC role**, not keys in repository secrets.
- In session 19 an EC2 instance that needs S3 should get an **instance profile** like the one above.
