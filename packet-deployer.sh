#!/bin/bash
#set -x

SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

# Enter your Equinix Metal API Key here
API_TOKEN=""

# Set project name
project_name="FPM-Lab"

# Set termination in 6 hours
TERMINATION=$(date -d '+6 hours' +%FT%T%Z)

# Set desired server types
PLAN_ONDEMAND="s3.xlarge.x86"
PLAN_SPOT="m3.large.x86"

# Set your pull secret
PULLSECRET=''

create_project_with_payment() {
  curl -X POST -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects" \
  -d '{
    "name": "'$project_name'",
    "payment_method_id": "'$payment_id'"
  }'
}

create_project() {
  curl -X POST -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects" \
  -d '{
    "name": "'$project_name'"
  }'
}

create_project_ssh_key() {
  cat <<EOF > data.json
{
  "label": "$project_name-key",
  "key": "$SSH_KEY"
}
EOF
  curl -X POST -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects/$project_id/ssh-keys" \
  -d @data.json
  rm -f data.json
}

delete_project() {
  project_id=$1
  curl -X DELETE -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects/$project_id"
}

create_server_spot() {
  curl -X POST -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects/$project_id/devices" \
  -d '{
    "facility": "am6",
    "plan": "'$PLAN_ONDEMAND'",
    "hostname": "'$project_name'",
    "operating_system": "centos_8",
    "spot_instance": true,
    "spot_price_max": 0.70,
    "termination_time": "'$TERMINATION'"
  }'
}

create_server() {
  curl -X POST -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/projects/$project_id/devices" \
  -d '{
    "facility": "am6",
    "plan": "'$PLAN_ONDEMAND'",
    "hostname": "'$project_name'",
    "operating_system": "centos_8",
    "termination_time": '$TERMINATION'
  }'
}

get_server_ip() {
  my_server=$1
  curl -X GET -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/devices/$my_server/ips"
}

prepare_node_setup() {
  cat <<EOF > node-prep.sh
  dnf -y update
  dnf -y install firewalld git qemu-kvm libvirt jq
  mdadm --create /dev/md0 --level=0 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1
  mkfs.ext4 -v -L nvmeRAID -m 1 -b 4096 -E stride=128,stripe-width=256 /dev/md0
  mount /dev/md0 /var/lib/libvirt/images
  mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
  echo /dev/md0 /var/lib/libvirt/images defaults,nofail,nobootwait 0 2 >> /etc/fstab
  git clone --branch packet --single-branch https://github.com/hgeaydem/openshift-virt-labs.git
  sed -i 's/PULLSECRET/$PULLSECRET/g' openshift-virt-labs/install.sh
EOF
}

delete_server() {
  my_server=$1
  curl -X DELETE -H "Content-Type: application/json" -H "X-Auth-Token: $API_TOKEN" "https://api.equinix.com/metal/v1/devices/$my_server" \
  -d '{
    "force_delete": true
  }'
}

deploy() {
  project_id=$(create_project |jq .id |tr -d '"')
  create_project_ssh_key
#  SERVER_YAML=$(create_server_spot)
  SERVER_ID=$(create_server_spot |jq .id |tr -d '"')
  SERVER_IP="null"
  while [ "$SERVER_IP" = "null" ]
  do
    SERVER_IP=$(get_server_ip $SERVER_ID |jq .ip_addresses[0].address |tr -d '"')
    sleep 5
  done
  sleep 180
  SERVER_IP=$(get_server_ip $SERVER_ID |jq .ip_addresses[0].address |tr -d '"')
  echo $SERVER_IP
  echo "SERVER_IP=$SERVER_IP" > ./node-infos.txt
  echo "PROJECT_ID=$project_id" >> ./node-infos.txt
  prepare_node_setup
  scp -o StrictHostKeyChecking=no node-prep.sh root@$SERVER_IP:/root/
  ssh -o StrictHostKeyChecking=no root@$SERVER_IP sh /root/node-prep.sh
  rm -f node-prep.sh
  sleep 10
  ssh -o StrictHostKeyChecking=no root@$SERVER_IP "cd /root/openshift-virt-labs; sh install.sh"
}


case $1 in
  [Tt][Ee][Ss][Tt]) project_id=$(create_project |jq .id |tr -d '"')
        echo $project_id ;;
  [Dd][Ee][Pp][Ll][Oo][Yy])
        deploy
        echo "Server IP : $SERVER_IP"
        echo "Lab instructions : https://github.comRHFieldProductManagement/openshift-virt-labs" ;;
  [Cc][Ll][Ee][Aa][Nn]*) delete_project $2 ;;
  *) echo "Usage : $0 [ Deploy | Clean <project_id> ]"
    exit 0 ;;
esac

#delete_server $SERVER_ID
