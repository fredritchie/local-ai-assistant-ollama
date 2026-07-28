# Ansible Branch: Deployment and Installation Interview Guide

These 200 interview-ready questions and answers are based on the deployment
and installation implementation in the repository's `ansible` branch. They
focus on Terraform, AWS, Ansible, SSH, Docker, systemd, CI, security, and
operations. Application UI, inference-runtime, and model internals are
intentionally excluded.

## Architecture and deployment strategy

### 1. Give me an overview of the repository's deployment architecture.

Terraform creates the AWS infrastructure, including the VPC, subnet, routing,
security group, IAM resources, SSH key when required, and EC2 instance. The
wrapper then creates an Ansible inventory from Terraform outputs. Ansible
connects over SSH, installs system dependencies, checks out the application,
configures either a native or Docker runtime, installs a systemd service, and
verifies application health.

### 2. Why does this project use Terraform and Ansible together?

They manage different layers. Terraform declaratively manages cloud resources
and their lifecycle, while Ansible manages the operating system and application
configuration inside the VM. This separation makes infrastructure changes
predictable and server configuration repeatable.

### 3. Where does Terraform's responsibility end and Ansible's responsibility begin?

Terraform stops after producing a reachable VM and its supporting AWS
resources. It exposes connection and deployment values as outputs. Ansible
starts at the host boundary: it installs packages, creates users and
directories, retrieves source code, installs dependencies, renders services,
and validates readiness.

### 4. What problems would arise if Terraform also handled detailed server configuration?

Terraform provisioners do not model package and file state as well as Ansible,
are harder to rerun independently, and often mix infrastructure lifecycle with
application failures. A configuration error could make an otherwise valid
infrastructure apply fail or require replacing resources unnecessarily.

### 5. Why is Ansible more suitable than Terraform `remote-exec` provisioners for installing the application?

Ansible provides purpose-built modules, variable precedence, handlers,
conditionals, privilege escalation, inventory management, and idempotency.
`remote-exec` mainly runs imperative commands and offers much weaker
configuration-state management.

### 6. Walk me through the complete deployment flow.

`deploy_with_ansible.sh` validates local tools, initializes and applies
Terraform, reads the instance IP and SSH-key path, scans the SSH host key,
generates inventory, waits for connectivity, and runs the playbook. The
playbook validates the host, installs dependencies, deploys the selected Git
revision, configures the runtime and systemd, starts the service, and polls its
local HTTP health endpoint.

### 7. Which deployment steps execute on the control machine, and which execute on EC2?

Terraform, SSH host-key scanning, inventory generation, and Ansible orchestration
run on the control machine. Package installation, user and directory creation,
Git checkout, dependency installation, image building, systemd configuration,
and local health checks run on EC2.

### 8. What dependencies must exist on the control machine?

The combined wrapper requires Terraform, Ansible Core, `ansible-playbook`,
OpenSSH tools including `ssh-keyscan`, valid AWS credentials, and network
access to AWS and the instance. Git and Python are also useful for repository
development and CI validation.

### 9. What dependencies must the target server be able to download?

The server needs outbound access to Debian package repositories, the configured
HTTPS Git repository, Python package sources in native mode, and base-image or
package registries required by Docker builds.

### 10. What assumptions does the deployment make about the target operating system?

The Ansible role explicitly requires the Debian OS family, `apt`, Python 3, and
systemd. It also assumes the remote account can use passwordless sudo and that
the host is reachable through SSH.

### 11. Why does the playbook gather facts before executing the role?

Facts provide values such as `ansible_facts.os_family`. The role uses them to
reject unsupported hosts before making changes and can use them for future
platform-specific decisions.

### 12. How does the repository support native and Docker deployment modes?

The `app_deployment_mode` variable selects conditional tasks and template
branches. Native mode creates a Python virtual environment and runs the
application directly. Docker mode installs Docker, builds an image, and runs a
named container under systemd.

### 13. What are the trade-offs between native and Docker deployment?

Native mode is simpler and has less runtime overhead, but the host directly
owns Python dependencies. Docker provides a reproducible filesystem and
stronger dependency isolation, but adds image-build time, daemon management,
container networking, and another troubleshooting layer.

### 14. How would you deploy the application to multiple servers?

Add all hosts to the `app_servers` inventory group or use dynamic AWS
inventory, then run the same play. I would also introduce load balancing,
rolling-update controls such as `serial`, per-host health validation, and
shared environment-specific variables.

### 15. How would you support development, staging, and production?

Use separate state backends or state keys, variable files, inventory groups,
and AWS accounts where possible. Pin production to immutable commits, apply
stricter CIDRs and IAM, and promote the same tested artifact through each
environment.

## Terraform configuration and state

### 16. What minimum Terraform version is required, and where is it enforced?

`terraform/versions.tf` sets `required_version = ">= 1.6.0"`. Terraform checks
this constraint during initialization and normal commands.

### 17. Which Terraform providers are used?

