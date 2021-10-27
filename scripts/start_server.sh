#!/bin/bash
version="0.1.6"
echo "Starting server....(start_server.sh v$version)"
if [ "$1" == "-h" ]; then
  echo "Usage: `basename $0` application_url"
  echo '    Param 1: (optional) URL for SNS Callback'
  echo '             Will use public-host-name if not passed'
  echo '             e.g. https://myrg.example.com'
  echo '    Param 2: (optional) Target Group ARN to register with'
  exit 0
fi

[ -z $RG_HOME ] && RG_HOME='/opt/deploy/sp2'
echo "RG_HOME=$RG_HOME"

myurl=$1
tgarn=$2
port=80

echo 'Login to ECR'
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 045938549113.dkr.ecr.us-east-2.amazonaws.com

echo 'Pulling docker image for research portal'
docker pull 045938549113.dkr.ecr.us-east-2.amazonaws.com/researchportal:_fd_1.7.3_b764
echo 'Pulling docker image for nginx'
docker pull 045938549113.dkr.ecr.us-east-2.amazonaws.com/nginx:latest
echo 'Pulling docker image for notificationsink'
docker pull 045938549113.dkr.ecr.us-east-2.amazonaws.com/notificationsink:1.7.3_b1

echo 'Modifying HttpResponseHopLimit'
ec2instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 modify-instance-metadata-options --instance-id "$ec2instanceid" --http-put-response-hop-limit 2

if [ -z $myurl ]; then
    public_host_name="$(wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname)"
    baseurl="$public_host_name"
else
    baseurl="$myurl"
fi
echo "BaseURL=$baseurl"
echo "TGARN=$tgarn"

if [ ! -z $tgarn ]; then
    ec2instanceid=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "Registering instance $ec2instanceid with Target group: $tgarn"
    aws elbv2 register-targets  --targets "Id=$ec2instanceid,Port=$port" --target-group-arn "$tgarn" 
fi
echo "Calling swarm init will respond with error if this node is already part of a swarm"
docker swarm init

echo "Creating secrets"
docker secret create sp2prod-dashboard-settings.json "$RG_HOME/config/dashboard-settings.json"
docker secret create sp2prod-config.json "$RG_HOME/config/config.json"
docker secret create sp2prod-alert-config.json "$RG_HOME/config/alert-config.json"

echo "Starting stack..."
docker stack deploy -c $RG_HOME/docker-compose.yml sp2

#Wait for 30 secs
sleep 5

#Check if stack is deployed
echo "Checking if stack is deployed"
service_count=`docker service ls -q | wc -l`
if [ "${service_count}" -gt 0  ]; then
  echo "Service count deployed is $service_count"
else
  echo "Service not deployed successfully"
  exit 1
fi

sleep 30

function check_stack_status(){
  #Check if all the services are up
  state_replicated=0
  for i in `docker service ls -q`; do
  echo "$i"
  replicated=`docker service inspect --pretty $i | grep -i "Service Mode" | awk '{print $3}'`
  echo "Replicated service status: $replicated"
  if [ "${replicated}" == "Replicated" ]; then
        replicas=`docker service inspect --pretty $i | grep -i replicas | awk '{print $2}'`
        echo "Replicas count : $replicas"
        running_replicas=`docker service ps $i |grep -i running | wc -l`
        echo "Running replicas count : $running_replicas"
        if [ ${replicas} -ne "${running_replicas}" ]; then
                let "state_replicated=state_replicated+1"
        fi
    fi
  done
  echo "Stack replication : $state_replicated"
  if [ "${state_replicated}" -gt 0 ]; then
      echo "CRITICAL - Not all services are replicated"
  else
      echo "OK - All services are replicated"
  fi
  return $state_replicated
}

for i in {0..3}
  do
    echo "Checking stack status $i"
    check_stack_status
    res=$?
    echo "$res"
    if [ "${res}" == 0 ]; then
      echo "All services are up"
      break
    else
      sleep 30
    fi
 done
 
#Check if web application is up and running
for i in {0..3}
  do
    sleep 10
    echo "Checking if web application is up and running"
    status_code=$(curl -sL -w "%{http_code}\n" "$baseurl" -o /dev/null)
    if [ "$status_code" -ne 200 ]; then
      echo "Application is not up, responded with status $status_code"
    else
      echo "Application is up and running, status code response is $status_code"
      break
    fi	
  done

echo "Done" 
