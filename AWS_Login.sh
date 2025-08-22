SECRET_BASE32=""  # Replace with your own Base32 secret
TIME_STEP=30
DIGITS=6

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
}

# --- Generate TOTP ---
generate_totp() {
    local secret_bin=$(decode_base32 "$SECRET_BASE32")
    local counter=$(get_time_counter)
    local counter_bytes=$(int_to_bytes "$counter")
    # Generate HMAC-SHA1
    local hmac=$(printf "$counter_bytes" | xxd -r -p | openssl dgst -sha1 -mac HMAC -macopt hexkey:${secret_bin} -binary | xxd -p -c 1000)

    # Dynamic truncation
    local offset=$(( 0x${hmac:39:1} * 2 ))
    local part=${hmac:$offset:8}
    local binary=$(( 0x${part} & 0x7fffffff ))
    local otp=$(( binary % 10**DIGITS ))

    printf "%0${DIGITS}d\n" "$otp"
}

check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Error: Unable to create session. Exiting."
    exit 1
  fi
}

MFA_TOKEN_CODE=$(generate_totp)
echo "MFA Token Code: $MFA_TOKEN_CODE"

aws sts get-session-token \
  --serial-number $ARN_OF_MFA \
  --token-code $MFA_TOKEN_CODE \
  --profile $AWS_SOURCE_PROFILE

check_success

expire_time=$(date -d "+36 hours" "+%Y-%m-%d %H:%M:%S")
echo "✅ Session created successfully. Expire at ${expire_time}"
