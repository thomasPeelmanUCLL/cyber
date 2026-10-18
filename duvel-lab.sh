#!/usr/bin/env bash
# =============================================================================
#  DUVEL MOORTGAT LAB  -  Defensive Cybersecurity (UCLL)
#  Recreates a plausible brewery network so you have something real to scan.
#
#  EVERYTHING IN THIS LAB IS FICTIONAL. The hosts, staff names, files and
#  passwords are invented for teaching. They are NOT real Duvel Moortgat
#  systems or data. The scenario is inspired by the publicly reported
#  ransomware attack of 6 March 2024.
#
#  The machines are deliberately outdated and misconfigured. Keep them on an
#  isolated lab network. Never bridge them to a network you do not own.
# =============================================================================
set -euo pipefail

LAB_DIR="${LAB_DIR:-/opt/duvel-lab}"
LAB_NET="duvel-net"
SUBNET="10.6.24.0/24"          # 6 March 2024, the night the brewery stopped
COMPOSE_PROJECT="duvel"

# ---------------------------------------------------------------- colours ---
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[38;5;197m'; GOLD=$'\e[38;5;214m'; NAVY=$'\e[38;5;68m'
  GREEN=$'\e[38;5;42m'; GREY=$'\e[38;5;245m'
else
  R=""; B=""; DIM=""; RED=""; GOLD=""; NAVY=""; GREEN=""; GREY=""
fi

say()   { printf '%s\n' "$*"; }
step()  { printf '  %s>%s %s\n' "$GOLD" "$R" "$*"; }
ok()    { printf '  %s[ok]%s %s\n' "$GREEN" "$R" "$*"; }
warn()  { printf '  %s[!!]%s %s\n' "$RED" "$R" "$*"; }
die()   { printf '\n%s[fatal]%s %s\n\n' "$RED" "$R" "$*" >&2; exit 1; }
hint_line() { printf '  %s%-34s%s %s# %s%s\n' "$NAVY" "$1" "$R" "$GREY" "$2" "$R"; }

banner() {
  printf '%s' "$GOLD"
  cat <<'ART'
        .  .  .
       (o) (o) (o)          ___________________________
        |   |   |          /                           \
      .-'---'---'-.       |  DUVEL MOORTGAT - IT LAB    |
     |  ~ ~ ~ ~ ~  |      |  Puurs, February 2024       |
     |  D U V E L  |      \___________________________/
     |  M O O R T  |
     |  G A T  ~   |       "It is only a brewery.
     |  ~ ~ ~ ~ ~  |        What could possibly happen?"
      '-----------'
ART
  printf '%s' "$R"
}

# ---------------------------------------------------------------- the cast ---
# ip_last | hostname | role | what nmap should see | ports that must answer
HOSTS=(
  "10|duvel-web01|Webshop / order portal|nginx 1.14 (end of life)|80"
  "11|duvel-portal02|Customer sales portal|PHP 7.2 on Apache|80"
  "12|duvel-erp01|ERP front end (order + HR)|Apache 2.4.29|80"
  "13|duvel-db01|Customer & HR database|MySQL 5.7, remote root|3306"
  "14|duvel-files01|Office file share|SMB, anonymous share|139 445"
  "15|duvel-backup01|Backup server|FTP, anonymous login|21"
  "16|duvel-scada01|Brewing control (OT)|telnet + HMI + Modbus 502|23 80 502"
  "17|duvel-jump01|Partner jump server|SSH, password login|22"
  "77|duvel-unknown77|??? nobody documented this|old web server|80"
)

# ------------------------------------------------------------- preflight ----
require_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker is not installed. See the install guide on Toledo."
  docker info >/dev/null 2>&1 || die "Docker is installed but not running (or you need sudo)."
  docker compose version >/dev/null 2>&1 || die "The docker compose plugin is missing."
}

ensure_emulation() {
  # The brewery runs on genuinely old images, and those only exist for x86.
  case "$(uname -m)" in
    aarch64|arm64)
      step "ARM processor detected. The old brewery images are x86 only, installing emulation"
      if docker run --privileged --rm tonistiigi/binfmt --install amd64 >/dev/null 2>&1; then
        ok "x86 emulation ready (the lab will be slower on ARM, that is normal)"
      else
        warn "Could not install x86 emulation automatically."
        warn "Run this once by hand, then try again:"
        warn "  docker run --privileged --rm tonistiigi/binfmt --install amd64"
      fi
      ;;
  esac
}

safety_check() {
  # Refuse to run the deliberately weak lab on a machine with a public address.
  local addrs
  addrs="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"
  local a
  for a in $addrs; do
    case "$a" in
      10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|127.*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*) ;;
      *) warn "This machine has a public-looking address ($a)."
         warn "The lab hosts are deliberately vulnerable. Only continue on an isolated lab machine."
         printf '  Type %sbrew%s to continue anyway: ' "$B" "$R"
         read -r answer </dev/tty || answer=""
         [ "$answer" = "brew" ] || die "Stopped. Good call."
         ;;
    esac
  done
}

