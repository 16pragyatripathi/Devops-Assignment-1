# AWS S3 (Simple Storage Service) – Research

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

S3 is **object storage**: I put whole files (objects) into containers (buckets) over HTTPS and get them back by name. It is not a disk I can mount and edit in place, and it is not a database. It is designed for 99.999999999% (eleven nines) durability: data is copied across at least three Availability Zones in a region.

## Buckets
- A bucket lives in **one region**, but its name must be **unique across all AWS accounts worldwide**. That is why I use names like `pragya-24bcs10032-tf-demo`.
- Names: 3–63 characters, lowercase letters, numbers, dots and hyphens.
- A bucket has no real folders. `reports/q1.csv` is just a key that contains a `/`. The console draws folders from those slashes.
- Since April 2023, new buckets have **Block Public Access on** and **ACLs disabled** by default.

## Objects
An object = **key** (its name) + **data** (up to 5 TB) + **metadata** (content-type, custom headers) + optional **tags** + a **version ID** if versioning is on. Uploads larger than ~100 MB should use multipart upload. The CLI does this by itself.

## Storage classes
All classes keep the same durability. They differ in price, access cost and how fast you can read.

| Class | When to use | Retrieval |
|---|---|---|
| S3 Standard | Hot data, read often | Instant |
| S3 Intelligent-Tiering | Unknown or changing access pattern; AWS moves it for you | Instant (for frequent/infrequent tiers) |
| S3 Standard-IA | Read rarely but must be instant (backups) | Instant, per-GB retrieval fee |
| S3 One Zone-IA | Re-creatable data; stored in only one AZ | Instant |
| Glacier Instant Retrieval | Archive read about once a quarter | Milliseconds |
| Glacier Flexible Retrieval | Archive | Minutes to hours |
| Glacier Deep Archive | Compliance archives kept for years | Up to 12–48 hours |

## Versioning
With versioning **enabled**, overwriting an object keeps the old copy as a "noncurrent version", and deleting only adds a *delete marker*. So mistakes can be undone. Once enabled, versioning can only be **suspended**, never fully turned off. Old versions cost storage, so versioning is usually combined with a lifecycle rule that expires them.

## Lifecycle policies
Lifecycle rules run automatically on matching objects (filtered by prefix or tag):
- **Transition**: move to a cheaper class after N days (Standard → Standard-IA → Glacier)
- **Expiration**: delete after N days
- clean up noncurrent versions and incomplete multipart uploads

## Encryption
- **SSE-S3** (AES-256, keys managed by S3): on by default for every new object since January 2023
- **SSE-KMS**: keys in AWS KMS, so key usage is logged in CloudTrail and access to the key can be restricted
- **DSSE-KMS**: two layers of KMS encryption, for strict compliance
- **SSE-C / client-side**: I manage the key myself
- **In transit**: HTTPS. A bucket policy can deny any request where `aws:SecureTransport` is false.

## Access control
- **IAM policies**: what a user or role may do on S3
- **Bucket policy**: a resource-based policy on the bucket, e.g. allow a CloudFront distribution or another account, or deny non-HTTPS access
- **Block Public Access**: four switches that override any public ACL or policy. This is the safety net against the classic "public bucket leaked customer data" incident.
- **Pre-signed URLs**: a link that gives temporary access to one object without making it public

## Hands-on (LocalStack)
CLI pointed at LocalStack 3.8 through `AWS_ENDPOINT_URL` (see the [IAM page](../01-iam/README.md)). `aws s3` is the high-level command set; `aws s3api` maps one-to-one to API calls.

