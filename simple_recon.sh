#!/bin/bash

# Automated Reconnaissance Script
# Author: Security Analyst
# Version: 2.0
# Description: Comprehensive automated reconnaissance tool

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="recon_results"
TOOLS=("nmap" "whois" "dig" "host" "curl" "wget" "dnsenum")
REQUIRED_TOOLS=("nmap" "whois" "dig")
NMAP_SCAN_TYPES=("quick" "full" "vuln")
NMAP_QUICK_FLAGS="-T4 -F"
NMAP_FULL_FLAGS="-T4 -A -v -p-"
NMAP_VULN_FLAGS="-T4 --script vuln"

# Create output directory
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo -e "${GREEN}[+] Created output directory: ${OUTPUT_DIR}${NC}"
    fi
}

# Check for required tools
check_dependencies() {
    local missing=0
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}[-] ERROR: $tool is not installed${NC}"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "${YELLOW}[!] Please install missing tools before continuing${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[+] All required tools are installed${NC}"
}

# Display help information
display_help() {
    echo -e "${YELLOW}Automated Reconnaissance Script${NC}"
    echo "Usage: $0 [options] -t <target>"
    echo ""
    echo "Options:"
    echo "  -t, --target      Target domain or IP address (required)"
    echo "  -o, --output      Output directory (default: recon_results)"
    echo "  -s, --scan-type   Nmap scan type (quick|full|vuln, default: quick)"
    echo "  -d, --dns         Perform DNS reconnaissance"
    echo "  -w, --whois       Perform WHOIS lookup"
    echo "  -n, --nmap        Perform Nmap scan"
    echo "  -a, --all         Perform all reconnaissance tasks"
    echo "  -v, --verbose     Enable verbose output"
    echo "  -h, --help        Show this help message"
    exit 0
}

# Perform DNS reconnaissance
dns_recon() {
    local target=$1
    echo -e "${BLUE}[*] Starting DNS reconnaissance on ${target}${NC}"
    
    # Basic DNS lookup
    echo -e "${YELLOW}[+] Performing basic DNS lookup${NC}"
    host "$target" > "$OUTPUT_DIR/dns_lookup.txt"
    
    # DIG all record types
    echo -e "${YELLOW}[+] Performing DIG for all record types${NC}"
    dig "$target" ANY > "$OUTPUT_DIR/dig_any.txt"
    
    # DNS enumeration
    if command -v dnsenum &> /dev/null; then
        echo -e "${YELLOW}[+] Performing DNS enumeration${NC}"
        dnsenum "$target" > "$OUTPUT_DIR/dns_enumeration.txt"
    else
        echo -e "${RED}[-] dnsenum not found, skipping DNS enumeration${NC}"
    fi
    
    # DNS zone transfer test
    echo -e "${YELLOW}[+] Testing for DNS zone transfer${NC}"
    for ns in $(host -t ns "$target" | awk '{print $4}'); do
        host -l "$target" "$ns" >> "$OUTPUT_DIR/zone_transfer.txt"
    done
    
    echo -e "${GREEN}[+] DNS reconnaissance completed${NC}"
}

# Perform WHOIS lookup
whois_lookup() {
    local target=$1
    echo -e "${BLUE}[*] Starting WHOIS lookup for ${target}${NC}"
    
    whois "$target" > "$OUTPUT_DIR/whois.txt"
    
    echo -e "${GREEN}[+] WHOIS lookup completed${NC}"
}

# Perform Nmap scan
nmap_scan() {
    local target=$1
    local scan_type=$2
    
    echo -e "${BLUE}[*] Starting Nmap ${scan_type} scan on ${target}${NC}"
    
    case $scan_type in
        "quick")
            nmap $NMAP_QUICK_FLAGS "$target" -oN "$OUTPUT_DIR/nmap_quick.txt"
            ;;
        "full")
            nmap $NMAP_FULL_FLAGS "$target" -oN "$OUTPUT_DIR/nmap_full.txt"
            ;;
        "vuln")
            nmap $NMAP_VULN_FLAGS "$target" -oN "$OUTPUT_DIR/nmap_vuln.txt"
            ;;
        *)
            echo -e "${RED}[-] Invalid scan type specified${NC}"
            return
            ;;
    esac
    
    # Convert to XML for further processing
    xsltproc "$OUTPUT_DIR/nmap_${scan_type}.txt" -o "$OUTPUT_DIR/nmap_${scan_type}.xml" 2>/dev/null
    
    echo -e "${GREEN}[+] Nmap ${scan_type} scan completed${NC}"
}

# Perform HTTP reconnaissance
http_recon() {
    local target=$1
    echo -e "${BLUE}[*] Starting HTTP reconnaissance on ${target}${NC}"
    
    # Check HTTP headers
    echo -e "${YELLOW}[+] Checking HTTP headers${NC}"
    curl -I "http://${target}" > "$OUTPUT_DIR/http_headers.txt" 2>/dev/null
    
    # Check HTTPS headers
    echo -e "${YELLOW}[+] Checking HTTPS headers${NC}"
    curl -I "https://${target}" >> "$OUTPUT_DIR/http_headers.txt" 2>/dev/null
    
    # Check for common files/directories
    echo -e "${YELLOW}[+] Checking for common files${NC}"
    for file in robots.txt sitemap.xml .git/HEAD; do
        curl -s "http://${target}/${file}" -o "$OUTPUT_DIR/${file//\//_}"
    done
    
    # Take screenshot if cutycapt is available
    if command -v cutycapt &> /dev/null; then
        echo -e "${YELLOW}[+] Taking website screenshot${NC}"
        cutycapt --url="http://${target}" --out="$OUTPUT_DIR/screenshot.png"
    fi
    
    echo -e "${GREEN}[+] HTTP reconnaissance completed${NC}"
}

