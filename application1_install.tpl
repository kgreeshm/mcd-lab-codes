#!/bin/bash
sudo apt-get update
sudo apt-get install -y w3m
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
cd ../../var/www/html/
echo 'This is application-1' | sudo tee index.html