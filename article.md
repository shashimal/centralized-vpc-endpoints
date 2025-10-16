# Building Centralized VPC Endpoints with Cross-Account DNS Resolution on AWS

## Introduction

In multi-account AWS environments, organizations often struggle with the cost and complexity of managing VPC endpoints across numerous accounts. Each account typically needs its own set of VPC endpoints to access AWS services privately, leading to duplicated infrastructure and increased costs. This article demonstrates how to implement a centralized VPC endpoints architecture that allows multiple AWS accounts to share a single set of VPC endpoints while maintaining proper DNS resolution.

## The Challenge

Traditional VPC endpoint implementations face several challenges:

- **Cost Multiplication**: Each AWS account requires its own VPC endpoints, multiplying costs across the organization
- **Management Overhead**: Maintaining endpoints across multiple accounts increases operational complexity  
- **DNS Resolution Issues**: Cross-account VPC endpoint sharing breaks private DNS resolution
- **Network Complexity**: Establishing secure connectivity between accounts while maintaining isolation

## Solution Architecture

Our solution implements a hub-and-spoke model where:

1. **Service Provider Account** (Hub): Hosts centralized VPC endpoints and DNS infrastructure
2. **Consumer Accounts** (Spokes): Connect to shared endpoints via Transit Gateway
3. **DNS Resolution**: Route53 Resolver forwards DNS queries across accounts
4. **Resource Sharing**: AWS RAM enables secure resource sharing

### Key Components

- **VPC Endpoint Service**: Exposes the shared service
- **VPC Interface Endpoint**: Provides private connectivity (with private DNS disabled)
- **Transit Gateway**: Enables cross-account network connectivity
- **Route53 Resolver**: Handles DNS forwarding between accounts
- **Private Hosted Zone**: Resolves domain names to VPC endpoint IPs
- **AWS RAM**: Shares Transit Gateway and Resolver rules across accounts

## Implementation Deep Dive

### 1. Service Provider Account Setup

The service provider account hosts the core infrastructure:

```hcl
# Central VPC with proper DNS configuration
module "central_account_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "service-provider-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

The application infrastructure includes an EC2 instance running Apache, fronted by a Network Load Balancer:

```hcl
# Network Load Balancer for the VPC Endpoint Service
module "nlb" {
  source = "terraform-aws-modules/alb/aws"
  
  name               = "service-provider-nlb"
  load_balancer_type = "network"
  internal           = true
  
  listeners = {
    http_80 = {
      port     = 80
      protocol = "TCP"
    }
    https_443 = {
      port            = 443
      protocol        = "TLS"
      certificate_arn = aws_acm_certificate.app_acm.arn
    }
  }
}
```

### 2. VPC Endpoint Service Creation

The VPC Endpoint Service exposes the application without enabling private DNS:

```hcl
resource "aws_vpc_endpoint_service" "endpoint_service" {
  network_load_balancer_arns = [module.nlb.arn]
  acceptance_required        = false
  supported_regions          = ["ap-southeast-1"]
}

# Shared Interface Endpoint (Private DNS disabled)
resource "aws_vpc_endpoint" "shared_interface_endpoint" {
  vpc_id              = module.central_account_vpc.vpc_id
  service_name        = aws_vpc_endpoint_service.endpoint_service.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false  # Critical for cross-account sharing
  subnet_ids          = module.central_account_vpc.private_subnets
}
```

### 3. Transit Gateway for Cross-Account Connectivity

Transit Gateway enables secure network connectivity between accounts:

```hcl
resource "aws_ec2_transit_gateway" "main_tgw" {
  description = "Central TGW for cross-account VPC connectivity"
  
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
}

# Share TGW via AWS RAM
resource "aws_ram_resource_share" "central_tgw_share" {
  name                      = "central-tgw-share"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "consumer_account_association" {
  resource_share_arn = aws_ram_resource_share.central_tgw_share.arn
  principal          = local.consumer_account_id
}
```

### 4. DNS Resolution Infrastructure

The most critical component is the DNS resolution setup using Route53 Resolver:

```hcl
# Inbound Resolver Endpoint
resource "aws_route53_resolver_endpoint" "inbound_interface_endpoint_resolver" {
  name               = "inbound-interface-endpoint-resolver"
  direction          = "INBOUND"
  security_group_ids = [module.resolver_sg.security_group_id]

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[0]
  }
  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[1]
  }
}

# Outbound Resolver Endpoint  
resource "aws_route53_resolver_endpoint" "outbound_interface_endpoint_resolver" {
  name               = "outbound-interface-endpoint-resolver"
  direction          = "OUTBOUND"
  security_group_ids = [module.resolver_sg.security_group_id]

  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[0]
  }
  ip_address {
    subnet_id = module.central_account_vpc.private_subnets[1]
  }
}

# Resolver Rule for DNS Forwarding
resource "aws_route53_resolver_rule" "forward_to_inbound" {
  name                 = "interface-endpoint-traffic-forward-to-inbound"
  domain_name          = local.app_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound_interface_endpoint_resolver.id

  dynamic "target_ip" {
    for_each = toset([
      for ip in aws_route53_resolver_endpoint.inbound_interface_endpoint_resolver.ip_address : ip.ip
    ])
    content {
      ip = target_ip.value
    }
  }
}
```

### 5. Private Hosted Zone Configuration

The private hosted zone resolves the domain to the VPC endpoint:

```hcl
# Private Hosted Zone
resource "aws_route53_zone" "phz" {
  name = local.app_domain

  vpc {
    vpc_id = module.central_account_vpc.vpc_id
  }
}

