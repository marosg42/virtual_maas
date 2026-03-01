#!/usr/bin/env python3
"""Write Juju config files to $HOME for juju add-cloud / add-credential / bootstrap.

Reads MAAS_URL and MAAS_API_KEY from environment variables.
"""
import os

home = os.path.expanduser("~")
maas_url = os.environ["MAAS_URL"]
maas_api_key = os.environ["MAAS_API_KEY"]

with open(f"{home}/juju_maas_cloud.yaml", "w") as f:
    f.write(
        f"""clouds:
    maas_cloud:
        type: maas
        auth-types: [oauth1]
        endpoint: {maas_url}
        regions:
            default:
                endpoint: {maas_url}
"""
    )

with open(f"{home}/juju_maas_credentials.yaml", "w") as f:
    f.write(
        f"""credentials:
    maas_cloud:
        maas_cloud_credentials:
            auth-type: oauth1
            maas-oauth: {maas_api_key}
"""
    )
os.chmod(f"{home}/juju_maas_credentials.yaml", 0o600)

with open(f"{home}/juju_model_defaults.yaml", "w") as f:
    f.write(
        'cloudinit-userdata: "write_files:\\n  - content: |\\n      kernel.keys.maxkeys = 2000\\n'
        '    owner: \\"root:root\\"\\n    path: /etc/sysctl.d/10-maxkeys.conf\\n'
        '    permissions: \\"0644\\"\\npostruncmd:\\n  - sysctl --system\\n"\n'
        "juju-no-proxy: 10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,127.0.0.1,localhost\n"
        "logging-config: <root>=DEBUG\n"
    )
