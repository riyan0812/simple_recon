# simple_recon
just a simple reocn

Cara Pake
chmod +x recon.sh
# Scan dasar (WHOIS, DNS, Nmap quick scan)
./recon.sh -t example.com
# Scan lengkap dengan Nmap vulnerability scan
./recon.sh -t 192.168.1.1 -a -s vuln
# Scan spesifik hanya WHOIS dan DNS
./recon.sh -t example.com -w -d
# Dengan output directory khusus
./recon.sh -t example.com -a -o custom_output_dir

Tools yang harus diinstall:
nmap
whois
dig
host
curl
dnsenum (opsional)
cutycapt (opsional, untuk screenshot)
Install dependencies di Ubuntu/Debian:

