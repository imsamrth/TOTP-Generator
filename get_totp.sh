#!/bin/bash

# --- Configuration ---
SECRET_BASE32=""  # Replace with your own Base32 secret
TIME_STEP=30

DIGITS=6

# --- Decode Base32 Secret ---
#decode_base32() {
#    echo "$1" | tr 'A-Z2-7' 'a-z2-7' | base32 --decode 2>/dev/null
#}

decode_base32() {
    local input="$1"

    # Add padding if needed (Base32 is 8-character blocks)
    local mod=$(( ${#input} % 8 ))
    if [ $mod -ne 0 ]; then
        local padding=$(( 8 - mod ))
        input="${input}$(printf '=%.0s' $(seq 1 $padding))"
    fi

    echo "$input" | base32 --decode 2>/dev/null | xxd -p -c 1000
}

# --- Get Current Time Step ---
get_time_counter() {
    local timestamp=$(date +%s)
    echo $((timestamp / TIME_STEP))
}

# --- Convert Integer to 8-byte Big Endian ---
int_to_bytes() {
    printf "%016x" "$1"
    #| sed 's/../\\x&/g'
}

# --- Generate TOTP ---
generate_totp() {
    local secret_bin=$(decode_base32 "$SECRET_BASE32")
    local counter=$(get_time_counter)
    local counter_bytes=$(int_to_bytes "$counter")
    local counter_local=$(echo "$counter_bytes" | xxd -r -p )
    # Generate HMAC-SHA1
    local hmac=$(printf "$counter_bytes" | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt hexkey:${secret_bin} -binary | xxd -p -c 1000)

    # Dynamic truncation
    local offset=$(( 0x${hmac:39:1} * 2 ))
    local part=${hmac:$offset:8}
    local binary=$(( 0x${part} & 0x7fffffff ))
    local otp=$(( binary % 10**DIGITS ))

    printf "%0${DIGITS}d\n" "$otp"
}

# --- Run ---
generate_totp
