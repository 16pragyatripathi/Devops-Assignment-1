# AWS VPC (Virtual Private Cloud) – Research

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

A VPC is my own private, isolated network inside an AWS region. I choose its IP range, cut it into subnets, and decide with route tables and firewalls what can talk to what, including whether anything can reach the internet. Every EC2 instance, RDS database, load balancer and EKS node lives in a VPC.

Each region gives a new account a **default VPC** (`172.31.0.0/16`, with a public subnet in each AZ) so beginners can launch instances straight away. Real projects create their own VPC with a planned layout.

## CIDR
A CIDR block writes an IP range as `address/prefix`. The prefix is how many leading bits are fixed. Fewer fixed bits = more addresses.

| CIDR | Addresses | Typical use |
|---|---|---|
| `10.20.0.0/16` | 65,536 | Whole VPC (AWS allows /16 down to /28) |
| `10.20.1.0/24` | 256 (251 usable in AWS) | One subnet |
| `10.20.1.0/28` | 16 (11 usable) | Smallest subnet allowed |
| `203.0.113.25/32` | 1 | A single host, e.g. "SSH only from my IP" |

AWS reserves **5 addresses in every subnet**: network address, VPC router (+1), DNS (+2), future use (+3) and broadcast (last). That is why a /24 shows **251** available IPs below.

Use private ranges (RFC 1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) and avoid overlapping with other VPCs or the office network if they may ever be connected (peering, VPN).

## Subnets
A subnet is a slice of the VPC's range that lives in **exactly one Availability Zone**. For high availability you create the same kind of subnet in at least two AZs, so one data-centre failure does not take the app down.

## Public vs private subnet
There is no "public" checkbox. The difference is only the **route table**:

| | Public subnet | Private subnet |
|---|---|---|
| Route for `0.0.0.0/0` | → Internet Gateway | → NAT Gateway (or none) |
| Instances get public IPs | usually yes | no |
| Reachable from internet | yes, if the SG allows it | no |
| Put here | load balancers, bastion, NAT gateway | app servers, databases, caches |

## Route tables
A route table is a list of "destination CIDR → target". Every VPC route table has a `local` route for the VPC's own range, so all subnets can reach each other. Each subnet is associated with exactly one route table. If it has none, it uses the VPC's **main** route table. The most specific matching route wins.

## Internet Gateway (IGW)
A horizontally scaled, highly available gateway attached to the VPC (one per VPC). It lets instances with public IPs talk to the internet both ways, and translates between private and public IPs. It is free.

## NAT Gateway
Lets instances in **private** subnets start connections *out* to the internet (OS updates, calling external APIs) while nothing on the internet can start a connection *in*. It:
- sits in a **public** subnet and needs an **Elastic IP**
- is zonal: production uses one per AZ, so losing one AZ does not cut egress for the others
- costs money per hour plus per GB processed. That is why my session 19 Terraform makes it optional.

## Security Groups vs Network ACLs

| | Security Group | Network ACL |
|---|---|---|
| Attached to | Network interface (instance) | Subnet |
| Rules | Allow only | Allow **and** Deny |
| State | **Stateful**: replies allowed automatically | **Stateless**: return traffic needs its own rule (ephemeral ports 1024–65535) |
| Evaluation | All rules considered together | Numbered rules, lowest number first, first match wins |
| Default | Deny all in, allow all out | Default NACL allows everything |
| Typical use | Main tool: per-tier firewall | Extra coarse layer, e.g. block a bad IP range for a whole subnet |

## Other pieces worth knowing
- **VPC endpoints**: reach S3/DynamoDB (gateway endpoint, free) or other AWS APIs (interface endpoint) without going through NAT or the internet
- **VPC peering / Transit Gateway**: connect VPCs together
- **Flow logs**: record accepted/rejected traffic for debugging and security

## A typical layout

