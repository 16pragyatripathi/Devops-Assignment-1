# Kubernetes Fundamentals – Homework

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

I practised the basics on a local 2-node Kubernetes cluster (1 control-plane + 1 worker) created with **kind** (Kubernetes in Docker). Minikube would work the same way. All outputs are copied from my terminal.

Cluster config: [kind-cluster.yaml](kind-cluster.yaml)

```bash
kind create cluster --config kind-cluster.yaml
```

---

*Screenshots below come from a second run of the same labs, so Pod names, IPs and ages differ from the text output.*

## 1. Kubernetes architecture in short

| Component | Runs on | Job |
|---|---|---|
| `kube-apiserver` | Control plane | The only entry point. `kubectl` and every other component talk to it |
| `etcd` | Control plane | Key-value database that stores the whole cluster state |
| `kube-scheduler` | Control plane | Decides which node a new Pod should run on |
| `kube-controller-manager` | Control plane | Control loops that keep actual state equal to desired state |
| `kubelet` | Every node | Agent that starts and watches the containers of the Pods on its node |
| `kube-proxy` | Every node | Programs the network rules that make Services work |
| Container runtime (`containerd`) | Every node | Actually runs the containers |
| `CoreDNS` | Add-on | DNS for Services and Pods inside the cluster |

Kubernetes is **declarative**: I describe the desired state in YAML, and the controllers keep working until the real state matches it.

## 2. Cluster information

```text
$ kubectl version
Client Version: v1.34.1
Kustomize Version: v5.7.1
Server Version: v1.37.0
Warning: version difference between client (1.34) and server (1.37) exceeds the supported minor version skew of +/-1

$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:54141
CoreDNS is running at https://127.0.0.1:54141/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ kubectl get nodes -o wide
NAME                      STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION             CONTAINER-RUNTIME
devops-hw-control-plane   Ready    control-plane   7m48s   v1.37.0   172.18.0.3    <none>        Debian GNU/Linux 13 (trixie)   6.12.76-linuxkit (arm64)   containerd://2.3.4
devops-hw-worker          Ready    <none>          7m34s   v1.37.0   172.18.0.2    <none>        Debian GNU/Linux 13 (trixie)   6.12.76-linuxkit (arm64)   containerd://2.3.4

$ kubectl get namespaces
NAME                 STATUS   AGE
default              Active   7m48s
kube-node-lease      Active   7m48s
kube-public          Active   7m48s
kube-system          Active   7m48s
local-path-storage   Active   7m45s
```

**What I understood:** the server runs v1.37 and both nodes are `Ready`. The control-plane node hosts the API server, and the worker node runs my applications. Default namespaces: `default` (my objects), `kube-system` (cluster components), `kube-public`, `kube-node-lease` (node heartbeats).

**Cluster info, nodes and namespaces**

![k8-01-cluster](screenshots/k8-01-cluster.png)


## 3. The architecture components are real Pods

```text
$ kubectl get pods -n kube-system -o wide
NAME                                              READY   STATUS    RESTARTS   AGE     IP           NODE                      NOMINATED NODE   READINESS GATES
coredns-559f6c778d-24m6v                          1/1     Running   0          7m38s   10.244.0.3   devops-hw-control-plane   <none>           <none>
coredns-559f6c778d-bvm4l                          1/1     Running   0          7m38s   10.244.0.2   devops-hw-control-plane   <none>           <none>
etcd-devops-hw-control-plane                      1/1     Running   0          7m46s   172.18.0.3   devops-hw-control-plane   <none>           <none>
kindnet-9fvmb                                     1/1     Running   0          7m34s   172.18.0.2   devops-hw-worker          <none>           <none>
kindnet-x6c44                                     1/1     Running   0          7m38s   172.18.0.3   devops-hw-control-plane   <none>           <none>
kube-apiserver-devops-hw-control-plane            1/1     Running   0          7m46s   172.18.0.3   devops-hw-control-plane   <none>           <none>
kube-controller-manager-devops-hw-control-plane   1/1     Running   0          7m46s   172.18.0.3   devops-hw-control-plane   <none>           <none>
kube-proxy-qjkzx                                  1/1     Running   0          7m34s   172.18.0.2   devops-hw-worker          <none>           <none>
kube-proxy-zgbzd                                  1/1     Running   0          7m38s   172.18.0.3   devops-hw-control-plane   <none>           <none>
kube-scheduler-devops-hw-control-plane            1/1     Running   0          7m46s   172.18.0.3   devops-hw-control-plane   <none>           <none>
```

