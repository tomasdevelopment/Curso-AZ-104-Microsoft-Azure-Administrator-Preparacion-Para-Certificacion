# List everything inside root directory
ls -la /

# List everything recursively in the webroot
ls -laR /home/site/wwwroot

# Navigate back to root and then to webroot
cd /
cd home/site/wwwroot

# List first 20 files recursively in webroot
ls -R /home/site/wwwroot | head -20

# Check if host.json exists and print first 20 lines or say not found
if [ -f /home/site/wwwroot/host.json ]; then
  head -20 /home/site/wwwroot/host.json
else
  echo "no host.json"
fi

# Check your environment Variables

echo $name_of_save_env_var