The AWS provider creates cloud infrastructure, the TLS provider generates an
optional SSH key pair, and the local provider writes the generated private key
to a local file.

### 18. Why are upper bounds defined for provider versions?

Upper bounds prevent an automatic upgrade to a future major version that may
contain breaking changes. The ranges still permit compatible fixes and minor
features within the tested major versions.

### 19. What is the purpose of `.terraform.lock.hcl`?

It records the provider versions and checksums selected by `terraform init`.
This makes provider installation reproducible across engineers and CI.

### 20. Should `.terraform.lock.hcl` be committed?

Yes, for a root deployment module it should normally be committed. It gives
reviewers visibility into provider upgrades and keeps local and CI executions
on consistent provider builds.

### 21. What happens during `terraform init`?

Terraform initializes the working directory, downloads required providers,
checks version constraints, prepares the configured backend, and updates or
honors the dependency lock file.

### 22. Why does the wrapper pass `-input=false` to `terraform init`?

It prevents initialization from waiting for interactive input, which makes the
wrapper and CI behavior predictable. Missing required backend values fail
instead of hanging.

### 23. Where is Terraform state stored by default?

Without an enabled backend file, it is stored locally in
`terraform/terraform.tfstate`, with backups in the same directory.

### 24. Why is local state unsuitable for shared production use?

It has no coordinated locking, centralized access control, durable backup, or
safe collaboration workflow. Losing or copying the file can break resource
management or expose sensitive values.

### 25. How does `backend.tf.example` configure remote state?

It shows an S3 backend with a bucket, object key, AWS region, server-side
encryption, and S3-native lockfile support. The operator must create the bucket
and copy the example to an active backend file.

### 26. What does `use_lockfile = true` provide?

It enables state locking through an S3 lock file. A second Terraform operation
cannot safely write the same state while another operation owns the lock.

### 27. Why should state-bucket versioning be enabled?

Versioning makes accidental deletion or corruption recoverable by retaining
older state objects. It complements locking and encryption but does not replace
access control.

### 28. Why are backend configuration files ignored by Git?

They can contain environment-specific bucket names, keys, regions, or other
deployment details. Ignoring them reduces accidental coupling and disclosure,
although reusable non-secret backend structure can also be committed in some
organizations.

### 29. How would you migrate local state into S3?

Create and secure the bucket, activate the backend configuration, and run
`terraform init -migrate-state`. I would back up local state first and confirm
the resource list with `terraform state list` afterward.

### 30. What sensitive information can appear in this project's state?

The generated SSH private key is stored in state because it is an attribute of
the TLS resource. State also contains resource identifiers, IP addresses, IAM
details, and configuration values that may help an attacker map the environment.

### 31. Why is ignoring the generated key in Git insufficient?

Git ignore only prevents normal source commits. The private key remains on
disk and in Terraform state, so filesystem permissions, encrypted storage,
secure state access, backup controls, and key rotation are still required.

### 32. How would you protect remote state?

Use TLS, S3 server-side encryption with a managed KMS key, bucket versioning,
public-access blocking, least-privilege bucket and KMS policies, access
logging, lock files, and tightly controlled CI roles.

### 33. How would you restrict state access with IAM?

Grant the deployment role access only to the specific bucket and state-key
prefix, plus the required KMS operations. Separate read, plan, and apply
permissions where practical and deny public or cross-account access by default.

### 34. What happens if two engineers apply against the same state?

With locking, one operation fails or waits rather than writing concurrently.
Without locking, both may read stale state and overwrite each other's results,
causing drift or state corruption.

### 35. Why generate and apply a saved plan?

A saved plan ensures the reviewed actions are the actions applied, assuming no
external changes invalidate it. It also creates a useful approval boundary in
CI/CD.

### 36. How do `validate`, `plan`, and `apply` differ?

`validate` checks Terraform configuration syntax and internal consistency.
`plan` compares configuration, state, and provider data to propose changes.
`apply` performs the proposed resource changes and updates state.

### 37. Why does CI use `terraform init -backend=false`?

CI only needs providers and module initialization for static validation. It
should not access, lock, migrate, or modify a real environment's remote state.

### 38. What does `terraform fmt -check -recursive` verify?

It checks that every Terraform file below the directory uses canonical
formatting. It exits nonzero when formatting changes would be required.

### 39. How would you detect configuration drift?

Run scheduled `terraform plan` operations against the correct remote state and
credentials, then alert on nonempty plans. Cloud configuration tools can add
independent change detection, but Terraform remains the reconciliation source.

### 40. How would you import a manually created resource?

First add a matching resource block, then use an `import` block or
`terraform import` with the AWS resource ID. Run a plan and adjust the
configuration until Terraform proposes no unintended replacement or mutation.

## Terraform variables and validation

### 41. How is the AWS region selected?

The AWS provider uses `var.aws_region`, which defaults to `ap-south-1`. It can
be overridden through a variable file, command-line variable, or supported
Terraform environment variable.

### 42. What are `project_name` and `environment` used for?

