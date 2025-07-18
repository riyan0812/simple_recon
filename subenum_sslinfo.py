import subprocess
import requests
import socket
import random
import time
import re
from bs4 import BeautifulSoup
from fake_useragent import UserAgent
import os
import ssl
from datetime import datetime

# === Konfigurasi ===
USE_TOR = False  # Set True jika ingin menggunakan Tor
VT_API_KEY = "37b4bdac2032cc1f59c1f22691eed1b3d8787a892b514d1019f34a798775dd71"
ABUSEIPDB_API_KEY = "3e34ca3524ddaed1dba4d35584c589ca0bbb4caf936aa2b0eb6092cdc56de6483df5f4eea5a821db"
COMMON_PORTS = [21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 8080]

ua = UserAgent()

# === Fungsi HTTP Header dan Proxy ===
def stealth_headers():
    return {
        'User-Agent': ua.random,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    }

def tor_proxies():
    return {
        'http': 'socks5h://127.0.0.1:9050',
        'https': 'socks5h://127.0.0.1:9050'
    } if USE_TOR else None

def check_my_ip():
    if not USE_TOR:
        print("[!] TOR tidak aktif.")
        return
    try:
        r = requests.get("https://httpbin.org/ip", proxies=tor_proxies(), timeout=10)
        print("[*] IP kamu via TOR:", r.json()["origin"])
    except Exception as e:
        print("[!] Gagal cek IP:", e)

def geoip_lookup(ip):
    try:
        r = requests.get(f"http://ip-api.com/json/{ip}", timeout=10)
        data = r.json()
        return f"{data['country']} - {data['org']} ({data['isp']})"
    except:
        return "GeoIP lookup gagal"

def detect_waf(domain):
    try:
        r = requests.get(f"http://{domain}", headers=stealth_headers(), timeout=10)
        server = r.headers.get('Server', '')
        cdn_headers = ['cf-ray', 'cf-cache-status', 'x-sucuri-id', 'x-akamai', 'x-cdn']
        waf = [h for h in r.headers if h.lower() in cdn_headers]
        return f"Server: {server}, WAF: {'Ya' if waf else 'Tidak'}"
    except:
        return "Tidak terdeteksi"

def vt_domain_reputation(domain):
    try:
        headers = {"x-apikey": VT_API_KEY}
        r = requests.get(f"https://www.virustotal.com/api/v3/domains/{domain}", headers=headers, timeout=10)
        stats = r.json().get("data", {}).get("attributes", {}).get("last_analysis_stats", {})
        return f"Malicious: {stats.get('malicious', 0)}, Suspicious: {stats.get('suspicious', 0)}"
    except:
        return "Gagal ambil reputasi (VT)"

def abuseipdb_lookup(ip):
    try:
        headers = {
            "Key": ABUSEIPDB_API_KEY,
            "Accept": "application/json"
        }
        params = {"ipAddress": ip, "maxAgeInDays": 90}
        r = requests.get("https://api.abuseipdb.com/api/v2/check", headers=headers, params=params, timeout=10)
        data = r.json().get("data", {})
        return f"Score: {data.get('abuseConfidenceScore', 0)}, Negara: {data.get('countryCode', '?')}"
    except:
        return "Gagal ambil reputasi (AbuseIPDB)"

def stealth_port_scan(ip, ports):
    open_ports = []
    for port in ports:
        try:
            s = socket.socket()
            s.settimeout(1)
            s.connect((ip, port))
            open_ports.append(port)
            s.close()
        except:
            continue
    return open_ports

def run_command(command):
    try:
        return subprocess.check_output(command, shell=True, text=True).splitlines()
    except subprocess.CalledProcessError:
        return []

def crtsh(domain):
    print("[+] Scraping crt.sh...")
    try:
        r = requests.get(f"https://crt.sh/?q=%25.{domain}&output=json", headers=stealth_headers(), timeout=15, proxies=tor_proxies())
        return list(set(re.findall(r'"common_name":"([\w.-]+)"', r.text)))
    except:
        return []

def rapiddns(domain):
    print("[+] Scraping rapiddns.io...")
    try:
        r = requests.get(f"https://rapiddns.io/subdomain/{domain}?full=1", headers=stealth_headers(), timeout=15, proxies=tor_proxies())
        soup = BeautifulSoup(r.text, 'html.parser')
        return list(set(a.text.strip() for a in soup.find_all('td') if domain in a.text))
    except:
        return []