```text
                         Internet
                            │
                     Internet Gateway
                            │
 ┌──────────────── VPC 10.20.0.0/16 ─────────────────────┐
 │  AZ a                         AZ b                     │
 │  ┌─ public 10.20.1.0/24 ─┐    ┌─ public 10.20.2.0/24 ─┐ │
 │  │ ALB, NAT GW, bastion  │    │ ALB                   │ │
 │  └───────────┬───────────┘    └───────────┬───────────┘ │
 │  ┌─ private 10.20.11.0/24┐    ┌─ private 10.20.12.0/24┐ │
 │  │ app servers, RDS      │    │ app servers, RDS std. │ │
 │  └───────────────────────┘    └───────────────────────┘ │
 └─────────────────────────────────────────────────────────┘
```

This is exactly what I build with Terraform in [session 19](../../../19_Cloud_Terraform_Action/README.md).

## Hands-on (LocalStack)
CLI pointed at LocalStack 3.8 through `AWS_ENDPOINT_URL` (setup on the [IAM page](../01-iam/README.md)). I built a small VPC by hand, which shows how many separate API calls a "simple" network needs. The commands ran one after another in the same shell, so `$VPC`, `$PUB` etc. carry over.

```text
$ VPC=$(aws ec2 create-vpc --cidr-block 10.50.0.0/16 --query Vpc.VpcId --output text); echo $VPC
vpc-27349d5f

$ PUB=$(aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.50.1.0/24 --availability-zone ap-south-1a --query Subnet.SubnetId --output text); echo $PUB
subnet-56f2c46e

$ PRIV=$(aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.50.11.0/24 --availability-zone ap-south-1a --query Subnet.SubnetId --output text); echo $PRIV
subnet-87274f32

$ aws ec2 describe-subnets --subnet-ids $PUB $PRIV --query 'Subnets[].[SubnetId,CidrBlock,AvailableIpAddressCount]' --output text
subnet-56f2c46e	10.50.1.0/24	251
subnet-87274f32	10.50.11.0/24	251

$ IGW=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text); echo $IGW
igw-ab651a9f

$ aws ec2 attach-internet-gateway --vpc-id $VPC --internet-gateway-id $IGW

$ RT=$(aws ec2 create-route-table --vpc-id $VPC --query RouteTable.RouteTableId --output text); echo $RT
rtb-467f669e

$ aws ec2 create-route --route-table-id $RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW --query Return
true

$ aws ec2 associate-route-table --route-table-id $RT --subnet-id $PUB --query AssociationId --output text
rtbassoc-ed615644

$ aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC --query 'RouteTables[].[RouteTableId,Routes[].DestinationCidrBlock|join(`,`,@),Routes[].GatewayId|join(`,`,@)]' --output table
------------------------------------------------------------------
|                       DescribeRouteTables                      |
+--------------+--------------------------+----------------------+
|  rtb-483290ff|  10.50.0.0/16            |  local               |
|  rtb-467f669e|  10.50.0.0/16,0.0.0.0/0  |  local,igw-ab651a9f  |
+--------------+--------------------------+----------------------+
```

- `251` available IPs per /24 confirms the 5 reserved addresses.
- `rtb-483290ff` is the **main** route table that AWS created with the VPC. It only has `local`. The private subnet uses it, so it has no way out.
- `rtb-467f669e` is my public route table. The extra `0.0.0.0/0 → igw` route is literally the only thing that makes `10.50.1.0/24` "public".

Then a NAT gateway in the public subnet:

```text
$ EIP=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text); echo $EIP
eipalloc-2cbb7921

$ NAT=$(aws ec2 create-nat-gateway --subnet-id subnet-56f2c46e --allocation-id $EIP --query NatGateway.NatGatewayId --output text); echo $NAT
nat-8beefd68c6ec85bd9

$ aws ec2 describe-nat-gateways --nat-gateway-ids $NAT --query 'NatGateways[].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output text
nat-8beefd68c6ec85bd9	available	subnet-56f2c46e	127.49.116.102
```

LocalStack accepted the NAT gateway and marked it `available` immediately (real AWS takes a minute or two in `pending`). The "public" IP `127.49.116.102` is a fake value from the emulator. No packets are actually routed. I deleted all of these demo resources afterwards.

## Common use cases
Isolating environments (dev/test/prod in separate VPCs), three-tier web apps (public LB / private app / private DB), private EKS clusters, hybrid networking to an office or data centre over VPN or Direct Connect, and keeping databases completely unreachable from the internet.