They provide consistent names and tags. `project_name` forms resource name
prefixes, while `environment` identifies the deployment lifecycle such as
production or staging.

### 43. How are default AWS tags applied?

The AWS provider has a `default_tags` block that adds `Project` and
`ManagedBy=Terraform`. Individual resources add more tags such as `Name` and
`Environment`.

### 44. Why are variable validation blocks important?

They reject unsafe or unsupported values before provisioning begins. This
provides faster feedback and documents the assumptions enforced by the stack.

### 45. How is `allowed_app_cidr` validated?

Terraform first checks that it is a valid CIDR with `cidrnetmask`, then applies
a regular expression requiring an IPv4 prefix between `/24` and `/32`.

### 46. Why permit only `/24` or narrower networks?

The restriction reduces accidental exposure to very large address ranges. It
is a guardrail, not complete authentication, and `/32` remains the safest
default for a single operator.

### 47. Why is `/32` recommended for administrative access?

A `/32` permits one public IPv4 address. This minimizes the population that can
reach an exposed port, although dynamic client IPs may require controlled
updates.

### 48. What happens if SSH is enabled without `allowed_ssh_cidr`?

The security-group lifecycle precondition fails with an explicit message.
Terraform therefore does not silently expose SSH using an unintended fallback.

### 49. Why is `allowed_ssh_cidr` nullable but `allowed_app_cidr` required?

SSH is optional and closed by default, so its CIDR is unnecessary until SSH is
enabled. The application port is always created by this stack, so its trusted
CIDR must be supplied.

### 50. How is the key-pair name validated?

A regular expression permits only letters, numbers, periods, underscores, and
hyphens. This avoids unsupported AWS names and unsafe shell or path characters.

### 51. Why is `server_configuration` limited to two values?

The resources implement exactly two supported paths: EC2 user data or external
Ansible. Rejecting other strings prevents silently creating an unconfigured
server.

### 52. What happens to user data in Ansible mode?

The EC2 resource sets `user_data` to `null`. Terraform creates the host, and
the external wrapper is responsible for waiting for SSH and executing the
Ansible role.

### 53. Why must SSH be enabled in Ansible mode?

The included Ansible workflow uses the standard SSH connection plugin. Without
an SSH key and permitted port 22, the control machine cannot reach the new
host using this implementation.

### 54. How is deployment mode validated?

Terraform uses `contains(["native", "docker"], var.deployment_mode)`. Ansible
independently asserts the same allowed values, protecting both entry points.

### 55. Why enforce a minimum root-volume size?

The selected base image, system packages, source checkout, Python environment,
Docker layers, logs, and runtime data need adequate disk space. Early
validation prevents predictable installation failures.

### 56. How is the repository URL validated?

The variable requires an HTTPS URL without whitespace or quote characters.
The Ansible role also asserts an `https://` prefix.

### 57. Why accept only an HTTPS repository URL?

It avoids insecure plaintext Git transport and simplifies noninteractive
checkout. It does not itself verify repository trust, so immutable revisions
and trusted hosting are still important.

### 58. How is the Git branch name validated?

A regular expression allows common Git-ref characters: alphanumerics, periods,
underscores, slashes, and hyphens. It blocks whitespace and shell metacharacters.

### 59. Why is a commit SHA more reproducible than a branch?

A branch can move between deployments, while a commit SHA identifies one
specific source tree. Pinning allows an exact release to be audited, reproduced,
and rolled back.

### 60. How do `repository_branch` and `repository_commit` differ?

The branch provides the normal checkout line. When a commit is supplied, the
deployment selects that immutable revision instead of relying on the branch's
current head.

## AWS networking, compute, IAM, and security

### 61. Which AWS resources does the stack create?

It creates a VPC, internet gateway, public subnet, route table and association,
security group, optional SSH key resources, IAM role and instance profile, and
an EC2 instance with an encrypted root volume.

### 62. Why create a dedicated VPC?

It gives the project an isolated address space, routing table, and security
boundary. The trade-off is that the stack does not reuse enterprise networking,
central egress controls, or existing private connectivity.

### 63. Why enable VPC DNS support and hostnames?

DNS support allows instances to resolve external package and Git endpoints.
DNS hostnames allow public DNS naming for instances that receive public
addresses.

### 64. Why is the instance in a public subnet?

The current design needs direct inbound access from trusted CIDRs and direct
outbound installation access without a NAT gateway. A production alternative
would use a private subnet, load balancer, managed egress, and Session Manager.

### 65. How does the subnet reach the internet?

Its associated route table sends `0.0.0.0/0` to the VPC internet gateway, and
the instance receives a public IP address.

### 66. What is the internet gateway's role?

It provides the VPC route target for internet traffic and enables communication
between public IPv4 addresses and resources in appropriately routed public
subnets.

### 67. Why enable automatic public IP assignment?

It gives the instance an address for the current direct-access and SSH design.
Without it, an alternative such as a load balancer, VPN, bastion, NAT, or
Session Manager-only workflow would be needed.

