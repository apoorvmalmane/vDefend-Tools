#!/bin/bash
# Author: Apoorv Malmane <apoorv.malmane@broadcom.com>
#
# DISCLAIMER: This script is provided "as is", without warranty of any kind and
# without official support. It logs in to ESXi hosts as the configured user
# (root by default) and runs the commands listed below, so review those commands
# before use and try the script on a non-production cluster first. The author
# accepts no liability for any impact, data loss or outage resulting from its use.
# 
# ======================= What does this script do? ======================= 
# This script runs commands on ESXi hosts managed by NSX, from the NSX Manager shell.
# This script currently performs Health analysis (e.g., identifying high-frequency logging events and active VIFs). 
# Users are encouraged to adapt and re-use this script for other ESXi shell diagnostic tasks
# 
# Hosts are discovered via the NSX API (fabric/discovered-nodes), optionally per cluster.
#
# =======================  How to use the script ======================= 
# Usage:
#   ./esx_dfw_health.sh -l                         # list clusters
#   ./esx_dfw_health.sh                            # run on all hosts, output to console
#   ./esx_dfw_health.sh -c "Cluster-A"             # one cluster only
#   ./esx_dfw_health.sh -c "Cluster-A" -o out.txt  # console + text file
#
# Options:
#   -n <nsx>   NSX Manager address (default: 127.0.0.1)
#   -u <user>  NSX API user (default: admin)
#   -e <user>  ESXi SSH user (default: root)
#   -c <name>  cluster display name (repeat -c for several)
#   -o <file>  also write output to file
#   -l         list clusters and exit
#
# Env (optional, avoids prompts): NSX_PASS, ESX_PASS
# Requires: curl, perl (JSON::PP, same module json_pp uses); sshpass (only if ESX_PASS is used; otherwise ssh prompts per host)
# SSH must be enabled on the ESXi hosts.

# ======================= COMMANDS TO RUN (add more here) =======================
# One command per line, typed exactly as you would at the ESXi shell (no quoting/escaping needed).
# Format:  command     or     Description :: command      Lines starting with # are ignored.
read -r -d '' COMMANDS_TEXT <<'COMMANDS_END'

Current date/time :: date

ESXi version :: vmware -vl

# Hostname :: hostname

# IPv4 interfaces :: esxcli network ip interface ipv4 get

# NSX VIBs :: esxcli software vib list | grep -i nsx

Highest logged seconds Top 10 ::  less /var/run/log/dfwpktlogs* | awk -F. '{print $1}' | sort | uniq -c | sort -nrk 1 | head -n 10 | awk 'BEGIN {printf "%-10s %s\n", "COUNT", "TIME_STAMP"} {printf "%-10s %s\n", $1, $2}'

Top 10 VIFs :: printf "%-10s %-9s %s\n" COUNT VIF VM.VNIC; awk '{for(i=1; i<=NF; i++) if($i == "INET" || $i == "INET6") {print $(i-1); next}}' /var/run/log/dfwpktlogs* | sort | uniq -c | sort -nrk 1 | head -n 10 | while read c v; do f=$(vsipioctl getfilters | awk -F' : ' -v v="$v" '/Filter Name/{f=$2} /VIF ID/ && $2 ~ v"$" {print f}'); p=$(summarize-dvfilter | awk -v f="$f" '/^ port /{sub(/^ port [0-9]+ /,""); p=$0} $1=="name:" && $2==f {print p}'); printf "%-10s %-9s %s\n" "$c" "$v" "${p:-<not on this host>}"; done

Top 10 VIFs All files :: printf "%-10s %-9s %s\n" COUNT VIF VM.VNIC; (cat /var/run/log/dfwpktlogs.log 2>/dev/null; zcat /var/run/log/dfwpktlogs*.gz 2>/dev/null) |  awk '{for(i=1; i<=NF; i++) if($i == "INET" || $i == "INET6") {print $(i-1); next}}' | sort | uniq -c | sort -nrk 1 | head -n 10 | while read c v; do f=$(vsipioctl getfilters | awk -F' : ' -v v="$v" '/Filter Name/{f=$2} /VIF ID/ && $2 ~ v"$" {print f}'); p=$(summarize-dvfilter | awk -v f="$f" '/^ port /{sub(/^ port [0-9]+ /,""); p=$0} $1=="name:" && $2==f {print p}'); printf "%-10s %-9s %s\n" "$c" "$v" "${p:-<not on this host>}"; done

