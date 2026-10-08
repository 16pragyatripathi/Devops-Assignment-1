# AWS Databases: DynamoDB and RDS – Research

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

AWS has many managed databases. These two are the ones most applications start with:

- **DynamoDB**: serverless NoSQL key-value / document database
- **RDS**: managed relational (SQL) databases such as PostgreSQL and MySQL

"Managed" means AWS handles the hardware, OS, patching, backups and failover. I still own the data model, queries, access rules and cost.

---

# DynamoDB

## NoSQL in one paragraph
A relational database stores data in tables with a fixed schema and lets you join them in any way at query time. A NoSQL database like DynamoDB gives up joins and free-form queries. In return, reads and writes by key are fast (single-digit milliseconds) at **any scale**. You design the table around the questions the app will ask ("all orders of customer X, newest first"), not around a normalised schema.

## Tables, items, attributes
| DynamoDB | Rough SQL equivalent |
|---|---|
| Table | Table |
| Item | Row (max 400 KB) |
| Attribute | Column, but each item can have different attributes |

Only the key attributes must be declared up front. Everything else is schemaless. In my demo below, one order has a `coupon` attribute and the others do not.

## Partition key and sort key
- **Partition key (HASH)**: required. DynamoDB hashes it to decide which internal partition stores the item. A key with many distinct values (customer ID, user ID) spreads load evenly. A key like `status` with three values creates "hot partitions".
- **Sort key (RANGE)**: optional. Items with the same partition key are stored sorted by it. That makes range queries like `order_date >= 2026-10-02` cheap.
- With only a partition key, each key value identifies one item. With both, the **pair** must be unique.

Extra access patterns use **secondary indexes**: a GSI (different partition + sort key, can be added any time) or an LSI (same partition key, different sort key, only at table creation).

## Capacity and other features
- **On-demand** (`PAY_PER_REQUEST`): pay per read/write, no planning. Good for new or spiky workloads.
- **Provisioned**: set read/write capacity units (optionally with auto scaling). Cheaper for steady traffic.
- **Streams** (change feed for Lambda triggers), **TTL** (auto-delete expired items), **point-in-time recovery**, **global tables** (multi-region replication), transactions.

## Hands-on (LocalStack)
CLI pointed at LocalStack 3.8 through `AWS_ENDPOINT_URL` (setup on the [IAM page](../01-iam/README.md)). LocalStack community emulates DynamoDB well.

```text
$ aws dynamodb create-table --table-name pragya-orders --attribute-definitions AttributeName=customer_id,AttributeType=S AttributeName=order_date,AttributeType=S --key-schema AttributeName=customer_id,KeyType=HASH AttributeName=order_date,KeyType=RANGE --billing-mode PAY_PER_REQUEST --query 'TableDescription.[TableName,TableStatus,BillingModeSummary.BillingMode]' --output text
pragya-orders	ACTIVE	PAY_PER_REQUEST

$ aws dynamodb put-item --table-name pragya-orders --item '{"customer_id":{"S":"c-101"},"order_date":{"S":"2026-10-01"},"total":{"N":"499"},"item":{"S":"keyboard"}}'

$ aws dynamodb put-item --table-name pragya-orders --item '{"customer_id":{"S":"c-101"},"order_date":{"S":"2026-10-05"},"total":{"N":"1299"},"item":{"S":"monitor"},"coupon":{"S":"DIWALI10"}}'

$ aws dynamodb put-item --table-name pragya-orders --item '{"customer_id":{"S":"c-202"},"order_date":{"S":"2026-10-03"},"total":{"N":"250"}}'

$ aws dynamodb query --table-name pragya-orders --key-condition-expression 'customer_id = :c AND order_date >= :d' --expression-attribute-values '{":c":{"S":"c-101"},":d":{"S":"2026-10-02"}}' --query 'Items[].[order_date.S,item.S,total.N,coupon.S]' --output text
2026-10-05	monitor	1299	DIWALI10

$ aws dynamodb get-item --table-name pragya-orders --key '{"customer_id":{"S":"c-202"},"order_date":{"S":"2026-10-03"}}' --query 'Item' --output json
{
    "customer_id": {
        "S": "c-202"
    },
    "order_date": {
        "S": "2026-10-03"
    },
    "total": {
        "N": "250"
    }
}

$ aws dynamodb scan --table-name pragya-orders --select COUNT --query '[Count,ScannedCount]' --output text
3	3
```

**What I understood:**
- Only `customer_id` and `order_date` were declared. `total`, `item` and `coupon` were just added per item. The third item has no `item` at all.
- The `query` used the partition key plus a condition on the sort key. It only read customer `c-101`'s items and returned the one order on or after 2 Oct. This is the efficient access pattern.
- `get-item` needs the **full** primary key (both parts) because the table has a composite key.
- `scan` reads the whole table (3 of 3 items). On a big table that is slow and expensive, which is why access patterns are designed around `query`.