# ------------------------------------------------------------ lab content ---
write_files() {
  mkdir -p "$LAB_DIR"/{web,portal,erp,db-init,share,ftp,scada}

  # -- the webshop ------------------------------------------------------------
  cat > "$LAB_DIR/web/index.html" <<'HTML'
<!doctype html><html lang="nl"><head><meta charset="utf-8">
<title>Duvel Moortgat - Bestelportaal</title>
<style>body{font-family:Arial,sans-serif;background:#f4f1ea;color:#2b2b2b;margin:0}
header{background:#1b1b1b;color:#e8c66a;padding:18px 28px}
main{max-width:760px;margin:28px auto;background:#fff;padding:24px;border:1px solid #ddd}
.small{color:#777;font-size:12px}</style></head><body>
<header><h1>Duvel Moortgat - Bestelportaal</h1><div class="small">intern testsysteem - LAB / FICTIEF</div></header>
<main>
<h2>Welkom</h2>
<p>Bestellingen voor Duvel, La Chouffe, Liefmans en De Koninck.</p>
<ul>
  <li><a href="/orders.html">Openstaande bestellingen</a></li>
  <li><a href="/README.txt">README (IT)</a></li>
</ul>
<p class="small">Deze omgeving is volledig fictief en dient enkel als oefenlab.</p>
</main></body></html>
HTML

  cat > "$LAB_DIR/web/orders.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>Bestellingen</title></head><body>
<h2>Openstaande bestellingen (fictief)</h2>
<table border="1" cellpadding="6">
<tr><th>Order</th><th>Klant</th><th>Product</th><th>Colli</th></tr>
<tr><td>SO-24-1183</td><td>Drankencentrale De Vos</td><td>Duvel 33cl</td><td>240</td></tr>
<tr><td>SO-24-1184</td><td>Horeca Vandenberghe</td><td>La Chouffe 33cl</td><td>120</td></tr>
<tr><td>SO-24-1185</td><td>Cafe 't Vat</td><td>Liefmans Kriek</td><td>60</td></tr>
</table>
<p><i>Backend: erp01 (Dynamics NAV) - database: db01</i></p>
</body></html>
HTML

  cat > "$LAB_DIR/web/README.txt" <<'TXT'
Duvel Moortgat - webshop server (LAB, FICTIEF)
----------------------------------------------
TODO (Jan, IT, 2019):
 - nginx nog updaten, draait nog op 1.14
 - db-wachtwoord staat nog in het oude script op de fileshare
 - backup gaat via FTP naar backup01, anoniem, dat moet ooit dichter
 - partner (Brouwtechniek NV) heeft SSH naar jump01 met een gedeeld account

Niemand heeft deze lijst sinds 2019 nog bekeken.
TXT

  # -- the customer portal ----------------------------------------------------
  cat > "$LAB_DIR/portal/index.php" <<'PHP'
<?php
// Duvel Moortgat - klantenportaal (LAB / FICTIEF)
$staff = [
  ["Jan Peeters", "IT operations", "jan.peeters@example-brewery.test"],
  ["Sofie Claes", "HR", "sofie.claes@example-brewery.test"],
  ["Marc Vermeulen", "Productie", "marc.vermeulen@example-brewery.test"],
];
?><!doctype html><html><head><meta charset="utf-8"><title>Klantenportaal</title></head><body
 style="font-family:Arial;background:#fbf7ef">
<h1>Duvel Moortgat - Klantenportaal</h1>
<p>PHP <?php echo phpversion(); ?> - interne testomgeving (fictief)</p>
<h3>Contactpersonen</h3><ul>
<?php foreach ($staff as $s) { echo "<li>{$s[0]} - {$s[1]} - {$s[2]}</li>"; } ?>
</ul>
<p style="color:#777;font-size:12px">Alle namen en gegevens zijn verzonnen voor dit lab.</p>
</body></html>
PHP

  cat > "$LAB_DIR/portal/info.php" <<'PHP'
<?php
// Leaks the stack on purpose: a classic information-disclosure finding.
echo "<h2>Server info (LAB)</h2>";
echo "<pre>PHP ".phpversion()."\n".$_SERVER['SERVER_SOFTWARE']."</pre>";
echo "<p>DB host: db01.duvel.lab (user: root)</p>";
PHP

  # -- the ERP front end ------------------------------------------------------
  cat > "$LAB_DIR/erp/index.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>ERP - Dynamics NAV portal</title></head>
<body style="font-family:Arial;background:#eef2f7">
<h1>Duvel Moortgat ERP</h1>
<p>Microsoft Dynamics NAV web client (fictieve labkopie)</p>
<ul>
 <li>Module: Verkoop en orders</li>
 <li>Module: Productieplanning (koppeling SCADA)</li>
 <li>Module: HR en payroll</li>
</ul>
<p><small>Server: Apache 2.4.29 - laatste update 2018. Ticket ITSM-2291 staat nog open.</small></p>
</body></html>
HTML

  # -- the database seed ------------------------------------------------------
  cat > "$LAB_DIR/db-init/01-brewery.sql" <<'SQL'
-- Duvel Moortgat lab database (FICTIONAL DATA ONLY)
CREATE DATABASE IF NOT EXISTS brewery;
USE brewery;

CREATE TABLE customers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80), city VARCHAR(60), email VARCHAR(120)
);
INSERT INTO customers (name, city, email) VALUES
 ('Drankencentrale De Vos','Mechelen','orders@example-drinks.test'),
 ('Horeca Vandenberghe','Gent','info@example-horeca.test'),
 ('Cafe t Vat','Puurs','vat@example-cafe.test');

-- The kind of table that made the 2024 incident a data breach as well.
CREATE TABLE hr_employees (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80), role VARCHAR(60), iban VARCHAR(40), passport VARCHAR(40)
);
INSERT INTO hr_employees (name, role, iban, passport) VALUES
 ('Jan Peeters','IT operations','BE00 0000 0000 0000 (FICTIEF)','XX0000000 (FICTIEF)'),
 ('Sofie Claes','HR','BE00 0000 0000 0000 (FICTIEF)','XX0000000 (FICTIEF)'),
 ('Marc Vermeulen','Productie','BE00 0000 0000 0000 (FICTIEF)','XX0000000 (FICTIEF)');

CREATE TABLE recipes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  beer VARCHAR(60), note VARCHAR(200)
);
INSERT INTO recipes (beer, note) VALUES
 ('Duvel','Gistingstemperatuur en hopschema - bedrijfsgeheim (fictief)'),
 ('La Chouffe','Kruidenmengeling - bedrijfsgeheim (fictief)');
SQL

  # -- the file share ---------------------------------------------------------
  cat > "$LAB_DIR/share/LOONFICHES-2024-KOPIE.csv" <<'CSV'
naam,functie,brutoloon,iban,opmerking
Jan Peeters,IT operations,3200,BE00 0000 0000 0000 (FICTIEF),kopie voor sociaal secretariaat
Sofie Claes,HR,3400,BE00 0000 0000 0000 (FICTIEF),kopie voor sociaal secretariaat
Marc Vermeulen,Productie,2950,BE00 0000 0000 0000 (FICTIEF),kopie voor sociaal secretariaat
CSV

  cat > "$LAB_DIR/share/backup-script-2019.bat" <<'BAT'
@echo off
REM Oud backupscript - staat al jaren op de open share (LAB / FICTIEF)
set DBHOST=10.6.24.13
set DBUSER=root
set DBPASS=Duvel2019!
mysqldump -h %DBHOST% -u %DBUSER% -p%DBPASS% brewery > \\backup01\backups\brewery.sql
BAT

  cat > "$LAB_DIR/share/LEESMIJ.txt" <<'TXT'
Deze share staat open voor iedereen op het kantoornetwerk.
"Voorlopig", sinds 2019.
Alles hier is fictief labmateriaal.
TXT

  # -- the backup server ------------------------------------------------------
  cat > "$LAB_DIR/ftp/brewery-2024-02-28.sql" <<'TXT'
-- Fictieve databasedump, hier neergezet door het backupscript.
-- In het echte incident van maart 2024 werden backups als eerste aangepakt.
CREATE TABLE placeholder (id INT);
TXT

  cat > "$LAB_DIR/ftp/LEESMIJ.txt" <<'TXT'
backup01 - anonieme FTP staat aan sinds de installatie.
Niemand weet nog waarom. Fictief labmateriaal.
TXT

  # -- the brewing HMI --------------------------------------------------------
  cat > "$LAB_DIR/scada/index.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>BrewControl HMI</title>
<meta http-equiv="refresh" content="30"></head>
<body style="font-family:monospace;background:#101c10;color:#8f8">
<h1>BrewControl HMI v2.1 (LAB / FICTIEF)</h1>
<pre>
  BROUWZAAL 1     status: BREWING     temp:  67.4 C   druk: 1.2 bar
  BROUWZAAL 2     status: MASHING     temp:  52.1 C   druk: 1.1 bar
  GISTKELDER A    status: FERMENT     temp:  21.0 C
  FILTER          status: IDLE
</pre>
<p>Geen login vereist voor deze pagina.</p>
<p>Onderhoud: telnet naar dit toestel, login <b>operator</b> / <b>brewmaster</b>.
Deze regel staat hier sinds de installatie in 2016 zodat de techniekers ze niet vergeten.</p>
</body></html>
HTML

  # -- the undocumented host --------------------------------------------------
  cat > "$LAB_DIR/scada/shadow.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>test</title></head>
<body style="font-family:Arial">
<h2>testserver</h2>
<p>Ooit opgezet voor een proefproject. Staat niet in de inventaris.
Niemand weet nog van wie hij is.</p>
<p><small>Fictief labmateriaal.</small></p>
</body></html>
HTML
}

