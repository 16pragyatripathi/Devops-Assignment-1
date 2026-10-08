# AWS EC2 (Elastic Compute Cloud) – Research

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

EC2 rents out virtual machines (called **instances**) by the second. I choose the operating system, the size and the network, and AWS runs the VM on its hardware. This is **IaaS**: AWS manages the physical servers and the hypervisor. I manage everything from the OS upwards (patches, software, firewall rules inside the OS).

## AMI (Amazon Machine Image)
An AMI is the template a new instance boots from: a root disk snapshot (OS + any pre-installed software) plus some metadata (architecture, boot mode).

| AMI source | Example |
|---|---|
| Published by AWS | Amazon Linux 2023, Windows Server |
| Published by vendors | Ubuntu (Canonical), RHEL, Debian |
| Marketplace | Pre-built images with licensed software |
| My own | Built from a configured instance, or by Packer in a pipeline |

AMI IDs are **different in every region**, so hard-coding an ID in Terraform breaks when the region changes. The usual fix is an `aws_ami` data source that searches by name and owner. I used this in session 19.

## Instance types
The name tells you the family, generation and size. For `t3.micro`: family **t** (burstable), generation **3**, size **micro**.

| Family | Optimised for | Typical use |
|---|---|---|
| t (t3, t4g) | Cheap, burstable CPU credits | Dev servers, small websites |
| m (m5, m7g) | Balanced CPU/RAM | General app servers |
| c (c6i, c7g) | CPU | Batch jobs, video encoding, CI runners |
| r / x | Memory | In-memory caches, big databases |
| g / p | GPU | ML training, graphics |
| i / d | Local NVMe disk | High-IO databases |

A `g` after the generation (t4**g**, m7**g**) means an ARM Graviton CPU, which is cheaper for the same work.

## Key pairs
For SSH into Linux instances, AWS stores the **public** key and puts it into `~/.ssh/authorized_keys` on first boot. The **private** key (`.pem`) is shown only once at creation. If I lose it, I cannot SSH in with that key. Modern setups often skip SSH entirely and use **SSM Session Manager**, which needs no open port 22.

## Security groups
A security group is a **stateful firewall attached to the instance's network interface**:
- rules only **allow**; there is no deny rule
- by default all inbound traffic is blocked and all outbound is allowed
- "stateful" means a reply to an allowed request is automatically allowed back
- a rule's source can be another security group instead of an IP range ("allow 5432 only from the web-tier SG")

## EBS (Elastic Block Store)
EBS volumes are network disks that live in **one AZ** and attach to an instance in that AZ.

| Type | Notes |
|---|---|
| gp3 / gp2 | General purpose SSD (gp3 is the newer, cheaper default) |
| io2 | Provisioned IOPS SSD for heavy databases |
| st1 / sc1 | HDD for large sequential reads (logs, big data) |

Snapshots of EBS volumes are saved to S3 and can be copied to other regions. **Instance store** is different: it is a disk physically inside the host, very fast, but its data is lost when the instance stops.

## Public and private IPs
- Every instance gets a **private IP** from its subnet's range. It stays the same for the instance's lifetime.
- A **public IP** is given only if the subnet (or launch setting) asks for one. It **changes** after a stop/start.
- An **Elastic IP** is a static public IP I own and can move between instances.
- A public IP is not enough to be reachable. The subnet also needs a route to an Internet Gateway, and the security group must allow the port.

## Lifecycle

```text
pending ──> running ──> stopping ──> stopped ──> pending ...
               │
               └──> shutting-down ──> terminated   (gone for good)
```

Billing for compute stops when the instance is `stopped`, but its EBS volumes are still charged.

