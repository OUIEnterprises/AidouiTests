#!/usr/bin/env bash
set -euo pipefail


# API

export API_URL="https://api.beta.aidoui.com"
# Note: API Key is REQUIRED for all requests to the API Gateway
# This is because ONLY AIDOUI should be able to access the APIs
# Please do not share this API key with anyone else
export API_KEY="GFepKCd9uS8VzdI3XUYBT1E3oZbT9mPs2gvwrSQr"

# Test users - Pre-existing accounts for E2E testing
# Create these accounts once using: test/setup/setup_test_accounts.sh

# PATIENT credentials
export PATIENT1_EMAIL="patient+1@example.com"
export PATIENT1_PASS="TempTestPass456!"
export PATIENT1_ROLE="Patient"

export PATIENT2_EMAIL="patient+2@example.com"
export PATIENT2_PASS="P@ssw0rd!"
export PATIENT2_ROLE="Patient"

# DOCTOR credentials
export DOCTOR1_EMAIL="doctor+1@example.com"
export DOCTOR1_PASS="P@ssw0rd!"
export DOCTOR1_ROLE="Doctor"

# LABORATORY credentials
export LAB1_EMAIL="lab+1@example.com"
export LAB1_PASS="P@ssw0rd!"
export LAB1_ROLE="Laboratory"

# PHARMACY credentials
export PHARMACY1_EMAIL="pharmacy+1@example.com"
export PHARMACY1_PASS="P@ssw0rd!"
export PHARMACY1_ROLE="Pharmacy"

# HOSPITAL credentials
export HOSPITAL1_EMAIL="hospital+1@example.com"
export HOSPITAL1_PASS="P@ssw0rd!"
export HOSPITAL1_ROLE="Hospital"


# AWS
export AWS_REGION="eu-central-1"

# Resources
export RECORDS_BUCKET="aidoui-records-beta"
export RECORDS_TABLE="Records-beta"

export PRESCRIPTIONS_BUCKET="aidoui-prescriptions-beta"
export PRESCRIPTIONS_TABLE="Prescriptions-beta"

export PASSES_TABLE="EntityPasses-beta"


# helper to pretty-print JSON
jq() { command jq "${@}" ;}



