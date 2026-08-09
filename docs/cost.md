# Cost estimate and GPU selection

Estimate date: **August 10, 2026**. Region: **Asia Pacific (Mumbai),
`ap-south-1`**. Prices exclude taxes, discounts, Savings Plans, data transfer,
model download traffic, CloudWatch ingestion, ECR storage, snapshots, and
public IPv4 charges. Always confirm with the [AWS Pricing Calculator](https://calculator.aws/).

## Baseline monthly estimate

Assumes 730 hours per month and low ALB traffic.

| Resource | Development | Production HA | Approximate rate |
|---|---:|---:|---:|
| `g4dn.xlarge` | 1 × $422.67 | 2 × $422.67 | $0.579/hour |
| `t4g.small` | 1 × $8.18 | 2 × $8.18 | $0.0112/hour |
| NAT Gateway hours | 1 × $40.88 | 2 × $40.88 | $0.056/hour, plus $0.056/GB |
| Two ALB hours | about $34.89 | about $34.89 | $0.0239/ALB-hour |
| Two low-use ALB LCUs | about $11.68 | about $11.68 | $0.008/LCU-hour |
| gp3 volumes | about $23.16 | about $46.33 | $0.0912/GB-month |
| WAF base resources | Disabled | about $8 | Plus request charges |
| **Estimated baseline** | **about $542/month** | **about $1,045/month** | Before variable services |

The GPU tier dominates cost. Destroy development when it is not being used.
For a portfolio demonstration, create the environment shortly before the demo
and destroy it afterward.

## Why `g4dn.xlarge`

The instance includes one NVIDIA T4 GPU with 16 GiB VRAM, four vCPUs, 16 GiB
system memory, CUDA support, and local NVMe storage. It is a practical entry
point for quantized 3B and many 7B inference workloads and is materially less
expensive than larger multi-GPU instances.

AWS positions G4dn for cost-effective machine-learning inference. See the
[official G4 instance details](https://aws.amazon.com/ec2/instance-types/g4/).

## Alternatives

- CPU-only instances reduce cost but substantially increase response latency.
- `g5.xlarge` provides a newer A10G GPU and more VRAM but costs more and must be
  benchmarked with the selected model.
- Spot can reduce development cost, but interruption-aware model cache and
  capacity fallback are required.
- A single production GPU halves GPU spend but removes inference HA.
- Scale-to-zero is not implemented because EC2 ASGs, model warming, and
  Streamlit expectations make startup slow. Scheduled development capacity is
  a reasonable future improvement.

## Cost controls

- AWS Budget and billing alarms
- Short CloudWatch retention in development
- ECR lifecycle cleanup
- Incremental EBS snapshots and retention limits
- One NAT Gateway in development
- Environment-specific ASG capacity
- Exact model selection rather than downloading every available model
- Resource tags for project and environment allocation

NAT Gateways charge for both hours and processed data. See [AWS NAT Gateway
pricing guidance](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html).
