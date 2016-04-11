#!/bin/bash
CSRF_PROTECTION_VERSION="0.0.5"
CSRF_PROTECTION_ZIP="CsrfProtection-$CSRF_PROTECTION_VERSION.zip"
zip $CSRF_PROTECTION_ZIP CsrfProtection.cfc LICENSE README.md controller/* view/*
