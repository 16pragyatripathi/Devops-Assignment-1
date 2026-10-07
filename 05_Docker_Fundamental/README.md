# Docker Fundamentals – Homework

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

## Task: Hello World web applications with Docker

Six applications, each in its own folder with its code and a `Dockerfile`.

| # | Folder | Stack | Base image | Container port | Host port used |
|---|---|---|---|---|---|
| 1 | [nodejs-app](nodejs-app) | Node.js `http` server | `node:20` | 3000 | 9001 |
| 2 | [python-app](python-app) | Python `http.server` | `python:3.12` | 8000 | 9002 |
| 3 | [java-app](java-app) | Java `HttpServer` | `eclipse-temurin:21` | 8080 | 9003 |
| 4 | [Apache-app](Apache-app) | Apache httpd static page | `httpd:2.4` | 80 | 9004 |
| 5 | [React-app](React-app) | React + Vite, served by Nginx (multi-stage build) | `node:20-alpine` → `nginx:alpine` | 80 | 9005 |
| 6 | [nginx-app](nginx-app) | Nginx static page | `nginx:alpine` | 80 | 9006 |

## Step 1: Build the images

```bash
docker build -t hw-nodejs:1.0 nodejs-app
docker build -t hw-python:1.0 python-app
docker build -t hw-java:1.0   java-app
docker build -t hw-apache:1.0 Apache-app
docker build -t hw-react:1.0  React-app
docker build -t hw-nginx:1.0  nginx-app
```

```text
$ docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' | grep '^hw-' | sort
hw-apache:1.0  205MB
hw-java:1.0  744MB
hw-nginx:1.0  102MB
hw-nodejs:1.0  1.57GB
hw-python:1.0  1.6GB
hw-react:1.0  102MB
```

## Step 2: Run the containers

`-d` runs in the background, `--name` gives a fixed name, `-p host:container` publishes the port.

```text
$ docker run -d --name hw-nodejs -p 9001:3000 hw-nodejs:1.0
5ee412597b8fdd11d9973c436c9b60407a930be4838d135a362c5ea3a8c16f90

$ docker run -d --name hw-python -p 9002:8000 hw-python:1.0
dd5fcd5f038ff234ab044c4523d0c5b6e5c175791e95ea528dcb2eb611795375

$ docker run -d --name hw-java -p 9003:8080 hw-java:1.0
a7573c571980fa98d05ff34c1a48f57e5d02da31275fa9ff8a8c03a3be6e491a

$ docker run -d --name hw-apache -p 9004:80 hw-apache:1.0
5bd682b1fe0b47a615089b7d0886cdefd40e649c53d1d6b7811f17b2790e9aee

$ docker run -d --name hw-react -p 9005:80 hw-react:1.0
e21d74fea2ba02665fc39eb325b95c7ae454082bd747d48c6d6507310e40daf2

$ docker run -d --name hw-nginx -p 9006:80 hw-nginx:1.0
7e617492d31cd0d05a5afc660908be1460cdfdd18f5c28ece5df1e9a0757dcb0
```

## Step 3: Verify the containers are running

```text
$ docker ps --filter 'name=^hw-' --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
NAMES       IMAGE           STATUS          PORTS
hw-nginx    hw-nginx:1.0    Up 13 seconds   0.0.0.0:9006->80/tcp, [::]:9006->80/tcp
hw-react    hw-react:1.0    Up 13 seconds   0.0.0.0:9005->80/tcp, [::]:9005->80/tcp
hw-apache   hw-apache:1.0   Up 13 seconds   0.0.0.0:9004->80/tcp, [::]:9004->80/tcp
hw-java     hw-java:1.0     Up 13 seconds   0.0.0.0:9003->8080/tcp, [::]:9003->8080/tcp
hw-python   hw-python:1.0   Up 13 seconds   0.0.0.0:9002->8000/tcp, [::]:9002->8000/tcp
hw-nodejs   hw-nodejs:1.0   Up 13 seconds   0.0.0.0:9001->3000/tcp, [::]:9001->3000/tcp
```

## Step 4: Verify that Hello World is displayed

Each URL can be opened in the browser. Here the same pages are fetched with `curl`.

```text
$ curl -s http://localhost:9001
<h1>Hello World</h1>
$ curl -s http://localhost:9002
<h1>Hello World</h1>
$ curl -s http://localhost:9003
<h1>Hello World</h1>
$ curl -s http://localhost:9004
<h1>Hello World</h1>
$ curl -s http://localhost:9005
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>React Hello World</title>
    <script type="module" crossorigin src="/assets/index-CRbdCdKj.js"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>

$ curl -s http://localhost:9006
<h1>Hello World</h1>
```

The React page is an empty `<div id="root">` plus a JavaScript bundle, because React draws the heading in the browser. To confirm the text is really in the bundle that Nginx serves:

```text
$ curl -s http://localhost:9005/$(curl -s http://localhost:9005 | grep -o "assets/[^\"]*\.js") | grep -o "Hello World from React"
Hello World from React
```

Opening <http://localhost:9005> in a browser shows the heading **Hello World from React**.

## Step 5: Clean up

```bash
docker rm -f hw-nodejs hw-python hw-java hw-apache hw-react hw-nginx
```

## What I understood

- A `Dockerfile` is the recipe: `FROM` picks the base image, `COPY` adds my code, `RUN` executes at build time, `CMD` is what starts when the container runs, and `EXPOSE` documents the port.
- `EXPOSE` alone does not open anything. The port is only reachable from my laptop because of `-p 9001:3000`.
- The server inside the container must listen on `0.0.0.0`, not `127.0.0.1`, or the published port will not answer.
- Image size depends heavily on the base image. `node:20` and `python:3.12` are over 1.5 GB, while the Nginx based images are about 100 MB. The `-alpine` or `-slim` variants are a simple way to shrink them.
- The React app uses a **multi-stage build**. Stage 1 (`node:20-alpine`) runs `npm install` and `npm run build`. Stage 2 (`nginx:alpine`) copies only the `dist` folder. The final image has no Node.js and no `node_modules`.
