#!/bin/bash

echo hello this is my first script
read -p "Enter option number: " choice
echo 1. update and upgrade the server







case $choice in  

1) 
echo "starting the update and upgrade process...."
apt update && apt upgrade -y

esac
