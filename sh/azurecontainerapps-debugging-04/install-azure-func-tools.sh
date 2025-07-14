#!/bin/bash

echo "Updating packages and installing prerequisites..."
apt update
apt install -y curl gnupg

echo "Adding Microsoft GPG key and repository..."
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-jammy-prod jammy main" > /etc/apt/sources.list.d/dotnetdev.list'

echo "Updating package lists and installing Azure Functions Core Tools..."
apt-get update
apt-get install -y azure-functions-core-tools-4

echo "Starting Azure Functions host with verbose logging..."
func start --verbose
#func start --port 7071 if you need  to try another pot