**What I understood:** every component from the table above is visible here: `etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` on the control-plane node, and one `kube-proxy` plus one `kindnet` (the CNI network plugin) **per node**. `coredns` runs with 2 replicas.

**Control-plane components running as Pods in `kube-system`**

![k8-02-kube-system](screenshots/k8-02-kube-system.png)


### How the control plane itself starts: static Pods

That listing raises a chicken-and-egg question. `kube-apiserver` is a Pod, but Pods are created *through* the API server. So who starts it?

The answer is **static Pods** — manifests on disk that the kubelet reads directly, with no API server involved.

```text
$ docker exec devops-hw-control-plane ls /etc/kubernetes/manifests
etcd.yaml
kube-apiserver.yaml
kube-controller-manager.yaml
kube-scheduler.yaml

$ docker exec devops-hw-worker ls /etc/kubernetes/manifests
```

Four manifests on the control-plane node, and the worker's directory is **empty**. The kubelet watches that folder and starts whatever it finds, which is how the four control-plane components come up before anything else exists. Once the API server is live, the kubelet registers mirror Pods for them so they show up in `kubectl get pods` — that is why their names are suffixed with the node name (`etcd-devops-hw-control-plane`) rather than a random hash like a Deployment's Pods.

The practical consequence: `kubectl delete pod kube-apiserver-devops-hw-control-plane` does not remove it. The mirror Pod disappears and the kubelet immediately recreates it from the file on disk. Editing the YAML in that directory is how you actually change an API server flag.

On the worker there is no such directory content, and the node's own agents run as ordinary processes rather than Pods:

```text
$ docker exec devops-hw-worker ps -eo comm --no-headers | sort -u | grep -E 'kubelet|kube-proxy|containerd'
containerd
containerd-shim
kube-proxy
kubelet
```

`kubelet` and `containerd` are host processes — they have to be, because they are what runs Pods. `kube-proxy` appears both here and as a Pod because it is deployed as a DaemonSet; the process listed is the one inside that Pod's container.

### Control plane vs worker, in one line each

| | Control plane | Worker |
|---|---|---|
| Decides | **what should happen** — scheduling, reconciliation, admission | nothing; it takes orders |
| Runs | `etcd`, `kube-apiserver`, `kube-scheduler`, `kube-controller-manager` as static Pods | `kubelet` and `containerd` as processes |
| Also runs | `kubelet`, `kube-proxy`, CNI — it is still a node | `kube-proxy` and CNI via DaemonSets |
| Hosts user Pods | Not by default, a taint prevents it | Yes, this is its job |
| Lose it and | the cluster cannot accept changes; running Pods keep running | its Pods are rescheduled elsewhere |

The last row is the one worth remembering: the control plane going down does not stop traffic. The kubelets keep the existing Pods alive and `kube-proxy` keeps routing. What stops is *change* — no new Pods, no rescheduling, no `kubectl`.

## 4. Node capacity and API resources

```text
$ kubectl describe node devops-hw-worker | sed -n "/^Capacity/,/^System Info/p"
Capacity:
  cpu:                15
  ephemeral-storage:  977848209408
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             12234256Ki
  pods:               110
Allocatable:
  cpu:                15
  ephemeral-storage:  977848209408
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             12234256Ki
  pods:               110
System Info:

$ kubectl api-resources | head -12
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND
bindings                                         v1                                true         Binding
componentstatuses                   cs           v1                                false        ComponentStatus
configmaps                          cm           v1                                true         ConfigMap
endpoints                           ep           v1                                true         Endpoints
events                              ev           v1                                true         Event
limitranges                         limits       v1                                true         LimitRange
namespaces                          ns           v1                                false        Namespace
nodes                               no           v1                                false        Node
persistentvolumeclaims              pvc          v1                                true         PersistentVolumeClaim
persistentvolumes                   pv           v1                                false        PersistentVolume
pods                                po           v1                                true         Pod
```

**What I understood:** `Allocatable` is what the scheduler can hand out to Pods on that node (max 110 Pods). `kubectl api-resources` lists every object type with its short name (`po`, `cm`, `ns`), API version, and whether it is namespaced.