Top 10 Rules from All files :: printf "%-10s %s\n" COUNT RULE_ID; (cat /var/run/log/dfwpktlogs.log 2>/dev/null; zcat /var/run/log/dfwpktlogs*.gz 2>/dev/null) | awk '{for(i=1; i<=NF; i++) if($i == "IN" || $i == "OUT") {print $(i-1); next}}' /var/run/log/dfwpktlogs* | sort | uniq -c | sort -nrk 1 | head -n 10

Top 10 Destinations with Port from All files :: printf "%-10s %s\n" COUNT DESTINATION_AND_PORT;  (cat /var/run/log/dfwpktlogs.log 2>/dev/null; zcat /var/run/log/dfwpktlogs*.gz 2>/dev/null) | awk '{for(i=1; i<=NF; i++) if($i ~ /->/) {print $i; break}}' | awk -F '->' '{print $2}'| sort | uniq -c | sort -nrk 1 | head -n 10

Top 10 Sources from All files :: printf "%-10s %s\n" COUNT SOURCE; (cat /var/run/log/dfwpktlogs.log 2>/dev/null; zcat /var/run/log/dfwpktlogs*.gz 2>/dev/null) | awk '{for(i=1; i<=NF; i++) if($i ~ /->/) {split($i, a, "->"); split(a[1], src, "/"); print src[1]; break}}' | sort | uniq -c | sort -nrk 1 | head -n 10

# Collecting stats :: /usr/lib/vmware/vm-support/bin/vsipioctl_info.sh > /var/run/log/vsipioctl_info.sh_esx_dfw_health_sh.txt
# Total Rules on the host :: less /var/run/log/vsipioctl_info.sh_esx_dfw_health_sh.txt | grep ^rules: | awk '{rules += $2} END {print rules}'

COMMANDS_END


# ======================= Don't change anything below this line =======================
# ===============================================================================

NSX=127.0.0.1; NSX_USER=admin; ESX_USER=root; CLUSTERS=(); OUT=""; LIST=0
while getopts "n:u:e:c:o:l" o; do
  case $o in
    n) NSX=$OPTARG;; u) NSX_USER=$OPTARG;; e) ESX_USER=$OPTARG;;
    c) CLUSTERS+=("$OPTARG");; o) OUT=$OPTARG;; l) LIST=1;;
    *) sed -n '2,20p' "$0"; exit 1;;
  esac
done

perl -MJSON::PP -e1 2>/dev/null || { echo "perl with JSON::PP is required"; exit 1; }
[ -z "$NSX_PASS" ] && { read -rsp "NSX $NSX_USER password: " NSX_PASS; echo; }

api() { curl -sk -u "$NSX_USER:$NSX_PASS" "https://$NSX$1"; }

# jp <mode> [arg]: parse JSON on stdin with Perl's JSON::PP
#   valid         -> exit 0 if the JSON has a "results" array
#   clusters      -> name<TAB>id for each cluster (resource pools are skipped)
#   hosts [id]    -> addr1,addr2,..<TAB>name<TAB>cluster (name, IPv4s, IPv6s) for each host (fabric/discovered-nodes JSON on
#                    stdin); optional id limits to one cluster. Cluster names are read from
#                    the compute-collections JSON file in $CCFILE
jp() {
  perl -MJSON::PP -e '
    my ($mode, $arg) = @ARGV;
    local $/; my $d = eval { decode_json(<STDIN>) };
    exit 1 unless $d && ref $d->{results} eq "ARRAY";
    exit 0 if $mode eq "valid";
    my %name;
    if ($mode eq "hosts" && open(my $fh, "<", $ENV{CCFILE})) {
      my $cc = eval { decode_json(<$fh>) } || {};
      $name{$_->{external_id}} = $_->{display_name} for @{$cc->{results} || []};
    }
    my %seen;
    for my $r (@{$d->{results}}) {
      if ($mode eq "clusters") {
        print "$r->{display_name}\t$r->{external_id}\n" if $r->{external_id} =~ /:domain-c\d+$/;
      } elsif ($mode eq "hosts") {
        next if $r->{node_type} && $r->{node_type} ne "HostNode";
        my $pid = $r->{parent_compute_collection} // "";
        next if $arg && $pid ne $arg;
        my @ip = @{$r->{ip_addresses} || []};
        my @v4 = grep { /^\d+\.\d+\.\d+\.\d+$/ } @ip;
        my @v6 = grep { !/^\d+\.\d+\.\d+\.\d+$/ } @ip;
        my %u; my @c = grep { $_ && !$u{$_}++ } ($r->{display_name}, $r->{fqdn}, @v4, @v6);
        next unless @c;
        next if $seen{$c[0]}++;
        print join(",", @c) . "\t$r->{display_name}\t" . ($name{$pid} || "-") . "\n";
      }
    }' "$@"
}

