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

## Initial setup through CI/CD

1. Create the chosen subdomain in DuckDNS and rotate its token if it has ever
   been exposed.
2. In the ignored `.github/deployment-config/operator.env`, set:

   ```dotenv
   PROD_ENABLE_DUCKDNS=true
   PROD_ENABLE_LETSENCRYPT=true
   PROD_DUCKDNS_SUBDOMAIN=your-local-ai-assistant
   PROD_LETSENCRYPT_EMAIL=operator@example.com
   ```

3. Run `./scripts/sync_github_environment.sh prod`. The script creates or
   updates the protected GitHub environment, writes non-secret deployment
   configuration, and prompts for `DUCKDNS_TOKEN`. It stores that token only as
   the GitHub `prod` environment secret.
4. Run **Controlled deployment** with `environment=prod` and
   `operation=deploy`. The workflow first creates the Global Accelerator and
   an HTTP-only ALB path, updates DuckDNS, issues and imports the certificate,
   then applies the final HTTPS listener configuration. HTTP redirects to HTTPS
   at the ALB; Nginx remains private on port `80`.

The workflow stores the certificate ARN and accelerator IP in Parameter Store
for future deploys and renewals. No private key is stored in Terraform state.

## Recovery and rollback

If DNS update or certificate issuance fails, the initial HTTP-only deployment
can remain reachable through the ALB while you correct the DuckDNS token,
subdomain, or ACME email. Do not manually add a placeholder certificate ARN.

1. Correct the setting in `operator.env` and rerun
   `./scripts/sync_github_environment.sh prod` to update the GitHub environment
   and, when prompted, rotate the token.
2. Run controlled production `deploy` again. It detects the missing ACM ARN and
   retries the bootstrap issuance path.
3. If a newly imported certificate causes a problem, restore the previously
   working ACM ARN in Parameter Store and rerun `deploy`; then investigate the
   certificate and DNS logs before retrying renewal.

Never remove the Global Accelerator or its Parameter Store values by hand while
the workflow manages the endpoint; reconcile those resources through Terraform
and the controlled workflow.

## Automated renewal

The synchronization script configures the required non-secret GitHub variables:

| Variable | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Bootstrap deployment-role ARN |
| `DUCKDNS_SUBDOMAIN` | Label without `.duckdns.org` |
| `LETSENCRYPT_EMAIL` | ACME account email |

`Renew DuckDNS Let's Encrypt certificate` runs monthly and can also be started
manually. It retrieves the managed values from AWS Parameter Store. CloudWatch
raises an alarm if the certificate has fewer than 30 days remaining.

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