### 68. How is the availability zone selected?

Terraform queries the zones offering the configured instance type, converts
the result to a list, sorts it, and selects the first entry for the public
subnet.

### 69. What happens if no availability zone offers the instance type?

Indexing the empty sorted list fails during planning. A clearer implementation
could add a precondition with an explicit capacity or regional-support message.

### 70. Why sort the availability zones?

Provider results may not have a stable order. Sorting makes the chosen zone
deterministic and prevents unnecessary subnet replacement caused only by
ordering changes.

### 71. How is the AMI selected?

Terraform reads the current AMI ID from an AWS public SSM parameter for the
specified Ubuntu-based image family and passes that value to the EC2 resource.

### 72. Why use an SSM AMI parameter instead of a hard-coded ID?

AMI IDs vary by region and become outdated. A maintained parameter provides a
discoverable current image without manually updating the configuration.

### 73. What risk comes from selecting the latest AMI?

A newly published image may introduce package, driver, boot, or compatibility
changes without a source-code change. Production should resolve, test, approve,
and pin the resulting AMI ID.

### 74. Why use a `gp3` root volume?

`gp3` provides general-purpose SSD performance with independently configurable
capacity and performance at a predictable cost. It is a sensible default for
OS, dependencies, images, and logs.

### 75. How is root-volume encryption enabled?

The EC2 `root_block_device` sets `encrypted = true`. Without an explicit KMS
key, AWS uses the account's applicable default EBS key.

### 76. What does `delete_on_termination = true` mean?

AWS deletes the root EBS volume when the instance terminates. This avoids
orphaned storage costs but means durable data must live elsewhere.

### 77. How would you preserve important data?

Store it in a managed durable service or a separately managed encrypted EBS
volume with backups and `delete_on_termination = false`. Test snapshot and
restore procedures rather than relying on instance survival.

### 78. Why is IMDSv2 required?

The metadata configuration requires session tokens for metadata requests.
This provides stronger protection than unauthenticated IMDSv1 access.

### 79. What threats does IMDSv2 reduce?

Its token and hop-limit design makes several server-side request forgery,
open-proxy, and misconfigured network-appliance paths harder to use for
stealing instance-role credentials.

### 80. What inbound traffic is permitted?

The application port is allowed only from `allowed_app_cidr`. TCP 22 is added
only when SSH is enabled and is limited to `allowed_ssh_cidr`.

### 81. Why is SSH ingress a dynamic block?

The block must not exist when SSH is disabled. Iterating over either a
one-element or empty collection conditionally emits the ingress rule.

### 82. What outbound traffic is allowed?

The security group permits all protocols and destinations over IPv4. This
supports installation and source retrieval but is broader than ideal.

### 83. Why is outbound internet access needed?

The host retrieves OS packages, repository content, Python dependencies,
Docker base layers, and installation artifacts during configuration.

### 84. Why is unrestricted outbound access risky?

A compromised process could contact arbitrary command-and-control or
exfiltration endpoints. Broad egress also makes dependency provenance harder
to control.

### 85. How could egress be restricted?

Use private package mirrors, artifact repositories, VPC endpoints where
supported, an allow-listing proxy or firewall, and prebuilt images. Then reduce
security-group and network-firewall rules to approved destinations.

### 86. Why use `create_before_destroy` on the security group?

It allows Terraform to create a replacement before deleting the old group,
reducing interruption and avoiding dependency ordering problems during changes
that force replacement.

### 87. What is the EC2 IAM role for?

It gives the instance temporary AWS credentials for authorized services. In
this repository its principal purpose is registering with Systems Manager for
remote administration.

### 88. How does the trust policy work?

The policy permits the EC2 service principal to call `sts:AssumeRole`. The
instance receives the role through an IAM instance profile.

### 89. Why attach `AmazonSSMManagedInstanceCore`?

It grants the managed instance the standard permissions required to register,
receive commands, and communicate with AWS Systems Manager services.

### 90. What advantages does Session Manager have over SSH?

It can avoid inbound port 22 and long-lived user-managed keys, uses IAM for
authorization, and can integrate with audit logging. It still requires secure
IAM, a functioning agent, and outbound access to SSM endpoints.

## SSH key and access management

### 91. When does Terraform create an SSH key?

The TLS key, AWS key pair, and local private-key file all use a conditional
count and exist only when `enable_ssh` is true.

### 92. Why use `count` on the SSH resources?

It conditionally creates zero or one resource while keeping references aligned
through index zero. This prevents creating and storing key material when SSH
is not needed.

### 93. Why generate a 4096-bit RSA key?

It provides broad SSH compatibility and a strong key size. An organization
could instead standardize on Ed25519 where all clients and policies support it.

### 94. How is the public key registered?

Terraform takes `public_key_openssh` from the TLS resource, trims whitespace,
and supplies it to an `aws_key_pair` resource associated with the instance.

### 95. How is the private key written locally?

`local_sensitive_file` writes the TLS resource's PEM private key beneath the
Terraform module directory using the configured key name.

