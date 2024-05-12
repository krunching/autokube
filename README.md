# autokube
## Automated Homelab Kubernetes Cluster running on Proxmox with Ubuntu Server 24.04 LTS Nodes
feat. Flannel Networking,
      Traefik Ingress Controller,
      Metallb Load Balancer,
      OpenEBS ZFS Local PV Storage,
      Elastic Cluster

You can experiment with different storage solutions, as requirements for rook, longhorn or mayastor are met. Just deploy a different storage solution through helm in step 6. Basic manifests and and values are provided.

Make sure you have sufficent storage on your proxmox cluster. Best use thin-provisioned datastore.

Always start in autokube directory.

Tip: If your terraform deployment does not finish, a provisioned machine might have memory deadlock and needs to be resetted through the proxmox gui. The deploment automatically continues when the machine is up again. 

---

0. Prerequisites:
    - macos client with homebrew (https://brew.sh)
    - git installed
    ```
    brew install git
    ```
    - ssh-key added to agent
    ```
    ssh-add
    ```
    - proxmox server (https://www.proxmox.com/en/proxmox-virtual-environment/get-started)    
    - personal domain on the internet, otherwise you have to use kubectl port-forward to access the traefik dashboard and kibana

1. Setup files and folders
    - Clone this repository
    ```
    git clone https://github.com/krunching/autokube.git
    ```
    - Enter autokube directory
    ```
    cd autokube
    ```
    - Install dependencies
    ```
    cd brew
    ./brewPrerequisites.sh
    ```

2. Create VM template in Proxmox and setup terraform role and user
    - Enter proxmox directory
    ```
    cd proxmox
    ```
    - change variables in ubuntu-2404-cloudinit.sh according to your proxmox environment
    - use scp to copy script to home directory of root on proxmox server
    - connect via ssh to your proxmox server and run the script

   Or use Proxmox GUI and
    - start shell-session
    - use editor to create ubuntu-2404-cloudinit.sh and copy contents of file from repository into editor
    - change variables according to your proxmox environment
    - write changes and exit editor
    - run ubuntu-2404-cloudinit.sh

3. Deploy the Cluster VMs with terraform and ansible
    - create an api token through the gui for the newly created terraform-prov user
    - change the variables in terraform-tfvars to work with your proxmox setup
    - change vm specs according to your needs
    - ansible playbooks get called by the terraform process and setup the cluster
    - the playbooks start when the vms are deployed and the hosts file gets written to the ansible directory by terraform
    - Enter terraform directory
    ```
    cd terraform
    ```
    - Initialize terraform
    ```
    terraform init
    ```
    - Plan deployment
    ```
    terraform plan
    ```
    - Deploy
    ```
    terraform apply
    ```
    Optional:
     - Delete resources
       ```
       terraform destroy
       ```

4. Prepare your client to interact with the Kubernetes Cluster
    - use scp to copy the config file from kubernetes master to folder .kube in your home directory
    ```
    cd ~
    scp ubuntu@kubemaster-1:~/.kube/config ~/.kube/
    ```
    - Fix permissions on config file
    ```
    chmod go-r ~/.kube/config
    ```
    - Check cluster status
    ```
    kubectl get nodes
    ```
    - Watch pods
    ```
    watch kubectl get pods -o wide -A
    ```

5. Add Helm Repos
    ```
    cd helm
    ./helmRepos.sh
    ```

6. Install openebs
    ```
    helm install openebs --namespace openebs openebs/openebs --set engines.replicated.mayastor.enabled=false --create-namespace
    ```
    - Create storageclass openebs-zfspv
    ```
    cd openebs
    kubectl create -f zfsSC.yaml
    ```
    Optional:
    - Benchmark your storage with dbench
    ```
    cd openebs
    kubectl create -f dbench.yaml
    ```
    - Follow the dbench logs
    ```
    kubectl logs -f job/dbench
    ```
    - Clean up dbench
    ```
    cd openebs
    kubectl delete -f dbench.yaml
    ```

7. Install metallb
    ```
    helm install metallb metallb/metallb -n metallb-system --create-namespace
    ```
    - edit the pool.yaml to your network addresses and create ip pool
    ```
    cd metallb
    kubectl create -f pool.yaml
    ```
    - Create layer 2 advertisment
    ```
    kubectl create -f L2Advertisement.yaml
    ```

8. Install traefik
    - Customize values.yaml to your needs, especially the static config part for your acme resolver (starting line 575) and the dashboard ingressroute (starting line 157)
    - Install traefik with custom values
    ```
    cd traefik
    helm install traefik traefik/traefik -f values.yaml -n traefik --create-namespace
    ```
    - check loadbalancer external ip
    ```
    kubectl get svc -n traefik
    ```
    - Enable port forwarding for ports tcp 80 and tcp 443 to loadbalancer external ip in your router
    - If you want to expose the traefik dashboard create dns entry for traefik.yourdomain.xyz pointing to your wan ip (best use a dyndns service with cname)
    - Dashboard credentials are admin tr@efikd@sh
    Optional:
    - create your own dashboard credentials
    ```
    htpasswd -nb user password | openssl base64
    ```
    - Apply the secret
    ```
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: traefik-dashboard-auth-secret
      namespace: traefik
    data:
      users: <your_token_here>    
    EOF
    ```
    
9. Install elastic
    - Install eck operator
    ```
    helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace
    ```
    -  Create elastic namespace
    ```
    kubectl create ns elastic
    ```
    - optionally edit file metricbeat_hosts (adapted from https://github.com/elastic/cloud-on-k8s/tree/main/config/recipes/beats)
    - Deploy elastic cluster with metricbeat
    ```
    cd elastic
    kubectl create -f metricbeat_hosts.yaml -n elastic
    ```
    - Cluster with 1 elasticsearch node and a 50GB volume plus kibana and metricbeat containers is created 
    - If you want to expose the kibana dashboard create dns entry for kibana.yourdomain.xyz pointing to your wan ip (best use a dyndns service with cname)
    - Edit kibanaIngressroute.yaml to point to your domain
    - Create kibana ingressroute
    ```
    kubectl create -f kibanaIngressroute.yaml
    ```
    - Obtain elastic user password
    ```
    (kubectl get -n elastic secret elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'); echo
    ```
    - Log in to kibana with these credentials
    
