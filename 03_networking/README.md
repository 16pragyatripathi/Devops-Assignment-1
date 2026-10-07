# Networking Fundamentals – Homework

**Name:** Pragya Tripathi
**Roll No:** 24BCS10032

All commands were run on my own laptop (macOS). On macOS `ifconfig` and `netstat` are used where Linux uses `ip a` and `ss`. For privacy I have not pasted my MAC address, neighbour (ARP) table or VPN routes, so a few commands are filtered with `grep`.

## Command summary

| Command | OSI layer it helps debug | What it answers |
|---|---|---|
| `ifconfig` / `ip a` | 2–3 | What is my IP address, netmask, is the interface up? |
| `ping` | 3 | Is the host reachable, and how long does a round trip take? |
| `traceroute` | 3 | Which routers does the packet pass through, where does it slow down? |
| `netstat -rn` / `ip route` | 3 | Where do packets go first (default gateway)? |
| `netstat -an` / `ss -tulnp` | 4 | Which ports are listening or connected? |
| `nc -vz` / `telnet` | 4 | Is a specific TCP port open on a remote host? |
| `nslookup`, `dig`, `host` | 7 (DNS) | Which IP does this name resolve to, and who answered? |
| `curl` | 7 (HTTP) | Does the web server answer, with which status and headers? |

---

## 1. `ifconfig` – my IP address

```text
$ ifconfig en0 | grep -E 'flags|inet |status'
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 172.20.2.105 netmask 0xfffff800 broadcast 172.20.7.255
	status: active
```

**What I understood:** my laptop has the private IP `172.20.2.105`. The netmask `0xfffff800` is `255.255.248.0`, which is a `/21` network, so there are 2^11 − 2 = 2046 usable host addresses and the broadcast address is `172.20.7.255`. `172.16.0.0 – 172.31.255.255` is a private (class B) range, so this address is not visible on the internet and goes out through NAT.

## 2. `ping` – reachability and latency

```text
$ ping -c 4 google.com
PING google.com (142.251.222.142): 56 data bytes
64 bytes from 142.251.222.142: icmp_seq=0 ttl=118 time=21.236 ms
64 bytes from 142.251.222.142: icmp_seq=1 ttl=118 time=16.275 ms
64 bytes from 142.251.222.142: icmp_seq=2 ttl=118 time=62.286 ms
64 bytes from 142.251.222.142: icmp_seq=3 ttl=118 time=57.910 ms

--- google.com ping statistics ---
4 packets transmitted, 4 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 16.275/39.427/62.286/20.803 ms
```

**What I understood:** ping sends ICMP echo requests. `0.0% packet loss` means the host is reachable. `time` is the round trip time. `ttl=118` means the reply crossed some routers on the way, because every router reduces TTL by one. DNS is also tested indirectly, since `google.com` was resolved to an IP first.

## 3. `traceroute` – the path of a packet

```text
$ traceroute -m 8 -w 2 -q 1 google.com
traceroute to google.com (142.251.222.142), 8 hops max, 40 byte packets
 1  172.20.0.1 (172.20.0.1)  35.883 ms
 2  49.200.242.17 (49.200.242.17)  257.856 ms
 3  128.185.120.53 (128.185.120.53)  68.359 ms
 4  116.119.164.82 (116.119.164.82)  72.438 ms
 5  142.250.169.206 (142.250.169.206)  58.779 ms
 6  *
 7  142.251.55.62 (142.251.55.62)  25.845 ms
 8  209.85.247.251 (209.85.247.251)  106.954 ms
```

**What I understood:** traceroute sends packets with TTL 1, 2, 3 and so on. Each router that drops the packet replies, which reveals one hop at a time. Hop 1 is my default gateway `172.20.0.1`, the next hops belong to the ISP, and the last ones belong to Google. `*` means that router did not reply in time, which is normal because many routers ignore these probes. It does not mean the path is broken.

## 4. `netstat` – routing table and ports

```text
$ netstat -rn -f inet | grep -E "Destination|default" | head -2
Destination        Gateway            Flags               Netif Expire
default            172.20.0.1         UGScg                 en0

$ ifconfig en0 | grep -E 'flags|inet |status'
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 172.20.2.105 netmask 0xfffff800 broadcast 172.20.7.255
	status: active

$ netstat -an -p tcp | grep -c LISTEN
43

$ netstat -an -p tcp | grep ESTABLISHED | wc -l
      65
```

Sample of listening sockets:

```text
$ netstat -an -p tcp | grep LISTEN | head -10
tcp4       0      0  127.0.0.1.26922        *.*                    LISTEN
tcp4       0      0  127.0.0.1.38474        *.*                    LISTEN
tcp46      0      0  *.52884                *.*                    LISTEN
tcp46      0      0  *.52883                *.*                    LISTEN
tcp6       0      0  *.54763                *.*                    LISTEN
tcp4       0      0  *.54763                *.*                    LISTEN
tcp4       0      0  127.0.0.1.57577        *.*                    LISTEN
tcp4       0      0  127.0.0.1.57575        *.*                    LISTEN
tcp4       0      0  127.0.0.1.57570        *.*                    LISTEN
tcp4       0      0  127.0.0.1.52365        *.*                    LISTEN
```

