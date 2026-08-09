# Single EC2 Docker Ansible configuration

This playbook installs Ollama and Docker, pulls the configured models, checks
out the application branch, builds its image, and manages the Streamlit
container with systemd on one Debian-family host.

The repository wrapper generates the inventory automatically:

```bash
./deploy_with_ansible.sh
```

For an existing server, copy `inventory.ini.example`, edit the host and SSH
settings, then run from this directory:

```bash
ansible-playbook playbook.yml
```

Configuration values are in `group_vars/all.yml`. Set
`app_repository_version` to an immutable commit when required.
