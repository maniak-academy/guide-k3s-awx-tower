# AWX on Single Node K3x

Special thanks to @kurokobo https://github.com/kurokobo/awx-on-k3s these steps and code are from his repo. I am just making an ubuntu version for my lab.

An example implementation of AWX on single node K3s using AWX Operator, with easy-to-use simplified configuration with ownership of data and passwords.

- Accessible over HTTPS from remote host
- All data will be stored under `/data`
- Fixed (configurable) passwords for AWX and PostgreSQL
- Fixed (configurable) versions of AWX

## Environment

- Tested on:
  - Ubuntu 22.04 (Minimal)
  - K3s v1.28.5+k3s1
- Products that will be deployed:
  - AWX Operator 2.10.0
  - AWX 23.6.0
  - PostgreSQL 13

## References

- [K3s - Lightweight Kubernetes](https://docs.k3s.io/)
- [INSTALL.md on ansible/awx](https://github.com/ansible/awx/blob/23.6.0/INSTALL.md) @23.6.0
- [README.md on ansible/awx-operator](https://github.com/ansible/awx-operator/blob/2.10.0/README.md) @2.10.0


## Requirements

- **Computing resources**
  - **2 CPUs and 4 GiB RAM minimum**.
  - It's recommended to add more CPUs and RAM (like 4 CPUs and 8 GiB RAM or more) to avoid performance issue and job scheduling issue.
  - The files in this repository are configured to ignore resource requirements which specified by AWX Operator by default.
- **Storage resources**
  - At least **10 GiB for `/var/lib/rancher`** and **10 GiB for `/data`** are safe for fresh install.
  - **Both will be grown during lifetime** and **actual consumption highly depends on your environment and your use case**, so you should to pay attention to the consumption and add more capacity if required.
  - `/var/lib/rancher` will be created and consumed by K3s and related data like container images and overlayfs.
  - `/data` will be created in this guide and used to store AWX-related databases and files.

## Deployment Instruction

## Prep the OS
Install required packages to deploy AWX Operator and AWX.

```
sudo apt-get install -y git curl ansible-core build-essential
```

### Install K3s

Install specific version of K3s with `--write-kubeconfig-mode 644` to make config file (`/etc/rancher/k3s/k3s.yaml`) readable by non-root user.

```
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.28.5+k3s1 sh -s - --write-kubeconfig-mode 644
```


### Install AWX Operator

Clone this repository and change directory.

```
git clone https://github.com/maniak-academy/guide-k3s-awx-tower.git
cd guide-k3s-awx-tower
```



Then invoke `kubectl apply -k operator` to deploy AWX Operator.

```
kubectl apply -k operator
```

The AWX Operator will be deployed to the namespace `awx`.

```
kubectl -n awx get all
```

Output
```
NAME                                                   READY   STATUS              RESTARTS   AGE
pod/awx-operator-controller-manager-775bd7b75d-fj5nl   0/2     ContainerCreating   0          10s

NAME                                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/awx-operator-controller-manager-metrics-service   ClusterIP   10.43.200.124   <none>        8443/TCP   10s

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/awx-operator-controller-manager   0/1     1            0           10s

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/awx-operator-controller-manager-775bd7b75d   1         1         0       10s
```



### Prepare required files to deploy AWX

Generate a Self-Signed certificate. Note that IP address can't be specified. If you want to use a certificate from public ACME CA such as Let's Encrypt or ZeroSSL instead of Self-Signed certificate, follow the guide on [📁 **Use SSL Certificate from Public ACME CA**](acme) first and come back to this step when done.

```
AWX_HOST="awx.example.com"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out ./base/tls.crt -keyout ./base/tls.key -subj "/CN=${AWX_HOST}/O=${AWX_HOST}" -addext "subjectAltName = DNS:${AWX_HOST}"
```

Modify `hostname` in `base/awx.yaml`.

```
vi base/awx.yaml
```


```
...
spec:
  ...
  ingress_type: ingress
  ingress_tls_secret: awx-secret-tls
  hostname: awx.example.com     👈👈👈
...
```


Modify two `password`s in `base/kustomization.yaml`. Note that the `password` under `awx-postgres-configuration` should not contain single or double quotes (`'`, `"`) or backslashes (`\`) to avoid any issues during deployment, backup or restoration.


```
vi base/kustomization.yaml
```

```
...
  - name: awx-postgres-configuration
    type: Opaque
    literals:
      - host=awx-postgres-13
      - port=5432
      - database=awx
      - username=awx
      - password=Ansible123!     👈👈👈
      - type=managed

  - name: awx-admin-password
    type: Opaque
    literals:
      - password=Ansible123!     👈👈👈
...
```

Prepare directories for Persistent Volumes defined in `base/pv.yaml`. These directories will be used to store your databases and project files. Note that the size of the PVs and PVCs are specified in some of the files in this repository, but since their backends are `hostPath`, its value is just like a label and there is no actual capacity limitation.

```
sudo mkdir -p /data/postgres-13
sudo mkdir -p /data/projects
sudo chmod 755 /data/postgres-13
sudo chown 1000:0 /data/projects
```


### Deploy AWX

Deploy AWX, this takes few minutes to complete.

```
kubectl apply -k base
```

Note: It takes a couple minutes, go grab a coffee or lunch

To monitor the progress of the deployment, check the logs of `deployments/awx-operator-controller-manager`:

```
kubectl -n awx logs -f deployments/awx-operator-controller-manager
```

## When its complete 
When the deployment completes successfully, the logs end with:

```
kubectl -n awx logs -f deployments/awx-operator-controller-manager

...
----- Ansible Task Status Event StdOut (awx.ansible.com/v1beta1, Kind=AWX, awx/awx) -----
PLAY RECAP *********************************************************************
localhost                  : ok=84   changed=0    unreachable=0    failed=0    skipped=79   rescued=0    ignored=1
```


Required objects has been deployed next to AWX Operator in `awx` namespace.

```
kubectl -n awx get awx,all,ingress,secrets
```

The output should look like this 

```
NAME                      AGE
awx.awx.ansible.com/awx   6m26s

NAME                                                   READY   STATUS    RESTARTS   AGE
pod/awx-operator-controller-manager-775bd7b75d-fj5nl   2/2     Running   0          9m16s
pod/awx-postgres-13-0                                  1/1     Running   0          6m15s
pod/awx-task-8486dc5d49-gszjz                          4/4     Running   0          5m51s
pod/awx-web-5dfdd99f4f-l4m2f                           3/3     Running   0          5m4s

NAME                                                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/awx-operator-controller-manager-metrics-service   ClusterIP   10.43.200.124   <none>        8443/TCP   9m16s
service/awx-postgres-13                                   ClusterIP   None            <none>        5432/TCP   6m15s
service/awx-service                                       ClusterIP   10.43.155.57    <none>        80/TCP     5m52s

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/awx-operator-controller-manager   1/1     1            1           9m16s
deployment.apps/awx-task                          1/1     1            1           5m51s
deployment.apps/awx-web                           1/1     1            1           5m4s

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/awx-operator-controller-manager-775bd7b75d   1         1         1       9m16s
replicaset.apps/awx-task-8486dc5d49                          1         1         1       5m51s
replicaset.apps/awx-web-5dfdd99f4f                           1         1         1       5m4s

NAME                               READY   AGE
statefulset.apps/awx-postgres-13   1/1     6m15s

NAME                                    CLASS     HOSTS             ADDRESS         PORTS     AGE
ingress.networking.k8s.io/awx-ingress   traefik   awx.example.com   172.16.10.139   80, 443   5m52s

NAME                                  TYPE                DATA   AGE
secret/redhat-operators-pull-secret   Opaque              1      9m16s
secret/awx-admin-password             Opaque              1      6m26s
secret/awx-postgres-configuration     Opaque              6      6m26s
secret/awx-secret-tls                 kubernetes.io/tls   2      6m26s
secret/awx-app-credentials            Opaque              3      5m54s
secret/awx-secret-key                 Opaque              1      6m22s
secret/awx-broadcast-websocket        Opaque              1      6m19s
secret/awx-receptor-ca                kubernetes.io/tls   2      5m59s
secret/awx-receptor-work-signing      Opaque              2      5m56s
```

Now your AWX is available at `https://awx.example.com/` or the hostname you specified. Or the hostname that you configured.