**What I understood:** the `default` route sends everything that is not local to the gateway `172.20.0.1` through `en0`. `LISTEN` means a program is waiting for connections on that port. `127.0.0.1.port` is only reachable from my own machine, while `*.port` accepts connections from the network. On Linux the modern equivalent is `ss -tulnp`.

## 5. `nslookup`, `dig` and `host` – DNS

```text
$ nslookup github.com
Server:		1.1.1.1
Address:	1.1.1.1#53

Non-authoritative answer:
Name:	github.com
Address: 20.207.73.82

$ dig +noall +answer +stats github.com
github.com.		20	IN	A	20.207.73.82
;; Query time: 106 msec
;; SERVER: 1.1.1.1#53(1.1.1.1)
;; WHEN: Thu Sep 17 18:57:05 IST 2026
;; MSG SIZE  rcvd: 55

$ dig +short MX gmail.com
20 alt2.gmail-smtp-in.l.google.com.
30 alt3.gmail-smtp-in.l.google.com.
40 alt4.gmail-smtp-in.l.google.com.
10 alt1.gmail-smtp-in.l.google.com.
5 gmail-smtp-in.l.google.com.

$ host scaler.com
scaler.com has address 54.240.162.67
scaler.com has address 54.240.162.70
scaler.com has address 54.240.162.109
scaler.com has address 54.240.162.101
scaler.com mail is handled by 1 aspmx.l.google.com.
scaler.com mail is handled by 10 aspmx2.googlemail.com.
scaler.com mail is handled by 10 aspmx3.googlemail.com.
scaler.com mail is handled by 5 alt1.aspmx.l.google.com.
scaler.com mail is handled by 5 alt2.aspmx.l.google.com.
```

**What I understood:** all three ask a DNS server to turn a name into records. `Server: 1.1.1.1` is the resolver that answered. `Non-authoritative answer` means the reply came from a cache, not from GitHub's own name server. In the `dig` output, `20` is the TTL in seconds, `IN A` is an IPv4 address record, and `Query time` tells how slow DNS is. `MX` records list the mail servers of a domain, and the lowest number has the highest priority.

## 6. `curl` – testing HTTP

```text
$ curl -sI https://github.com | head -8
HTTP/2 200
date: Thu, 17 Sep 2026 13:26:57 GMT
content-type: text/html; charset=utf-8
content-language: en-US
vary: X-PJAX, X-PJAX-Container, Turbo-Visit, Turbo-Frame, X-Requested-With, X-GitHub-Client-Version, Accept-Language, Sec-Fetch-Site,Accept-Encoding, Accept, X-Requested-With
etag: W/"bce79b00777dcf55a02caaf5d847eac4"
cache-control: max-age=0, private, must-revalidate
strict-transport-security: max-age=31536000; includeSubdomains; preload

$ curl -s -o /dev/null -w "http_code=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" https://github.com
http_code=200 dns=0.003429s connect=0.135607s tls=0.206206s total=1.662215s
```

**What I understood:** `-I` fetches only the response headers. `HTTP/2 200` means success. The `-w` format breaks the request into DNS lookup, TCP connect, TLS handshake and total time, which shows which step is slow.

## 7. `nc` (netcat) – is a TCP port open?

`telnet` is not installed on recent macOS versions, so I used `nc -vz`, which does the same port check.

```text
$ nc -vz -w 3 github.com 443
Connection to github.com port 443 [tcp/https] succeeded!

$ nc -vz -w 3 github.com 81
nc: connectx to github.com port 81 (tcp) failed: Operation timed out
```

**What I understood:** port 443 (HTTPS) is open on github.com. Port 81 timed out, which means a firewall silently dropped the packets. A closed port on a reachable host would give `Connection refused` immediately instead of a timeout.

---

## IP addressing notes (from the session)

| Class | First octet | Default mask | Network / host bits | Usable hosts |
|---|---|---|---|---|
| A | 1 – 127 | 255.0.0.0 (`/8`) | 8 / 24 | 2^24 − 2 |
| B | 128 – 191 | 255.255.0.0 (`/16`) | 16 / 16 | 2^16 − 2 |
| C | 192 – 223 | 255.255.255.0 (`/24`) | 24 / 8 | 2^8 − 2 = 254 |
| D | 224 – 239 | multicast | – | – |

Private ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.

Two addresses are subtracted because the first address is the network address and the last one is the broadcast address. Example: `197.23.45.10` with mask `255.255.255.0` is class C, the network is `197.23.45.0`, the broadcast is `197.23.45.255`, and the usable hosts are `.1` to `.254`.

## Troubleshooting order I learned

1. `ifconfig` – do I have an IP?
2. `ping <gateway>` – is the local network fine?
3. `ping 8.8.8.8` – is the internet reachable by IP?
4. `nslookup <name>` – is DNS working?
5. `nc -vz <host> <port>` – is the port open?
6. `curl -I <url>` – is the application answering?
