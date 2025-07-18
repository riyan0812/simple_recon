#!/bin/bash
DOMAIN="pln.co.id"
echo "[*] Mulai pemindaian untuk $DOMAIN..."

# Step 1: Cari subdomain
echo "[+] Menjalankan subfinder..."
subfinder -d $DOMAIN -silent -o subs.txt

# Step 2: Cek host yang live
echo "[+] Menjalankan httpx untuk memeriksa host yang aktif..."
httpx -l subs.txt -o live.txt

# Step 3: Cek port terbuka
echo "[+] Menjalankan naabu untuk port scanning..."
naabu -l subs.txt -o ports.txt

# Step 4: Jalankan Nuclei pada host aktif
echo "[+] Menjalankan nuclei untuk vulnerability scanning..."
nuclei -l live.txt -o nuclei-results.txt

echo "[✓] Pemindaian selesai!"
echo "    → Subdomain tersimpan di: subs.txt"
echo "    → Host aktif tersimpan di: live.txt"
echo "    → Port terbuka tersimpan di: ports.txt"
echo "    → Hasil Nuclei tersimpan di: nuclei-results.txt"
