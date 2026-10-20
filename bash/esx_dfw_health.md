# How-To use esx_dfw_health.sh 

## Introduction
Troubleshooting Distributed Firewall (DFW) logs across a fleet of ESXi hosts can feel like finding a needle in a haystack; especially when you need quick visibility into high-frequency logging events, top hit rules, or noisy VIFs.
To simplify health checks and diagnostic sweeps, Here is a Bash automation script (esx_dfw_health.sh) that automates discovery and log parsing directly from the NSX Manager shell.
This article shows sample output and how to use the esx_dfw_health.sh 

**Identify all the clusters**
```
root@nsx-mngr-01:~# ./esx_dfw_health.sh -l
NSX admin password:
Cluster-A   bd2e1d19-aaaa-1111-8eca-############:domain-c3
Cluster-B   bd2e1d19-aaaa-1111-8eca-############:domain-c24
```

**Run on Entire Environment**
```
root@nsx-mngr-01:~# ./esx_dfw_health.sh
NSX admin password:
ESXi root password:
<SNIP: Example NOT shown. The output will be similar to Cluster Run>
```

**Run on Entire Environment & Save it to a File**
```
root@nsx-mngr-01:~# ./esx_dfw_health.sh -o esx_dfw_health_all.txt
NSX admin password:
ESXi root password:
<SNIP: Example NOT shown. The output will be similar to Cluster Run>
```

**Running Per Cluster**
```
root@nsx-mngr-01:~# ./esx_dfw_health.sh -c Cluster-A
NSX admin password:
ESXi root password:
==================================================
Host: esx-0#.corp.local  Cluster: Cluster-A
==================================================
(connected via esx-0#.corp.local)
<SNIP>
--- Highest logged seconds Top 10 ---
COUNT      TIME_STAMP
68         2026-10-01T20:53:23
64         2026-10-01T20:53:22
59         2026-10-01T20:53:24
<SNIP>

--- Top 10 VIFs ---
COUNT      VIF       VM.VNIC
16571      2ff6ff74  113112-Ubuntu-24_04-64-Desktop-Tools-MAG.eth0
202        f46a00af  <not on this host>
<SNIP>

--- Top 10 VIFs All files ---
COUNT      VIF       VM.VNIC
16571      2ff6ff74  113112-Ubuntu-24_04-64-Desktop-Tools-MAG.eth0
202        f46a00af  <not on this host>
<SNIP>


--- Top 10 Rules from All files ---
COUNT      RULE_ID
  12082 1003
   4691 2
<SNIP>

--- Top 10 Destinations with Port from All files ---
COUNT      DESTINATION_AND_PORT
  11836 192.168.110.10/53
    626 74.125.143.100/443
    582 74.125.143.113/443
<SNIP>

--- Top 10 Sources from All files ---
COUNT      SOURCE
  15881 172.16.251.51
    278 fe80::ffff:ffff:ffff:ffff
    264 0.0.0.0
<SNIP>

==================================================
Host: esx-0#.corp.local  Cluster: Cluster-#
==================================================
<SNIP>

root@nsx-mngr-01:~#
```

**Run on Multiple Cluster**
```
root@nsx-mngr-01:~# ./esx_dfw_health.sh -c Cluster-A -c Cluster-B
NSX admin password:
ESXi root password:
<SNIP: Example NOT shown. The output will be similar to Cluster Run>
```
