# SSH

## Before instaniating a SSHCluster it is recommended to configure keyless SSH for your local machine and other machines in the cluster

For example, on a Mac to SSH into localhost (local machine) you need to ensure the Remote Login option is set in System Preferences -> Sharing. In addition, id_rsa.pub should be in authorized_keys for keyless login.

1. Generate a public/private key pair on your local machine using the `ssh-keygen` command.
2. Copy the public key to the remote machine(s) that you want to access without a password. You can do this using the `ssh-copy-id` command.
3. Test your connection by running the ssh command to connect to the remote machine without entering a password. If the configuration was successful, you should be logged in without being prompted for a password.
4. You can repeat the same process for any other remote machines that you want to access without a password.

## Deploy a Dask cluster using SSH

```python
from dask.distributed import Client, SSHCluster
cluster = SSHCluster(
    ["localhost", "hostwithgpus", "anothergpuhost"],
    connect_options={"known_hosts": None},
    worker_options={"nthreads": 1},
    scheduler_options={"port": 0, "dashboard_address": ":8797"},
    )
client = Client(cluster)
```

## Deploy a Dask cluster using SSH with docker

`dask-ssh-docker localhost "localhost --nprocs 2" -- test.py`
