# db-ops

Ansible repository for initialising Postgres on GCE VM instances.

```bash
# This wrapper script tells Ansible to use IAP for every host
ansible-playbook -i gcp_compute.yml deploy_ha_postgres.yml \
  --connection="ssh" \
  --extra-vars "ansible_ssh_common_args='-o ProxyCommand=\"gcloud compute start-iap-tunnel %h %p --listen-on-stdin --zone=%(zone)s\"'"
```

> The google.cloud.gcp_compute inventory plugin automatically populates the zone variable for each host, allowing the command above to dynamically pick the correct zone for the tunnel.