write_compose() {
  cat > "$LAB_DIR/docker-compose.yml" <<COMPOSE
# Duvel Moortgat lab - generated by duvel-lab.sh. Fictional, deliberately weak.
name: ${COMPOSE_PROJECT}

x-lab: &lab
  restart: unless-stopped
  platform: linux/amd64

services:

  web01:
    <<: *lab
    image: nginx:1.14-alpine
    container_name: duvel-web01
    hostname: duvel-web01
    volumes:
      - ./web:/usr/share/nginx/html:ro
    networks: { duvel: { ipv4_address: 10.6.24.10 } }

  portal02:
    <<: *lab
    image: php:7.2-apache
    container_name: duvel-portal02
    hostname: duvel-portal02
    volumes:
      - ./portal:/var/www/html:ro
    networks: { duvel: { ipv4_address: 10.6.24.11 } }

  erp01:
    <<: *lab
    image: httpd:2.4.29
    container_name: duvel-erp01
    hostname: duvel-erp01
    volumes:
      - ./erp:/usr/local/apache2/htdocs:ro
    networks: { duvel: { ipv4_address: 10.6.24.12 } }

  db01:
    <<: *lab
    image: mysql:5.7
    container_name: duvel-db01
    hostname: duvel-db01
    environment:
      MYSQL_ROOT_PASSWORD: "Duvel2019!"
      MYSQL_ROOT_HOST: "%"
    volumes:
      - ./db-init:/docker-entrypoint-initdb.d:ro
    networks: { duvel: { ipv4_address: 10.6.24.13 } }

  files01:
    <<: *lab
    image: dperson/samba
    container_name: duvel-files01
    hostname: duvel-files01
    command: -p -n -s "kantoor;/share;yes;no;yes"
    volumes:
      - ./share:/share
    networks: { duvel: { ipv4_address: 10.6.24.14 } }

  backup01:
    <<: *lab
    image: alpine:3.18
    container_name: duvel-backup01
    hostname: duvel-backup01
    volumes:
      - ./ftp:/srv/ftp:ro
    command:
      - /bin/sh
      - -c
      - |
        set -e
        apk add --no-cache vsftpd >/dev/null 2>&1
        cat > /etc/vsftpd/vsftpd.conf <<'CONF'
        listen=YES
        anonymous_enable=YES
        no_anon_password=YES
        anon_root=/srv/ftp
        local_enable=NO
        write_enable=NO
        dirmessage_enable=YES
        xferlog_enable=YES
        xferlog_std_format=NO
        log_ftp_protocol=YES
        seccomp_sandbox=NO
        pasv_enable=YES
        pasv_address=10.6.24.15
        pasv_min_port=21100
        pasv_max_port=21110
        ftpd_banner=Duvel Moortgat backup server - LAB - authorised personnel only
        CONF
        exec vsftpd /etc/vsftpd/vsftpd.conf
    networks: { duvel: { ipv4_address: 10.6.24.15 } }

  scada01:
    <<: *lab
    image: alpine:3.18
    container_name: duvel-scada01
    hostname: duvel-scada01
    volumes:
      - ./scada:/www:ro
    command:
      - /bin/sh
      - -c
      - |
        set -e
        apk add --no-cache socat busybox-extras >/dev/null 2>&1
        deluser operator 2>/dev/null || true
        adduser -D -s /bin/sh operator
        echo 'operator:brewmaster' | chpasswd
        # HMI on 80
        busybox-extras httpd -p 80 -h /www
        # Modbus/TCP on 502, the protocol that has no authentication at all
        socat TCP-LISTEN:502,reuseaddr,fork SYSTEM:'echo MODBUS/TCP BrewControl PLC unit 1 ready' &
        # telnet on 23, still there for the maintenance partner
        busybox-extras telnetd -F -l /bin/login
    networks: { duvel: { ipv4_address: 10.6.24.16 } }

  jump01:
    <<: *lab
    image: linuxserver/openssh-server:latest
    container_name: duvel-jump01
    hostname: duvel-jump01
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: "Europe/Brussels"
      PASSWORD_ACCESS: "true"
      USER_NAME: "brouwtechniek"
      USER_PASSWORD: "Partner2019"
      SUDO_ACCESS: "false"
      LISTEN_PORT: "22"
    networks: { duvel: { ipv4_address: 10.6.24.17 } }

  unknown77:
    <<: *lab
    image: nginx:1.16-alpine
    container_name: duvel-unknown77
    hostname: duvel-unknown77
    volumes:
      - ./scada/shadow.html:/usr/share/nginx/html/index.html:ro
    networks: { duvel: { ipv4_address: 10.6.24.77 } }

networks:
  duvel:
    name: ${LAB_NET}
    driver: bridge
    ipam:
      config:
        - subnet: ${SUBNET}
COMPOSE
}

