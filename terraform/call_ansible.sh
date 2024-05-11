#! /bin/bash
cd ../ansible
while ! test -f "hosts"; do
  sleep 10
  echo "Waiting for ansible to create cluster"
done
ansible-playbook -i hosts create_cluster.yml --ssh-common-args='-o StrictHostKeyChecking=no'