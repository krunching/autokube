# autokube
Automated Homelab Kubernetes Cluster running on Proxmox
feat. Flannel Networking,
      Traefik Ingress Controller,
      Metallb Load Balancer,
      OpenEBS ZFS Local PV Storage,
      Elastic Cluster

You can experiment with different storage solutions, as requirements for rook, longhorn or mayastor are met. Just deploy a different storage solution through helm in step 6. Basic manifests and and values are provided.

Make sure you have sufficent storage on your proxmox cluster. Best use thin-provisioned datastore.



0. Prerequisites:
    - macos client with homebrew (https://brew.sh)
    - git installed
    - ssh-key added to agent (ssh-add)
    - proxmox server (https://www.proxmox.com/en/proxmox-virtual-environment/get-started)
    Optional:
    - personal domain on the internet, otherwise you have to use kubectl port-forward to access the traefik dashboard and kibana
    

1. Setup files and folders
    - clone this repository to your client machine (git clone https://github.com/krunching/autokube.git)
    - run brewPrerequisites.sh from folder brew

2. Create VM template in Proxmox
    - change variables in ubuntu-2404-cloudinit.sh according to your proxmox environment
    - use scp to copy script to home directory of root on proxmox server
    - make it executable for user via ssh and run the script

   Or use Proxmox GUI and
    - start shell-session
    - use nano to create ubuntu-2404-cloudinit.sh and copy contents of file from repository into editor
    - change variables according to your proxmox environment
    - write changes and exit editor
    - make the script executable for user
    - run ubuntu-2404-cloudinit.sh

3. Deploy the Cluster VMs with terraform and ansible
    - create an api token through the gui for the newly created terraform-prov user
    - change the variables in terraform-tfvars to work with your proxmox setup
    - change vm specs according to your needs
    - initialize terraform directory with "terraform init"
    - review with "terraform plan"
    - deploy with "terraform apply"
    - ansible playbooks get called by the terraform process and setup the cluster
    - the playbooks start when the vms are deployed and the hosts file gets written to the ansible directory by terraform, so always start terraform initial run without the hosts file

4. Prepare your client to interact with the Kubernetes Cluster
    - use scp to copy the config file from kubernetes master to folder .kube in your home directory (scp ubuntu@kubemaster-1:~/.kube/config ~/./kube/)
    - fix permissions on config file ("chmod go-r  ~/.kube/config")
    - check cluster status ("kubectl get nodes")
    - watch pods ("watch kubectl get pods -o wide -A")

5. Add Helm Repos
    - run the helmRepos.sh script

6. Install openebs
    - "helm install openebs --namespace openebs openebs/openebs --set engines.replicated.mayastor.enabled=false --create-namespace"
    - create storageclass ("kubectl create -f zfsSC.yaml")

7. Install metallb
    - "helm install metallb metallb/metallb -n metallb-system --create-namespace"
    - change pool.yaml to your network addresses and apply ("kubectl create -f pool.yaml")
    - create advertisment ("kubectl create -f L2Advertisement.yaml")


8. Install traefik
    - customize values.yaml to your needs, especially the static config part for your acme resolver (line 575) and the dashboard ingressroute (line 157)
    - "helm install traefik traefik/traefik -f values.yaml -n traefik --create-namespace"
    - check loadbalancer external ip ("kubectl get svc -n traefik)
    - enable port forwarding for ports tcp 80 and tcp 443 to this ip in your router
    - if you want to expose the traefik dashboard create dns entry for traefik.yourdomain.xyz pointing to your wan ip (best use a dyndns service with cname)
    - dashboard credentials are admin tr@efikd@sh

9. Install elastic
    - install eck operator ("helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace")
    - create elastic namespace ("kubectl create ns elastic")
    - optionally edit file metricbeat_hosts (adapted from https://github.com/elastic/cloud-on-k8s/tree/main/config/recipes/beats)
    - deploy elastic cluster ("kubectl create -f metricbeat_hosts.yaml -n elastic")
    - cluster with 1 elasticsearch node and a 50GB volume plus metricbeat containers is created 
    - if you want to expose the kibana dashboard create dns entry for kibana.yourdomain.xyz pointing to your wan ip (best use a dyndns service with cname)
    - change the domian in file kibanaIngressroute.yaml and create kibana ingressroute ("kubectl create -f kibanaIngressroute.yaml")
    - obtain elastic user password ("(kubectl get -n elastic secret elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'); echo")
    - log in to kibana with these credentials
    