# ------------------------------------------------------------- commands -----
cmd_up() {
  banner
  say "${B}Welcome to the brewery IT department.${R}"
  say "${GREY}It is February 2024. Nothing has been patched since 2019.${R}"
  say "${GREY}Your job starts with a simple question: what do we actually have?${R}"
  say ""
  require_docker
  safety_check
  ensure_emulation

  step "Writing the lab into $LAB_DIR"
  write_files
  write_compose
  ok "Configuration written"

  step "Racking the servers (pulling images, first run takes a few minutes)"
  ( cd "$LAB_DIR" && docker compose pull --quiet ) || warn "Some images could not be pulled quietly; continuing"
  ok "Images ready"

  step "Powering on the brewery"
  ( cd "$LAB_DIR" && docker compose up -d )
  ok "Containers started"

  step "Waiting for the database to finish its first start"
  local i
  for i in $(seq 1 30); do
    if docker exec duvel-db01 mysqladmin ping -h127.0.0.1 --silent >/dev/null 2>&1; then break; fi
    sleep 3
  done
  ok "Brewery is online"
  say ""
  cmd_map
  say ""
  cmd_verify
  say ""
  say "${B}Next:${R} scan it. You are the new security officer, and nobody kept an inventory."
  hint_line "nmap -sn ${SUBNET}"        "who is out there"
  hint_line "nmap -sV -sC 10.6.24.10"   "what is it actually running"
  hint_line "$0 hints"                  "if your scan goes nowhere"
  say ""
}