# Main function
main() {
    # Parse arguments
    local target=""
    local scan_type="quick"
    local do_dns=false
    local do_whois=false
    local do_nmap=false
    local do_all=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -s|--scan-type)
                if [[ " ${NMAP_SCAN_TYPES[@]} " =~ " $2 " ]]; then
                    scan_type="$2"
                else
                    echo -e "${RED}[-] Invalid scan type. Use quick, full, or vuln${NC}"
                    exit 1
                fi
                shift 2
                ;;
            -d|--dns)
                do_dns=true
                shift
                ;;
            -w|--whois)
                do_whois=true
                shift
                ;;
            -n|--nmap)
                do_nmap=true
                shift
                ;;
            -a|--all)
                do_all=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                display_help
                ;;
            *)
                echo -e "${RED}[-] Unknown option: $1${NC}"
                display_help
                ;;
        esac
    done
    
    # Validate target
    if [ -z "$target" ]; then
        echo -e "${RED}[-] Target is required${NC}"
        display_help
    fi
    
    # Check dependencies
    check_dependencies
    
    # Create output directory
    create_output_dir
    
    # Set default behavior if no specific options are set
    if ! $do_dns && ! $do_whois && ! $do_nmap && ! $do_all; then
        do_all=true
    fi
    
    # Perform all scans if --all is specified
    if $do_all; then
        do_dns=true
        do_whois=true
        do_nmap=true
    fi
    
    # Start reconnaissance
    echo -e "${YELLOW}[*] Starting automated reconnaissance on ${target}${NC}"
    echo -e "${YELLOW}[*] Results will be saved in ${OUTPUT_DIR}${NC}"
    
    # WHOIS lookup
    if $do_whois; then
        whois_lookup "$target"
    fi
    
    # DNS reconnaissance
    if $do_dns; then
        dns_recon "$target"
    fi
    
    # Nmap scan
    if $do_nmap; then
        nmap_scan "$target" "$scan_type"
    fi
    
    # HTTP reconnaissance (always performed for domain targets)
    if [[ "$target" =~ [a-zA-Z] ]]; then
        http_recon "$target"
    fi
    
    # Generate report summary
    generate_report
    
    echo -e "${GREEN}[+] Reconnaissance completed successfully!${NC}"
    echo -e "${GREEN}[+] Results saved in ${OUTPUT_DIR}${NC}"
}

# Generate a summary report
generate_report() {
    echo -e "${YELLOW}[*] Generating summary report${NC}"
    
    {
        echo "Automated Reconnaissance Report"
        echo "============================="
        echo "Target: $target"
        echo "Date: $(date)"
        echo ""
        
        if $do_whois; then
            echo "WHOIS Information:"
            echo "-----------------"
            grep -E "Registrant|Admin|Tech|Name Server|Creation Date|Expiration Date" "$OUTPUT_DIR/whois.txt" || echo "No significant WHOIS info found"
            echo ""
        fi
        
        if $do_dns; then
            echo "DNS Information:"
            echo "---------------"
            echo "DNS Lookup:"
            cat "$OUTPUT_DIR/dns_lookup.txt"
            echo ""
            
            echo "DNS Records (DIG):"
            grep -E "IN\s+(A|MX|NS|TXT)" "$OUTPUT_DIR/dig_any.txt" || echo "No DNS records found"
            echo ""
            
            if [ -f "$OUTPUT_DIR/dns_enumeration.txt" ]; then
                echo "DNS Enumeration Findings:"
                grep -E "Found|Trying" "$OUTPUT_DIR/dns_enumeration.txt" || echo "No DNS enumeration findings"
                echo ""
            fi
            
            echo "Zone Transfer Test:"
            if [ -s "$OUTPUT_DIR/zone_transfer.txt" ]; then
                echo "Zone transfer possible!"
                cat "$OUTPUT_DIR/zone_transfer.txt"
            else
                echo "Zone transfer not possible"
            fi
            echo ""
        fi
        
        if $do_nmap; then
            echo "Nmap Scan Results (${scan_type} scan):"
            echo "------------------------------------"
            grep -E "open|filtered|closed" "$OUTPUT_DIR/nmap_${scan_type}.txt" || echo "No port information found"
            echo ""
            
            if [ "$scan_type" == "vuln" ]; then
                echo "Vulnerability Findings:"
                grep -E "VULNERABLE|CVE" "$OUTPUT_DIR/nmap_${scan_type}.txt" || echo "No vulnerabilities found"
                echo ""
            fi
        fi
        
        if [[ "$target" =~ [a-zA-Z] ]]; then
            echo "HTTP Information:"
            echo "----------------"
            echo "HTTP Headers:"
            cat "$OUTPUT_DIR/http_headers.txt"
            echo ""
            
            if [ -f "$OUTPUT_DIR/robots.txt" ]; then
                echo "robots.txt Contents:"
                cat "$OUTPUT_DIR/robots.txt"
                echo ""
            fi
        fi
        
        echo "Reconnaissance completed at: $(date)"
    } > "$OUTPUT_DIR/report_summary.txt"
    
    echo -e "${GREEN}[+] Summary report generated: ${OUTPUT_DIR}/report_summary.txt${NC}"
}

# Start the script
main "$@"