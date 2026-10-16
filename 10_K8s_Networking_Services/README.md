# Kubernetes Networking & Services – Homework

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

Manifests are from the class repository ([session-11-kubernetes-services](https://github.com/Nency-Ravaliya/devops-heros/tree/main/session-11-kubernetes-services)) and are copied into [manifests/](manifests). I ran all five service types on my local 2-node kind cluster. All outputs are copied from my terminal.

*Screenshots below come from a second run of the same labs, so Pod names, IPs and ages differ from the text output.*

## Why Services exist

Pods are temporary. Every time a Pod is re-created it gets a **new IP**, so nothing can depend on a Pod IP. A Service gives a **stable name and virtual IP** in front of all Pods that match its label selector, and load balances between them.

| Type | Reachable from | How | Typical use |
|---|---|---|---|
| **ClusterIP** (default) | Inside the cluster only | Virtual IP + DNS name | Service-to-service calls, databases |
| **NodePort** | Outside, through `<NodeIP>:30000-32767` | Opens the same port on every node | Demos, on-prem without a load balancer |
| **LoadBalancer** | Internet | Cloud provider creates an external load balancer | Production entry point on cloud |
| **ExternalName** | Inside the cluster | DNS `CNAME` to an external hostname, no proxying | Giving an external DB/API an in-cluster name |
| **Headless** (`clusterIP: None`) | Inside the cluster | DNS returns the **Pod IPs** directly | StatefulSets, databases, peer discovery |

Ports: `port` is the Service port, `targetPort` is the container port, `nodePort` is the port opened on the nodes.

---

## 1. ClusterIP

[manifests/01-clusterip](manifests/01-clusterip): 3 Nginx Pods, a Service mapping `8080 → 80`, and a `curl-client` Pod for testing from inside the cluster.

```text
$ kubectl apply -f 01-clusterip/app-deployment.yaml -f 01-clusterip/service.yaml -f 01-clusterip/client-pod.yaml
deployment.apps/web-app-clusterip created
service/web-service-clusterip created
pod/curl-client created

$ kubectl rollout status deployment/web-app-clusterip --timeout=180s | tail -1
deployment "web-app-clusterip" successfully rolled out

$ kubectl wait --for=condition=Ready pod/curl-client --timeout=180s
pod/curl-client condition met

$ kubectl get pods -l app=web-clusterip -o wide
NAME                                 READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
web-app-clusterip-66865d4855-5pztf   1/1     Running   0          7s    10.244.1.35   devops-hw-worker   <none>           <none>
web-app-clusterip-66865d4855-fjdhd   1/1     Running   0          7s    10.244.1.34   devops-hw-worker   <none>           <none>
web-app-clusterip-66865d4855-xd64h   1/1     Running   0          7s    10.244.1.36   devops-hw-worker   <none>           <none>

$ kubectl get svc web-service-clusterip
NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
web-service-clusterip   ClusterIP   10.96.247.35   <none>        8080/TCP   7s

$ kubectl get endpointslices -l kubernetes.io/service-name=web-service-clusterip
NAME                          ADDRESSTYPE   PORTS   ENDPOINTS                             AGE
web-service-clusterip-qtw64   IPv4          80      10.244.1.34,10.244.1.35,10.244.1.36   7s

$ kubectl exec curl-client -- curl -s http://web-service-clusterip:8080 | grep -E "<title>|<h1>"
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>

$ kubectl exec curl-client -- curl -s -o /dev/null -w 'HTTP %{http_code} from %{remote_ip}:%{remote_port}\n' http://10.96.247.35:8080
HTTP 200 from 10.96.247.35:8080

$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://web-service-clusterip.default.svc.cluster.local:8080
HTTP 200

$ kubectl exec curl-client -- nslookup web-service-clusterip.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-clusterip.default.svc.cluster.local
Address: 10.96.247.35

$ kubectl exec curl-client -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

**What I understood:**

- The Service got the virtual IP `10.96.247.35`, and its EndpointSlice lists the three Pod IPs on port 80. `EXTERNAL-IP` is `<none>`, so it is internal only.
- The same Service answered by **short name**, by **ClusterIP** and by **FQDN** `web-service-clusterip.default.svc.cluster.local`.
- The short name works because of the `search default.svc.cluster.local svc.cluster.local cluster.local` line in the Pod's `/etc/resolv.conf`. The name server `10.96.0.10` is CoreDNS.
- FQDN format: `<service>.<namespace>.svc.cluster.local`. To call a Service in another namespace, at least `<service>.<namespace>` is needed.
- Newer Kubernetes versions use `EndpointSlices`. `kubectl get endpoints` still works but prints a deprecation warning.

### Proof that the Service follows the Pods

```text
$ kubectl delete pod $(kubectl get pods -l app=web-clusterip -o jsonpath="{.items[0].metadata.name}")
pod "web-app-clusterip-66865d4855-5pztf" deleted from default namespace

$ kubectl rollout status deployment/web-app-clusterip --timeout=120s | tail -1
deployment "web-app-clusterip" successfully rolled out

$ kubectl get endpointslices -l kubernetes.io/service-name=web-service-clusterip
NAME                          ADDRESSTYPE   PORTS   ENDPOINTS                             AGE
web-service-clusterip-qtw64   IPv4          80      10.244.1.34,10.244.1.36,10.244.1.38   8s

$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://web-service-clusterip:8080
HTTP 200
```

I deleted the Pod with IP `10.244.1.35`. The Deployment created a new Pod (`10.244.1.38`), and the EndpointSlice was updated **automatically**. The client kept using the same name and still got `HTTP 200`. This is exactly the problem Services solve.

**ClusterIP Service and its EndpointSlice**

![k10-01-clusterip](screenshots/k10-01-clusterip.png)

**Access by service name and FQDN, CoreDNS lookup, `resolv.conf`**

![k10-02-clusterip-dns](screenshots/k10-02-clusterip-dns.png)


## 2. NodePort

[manifests/02-nodeport](manifests/02-nodeport): `port: 80`, `targetPort: 80`, `nodePort: 30080`.

```text
$ kubectl apply -f 02-nodeport/app-deployment.yaml -f 02-nodeport/service.yaml
deployment.apps/web-app-nodeport created
service/web-service-nodeport created

$ kubectl rollout status deployment/web-app-nodeport --timeout=180s | tail -1
deployment "web-app-nodeport" successfully rolled out

$ kubectl get svc web-service-nodeport
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
web-service-nodeport   NodePort   10.96.102.115   <none>        80:30080/TCP   1s

$ kubectl get nodes -o wide | cut -c1-90
NAME                      STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-
devops-hw-control-plane   Ready    control-plane   11m   v1.37.0   172.18.0.3    <none>
devops-hw-worker          Ready    <none>          11m   v1.37.0   172.18.0.2    <none>

$ kubectl get svc web-service-nodeport
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
web-service-nodeport   NodePort   10.96.102.115   <none>        80:30080/TCP   26s

$ docker exec devops-hw-control-plane curl -s -m 5 -o /dev/null -w "HTTP %{http_code} via worker node 172.18.0.2:30080\n" http://172.18.0.2:30080
HTTP 200 via worker node 172.18.0.2:30080

$ docker exec devops-hw-control-plane curl -s -m 5 -o /dev/null -w "HTTP %{http_code} via control-plane node 172.18.0.3:30080\n" http://172.18.0.3:30080
HTTP 200 via control-plane node 172.18.0.3:30080

$ docker exec devops-hw-worker curl -s -m 5 http://localhost:30080 | grep "<title>"
<title>Welcome to nginx!</title>
```

**What I understood:**

- `80:30080/TCP` means port 30080 is open on **every node**. Both node IPs answered, including the control-plane node where no application Pod is running. `kube-proxy` forwards the traffic to a matching Pod wherever it is.
- A NodePort Service still has a ClusterIP. Each type builds on the previous one: LoadBalancer ⊃ NodePort ⊃ ClusterIP.
- kind nodes are Docker containers, so their IPs (`172.18.0.x`) are reachable only from inside the Docker network. That is why I ran `curl` from inside the node containers. With Minikube the equivalent is `curl $(minikube ip):30080` or `minikube service web-service-nodeport --url`.

**NodePort 30080 answering on the nodes**

![k10-03-nodeport](screenshots/k10-03-nodeport.png)


## 3. LoadBalancer

[manifests/03-loadbalancer](manifests/03-loadbalancer)

```text
$ kubectl apply -f 03-loadbalancer/app-deployment.yaml -f 03-loadbalancer/service.yaml
deployment.apps/web-app-loadbalancer created
service/web-service-loadbalancer created

$ kubectl rollout status deployment/web-app-loadbalancer --timeout=180s | tail -1
deployment "web-app-loadbalancer" successfully rolled out

$ kubectl get svc web-service-loadbalancer
NAME                       TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE
web-service-loadbalancer   LoadBalancer   10.96.7.84   <pending>     80:31804/TCP   1s

$ curl -s -o /dev/null -w "HTTP %{http_code} through kubectl port-forward svc/web-service-loadbalancer 9080:80\n" http://localhost:9080
HTTP 200 through kubectl port-forward svc/web-service-loadbalancer 9080:80
```

**What I understood:**

- `EXTERNAL-IP` stays `<pending>` on a local cluster, because there is no cloud provider to create a real load balancer. On AWS/GCP/Azure a public IP or hostname would appear here. Locally, `minikube tunnel`, MetalLB or `cloud-provider-kind` can fill that role.
- The Service still got a NodePort (`80:31804`) and a ClusterIP, so it is usable. I verified it with `kubectl port-forward`, which returned `HTTP 200`.
- Every LoadBalancer Service is a separate paid cloud resource. In production, one LoadBalancer is placed in front of an **Ingress controller**, which then routes to many ClusterIP Services.

## 4. ExternalName

[manifests/04-externalname](manifests/04-externalname)

```text
$ kubectl apply -f 04-externalname/service.yaml -f 04-externalname/client-pod.yaml
service/external-database-service created
pod/dns-test-client created

$ kubectl wait --for=condition=Ready pod/dns-test-client --timeout=180s
pod/dns-test-client condition met

$ kubectl get svc external-database-service
NAME                        TYPE           CLUSTER-IP   EXTERNAL-IP        PORT(S)   AGE
external-database-service   ExternalName   <none>       nencyravaliya.me   <none>    0s

$ kubectl exec dns-test-client -- nslookup external-database-service.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

external-database-service.default.svc.cluster.local	canonical name = nencyravaliya.me

external-database-service.default.svc.cluster.local	canonical name = nencyravaliya.me
```

**What I understood:** there is no ClusterIP, no selector and no Pods. CoreDNS simply answers with a `CNAME` (`canonical name = nencyravaliya.me`). The application can use the in-cluster name `external-database-service`, and if the external database moves, only the Service is edited and not the application.

**LoadBalancer stays `<pending>` locally, ExternalName returns a CNAME**

![k10-04-loadbalancer-externalname](screenshots/k10-04-loadbalancer-externalname.png)


## 5. Headless Service + StatefulSet

[manifests/05-headless](manifests/05-headless)

```text
$ kubectl apply -f 05-headless/service.yaml -f 05-headless/app-statefulset.yaml -f 05-headless/client-pod.yaml
service/web-service-headless created
statefulset.apps/web-stateful created
pod/headless-dns-client created

$ kubectl rollout status statefulset/web-stateful --timeout=240s | tail -1
partitioned roll out complete: 3 new pods have been updated...

$ kubectl wait --for=condition=Ready pod/headless-dns-client --timeout=180s
pod/headless-dns-client condition met

$ kubectl get svc web-service-headless
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
web-service-headless   ClusterIP   None         <none>        80/TCP    2s

$ kubectl get pods -l app=web-headless -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
web-stateful-0   1/1     Running   0          2s    10.244.1.45   devops-hw-worker   <none>           <none>
web-stateful-1   1/1     Running   0          2s    10.244.1.47   devops-hw-worker   <none>           <none>
web-stateful-2   1/1     Running   0          1s    10.244.1.48   devops-hw-worker   <none>           <none>

$ kubectl exec headless-dns-client -- nslookup web-service-headless.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.1.45
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.1.47
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.1.48

$ kubectl exec headless-dns-client -- nslookup web-stateful-1.web-service-headless.default.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-stateful-1.web-service-headless.default.svc.cluster.local
Address: 10.244.1.47

$ kubectl exec headless-dns-client -- curl -s -o /dev/null -w "HTTP %{http_code} from pod web-stateful-0\n" http://web-stateful-0.web-service-headless:80
HTTP 200 from pod web-stateful-0
```

**What I understood:**

- With `clusterIP: None` there is no virtual IP and no load balancing. DNS for the Service name returns **all three Pod IPs**, and the client chooses.
- StatefulSet Pods have **stable names** (`web-stateful-0`, `-1`, `-2`), and each one gets its own DNS record: `<pod>.<service>.<namespace>.svc.cluster.local`. `web-stateful-1` resolved to exactly its own IP `10.244.1.47`.
- Databases and clustered systems (MySQL replication, Kafka, MongoDB) need this, because a replica must talk to one specific peer, not to a random one.

**Headless Service: DNS returns Pod IPs, per-Pod DNS for the StatefulSet**

![k10-05-headless](screenshots/k10-05-headless.png)


## 6. Troubleshooting – empty endpoints

[manifests/empty-endpoints.yaml](manifests/empty-endpoints.yaml) has the selector `app: wrong-backend-name`, which matches no Pod.

```text
$ kubectl apply -f troubleshooting/empty-endpoints.yaml
service/broken-backend-service created

$ kubectl get svc,endpointslices | grep -iE "NAME|broken|mismatch|empty"
NAME                                TYPE           CLUSTER-IP      EXTERNAL-IP        PORT(S)        AGE
service/broken-backend-service      ClusterIP      10.96.152.31    <none>             80/TCP         8s
service/external-database-service   ExternalName   <none>          nencyravaliya.me   <none>         11s
NAME                                                            ADDRESSTYPE   PORTS     ENDPOINTS                             AGE
endpointslice.discovery.k8s.io/broken-backend-service-qxkhx     IPv4          <unset>   <unset>                               8s
```

**What I understood:** the Service is created without any error, but its EndpointSlice shows `<unset>`, so every request would fail. When a Service does not respond, the first things to check are:

1. `kubectl get endpointslices` – is the list empty?
2. `kubectl get pods --show-labels` – does the Service `selector` match the Pod labels **exactly**?
3. Does `targetPort` match the port the container really listens on?
4. Are the Pods `Ready`? Pods that are not ready are removed from the endpoints.
5. Is CoreDNS running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`

**Troubleshooting: selector mismatch gives empty endpoints**

![k10-06-empty-endpoints](screenshots/k10-06-empty-endpoints.png)


## Service type summary

All five, side by side, after running each one above.

| Type | Gets a ClusterIP | Reachable from | How a client finds it | What it does under the hood |
|---|---|---|---|---|
| **ClusterIP** (default) | Yes | Inside the cluster only | `svc-name` or `svc.ns.svc.cluster.local` | kube-proxy rules load-balance the virtual IP across ready endpoints |
| **NodePort** | Yes | Any node's IP on a port in 30000–32767 | `<node-ip>:<nodeport>` | Everything ClusterIP does, plus every node listens on that port and forwards |
| **LoadBalancer** | Yes | Outside the cluster, via a cloud LB | The external IP | Everything NodePort does, plus asks the cloud provider for an LB. Stays `<pending>` on kind — there is no provider to answer |
| **ExternalName** | **No** | Inside the cluster | `svc-name` resolves to a CNAME | Pure DNS. No proxying, no endpoints, no kube-proxy involvement |
| **Headless** (`clusterIP: None`) | **No** | Inside the cluster | `svc-name` returns **every** Pod IP; `pod-0.svc` addresses one | DNS returns A records for each ready Pod. The client picks, not kube-proxy |

Each of the first three builds on the one before it — a LoadBalancer is a NodePort is a ClusterIP, with another layer added. The last two are the odd ones out: neither allocates a virtual IP, and neither load-balances. ExternalName is a DNS alias pointing out of the cluster; headless points at individual Pods inside it.

Choosing between them:

- **ClusterIP** for anything only other Pods talk to. This is most Services.
- **NodePort** for a quick external check in a local cluster. Awkward in production — high port numbers, and the client must know a node IP.
- **LoadBalancer** for real external traffic on a cloud provider, remembering each one is a separately billed resource. In practice you provision one for an Ingress controller and route everything through it.
- **ExternalName** to give an outside dependency a stable in-cluster name, so moving it later is a Service edit rather than a change in every app.
- **Headless** when the client needs to address specific Pods — StatefulSets, database replicas, anything doing its own peer discovery.

## Clean up

```bash
kubectl delete -f manifests/01-clusterip -f manifests/02-nodeport -f manifests/03-loadbalancer \
               -f manifests/04-externalname -f manifests/05-headless -f manifests/empty-endpoints.yaml
```

---

# Session 11 deliverables

## Task 2: Kubernetes object comparison

### Deployment vs ReplicaSet

| | ReplicaSet | Deployment |
|---|---|---|
| Keeps N Pods alive | Yes | Yes, through a ReplicaSet it owns |
| Versioned updates | **No** | Yes — a new ReplicaSet per revision |
| Rollback | **No** | `kubectl rollout undo`, instant |
| Update strategy | None | `RollingUpdate` or `Recreate` |
| Revision history | None | `kubectl rollout history` |
| Written by hand in practice | Rarely | Almost always |

A ReplicaSet can only answer "are there N Pods?". Change its image and it does nothing to the Pods already running — it has no notion of a rollout. A Deployment adds exactly that layer: it creates a second ReplicaSet for the new template, shifts replicas between the two, and keeps the old one at 0 so a rollback is just shifting them back. Seen directly in session 9:

```text
$ kubectl get rs -n s10-strategies -l app=web-rolling
NAME                     DESIRED   CURRENT   READY   AGE
web-rolling-678b84d9db   0         0         0       13s
web-rolling-95f475bc     4         4         4       1s
```

Two ReplicaSets, one Deployment, one of them parked at zero. That parked ReplicaSet *is* the rollback.

### Deployment vs DaemonSet vs StatefulSet

| | Deployment | DaemonSet | StatefulSet |
|---|---|---|---|
| How many Pods | Whatever `replicas` says | Exactly one per eligible node | Whatever `replicas` says |
| Pod names | Random suffix (`web-7b84d9f7f5-bg2jl`) | Random suffix | **Ordinal and stable** (`web-0`, `web-1`) |
| Identity across restart | Fresh name and IP | Fresh name and IP | **Same name, same DNS record** |
| Storage | Usually shared or none | Usually host paths | **One PVC per Pod**, via `volumeClaimTemplates` |
| Start / stop order | All at once | Per node, as nodes appear | **Ordered**: 0, then 1, then 2 |
| Scales with | Load | Cluster size | Load, but carefully |
| Typical use | Stateless web app, API | Log shipper, metrics exporter, CNI | Database, Kafka, anything with a replication protocol |

The dividing line is whether a replica is **interchangeable**. For a stateless API any Pod can serve any request, so random names are fine and a Deployment fits. A database replica is not interchangeable — replica 0 may be the primary, each one owns its own disk, and the others find it by a fixed DNS name. That needs stable identity and per-Pod storage, which is a StatefulSet. A DaemonSet answers a different question entirely: not "how many" but "one everywhere", so its count follows the node count. Session 9 showed this — the DaemonSet skipped the control-plane node until the taint was tolerated.

### ReplicaSet vs Service

These are not alternatives; they solve unrelated problems and are almost always used together.

| | ReplicaSet | Service |
|---|---|---|
| Category | Workload controller | Network abstraction |
| Answers | "Do N Pods exist?" | "What is the stable address for these Pods?" |
| Creates Pods | Yes | **Never** |
| Gives a stable IP / DNS name | No | Yes |
| Survives Pod replacement | Recreates the Pod, with a new IP | Keeps the same ClusterIP and name |
| Finds its targets by | `spec.selector.matchLabels` (owns them) | `spec.selector` (matches them, owns nothing) |

Both use label selectors, which is where they get confused, but the relationship differs. A ReplicaSet **owns** the Pods it selects — it sets `ownerReferences` and will recreate them if deleted. A Service only **matches** Pods; it takes no ownership and creates nothing. Delete a Service and every Pod keeps running, just unreachable by name. Delete a ReplicaSet and the Pods go with it.

They are complementary because Pod IPs are not durable. The ReplicaSet guarantees Pods exist; the Service guarantees there is one address in front of whichever Pods currently do. The `kubectl delete pod` test in section 1 showed both halves: the controller replaced the Pod with a new IP, and the Service picked up the replacement without its own address changing.

A Service with no matching Pods is not an error, just empty — the failure mode diagnosed in section 6.