### 96. Why set private-key mode to `0600`?

Only the owning user can read or modify it. OpenSSH commonly rejects private
keys that are accessible by other users.

### 97. Where is the key stored?

The local file is stored in the `terraform` directory by default, while the
same private material also exists in Terraform state.

### 98. What if Terraform state is compromised?

An attacker could recover the private key and use it while the matching public
key and network path remain valid. The response should include revoking the
EC2 key pair or replacing instances, rotating access, and investigating state
access.

### 99. How would you use an existing managed key?

Replace the TLS and local-file resources with an input referencing an existing
EC2 key-pair name, or use short-lived certificate-based SSH. Keep private
material outside Terraform state.

### 100. How could port 22 be removed while retaining Ansible?

Use Ansible's AWS Systems Manager connection support or execute Ansible from a
private runner with VPC connectivity. The inventory, credentials, required
collections, S3 transfer mechanism, and IAM permissions would need updating.

### 101. What is required for Ansible over Systems Manager?

Typically an appropriate Ansible AWS collection and connection plugin, AWS CLI
and Session Manager support, instance registration, IAM permissions, a suitable
artifact-transfer path, and inventory variables identifying the instance and
region.

### 102. Why enable strict SSH host-key checking?

It verifies that the server presents the expected key and helps prevent
man-in-the-middle attacks or accidental connection to a different host.

### 103. How does `ssh-keyscan` fit into the wrapper?

The wrapper repeatedly scans the new public IP until SSH responds, stores the
hashed host key in a dedicated file, and configures Ansible to use that file
with strict checking.

### 104. What limitation does first-use scanning have?

The scan proves only that a host answered at that address. If the first
connection is intercepted, the wrapper can record the attacker's key and trust
it afterward.

### 105. How could the host key be verified through a trusted channel?

Generate or publish the host key during image creation or cloud initialization,
store its fingerprint in a signed AWS channel such as a protected parameter,
and compare it before connecting. Another option is SSH host certificates
signed by a trusted CA.

## Terraform-to-Ansible wrapper

### 106. What is `deploy_with_ansible.sh` responsible for?

It joins the infrastructure and configuration phases: tool validation,
Terraform initialization and apply, output extraction, key permissions,
SSH-readiness detection, secure temporary inventory generation, Ansible
connectivity validation, playbook execution, and completion reporting.

### 107. What does `set -euo pipefail` do?

`-e` exits on an unhandled failure, `-u` rejects unset variables, and
`pipefail` makes a pipeline fail when any component fails. Together they reduce
silent partial deployments.

### 108. How does the script determine its directories?

It resolves the directory containing the script, then derives `terraform` and
`ansible` paths beneath it. This avoids dependence on the caller's current
working directory.

### 109. Why use `BASH_SOURCE[0]`?

It identifies the script file even when it is invoked through a relative or
absolute path. `$PWD` would identify the caller's directory instead.

### 110. Which commands does the wrapper verify?

It requires `terraform`, `ansible`, `ansible-playbook`, and `ssh-keyscan`.
Failure is immediate with a clear missing-command message.

### 111. Why verify both `ansible` and `ansible-playbook`?

The wrapper uses the `ansible` ad hoc command for
`wait_for_connection` and `ansible-playbook` for role execution. Both entry
points must be available.

### 112. How are extra Terraform options forwarded?

The script expands `"$@"` into the `terraform apply` command. Quoting preserves
each original argument as a separate value.

### 113. Why force `server_configuration=ansible`?

It ensures EC2 is created without the alternative bootstrap taking ownership
of configuration. This avoids two configuration systems racing or duplicating
installation.

### 114. Why force `enable_ssh=true`?

The included Ansible inventory connects directly over SSH. The forced value
causes Terraform to create the key pair, permit restricted port 22, and expose
the key path.

### 115. Can user options override the forced variables?

The forced `-var` arguments occur after `"$@"`, so for repeated command-line
variable assignments Terraform normally uses the final value. I would confirm
this behavior with `terraform plan` and automated wrapper tests rather than
depending on an undocumented assumption.

### 116. Why verify `server_configuration` after apply?

It is a defensive check that confirms Terraform selected the intended path
before Ansible proceeds. It catches unexpected variable precedence or
configuration drift early.

### 117. Which Terraform outputs does the wrapper consume?

It reads `server_configuration`, `public_ip`, `private_key_path`,
`ansible_variables`, and the final public application URL used in its
completion message.

### 118. How do Terraform outputs become Ansible variables?

Terraform serializes the `ansible_variables` object as JSON. The wrapper passes
that JSON to `ansible-playbook --extra-vars`, which Ansible parses into normal
variables.

### 119. Why is JSON useful for this handoff?

It preserves strings, lists, booleans, and numbers without generating a
temporary YAML file. It also avoids much of the fragile shell parsing required
for individual output values.

### 120. How does `resolve_terraform_path` work?

It returns absolute paths unchanged. Relative paths are resolved beneath the
Terraform directory after removing a leading `./`.