cmd_map() {
  printf '%s  The brewery network (%s)%s\n' "$B" "$SUBNET" "$R"
  printf '  %s%-4s %-13s %-16s %-30s %s%s\n' "$DIM" "" "IP" "HOSTNAME" "ROLE" "EXPECT TO SEE" "$R"
  local h last name role note ports state dot
  for h in "${HOSTS[@]}"; do
    IFS='|' read -r last name role note ports <<< "$h"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      state="$GREEN"; dot="up  "
    else
      state="$RED"; dot="down"
    fi
    printf '  %s%s%s 10.6.24.%-5s %-16s %-30s %s%s%s\n' \
      "$state" "$dot" "$R" "$last" "$name" "$role" "$GREY" "$note" "$R"
  done
}

cmd_status() {
  require_docker
  cmd_map
  say ""
  ( cd "$LAB_DIR" 2>/dev/null && docker compose ps ) || warn "Lab not deployed yet. Run: $0 up"
}

cmd_verify() {
  require_docker
  say "${B}  Checking that every host answers on the port it should${R}"
  local h last name role note ports p ip fails=0 total=0
  for h in "${HOSTS[@]}"; do
    IFS='|' read -r last name role note ports <<< "$h"
    ip="10.6.24.$last"
    for p in $ports; do
      total=$((total + 1))
      if timeout 4 bash -c "exec 3<>/dev/tcp/$ip/$p" 2>/dev/null; then
        ok "$ip:$p  $name"
      else
        warn "$ip:$p  $name  NOT ANSWERING"
        fails=$((fails + 1))
      fi
    done
  done
  say ""
  if [ "$fails" -eq 0 ]; then
    ok "All $total services are up. The brewery is ready to be scanned."
  else
    warn "$fails of $total services did not answer."
    warn "Give it another minute (first start is slow), then try: $0 up"
  fi
  return 0
}