```text
$ aws s3 mb s3://pragya-reports
make_bucket: pragya-reports

$ aws s3api put-bucket-versioning --bucket pragya-reports --versioning-configuration Status=Enabled

$ aws s3api get-bucket-versioning --bucket pragya-reports
{
    "Status": "Enabled"
}

$ aws s3 cp q1.csv s3://pragya-reports/reports/q1.csv
upload: ./q1.csv to s3://pragya-reports/reports/q1.csv

$ echo 'region,sales' > q1.csv; echo 'north,130' >> q1.csv; aws s3 cp q1.csv s3://pragya-reports/reports/q1.csv
upload: ./q1.csv to s3://pragya-reports/reports/q1.csv

$ aws s3api list-object-versions --bucket pragya-reports --prefix reports/q1.csv --query 'Versions[].[VersionId,IsLatest,Size]' --output table
-----------------------------------------------------
|                ListObjectVersions                 |
+-----------------------------------+--------+------+
|  CFje8IeBnu8w0rQdH2psYEPKxucVRwXr |  True  |  23  |
|  fkDiDzAx2YQyANEFpCIlpXEPN3iztNsI |  False |  32  |
+-----------------------------------+--------+------+

$ aws s3 ls s3://pragya-reports --recursive
2026-10-07 23:57:21         23 reports/q1.csv

$ aws s3 cp s3://pragya-reports/reports/q1.csv -
region,sales
north,130
```

The second upload did not destroy the first file. Both versions exist: the old 32-byte one (`IsLatest False`) and the new 23-byte one. `s3 ls` and `cp` only show the latest.

(The `cp` lines also print a progress counter that the terminal overwrites in place. I kept only the final `upload:` line that stays on screen.)

```text
$ aws s3api put-bucket-encryption --bucket pragya-reports --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

$ aws s3api head-object --bucket pragya-reports --key reports/q1.csv --query '[ServerSideEncryption,StorageClass,ContentLength]' --output text
AES256	None	23

$ aws s3api put-public-access-block --bucket pragya-reports --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

$ aws s3api get-public-access-block --bucket pragya-reports --output table
-------------------------------------
|       GetPublicAccessBlock        |
+-----------------------------------+
|| PublicAccessBlockConfiguration  ||
|+-------------------------+-------+|
||  BlockPublicAcls        |  True ||
||  BlockPublicPolicy      |  True ||
||  IgnorePublicAcls       |  True ||
||  RestrictPublicBuckets  |  True ||
|+-------------------------+-------+|
```

`StorageClass` is `None` because S3 leaves the header out for STANDARD objects.

Lifecycle rule (`lifecycle.json`): after 30 days move objects under `reports/` to Standard-IA, after 90 to Glacier, delete after a year.

```json
{
  "Rules": [{
    "ID": "archive-old-reports",
    "Status": "Enabled",
    "Filter": { "Prefix": "reports/" },
    "Transitions": [{ "Days": 30, "StorageClass": "STANDARD_IA" },
                    { "Days": 90, "StorageClass": "GLACIER" }],
    "Expiration": { "Days": 365 }
  }]
}
```

```text
$ aws s3api put-bucket-lifecycle-configuration --bucket pragya-reports --lifecycle-configuration file://lifecycle.json

$ aws s3api get-bucket-lifecycle-configuration --bucket pragya-reports --query 'Rules[0].[ID,Status,Expiration.Days]' --output text
archive-old-reports	Enabled	365

$ aws s3 cp q1.csv s3://pragya-reports/archive/q1-old.csv --storage-class GLACIER
upload: ./q1.csv to s3://pragya-reports/archive/q1-old.csv

$ aws s3api head-object --bucket pragya-reports --key archive/q1-old.csv --query StorageClass --output text
GLACIER

$ aws s3 presign s3://pragya-reports/reports/q1.csv --expires-in 300 | cut -c1-95
http://localhost:4566/pragya-reports/reports/q1.csv?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Cred
```

(I cut the pre-signed URL at 95 characters. The rest is the signature and expiry.)

LocalStack stored the lifecycle rule but obviously did not wait 30 days to move anything. Uploading directly with `--storage-class GLACIER` shows the class is recorded on the object.

## Common use cases
Static website assets (often behind CloudFront), backups and archives, data-lake storage for analytics, application uploads (images, documents), build artifacts and logs, and the **Terraform remote state backend** (S3 bucket with versioning; newer Terraform can lock with `use_lockfile = true`, older setups use a DynamoDB table).