## 5. My first Pod

```text
$ kubectl run hello-nginx --image=nginx:1.25-alpine --port=80
pod/hello-nginx created

$ kubectl wait --for=condition=Ready pod/hello-nginx --timeout=120s
pod/hello-nginx condition met

$ kubectl get pod hello-nginx -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
hello-nginx   1/1     Running   0          9s    10.244.1.2   devops-hw-worker   <none>           <none>

$ kubectl describe pod hello-nginx | sed -n "/^Events/,\$p"
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  9s    default-scheduler  Successfully assigned default/hello-nginx to devops-hw-worker
  Normal  Pulling    9s    kubelet            Pulling image "nginx:1.25-alpine"
  Normal  Pulled     0s    kubelet            Successfully pulled image "nginx:1.25-alpine" in 8.758s (8.758s including waiting). Image size: 20193659 bytes.
  Normal  Created    0s    kubelet            Container created
  Normal  Started    0s    kubelet            Container started

$ kubectl exec hello-nginx -- nginx -v
nginx version: nginx/1.25.5

$ kubectl logs hello-nginx | tail -3
2026/09/17 13:36:25 [notice] 1#1: start worker process 46
2026/09/17 13:36:25 [notice] 1#1: start worker process 47
2026/09/17 13:36:25 [notice] 1#1: start worker process 48
```

**What I understood:** the `Events` section shows the life of a Pod step by step: **Scheduled** (scheduler picked `devops-hw-worker`) → **Pulling / Pulled** (kubelet asked containerd for the image) → **Created** → **Started**. The Pod got its own IP `10.244.1.2` from the Pod network. `kubectl exec` runs a command inside the container and `kubectl logs` shows its stdout.

**First Pod: run, wait, inspect events, exec**

![k8-03-first-pod](screenshots/k8-03-first-pod.png)


## 6. Namespaces

```text
$ kubectl create namespace dev
namespace/dev created

$ kubectl run hello-dev --image=nginx:1.25-alpine -n dev
pod/hello-dev created

$ kubectl get pods -A | grep -E "NAMESPACE|hello"
NAMESPACE            NAME                                              READY   STATUS              RESTARTS   AGE
default              hello-nginx                                       1/1     Running             0          9s
dev                  hello-dev                                         0/1     ContainerCreating   0          0s
```

**What I understood:** namespaces are virtual clusters inside one cluster, used to separate teams or environments. `-n dev` targets a namespace and `-A` lists all of them. Two Pods with the same name can exist if they are in different namespaces.

**Namespaces**

![k8-04-namespaces](screenshots/k8-04-namespaces.png)


## 7. Generating YAML and reading documentation from the CLI

```text
$ kubectl run dry --image=nginx --dry-run=client -o yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: dry
  name: dry
spec:
  containers:
  - image: nginx
    name: dry
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

$ kubectl explain pod.spec.containers.image
KIND:       Pod
VERSION:    v1

FIELD: image <string>

DESCRIPTION:
    Container image name. More info:
    https://kubernetes.io/docs/concepts/containers/images This field is optional
    to allow higher level config management to default or override container
    images in workload controllers like Deployments and StatefulSets.
```

**What I understood:** `--dry-run=client -o yaml` prints the manifest without creating anything. It is the fastest way to get a starting YAML. `kubectl explain` is built-in documentation for every field.

## 8. Clean up

```text
$ kubectl delete pod hello-nginx --wait=false
pod "hello-nginx" deleted from default namespace

$ kubectl delete namespace dev --wait=false
namespace "dev" deleted
```

Deleting a namespace deletes everything inside it.

---

## kubectl cheat sheet

| Command | Purpose |
|---|---|
| `kubectl get <type> [-o wide] [-n ns] [-A]` | List objects |
| `kubectl describe <type> <name>` | Details and events, first stop for debugging |
| `kubectl logs <pod> [-f] [--previous]` | Container logs |
| `kubectl exec -it <pod> -- sh` | Shell inside a container |
| `kubectl apply -f file.yaml` | Create or update from a manifest (declarative) |
| `kubectl delete -f file.yaml` | Delete what the manifest created |
| `kubectl run` / `kubectl create` | Quick imperative creation |
| `kubectl explain <type.field>` | Field documentation |
| `kubectl config get-contexts` | Which cluster am I talking to |