### 121. Why validate the private-key file?

The Terraform output alone does not guarantee that the local file is present.
The explicit check produces a clear failure before inventory generation or an
opaque SSH error.

### 122. How long does the wrapper wait for SSH?

It tries up to 60 times and sleeps ten seconds between failed attempts, with a
five-second scan timeout. The intended maximum waiting period is approximately
ten minutes plus command overhead.

### 123. How is the temporary known-hosts file used?

Each successful scan writes to a temporary file. Only a nonempty successful
result is moved into the final file, reducing the chance of leaving a partial
trusted-host file.

### 124. Why check that the scan output is nonempty?

A zero exit status or unusual network condition should not produce an empty
trust database. The size check ensures Ansible receives at least one host key.

### 125. How is the generated inventory constructed?

The script writes an `app_servers` group with one alias and sets its public IP,
Ubuntu SSH user, generated private-key path, and strict known-hosts options
inline.

### 126. Why quote paths in the inventory?

The workspace and key paths may contain spaces. Quoting prevents Ansible's INI
inventory parser from splitting a single path into multiple tokens.

### 127. What does `ansible_ssh_common_args` configure?

It tells SSH to use the deployment-specific known-hosts file and enforces
`StrictHostKeyChecking=yes` for Ansible connections.

### 128. Why assign generated files mode `0600`?

The inventory reveals connection details and a sensitive key path, while the
known-hosts file is part of connection trust. Restricting both to the current
user reduces local disclosure or modification.

### 129. Why run `wait_for_connection` first?

An open SSH port does not guarantee authentication, Python availability, or a
ready SSH session. The Ansible module validates the actual connection path
before the larger play begins.

### 130. What artifacts remain after deployment?

The generated private key, Terraform state, provider directory, generated
inventory, and generated known-hosts file remain locally. They are ignored by
Git but still require secure storage and lifecycle management.

## Ansible configuration, inventory, and playbook

### 131. What settings are in `ansible.cfg`?

It defines the default inventory, local roles directory, enabled host-key
checking, disabled retry files, automatic Python discovery without warnings,
and SSH pipelining.

### 132. Why set `inventory = inventory.ini`?

It lets an operator run `ansible-playbook playbook.yml` from the Ansible
directory without repeatedly passing `-i`. The generated wrapper inventory
still overrides it explicitly.

### 133. What does `roles_path = roles` do?

It tells Ansible where to find the repository's local
`local_ai_assistant` role when the playbook refers to it by name.

### 134. Why explicitly enable host-key checking?

It makes server identity verification a deliberate security property rather
than relying on a user's global Ansible or SSH configuration.

### 135. Why disable retry files?

Retry files can clutter the repository and contain hostnames from failed
runs. Modern reruns can target failed hosts directly from output or CI data.

### 136. What does `interpreter_python = auto_silent` control?

Ansible discovers a suitable remote Python interpreter automatically while
suppressing routine discovery warnings. Python still must be present for most
modules.

### 137. What is SSH pipelining?

Pipelining reduces temporary-file transfers and SSH operations by sending
module code through the existing connection. It can make playbooks noticeably
faster.

### 138. What concerns can pipelining introduce?

Some sudo configurations requiring a TTY or unusual privilege-escalation
policies can conflict with it. It also changes module transport behavior, so
it should be tested against the target's SSH and sudo hardening.

### 139. Which inventory group does the play target?

The play targets `app_servers`. The example and generated inventories both
define this group.

### 140. Which example inventory values must be changed?

The operator must replace the example IP address and verify the SSH username
and private-key path. The server's host key must also be placed in a trusted
known-hosts file.

### 141. Why must the example inventory avoid real credentials?

Committed addresses, usernames, or key locations disclose environment details,
and committed private material would be a serious breach. Examples should be
obviously non-routable placeholders.

### 142. How would you represent multiple servers?

Add one host line per server under `[app_servers]`, optionally define
group-wide variables, or use an AWS dynamic inventory plugin to select
instances by tags.

### 143. How would different SSH users be configured?

Set `ansible_user` per host in inventory, in `host_vars/<hostname>.yml`, or
through dynamic inventory composition. Shared values belong in group
variables.

### 144. Why normally run from the `ansible` directory?

Ansible discovers `ansible.cfg` from the current working context. Running
elsewhere may cause it to miss the repository inventory, roles path, host-key
policy, and pipelining setting.

### 145. What does `become: true` do?

It enables privilege escalation, normally through sudo, for tasks that manage
packages, system users, `/opt`, `/etc/systemd/system`, and system services.

### 146. Why require passwordless sudo?

The wrapper is designed for unattended execution and does not supply a become
password. Passwordless sudo lets required root tasks execute without an
interactive prompt.

### 147. What if sudo requires an interactive password?

Privilege-escalated tasks fail or hang depending on invocation. The operator
would need `--ask-become-pass`, an approved credential mechanism, or a revised
sudo policy.

### 148. How would you run with a sudo password?

