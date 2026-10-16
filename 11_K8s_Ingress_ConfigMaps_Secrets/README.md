# Kubernetes Ingress, ConfigMaps & Secrets – Homework

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

Manifests are from the class repository ([session-12-ingress-configmaps-secrets/04-full-demo](https://github.com/Nency-Ravaliya/devops-heros/tree/main/session-12-ingress-configmaps-secrets/04-full-demo)) and are copied into [manifests/](manifests). I ran them on my local kind cluster. All outputs are copied from my terminal.

| Object | Purpose |
|---|---|
| **ConfigMap** | Non-sensitive configuration as key-value pairs, kept outside the image |
| **Secret** | Sensitive values (passwords, tokens, TLS keys), stored base64-encoded |
| **Ingress** | HTTP/HTTPS routing rules (host and path) from one entry point to many Services |
| **Ingress Controller** | The actual reverse proxy (here NGINX) that reads Ingress objects and applies them |

What gets built:

```text
                       Host: yatri.local
 curl / browser ─────────────► NGINX Ingress Controller
                                   │
                  path /           │           path /api/...
                  ▼                                ▼
      yatri-frontend-service            yatri-backend-service     (ClusterIP)
                  ▼                                ▼
        2 × Nginx Pods                  2 × Python API Pods
                                         ▲               ▲
                                  ConfigMap            Secret
                               yatri-app-config    yatri-db-secret
```

---

*Screenshots below come from a second run of the same labs, so Pod names, IPs and ages differ from the text output.*

## 0. Install the Ingress controller

The class demo uses `minikube addons enable ingress`. On kind the same NGINX controller is installed from its official manifest. My kind cluster maps the node's port 80 to `localhost:8081` on my laptop (see [kind-cluster.yaml](../08_Kubernetes_Fundamentals/kind-cluster.yaml)).

```text
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.3/deploy/static/provider/kind/deploy.yaml | tail -6
service/ingress-nginx-controller-admission created
deployment.apps/ingress-nginx-controller created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
ingressclass.networking.k8s.io/nginx created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created

$ kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
pod/ingress-nginx-controller-6897f8b69b-lb2kz condition met
```

On kind the controller must run on the node that has the mapped ports (the one labelled `ingress-ready=true`), so I pinned it there:

```bash
kubectl -n ingress-nginx patch deploy ingress-nginx-controller --type merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux","ingress-ready":"true"}}}}}'
```

```text
$ kubectl get pods -n ingress-nginx -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP           NODE                      NOMINATED NODE   READINESS GATES
ingress-nginx-controller-56859495b9-cp89g   1/1     Running   0          38s   10.244.0.5   devops-hw-control-plane   <none>           <none>

$ kubectl get ingressclass
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       36s
```

## 1. ConfigMap

[manifests/configmap.yaml](manifests/configmap.yaml)

```text
$ kubectl apply -f configmap.yaml
configmap/yatri-app-config created

$ kubectl get configmap yatri-app-config
NAME               DATA   AGE
yatri-app-config   5      0s

$ kubectl describe configmap yatri-app-config | sed -n "/^Data/,/^BinaryData/p"
Data
====
APP_PORT:
----
5000

DEFAULT_CURRENCY:
----
INR

ENVIRONMENT:
----
production

LOG_LEVEL:
----
INFO

MAX_BOOKING_DAYS:
----
30

BinaryData

$ kubectl create configmap cli-config --from-literal=FEATURE_FLAG=true --from-literal=REGION=ap-south-1
configmap/cli-config created

$ kubectl get configmap cli-config -o jsonpath="{.data}"; echo
{"FEATURE_FLAG":"true","REGION":"ap-south-1"}
```

**What I understood:** a ConfigMap is plain text and can be created from YAML or directly from the CLI (`--from-literal`, `--from-file`). The same image can run in dev and production with different ConfigMaps, so configuration changes do not need an image rebuild.

**Ingress controller running, ConfigMap applied**

![k11-01-ingress-controller-configmap](screenshots/k11-01-ingress-controller-configmap.png)


### Live updates: volumes refresh, environment variables do not

A ConfigMap can be consumed two ways, and they behave differently when the ConfigMap changes. [manifests/configmap-live-update.yaml](manifests/configmap-live-update.yaml) wires the **same** ConfigMap in both ways at once, in namespace `s12-configmap`, so the two can be compared directly.

```yaml
envFrom:                      # path 1: environment variables
  - configMapRef:
      name: live-config
volumeMounts:                 # path 2: files
  - name: config
    mountPath: /etc/live-config
```

Before any change, both agree:

```text
$ kubectl exec config-consumer -n s12-configmap -- env | grep -E 'GREETING|LOG_LEVEL'
GREETING=hello from v1
LOG_LEVEL=INFO

$ kubectl exec config-consumer -n s12-configmap -- cat /etc/live-config/GREETING
hello from v1

$ kubectl exec config-consumer -n s12-configmap -- ls -l /etc/live-config
total 0
lrwxrwxrwx    1 root     root            15 Oct 16 19:09 GREETING -> ..data/GREETING
lrwxrwxrwx    1 root     root            16 Oct 16 19:09 LOG_LEVEL -> ..data/LOG_LEVEL
```

Those are **symlinks**, not plain files — that detail matters in a moment. Now change the ConfigMap:

```text
$ kubectl patch configmap live-config -n s12-configmap -p '{"data":{"GREETING":"hello from v2","LOG_LEVEL":"DEBUG"}}'
configmap/live-config patched

$ kubectl get configmap live-config -n s12-configmap -o jsonpath='{.data}'
{"GREETING":"hello from v2","LOG_LEVEL":"DEBUG"}
```

After waiting for the kubelet to sync — **81 seconds** on this cluster:

```text
$ kubectl exec config-consumer -n s12-configmap -- cat /etc/live-config/GREETING   # the VOLUME
hello from v2

$ kubectl exec config-consumer -n s12-configmap -- env | grep -E 'GREETING|LOG_LEVEL'   # the ENV VARS
GREETING=hello from v1
LOG_LEVEL=INFO

$ kubectl get pod config-consumer -n s12-configmap
NAME              READY   STATUS    RESTARTS   AGE
config-consumer   1/1     Running   0          104s
```

**The file says v2. The environment still says v1.** Same ConfigMap, same Pod, no restart (`RESTARTS 0`).

The reason is *when* each is read. Environment variables are handed to the process once, at exec time — after that they live in the process's memory and nothing can change them from outside. The volume is maintained by the kubelet, which rewrites the `..data` directory and atomically re-points the symlinks, so the next `read()` sees new bytes.

Recreating the Pod is what picks up the new environment:

```text
$ kubectl delete pod config-consumer -n s12-configmap && kubectl apply -f ...
pod "config-consumer" deleted
pod/config-consumer created

$ kubectl exec config-consumer -n s12-configmap -- env | grep -E 'GREETING|LOG_LEVEL'
GREETING=hello from v2
LOG_LEVEL=DEBUG
```

Two things I took from this:

- The ~60-second default sync (81s measured here) means a volume-mounted config is eventually consistent, not instant. An app that must react immediately has to watch the file, not read it once at startup.
- For a Deployment the real fix is `kubectl rollout restart deployment/<name>`, which recreates the Pods and therefore re-reads the environment. A common production trick is putting a hash of the ConfigMap in a Pod template annotation, so changing the config changes the template and triggers a rollout automatically.
- A mistake I made while testing: re-running `kubectl apply -f` on the manifest **reverted** the ConfigMap to v1, because the file still said v1. `patch` and `apply` fight each other when the manifest is the source of truth.

## 2. Secret

[manifests/secret.yaml](manifests/secret.yaml)

```text
$ kubectl apply -f secret.yaml
secret/yatri-db-secret created

$ kubectl get secret yatri-db-secret
NAME              TYPE     DATA   AGE
yatri-db-secret   Opaque   3      0s

$ kubectl describe secret yatri-db-secret | sed -n "/^Type/,\$p"
Type:  Opaque

Data
====
POSTGRES_DB:        19 bytes
POSTGRES_PASSWORD:  14 bytes
POSTGRES_USER:      11 bytes

$ kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_USER}"; echo
eWF0cmlfYWRtaW4=

$ kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_USER}" | base64 --decode; echo
yatri_admin

$ echo -n "yatri_admin" | base64
eWF0cmlfYWRtaW4=

$ echo "yatri_admin" | base64
eWF0cmlfYWRtaW4K
```

**What I understood:**

- `kubectl describe secret` shows only the **size** of each value, never the value.
- Values under `data:` are **base64-encoded, not encrypted**. Anyone who can read the Secret can decode it with `base64 --decode`. Real protection comes from RBAC, encryption at rest for etcd, and keeping Secret YAML out of Git (or using Sealed Secrets / an external vault).
- **The base64 gotcha:** `echo -n "yatri_admin" | base64` gives `eWF0cmlfYWRtaW4=`, but without `-n` the result is `eWF0cmlfYWRtaW4K`. The trailing `K` is an encoded newline. That hidden newline ends up inside the password and causes login failures that are very hard to spot. Always use `echo -n`, or use `stringData:` and let Kubernetes do the encoding.

**Secret: describe hides values, base64 decode, and the `echo -n` gotcha**

![k11-02-secret](screenshots/k11-02-secret.png)


### What a Secret actually gives you, and what it does not

`kubectl describe` on a Secret hides the value, which is easy to mistake for protection:

```text
$ kubectl describe secret demo-secret -n s12-configmap
Name:         demo-secret
Namespace:    s12-configmap
Type:  Opaque

Data
====
API_KEY:  20 bytes
```

It reports the *length* and nothing else. But `describe` is the only thing being coy:

```text
$ kubectl get secret demo-secret -n s12-configmap -o jsonpath='{.data.API_KEY}'
bm90LWEtcmVhbC1rZXktMTIzNDU=

$ kubectl get secret demo-secret -n s12-configmap -o jsonpath='{.data.API_KEY}' | base64 -d
not-a-real-key-12345
```

One extra command and the value is in plain text. **base64 is an encoding, not encryption** — it exists so binary data can live in YAML, and it stops nothing. Anyone who can read the Secret can read its contents:

```text
$ kubectl auth can-i get secrets -n s12-configmap
yes
```

So what does a Secret actually buy over a ConfigMap?

| | What it does | What it does not do |
|---|---|---|
| Value in `describe` / logs | Kept out of casual output | — |
| RBAC | Can be granted separately from ConfigMaps, so `get secrets` is its own permission | Nothing, if the role already allows it |
| Node exposure | Only sent to nodes running a Pod that uses it, and held in tmpfs rather than on disk | — |
| At rest in etcd | — | **Not encrypted by default.** Needs an `EncryptionConfiguration` on the API server |
| In a Git repo | — | **Nothing.** A committed Secret is a published Secret |

The honest summary: a Secret is a *typed container with its own RBAC surface*, not a vault. It is better than a ConfigMap for credentials because access can be restricted independently and the value stays out of incidental output. It is not a substitute for encryption at rest, and committing one to a repo — as this homework does with `yatri-db-secret`, deliberately, since the values are throwaway — leaks it completely. Real deployments keep the value in an external store (Vault, AWS Secrets Manager, Sealed Secrets) and let the cluster pull it in.

## 3. Deploy the applications and inject the configuration

[manifests/frontend.yaml](manifests/frontend.yaml), [manifests/backend.yaml](manifests/backend.yaml)

The backend uses both injection styles:

```yaml
envFrom:
  - configMapRef:
      name: yatri-app-config          # every key becomes an environment variable
env:
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:                   # one specific key from the Secret
        name: yatri-db-secret
        key: POSTGRES_USER
```

```text
$ kubectl apply -f frontend.yaml -f backend.yaml
deployment.apps/yatri-frontend created
service/yatri-frontend-service created
deployment.apps/yatri-backend created
service/yatri-backend-service created

$ kubectl rollout status deployment/yatri-frontend --timeout=180s | tail -1
deployment "yatri-frontend" successfully rolled out

$ kubectl rollout status deployment/yatri-backend --timeout=180s | tail -1
deployment "yatri-backend" successfully rolled out

$ kubectl get pods,svc | grep -E "NAME|yatri"
NAME                                 READY   STATUS    RESTARTS   AGE
pod/yatri-backend-6c58cb99c7-4j6kj   1/1     Running   0          34s
pod/yatri-backend-6c58cb99c7-vt7dv   1/1     Running   0          34s
pod/yatri-frontend-ddcfc4b5f-6dgj6   1/1     Running   0          34s
pod/yatri-frontend-ddcfc4b5f-htfm2   1/1     Running   0          34s
NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/yatri-backend-service    ClusterIP   10.96.223.217   <none>        80/TCP    34s
service/yatri-frontend-service   ClusterIP   10.96.232.221   <none>        80/TCP    34s

$ kubectl exec deploy/yatri-backend -- env | grep -E "ENVIRONMENT|LOG_LEVEL|DEFAULT_CURRENCY|MAX_BOOKING|POSTGRES_USER|POSTGRES_DB" | sort
DEFAULT_CURRENCY=INR
ENVIRONMENT=production
LOG_LEVEL=INFO
MAX_BOOKING_DAYS=30
POSTGRES_DB=yatri_production_db
POSTGRES_USER=yatri_admin
```

**What I understood:** inside the container the ConfigMap keys and the **decoded** Secret values are ordinary environment variables. The application does not need to know Kubernetes exists. Environment variables are read only at start-up, so after changing a ConfigMap the Pods need `kubectl rollout restart deployment/<name>`. ConfigMaps mounted as volumes are refreshed automatically.

**Apps deployed, ConfigMap and Secret values visible as environment variables**

![k11-03-apps-env](screenshots/k11-03-apps-env.png)


## 4. Ingress

[manifests/ingress.yaml](manifests/ingress.yaml): host `yatri.local`, `/api(/|$)(.*)` → backend with `rewrite-target: /$2`, and `/` → frontend.

Instead of editing `/etc/hosts`, I sent the `Host` header with `curl`. The result is the same, because the Ingress controller routes based on that header.

```text
$ kubectl apply -f ingress.yaml
ingress.networking.k8s.io/yatri-ingress created

$ kubectl get ingress yatri-ingress
NAME            CLASS   HOSTS         ADDRESS     PORTS   AGE
yatri-ingress   nginx   yatri.local   localhost   80      15s

$ kubectl describe ingress yatri-ingress | sed -n "/^Rules/,/^Annotations/p"
Rules:
  Host         Path  Backends
  ----         ----  --------
  yatri.local
               /api(/|$)(.*)   yatri-backend-service:80 (10.244.1.54:5000,10.244.1.55:5000)
               /               yatri-frontend-service:80 (10.244.1.53:80,10.244.1.52:80)
Annotations:   nginx.ingress.kubernetes.io/rewrite-target: /$2

$ curl -s -H "Host: yatri.local" http://localhost:8081/ | head -12
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>

$ curl -s -H "Host: yatri.local" http://localhost:8081/api/
Yatri Backend API
=================
ENVIRONMENT     : production
LOG_LEVEL       : INFO
DEFAULT_CURRENCY: INR
POSTGRES_USER   : yatri_admin
POSTGRES_DB     : yatri_production_db

$ curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: unknown.local" http://localhost:8081/
HTTP 404
```

**What I understood:**

- **One entry point, two Services.** `/` returned the Nginx frontend page and `/api/` returned the backend API. Both Services are plain ClusterIP, so nothing else is exposed.
- The backend response contains `ENVIRONMENT: production` and `DEFAULT_CURRENCY: INR` from the **ConfigMap**, and `POSTGRES_USER: yatri_admin` from the **Secret**. That proves the whole chain works: Ingress → Service → Pod → configuration.
- `rewrite-target: /$2` removes the `/api` prefix, so the backend receives `/` instead of `/api/`.
- A request with an unknown host (`unknown.local`) got `404` from the controller's default backend, because no rule matches it. Routing really is host based.
- `ingressClassName: nginx` selects which controller handles the Ingress. An Ingress object without a running controller does nothing.
- Compared to one LoadBalancer per Service, Ingress needs a single external IP and adds path/host routing and TLS termination in one place.

**Ingress routing: `/` → frontend, `/api/` → backend, unknown host → 404**

![k11-04-ingress](screenshots/k11-04-ingress.png)

**Browser: `http://yatri.local:8081/` (frontend through the Ingress)**

![k11-05-browser-frontend](screenshots/k11-05-browser-frontend.png)

**Browser: `http://yatri.local:8081/api/` (backend showing ConfigMap and Secret values)**

![k11-06-browser-api](screenshots/k11-06-browser-api.png)


## 5. Clean up

```bash
kubectl delete -f manifests/
kubectl delete configmap cli-config
kubectl delete namespace s12-configmap
```