cmd_hints() {
  banner
  cat <<HINTS

  ${B}Stuck? Nudges, not answers.${R}

  ${GOLD}1.${R} Start with discovery, not with a full scan.
     Which hosts answer at all? ${NAVY}nmap -sn 10.6.24.0/24${R}
     Then note that the default scan only checks the 1000 most common
     ports. At least one interesting service does not live there.

  ${GOLD}2.${R} One host belongs in no inventory at all, and nobody will
     claim it. Find it, then decide: shadow IT, or a documentation error?

  ${GOLD}3.${R} Versions matter more than open ports.
     ${NAVY}nmap -sV${R} tells you which software is end of life. Several of these
     have not had a security fix in years.

  ${GOLD}4.${R} Some things are open that should never be open on an office
     network, let alone next to production. Anonymous file access is one.

  ${GOLD}5.${R} The office file share contains an old script. Old scripts
     contain old passwords. Findings that lead to other findings are
     worth more than findings that stand alone.

  ${GOLD}6.${R} OT is not IT. Look at what the brewing host speaks, and ask
     whether that protocol belongs on a network in 2024.

  ${GOLD}7.${R} For the assignment you also need an authenticated scan.
     Think about which host you have credentials for, and where you found them.

  ${GREY}Everything here is fictional lab material. Scan only this lab.${R}
HINTS
}

