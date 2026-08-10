# DuckDNS and Let's Encrypt HTTPS

This optional path gives the public ALB a DuckDNS hostname and a Let's Encrypt
certificate without putting a private key in Terraform state or on an EC2
instance.

![DuckDNS, Global Accelerator, Let's Encrypt, and ACM flow](domain-tls-flow.svg)

## Why the certificate is imported into ACM

TLS terminates at the public Application Load Balancer. Installing Certbot only
on the private Nginx instances would not provide HTTPS to clients because the
ALB must present the public certificate. The issuance script therefore uses a
DuckDNS DNS-01 challenge and imports the resulting certificate into AWS
Certificate Manager in `ap-south-1`.

ACM does not automatically renew imported certificates. The optional monthly
workflow reissues the certificate and reimports it using the same ARN, so the
ALB association remains unchanged.

## Initial setup

1. Create the chosen subdomain in DuckDNS and keep its token private.
2. Store the plain token in Secrets Manager using the required name prefix:

   ```bash
   aws secretsmanager create-secret \
     --region ap-south-1 \
     --name local-ai-assistant/duckdns-token \
     --secret-string 'YOUR_DUCKDNS_TOKEN'
   ```

3. For the first Terraform apply, temporarily use HTTP while creating the
   Global Accelerator:

   ```hcl
   enable_https      = false
   enable_duckdns    = true
   duckdns_subdomain = "your-local-ai-assistant"
   ```

4. Apply the environment and retrieve the primary static address:

   ```bash
   duckdns_ip=$(terraform -chdir=terraform/environments/prod output -raw duckdns_ipv4)
   export DUCKDNS_TOKEN='YOUR_DUCKDNS_TOKEN'
   ./scripts/update_duckdns.sh your-local-ai-assistant "$duckdns_ip"
   ```

5. Install `certbot`, then issue and import the initial certificate:

   ```bash
   certificate_arn=$(./scripts/issue_letsencrypt_duckdns.sh \
     you@example.com your-local-ai-assistant)
   ```

6. Set `enable_https = true` and `certificate_arn` to the returned ARN, then
   review and apply the production plan again. HTTP redirects to HTTPS at the
   ALB; Nginx remains private on port `80`.

## Automated renewal

Configure these variables in the protected GitHub `prod` environment:

| Variable | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Bootstrap deployment-role ARN |
| `DUCKDNS_SECRET_ARN` | Secrets Manager ARN created above |
| `DUCKDNS_SUBDOMAIN` | Label without `.duckdns.org` |
| `DUCKDNS_IPV4` | Terraform `duckdns_ipv4` output |
| `LETSENCRYPT_EMAIL` | ACME account email |
| `ACM_CERTIFICATE_ARN` | Imported certificate ARN |

`Renew DuckDNS Let's Encrypt certificate` runs monthly and can also be started
manually. CloudWatch raises an alarm if the certificate has fewer than 30 days
remaining.

## Availability limitation

Global Accelerator supplies two stable IPv4 addresses, but the DuckDNS update
API accepts one IPv4 address for a subdomain. This integration publishes the
first anycast address while retaining the ALB and application failure domains.
For redundant DNS publication of both accelerator addresses, use Route 53 or
another DNS provider supporting multiple A records.

DuckDNS documents both A-record and TXT-record updates in its
[official API specification](https://www.duckdns.org/spec.jsp). Let's Encrypt
documents why DNS-01 is appropriate for automated DNS providers in its
[challenge guide](https://letsencrypt.org/docs/challenge-types/). Imported ACM
certificates require operator-managed renewal according to the
[AWS ACM documentation](https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html).