Run `ansible-playbook --ask-become-pass` interactively. In automation, avoid
plain-text passwords; use an approved secrets system and a narrowly scoped
privilege policy.

### 149. Why place logic inside a role?

The playbook stays small while tasks, defaults, templates, files, and handlers
form one reusable unit. This structure supports testing and future use by other
inventories or plays.

### 150. What benefits does a role have over one large playbook?

Roles provide conventional directories, isolated defaults, reusable handlers
and templates, clearer ownership, dependency metadata if needed, and easier
testing with tools such as Molecule.

## Variables, precedence, and validation

### 151. How do `group_vars/all.yml` and role defaults differ?

Role defaults define reusable low-precedence fallback values.
`group_vars/all.yml` expresses repository-wide choices for every inventory
host and overrides those defaults.

### 152. Which value wins when both define the same variable?

The `group_vars/all.yml` value wins because inventory group variables have
higher precedence than role defaults.

### 153. Where do `--extra-vars` rank?

Extra variables have very high precedence and override role defaults,
inventory variables, and most other variable sources. That makes them suitable
for the Terraform handoff but also powerful enough to bypass local choices.

### 154. Why use extra variables instead of rewriting `group_vars`?

It avoids modifying tracked source files during deployment and preserves typed
Terraform output. Each run can supply its own values without leaving stale
configuration behind.

### 155. What is `app_repository_version` for?

It can contain an immutable tag or commit to deploy. An empty value tells the
role to use `app_repository_branch`.

### 156. How does `default(app_repository_branch, true)` behave?

The second argument makes the filter treat an empty string as absent. Therefore
an empty `app_repository_version` falls back to the configured branch.

### 157. Why configure the application user, group, and directory?

Different environments may enforce naming or filesystem standards. Variables
avoid hard-coding these choices throughout tasks and templates.

### 158. How does the role validate the OS family?

The first assertion checks
`ansible_facts.os_family == "Debian"`. Because facts were gathered, an
unsupported host fails before package installation.

### 159. Why validate variables first?

Failing before mutation avoids partially configured servers and produces a
single, intentional error for unsupported modes, URLs, values, or platforms.

### 160. What does `quiet: true` do on the assertion?

It suppresses verbose display of every successful assertion. Failures still
show the configured error message.

### 161. What happens on a Red Hat-family host?

The validation task fails immediately. Debian-specific package tasks and
assumptions are not executed.

### 162. How would you add Red Hat support?

Move platform-specific package names and tasks into OS-family includes, use
`package` where behavior is common, validate supported families, account for
SELinux and firewall rules, and test each distribution independently.

### 163. How would you organize environment variables?

Use groups such as `development`, `staging`, and `production` with separate
`group_vars` files or inventory directories. Keep reusable defaults in the
role and secrets in encrypted or external stores.

### 164. Which values belong in Ansible Vault?

Repository credentials, private registry tokens, service credentials, TLS
private keys, and any future secret environment variables. Non-secret runtime
choices do not need Vault.

### 165. How would you validate `app_install_dir`?

Assert that it is an absolute path beneath an approved prefix, reject root and
traversal-like components, and prevent overlap with sensitive system paths. For
stronger control, make the base directory fixed and configure only a safe name.

## Ansible installation and idempotency

### 166. Which base OS packages are installed?

The role installs CA certificates, curl, Git, Python 3, pip, and Python virtual
environment support. Docker is installed separately only in Docker mode.

### 167. Why does the package task use `state: present`?

It ensures each package is installed without forcing an upgrade on every run.
Already-present acceptable versions remain unchanged.

### 168. Why use `update_cache: true`?

The host needs current package metadata before installing packages, especially
on a newly created image whose cache may be absent or stale.

### 169. What does `cache_valid_time: 3600` do?

Ansible skips another package-index update when the cache was refreshed within
the last hour. This improves repeat-run speed while retaining reasonable
freshness.

### 170. When is Docker installed?

Only when `app_deployment_mode == "docker"`. Native deployments avoid the
daemon and package entirely.

### 171. How is Docker kept available?

`systemd_service` sets `enabled: true` and `state: started`, causing an
immediate start and automatic startup on future boots.

### 172. Why create a dedicated system group?

It provides a stable ownership boundary for application files and processes
without using an interactive human account.

### 173. Why create a dedicated system user?

Running the native service and Git checkout as a non-root service identity
limits the impact of an application compromise and avoids root-owned working
files.

### 174. Why use `/usr/sbin/nologin`?

The account exists to own and run a service, not for interactive access.
Disabling a login shell reduces misuse as a general-purpose SSH account.

### 175. Why disable home creation?

The role explicitly manages the application directory, so a separate home is
unnecessary. It avoids extra unmanaged files and initialization content.

### 176. Who owns the installation directory?

The configured application user and group own it. Root creates and manages the
directory's desired state, then the service account can check out and read the
application.

### 177. Why use directory mode `0755`?

The owner can write, while other users can traverse and read. If the
application contains secrets, tighter permissions such as `0750` would be more
appropriate.

