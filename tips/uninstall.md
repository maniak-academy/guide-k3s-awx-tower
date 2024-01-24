<!-- omit in toc -->
# Uninstall deployed resources

<!-- omit in toc -->
## Table of Contents

- [Uninstall resources on Kubernetes](#uninstall-resources-on-kubernetes)
- [Remove data in PVs](#remove-data-in-pvs)
- [Uninstall K3s](#uninstall-k3s)

### Uninstall resources on Kubernetes

In kubernetes, you can deploy resources with `kubectl create -f (-k)` or `kubectl apply -f (-k)` by specifying manifest files, and similarly, you can use manifest files to delete resources by `kubectl delete -f (-k)` command.

For example, some resources deployed with the following command;

```bash
$ kubectl apply -k base
namespace/awx created
secret/awx-admin-password created
secret/awx-postgres-configuration created
secret/awx-secret-tls created
persistentvolume/awx-postgres-volume created
persistentvolume/awx-projects-volume created
persistentvolumeclaim/awx-projects-claim created
awx.awx.ansible.com/awx created
```

can be deleted with the following command with same manifest files.

```bash
$ kubectl delete -k base
namespace "awx" deleted
secret "awx-admin-password" deleted
secret "awx-postgres-configuration" deleted
secret "awx-secret-tls" deleted
persistentvolume "awx-postgres-volume" deleted
persistentvolume "awx-projects-volume" deleted
persistentvolumeclaim "awx-projects-claim" deleted
awx.awx.ansible.com "awx" deleted
```

Or, you can delete all resources in specific namespace by deleting that namespace. PVs cannot be deleted in this way since the PVs are namespace-independent resources, so they need to be deleted manually.

```bash
$ kubectl delete ns awx
namespace "awx" deleted

$ kubectl delete pv <volume name>
persistentvolume "<volume name>" deleted
```

### Remove data in PVs

All manifest files in this repository, the PVs were persisted under `/data/<volume name>` on the K3s host using `hostPath`.

If you want to initialize the data and start all over again, for example, you can delete the data manually.

```bash
sudo rm -rf /data/<volume name>
```

### Uninstall K3s

K3s comes with a handy uninstall script. Once executed, it will perform an uninstall that includes removing all resources deployed on Kubernetes.

```bash
/usr/local/bin/k3s-uninstall.sh
```