def run_sublist3r(domain):
    print("[+] Running Sublist3r...")
    return [l.strip() for l in run_command(f"sublist3r -d {domain}") if domain in l]

def run_amass(domain):
    print("[+] Running Amass...")
    return run_command(f"amass enum -passive -d {domain}")

def run_subfinder(domain):
    print("[+] Running Subfinder...")
    return run_command(f"subfinder -d {domain} -silent")

def run_theharvester(domain):
    print("[+] Running theHarvester...")
    return run_command(f"theHarvester -d {domain} -b all -f /dev/null")

def verify_alive(domains):
    print("[+] Verifikasi domain aktif dengan httpx...")
    with open("all_temp.txt", "w") as f:
        f.writelines(d + "\n" for d in domains)
    cmd = "cat all_temp.txt | httpx -silent"
    if USE_TOR:
        cmd = "cat all_temp.txt | httpx -socks5 127.0.0.1:9050 -silent"
    output = run_command(cmd)
    os.remove("all_temp.txt")
    return output

def get_ssl_info(domain):
    context = ssl.create_default_context()
    try:
        with socket.create_connection((domain, 443), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=domain) as ssock:
                cert = ssock.getpeercert()
                issuer = dict(x[0] for x in cert['issuer'])['organizationName']
                not_after = cert['notAfter']
                expire_date = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
                expired = expire_date < datetime.utcnow()
                return {
                    "issuer": issuer,
                    "expire_date": expire_date.strftime("%Y-%m-%d"),
                    "expired": expired
                }
    except Exception as e:
        return {
            "issuer": "Tidak tersedia",
            "expire_date": "Tidak tersedia",
            "expired": "Tidak bisa diambil"
        }

def main():
    os.system("clear")
    print("=== Subdomain Enumerator with Threat Intel ===")
    check_my_ip()
    domain = input("\nMasukkan domain target (contoh: example.com): ").strip()
    all_domains = set()

    all_domains.update(crtsh(domain)); time.sleep(random.uniform(1, 2))
    all_domains.update(rapiddns(domain)); time.sleep(random.uniform(1, 2))
    all_domains.update(run_sublist3r(domain)); time.sleep(random.uniform(1, 2))
    all_domains.update(run_amass(domain)); time.sleep(random.uniform(1, 2))
    all_domains.update(run_subfinder(domain)); time.sleep(random.uniform(1, 2))
    all_domains.update(run_theharvester(domain))

    all_domains = set([d.strip().lower() for d in all_domains if domain in d])
    print(f"\n[+] Total subdomain ditemukan: {len(all_domains)}")

    active_domains = verify_alive(all_domains)
    print(f"[+] Total subdomain AKTIF: {len(active_domains)}\n")

    for sub in sorted(set(active_domains)):
        clean_sub = sub.replace("https://", "").replace("http://", "").strip("/")
        try:
            ip = socket.gethostbyname(clean_sub)
        except:
            print(f"- {sub} -> Resolusi IP gagal.")
            continue

        geo = geoip_lookup(ip)
        waf = detect_waf(clean_sub)
        vt = vt_domain_reputation(clean_sub)
        abuse = abuseipdb_lookup(ip)
        ports = stealth_port_scan(ip, COMMON_PORTS)
        ssl_info = get_ssl_info(clean_sub)

        print(f"\n🔍 {sub}")
        print(f"  📌 IP: {ip} | {geo}")
        print(f"  🛡️  WAF/CDN: {waf}")
        print(f"  ⚠️  VT: {vt}")
        print(f"  🚨 AbuseIPDB: {abuse}")
        print(f"  📡 Open Ports: {', '.join(map(str, ports)) if ports else 'None'}")
        print(f"  🔐 SSL Issuer: {ssl_info['issuer']}")
        print(f"  📅 SSL Expired Date: {ssl_info['expire_date']}")
        print(f"  ✅ Valid SSL: {'TIDAK VALID' if ssl_info['expired'] else 'Masih Berlaku'}")

    with open(f"{domain}.txt", "w") as out:
        for d in sorted(set(active_domains)):
            out.write(d + "\n")

    print(f"\n[+] Selesai! Hasil disimpan di: {domain}.txt\n")

if __name__ == "__main__":
    main()