### 178. Why run the Git task as the application user?

It avoids root-owned repository files and ensures later service-level
operations can access the working tree without corrective ownership changes.

### 179. How does the Git task update an existing checkout?

With `update: true`, the module fetches and checks out the configured revision
when required. It reports a change when the deployed working tree moves.

### 180. What happens to remote uncommitted files during an update?

The Git module may fail when local modifications conflict with the requested
revision unless forced behavior is configured. Production deployment
directories should be treated as immutable and not manually edited.

### 181. How would you deploy a private repository?

Use a read-only deploy key, short-lived token, or controlled artifact
distribution mechanism delivered through a secrets manager. Verify host keys,
avoid embedding credentials in URLs, and restrict credential access to the
deployment identity.

### 182. Why is an immutable commit safer than `main`?

It prevents an unreviewed branch movement from changing production during a
rerun. The exact source can be traced to CI results and restored during
rollback.

### 183. What does `app_repository_checkout.changed` mean?

It indicates that the Git task altered the deployed checkout, such as moving
to a new commit or performing the initial clone.

### 184. How does that result affect Docker builds?

The role builds when the repository changed or the requested image does not
exist. This avoids rebuilding on every idempotent run.

### 185. How is the native virtual environment created?

The role runs `python3 -m venv` as the application user and places the
environment at `.venv` inside the installation directory.

### 186. What makes virtual-environment creation idempotent?

The command uses `creates` pointing to `.venv/bin/python`. Once that file
exists, Ansible skips the command.

### 187. Why use `creates` with a command task?

The command module cannot otherwise infer whether `python3 -m venv` changed
anything. `creates` supplies a filesystem condition that makes repeat runs
predictable.

### 188. How are Python dependencies installed?

`ansible.builtin.pip` reads the checked-out `requirements.txt` and installs
packages into the configured virtual environment as the service account.

### 189. Will the pip task notice changed requirements?

Yes. The pip module evaluates the requirements against the environment and
installs or adjusts packages as needed. Reproducibility would be stronger with
fully pinned, hash-verified dependencies.

### 190. What changes trigger an application restart?

Repository changes, dependency changes, and systemd unit-template changes
notify the restart handler. Initial or changed Docker image builds also notify
it.

### 191. Why use handlers instead of unconditional restarts?

Handlers run only when a notifying task changes and are deduplicated within a
play. This avoids unnecessary downtime and repeated restarts.

### 192. What does `meta: flush_handlers` do?

It immediately runs pending handlers rather than waiting until the end of the
play. The role uses this before relying on newly installed or updated services.

### 193. What if handlers were not flushed before readiness checks?

The check could target an old process, a service using an outdated unit, or a
service that has not yet been restarted. That can create false success or a
misleading timeout.

### 194. How would you verify idempotency manually?

Run the playbook twice against the same unchanged host. The second recap should
show no unexpected changed tasks, while read-only checks remain `ok`.

### 195. How would you automate idempotency testing?

Use Molecule or an ephemeral VM test that applies the role twice, asserts zero
unexpected changes on the second run, validates the service and health command,
and destroys the environment afterward.

## Docker, systemd, health checks, CI, and troubleshooting

### 196. How does the role decide to build the Docker image, and what can it miss?

It builds when the Git checkout changed or image inspection fails. It can miss
changes in the base image referenced by an unchanged Dockerfile because
`--pull` runs only when a build is already triggered. A digest pin, scheduled
rebuild, or content-derived image tag would improve this.

### 197. Compare the native and Docker systemd configurations.

Native mode runs the virtual-environment process as the dedicated user and
group. Docker mode runs Docker commands, uses host networking, removes stale
named containers before start, stops and removes them during shutdown, and
requires the Docker daemon. Both wait for network readiness, use the
installation directory, restart on failure, and start at the multi-user target.

### 198. How do handlers and health checks verify deployment?

Template or installation changes notify service handlers. The role flushes
handlers, explicitly enables and starts the application, then repeatedly calls
the loopback HTTP health endpoint until it returns 200. The installed
`local-ai-assistant-health` command provides the same local operational check
for administrators.

### 199. What does CI validate, and what is missing?

CI checks Python compilation, linting and tests, Ansible syntax, shell scripts,
Terraform formatting and validation, and Docker image construction. It does
not execute the role on a real systemd host, test both deployment modes,
perform an idempotency run, validate service startup, or exercise the full
Terraform-to-Ansible handoff.

### 200. How would you troubleshoot a final health-check timeout?

Start with the failed Ansible task and run `systemctl status` and `journalctl`
for the application service. Confirm the unit rendered correctly, the expected
revision is checked out, files and virtual environment have correct ownership,
and the process is listening on port 8501. In Docker mode, inspect the daemon,
image, container state, logs, host networking, and name conflicts. Run
`local-ai-assistant-health` locally, check disk and memory availability, fix the
root cause, rerun the idempotent playbook, and verify both local and permitted
remote access.