# Alias record pointing to VPC Interface Endpoint
resource "aws_route53_record" "shared_vpc_endpoint_record" {
  zone_id = aws_route53_zone.phz.zone_id
  name    = local.app_domain
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.shared_interface_endpoint.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.shared_interface_endpoint.dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }
}
```

### 6. Consumer Account Configuration

Consumer accounts connect to the shared infrastructure:

```hcl
# Consumer VPC
module "consumer_account_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  providers = {
    aws = aws.consumer-account
  }
  
  name = "consumer-vpc"
  cidr = "20.0.0.0/16"
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Accept RAM shares and associate resolver rule
resource "aws_route53_resolver_rule_association" "forward_to_inbound_vpc_assoc" {
  provider = aws.consumer-account

  resolver_rule_id = aws_route53_resolver_rule.forward_to_inbound.id
  vpc_id           = module.consumer_account_vpc.vpc_id
}
```

## DNS Resolution Flow

The DNS resolution process follows these steps:

1. **Consumer Lambda** makes HTTPS call to `app.duleendra.com`
2. **Local DNS** in consumer VPC receives the query
3. **Resolver Rule** (shared via RAM) forwards query to outbound resolver
4. **Outbound Resolver** forwards to inbound resolver in service provider VPC
5. **Inbound Resolver** queries the private hosted zone
6. **Private Hosted Zone** returns VPC interface endpoint IP
7. **Response** travels back through the resolver chain
8. **Consumer Lambda** receives IP and makes HTTPS request via Transit Gateway

## Testing and Validation

The implementation includes Lambda functions in both accounts for testing:

```javascript
// Lambda test function
import https from 'https';

export const handler = async () => {
    const url = 'https://app.duleendra.com';

    const data = await new Promise((resolve, reject) => {
        const req = https.get(url, (res) => {
            let body = '';
            res.on('data', (chunk) => (body += chunk));
            res.on('end', () => resolve(body));
        });
        req.on('error', reject);
    });

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'HTTP call success',
            responseText: data,
        }),
    };
};
```

## Security Considerations

### Network Security
- All traffic flows through private subnets
- Security groups restrict access to necessary ports only
- Transit Gateway provides isolated network connectivity

### DNS Security
- Private hosted zones prevent DNS leakage
- Resolver endpoints use security groups for access control
- Cross-account sharing uses AWS RAM for secure resource access

### Access Control
- IAM roles and policies control resource access
- VPC endpoint policies can further restrict access
- Cross-account roles enable secure Terraform deployment

## Cost Benefits

This architecture provides significant cost savings:

- **Shared Infrastructure**: One set of VPC endpoints serves multiple accounts
- **Reduced NAT Gateway Costs**: Private connectivity eliminates internet routing
- **Consolidated Management**: Single point of management reduces operational overhead
- **Scalable Design**: Easy to add new consumer accounts without duplicating infrastructure

## Operational Benefits

### Centralized Management
- Single service provider account manages all VPC endpoints
- Consistent configuration across all consumer accounts
- Simplified monitoring and logging

### Scalability
- Easy to onboard new consumer accounts
- Horizontal scaling through additional availability zones
- Load balancing distributes traffic efficiently

### Reliability
- Multi-AZ deployment ensures high availability
- Health checks monitor endpoint status
- Automatic failover capabilities

## Deployment Guide

### Prerequisites
1. Two or more AWS accounts with appropriate IAM permissions
2. Cross-account IAM roles configured for Terraform
3. Domain registered in Route53 (optional, for HTTPS)

### Deployment Steps
1. **Deploy Service Provider Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configure Cross-Account Access**
   - Set up cross-account IAM roles
   - Configure AWS provider aliases

3. **Deploy Consumer Account Resources**
   - Accept RAM resource shares
   - Create VPC and Transit Gateway attachments

4. **Test Connectivity**
   - Deploy Lambda test functions
   - Verify DNS resolution and network connectivity

## Troubleshooting Common Issues

### DNS Resolution Problems
- Verify resolver rule association in consumer VPCs
- Check security group rules for DNS traffic (TCP/UDP 53)
- Ensure private hosted zone is properly configured

### Network Connectivity Issues
- Verify Transit Gateway route tables
- Check VPC route tables for proper routing
- Validate security group rules allow required traffic

### VPC Endpoint Issues
- Confirm VPC endpoint service is active
- Verify Network Load Balancer target health
- Check VPC endpoint security group configuration

## Future Enhancements

### Multi-Region Support
- Deploy resolver endpoints in multiple regions
- Implement cross-region Transit Gateway peering
- Configure regional failover mechanisms

### Advanced Monitoring
- CloudWatch metrics for endpoint usage
- VPC Flow Logs for traffic analysis
- AWS X-Ray for distributed tracing

### Automation
- AWS Config rules for compliance monitoring
- Lambda functions for automated scaling
- EventBridge integration for event-driven operations

## Conclusion

This centralized VPC endpoints architecture demonstrates how to effectively share AWS services across multiple accounts while maintaining security, reducing costs, and simplifying management. The combination of VPC endpoints, Transit Gateway, and Route53 Resolver creates a robust, scalable solution for multi-account AWS environments.

The implementation showcases several AWS best practices:
- Infrastructure as Code using Terraform
- Cross-account resource sharing with AWS RAM
- Private networking with VPC endpoints
- DNS resolution with Route53 Resolver
- Security through least-privilege access

Organizations implementing this pattern can expect significant cost savings, reduced operational overhead, and improved security posture while maintaining the flexibility and isolation benefits of multi-account architectures.

## Resources

- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/)
- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [Route53 Resolver Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver.html)
- [AWS RAM Documentation](https://docs.aws.amazon.com/ram/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

*This article is based on a real-world implementation using Terraform and AWS services. The complete source code is available in the project repository.*