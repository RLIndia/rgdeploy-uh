#!/usr/bin/env bash
bootstrap_s3_location="$1"
s3_mounts="$2"
rstudio_user="$3"
region="$4"

if [ -z "$region" ]
then
region=us-east-2
fi

INSTALL_DIR="/usr/local/share/workspace-environment"

# Download instance files and execute bootstrap script
sudo mkdir "$INSTALL_DIR"
su - root -c "aws s3 sync "$bootstrap_s3_location" "$INSTALL_DIR" --region $region"

bootstrap_script="$INSTALL_DIR/bootstrap.sh"
if [ -s "$bootstrap_script" ]
then
    sudo chmod 500 "$bootstrap_script"
    sudo "$bootstrap_script" "$s3_mounts" "$rstudio_user"
fi

exit 0