## DynamoDB use cases
Session stores and shopping carts, user profiles, gaming leaderboards, IoT telemetry, serverless backends with Lambda, and **Terraform state locking**: the S3 backend's `dynamodb_table` option uses a table keyed on `LockID` so two `terraform apply` runs cannot change the same state at once. (Terraform 1.10+ can also lock with a lock file in S3, `use_lockfile = true`.)

---

# RDS (Relational Database Service)

## What RDS manages for me
RDS runs a normal relational database engine on instances that AWS operates. I still write SQL, design tables and tune queries. AWS handles provisioning, OS and engine patching, automated backups, failover and storage scaling. I cannot SSH into the host.

## Engines
PostgreSQL, MySQL, MariaDB, Oracle, Microsoft SQL Server, IBM Db2, and **Aurora** (AWS's own MySQL/PostgreSQL-compatible engine with a shared, auto-growing storage layer replicated six ways across three AZs).

## DB instances
Like EC2, an RDS database runs on an instance class (`db.t3.micro`, `db.m6g.large`, `db.r6g.xlarge` …) with EBS storage (gp3 or io2). Changing the class means a restart. Aurora Serverless v2 scales capacity automatically instead.

## Security
- Put the DB in **private subnets** (a *DB subnet group* spanning at least two AZs) with `publicly_accessible = false`.
- A **security group** that allows the DB port (5432/3306) only from the application's security group, never from `0.0.0.0/0`.
- **Encryption at rest** with KMS (must be chosen at creation) and TLS in transit.
- Keep the master password in **Secrets Manager** (RDS can manage and rotate it), or use IAM database authentication. Never hard-code it in Terraform or in git.

## Backups
- **Automated backups**: daily snapshot plus transaction logs, retained 1–35 days. This allows **point-in-time restore** to any second in that window.
- **Manual snapshots**: kept until I delete them. Can be copied to other regions/accounts.
- A restore always creates a **new** DB instance; it does not overwrite the old one.

## Multi-AZ
RDS keeps a **synchronous standby** copy in another AZ. If the primary or its AZ fails, RDS flips the DNS endpoint to the standby, usually in 1–2 minutes, and the app reconnects to the same hostname. The standby is for **availability only**: it does not serve reads. (The newer "Multi-AZ DB cluster" option has two readable standbys.)

## Read replicas
**Asynchronous** copies that serve read-only queries, to take load off the primary (reports, dashboards). They can be in another region, can lag slightly behind, and can be promoted to stand-alone databases (for example during disaster recovery).

| | Multi-AZ standby | Read replica |
|---|---|---|
| Purpose | High availability | Read scaling |
| Replication | Synchronous | Asynchronous |
| Serves traffic | No (classic Multi-AZ) | Yes, reads |
| Failover | Automatic | Manual promotion |

## Hands-on: not possible on LocalStack community
I tried anyway:

```text
$ aws rds describe-db-instances

An error occurred (InternalFailure) when calling the DescribeDBInstances operation: API for service 'rds' not yet implemented or pro feature - please check https://docs.localstack.cloud/references/coverage/ for further information

$ aws rds create-db-instance --db-instance-identifier pragya-db --engine postgres --db-instance-class db.t3.micro --allocated-storage 20 --master-username pragya --master-user-password 'NotARealPass123'

An error occurred (InternalFailure) when calling the CreateDBInstance operation: API for service 'rds' not yet implemented or pro feature - please check https://docs.localstack.cloud/references/coverage/ for further information
```

RDS is only in LocalStack's paid edition, and the `/_localstack/health` endpoint of my container does not list `rds` among its services. On real AWS the same `create-db-instance` call would work. In Terraform it would be an `aws_db_instance` with `db_subnet_group_name`, `vpc_security_group_ids`, `multi_az = true`, `storage_encrypted = true` and `manage_master_user_password = true`. The password above was a throwaway string, used only for this failed call.

## RDS use cases
Any app that needs SQL, joins and transactions: e-commerce orders and payments, ERP/CRM systems, CMS platforms like WordPress, banking ledgers, and reporting where ad-hoc queries are needed.

---

# Choosing between them

| Question | DynamoDB | RDS |
|---|---|---|
| Data model | Key-value / documents, flexible attributes | Tables, fixed schema, relations |
| Queries | By key (and indexes) only; access patterns planned up front | Any SQL, joins, aggregations |
| Scale | Practically unlimited, horizontal, automatic | Vertical (bigger instance) + read replicas |
| Servers to size | None (serverless) | Instance class and storage |
| Transactions | Supported, limited (100 items) | Full ACID |
| Cost model | Per request or provisioned capacity + storage | Per instance-hour + storage, even when idle |
| Good fit | Huge traffic with simple, known lookups | Complex relationships and reporting |

My rule of thumb: if I can list every query the app will ever make and they are all "get by ID" shaped, DynamoDB is simpler to run at scale. If I need joins, ad-hoc reporting or strict relational integrity, RDS (usually PostgreSQL) is the safer default.