CCFILE=$(mktemp); export CCFILE; trap 'rm -f "$CCFILE"' EXIT
api /api/v1/fabric/compute-collections > "$CCFILE"
jp valid < "$CCFILE" || { echo "NSX API call failed: $(cat "$CCFILE")"; exit 1; }

if [ $LIST -eq 1 ]; then
  jp clusters < "$CCFILE"
  exit 0
fi

# Collect "addresses<TAB>name<TAB>cluster" lines
HOSTS=""
if [ ${#CLUSTERS[@]} -eq 0 ]; then
  HOSTS=$(api /api/v1/fabric/discovered-nodes | jp hosts)
else
  for c in "${CLUSTERS[@]}"; do
    id=$(jp clusters < "$CCFILE" | awk -F'\t' -v n="$c" '$1==n {print $2; exit}')
    [ -z "$id" ] && { echo "Cluster '$c' not found (use -l)"; exit 1; }
    HOSTS+=$(api /api/v1/fabric/discovered-nodes | jp hosts "$id")$'\n'
  done
fi
HOSTS=$(echo "$HOSTS" | sed '/^$/d')
[ -z "$HOSTS" ] && { echo "No hosts found"; exit 1; }

if [ -z "$ESX_PASS" ] && command -v sshpass >/dev/null; then
  read -rsp "ESXi $ESX_USER password: " ESX_PASS; echo
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5)
REMOTE=""
COMMANDS=()
while IFS= read -r line; do
  [[ -z "${line//[[:space:]]/}" || $line == \#* ]] || COMMANDS+=("$line")
done <<< "$COMMANDS_TEXT"
sq() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }   # escape single quotes for use inside '...'
for entry in "${COMMANDS[@]}"; do
  if [[ $entry == *" :: "* ]]; then desc=${entry%% :: *}; cmd=${entry#* :: }; else desc=""; cmd=$entry; fi
  title="\$ $cmd"; [ -n "$desc" ] && title="$desc"
  REMOTE+="echo '--- $(sq "$title") ---'; $cmd; echo; "
done

# Try each candidate address until ssh connects (exit 255 = could not connect/authenticate)
esx_ssh() {
  if [ -n "$ESX_PASS" ]; then
    SSHPASS="$ESX_PASS" sshpass -e ssh "${SSH_OPTS[@]}" "$ESX_USER@$1" "$REMOTE" 2>&1 </dev/null
  else
    ssh "${SSH_OPTS[@]}" "$ESX_USER@$1" "$REMOTE" 2>&1 </dev/null
  fi
}

run_all() {
  while IFS=$'\t' read -r addrs name cluster; do
    echo "=================================================="
    echo "Host: $name  Cluster: $cluster"
    echo "=================================================="
    errs=""; ok=0
    for addr in ${addrs//,/ }; do
      out=$(esx_ssh "$addr"); rc=$?
      if [ $rc -eq 0 ]; then echo "(connected via $addr)"; echo "$out"; ok=1; break; fi
      errs+="[$addr] $out"$'\n'
    done
    [ $ok -eq 0 ] && echo "FAILED to run on $name:" && echo "$errs"
    echo
  done <<< "$HOSTS"
}

if [ -n "$OUT" ]; then run_all | tee "$OUT"; echo "Saved to $OUT"; else run_all; fi