cmd_down() {
  require_docker
  step "Shutting the brewery down (containers stop, data stays)"
  ( cd "$LAB_DIR" && docker compose down )
  ok "Lab stopped. Start it again with: $0 up"
}

cmd_nuke() {
  require_docker
  warn "This removes the containers, the network and the generated files in $LAB_DIR."
  printf '  Type %snuke%s to confirm: ' "$B" "$R"
  read -r a </dev/tty || a=""
  [ "$a" = "nuke" ] || die "Cancelled."
  ( cd "$LAB_DIR" 2>/dev/null && docker compose down -v --remove-orphans ) || true
  rm -rf "$LAB_DIR"
  ok "Gone. Rebuild any time with: $0 up"
}

cmd_doctor() {
  say "${B}Checking your machine${R}"
  command -v docker >/dev/null 2>&1 && ok "docker: $(docker --version)" || warn "docker: missing"
  docker compose version >/dev/null 2>&1 && ok "compose: $(docker compose version --short 2>/dev/null)" || warn "compose plugin: missing"
  command -v nmap >/dev/null 2>&1 && ok "nmap: $(nmap --version | head -1)" || warn "nmap: missing (apt install nmap)"
  docker info >/dev/null 2>&1 && ok "docker daemon: running" || warn "docker daemon: not reachable"
  if docker network inspect "$LAB_NET" >/dev/null 2>&1; then ok "lab network $LAB_NET exists"; else warn "lab network not created yet"; fi
  local up
  up="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c '^duvel-' || true)"
  ok "lab containers running: ${up:-0} of ${#HOSTS[@]}"
}

usage() {
  banner
  cat <<USAGE
  ${B}duvel-lab.sh${R} - build the Duvel Moortgat lab network

    ${NAVY}up${R}       build and start the brewery (first run pulls images)
    ${NAVY}status${R}   show the network map and container state
    ${NAVY}map${R}      show the network map only
    ${NAVY}verify${R}   check that every host answers on its expected port
    ${NAVY}hints${R}    nudges if your scan is going nowhere
    ${NAVY}down${R}     stop the lab, keep the data
    ${NAVY}nuke${R}     remove everything this script created
    ${NAVY}doctor${R}   check docker, compose and nmap on this machine

  Everything is fictional and deliberately weak. Keep it on an isolated
  lab machine, and scan nothing but this lab.
USAGE
}

case "${1:-help}" in
  up)      cmd_up ;;
  status)  cmd_status ;;
  map)     require_docker; cmd_map ;;
  verify|check) cmd_verify ;;
  hints)   cmd_hints ;;
  down)    cmd_down ;;
  nuke)    cmd_nuke ;;
  doctor)  cmd_doctor ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