## Pricing options
**On-Demand** (pay per second, no commitment), **Savings Plans / Reserved** (1–3 year commitment, big discount), **Spot** (spare capacity at up to ~90% off, can be taken back with 2 minutes' notice).

## Hands-on (LocalStack)
Same setup as the IAM page: `aws` CLI pointed at LocalStack 3.8 through `AWS_ENDPOINT_URL`, region `ap-south-1`. In LocalStack community EC2 is **simulated**: the API answers, but no real VM boots.

```text
$ aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-2023*' --query 'Images[].[ImageId,Architecture,Name]' --output table
---------------------------------------------------------------------------------------
|                                   DescribeImages                                    |
+------------------------+---------+--------------------------------------------------+
|  ami-0e53db6fd757e38c7 |  x86_64 |  al2023-ami-2023.5.20240903.0-kernel-6.1-x86_64  |
|  ami-063121836079a0179 |  arm64  |  al2023-ami-2023.5.20240903.0-kernel-6.1-arm64   |
+------------------------+---------+--------------------------------------------------+

$ aws ec2 describe-instance-types --instance-types t3.micro t3.large m5.xlarge --query 'InstanceTypes[].[InstanceType,VCpuInfo.DefaultVCpus,MemoryInfo.SizeInMiB]' --output table
-----------------------------
|   DescribeInstanceTypes   |
+------------+----+---------+
|  m5.xlarge |  4 |  16384  |
|  t3.large  |  2 |  8192   |
|  t3.micro  |  2 |  1024   |
+------------+----+---------+

$ aws ec2 create-key-pair --key-name pragya-key --query 'KeyMaterial' --output text > pragya-key.pem && chmod 400 pragya-key.pem && head -1 pragya-key.pem
-----BEGIN RSA PRIVATE KEY-----

$ SG=$(aws ec2 create-security-group --group-name pragya-web-sg --description 'web demo' --query GroupId --output text); echo $SG
sg-cee03fbcb0d4db238

$ aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --query 'SecurityGroupRules[0].[IpProtocol,FromPort,CidrIpv4]' --output text
tcp	80	0.0.0.0/0

$ ID=$(aws ec2 run-instances --image-id ami-0e53db6fd757e38c7 --instance-type t3.micro --key-name pragya-key --security-group-ids $SG --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=pragya-ec2-demo}]' --query 'Instances[0].InstanceId' --output text); echo $ID
i-1aa2810c618a96659

$ aws ec2 describe-instances --instance-ids $ID --query 'Reservations[].Instances[].[InstanceType,State.Name,PrivateIpAddress,PublicIpAddress,Placement.AvailabilityZone]' --output table
------------------------------------------------------------------------
|                           DescribeInstances                          |
+----------+----------+----------------+---------------+---------------+
|  t3.micro|  running |  10.62.157.122 |  54.214.5.91  |  ap-south-1a  |
+----------+----------+----------------+---------------+---------------+

$ aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$ID --query 'Volumes[].[VolumeId,Size,VolumeType,State]' --output text
vol-eb372b03	8	gp2	in-use

$ aws ec2 stop-instances --instance-ids $ID --query 'StoppingInstances[0].[PreviousState.Name,CurrentState.Name]' --output text
running	stopping

$ aws ec2 start-instances --instance-ids $ID --query 'StartingInstances[0].[PreviousState.Name,CurrentState.Name]' --output text
stopped	pending

$ aws ec2 terminate-instances --instance-ids $ID --query 'TerminatingInstances[0].[PreviousState.Name,CurrentState.Name]' --output text
running	shutting-down
```

(I only printed the first line of the private key file. The rest is a private key and should never be shown.)

**What I noticed:**
- `run-instances` created an 8 GiB `gp2` root volume automatically. That is the EBS volume the AMI asks for.
- The state transitions match the lifecycle diagram: `running → stopping`, `stopped → pending`, `running → shutting-down`.
- A LocalStack quirk: since I gave no subnet, the instance went into the default VPC's subnet `subnet-32187184` (`172.31.0.0/20`, I checked with `describe-instances`/`describe-subnets`), but its private IP `10.62.157.122` is outside that range. Real AWS always picks an IP from the subnet's CIDR. The mock skips that check.
- The public IP `54.214.5.91` is invented by LocalStack. Nothing is listening there.

## Terraform equivalent

```hcl
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]
  tags                   = { Name = "pragya-s19-web-1" }
}
```

The full version is in [19_Cloud_Terraform_Action/terraform/compute.tf](../../../19_Cloud_Terraform_Action/terraform/compute.tf).

## Common use cases
Web and API servers, CI build runners, self-managed databases, batch and ML jobs (often on Spot), Kubernetes worker nodes (EKS node groups are EC2 instances), and lifting legacy apps from on-prem into the cloud.
