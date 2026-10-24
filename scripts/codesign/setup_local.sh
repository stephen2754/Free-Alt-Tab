#!/usr/bin/env bash
set -eu

if security find-identity -v -p codesigning | grep -q '"Free-Alt-Tab Local"'; then
    echo "Reusing Free-Alt-Tab Local signing identity"
    exit 0
fi
certificateFile="codesign"
certificatePassword=$(openssl rand -base64 12)
scripts/codesign/generate_selfsigned_certificate.sh "$certificateFile" "$certificatePassword"
scripts/codesign/import_certificate_into_main_keychain.sh "$certificateFile" "$certificatePassword"
