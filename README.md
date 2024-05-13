# autokube
## Automated Homelab Kubernetes Cluster running on Proxmox with Ubuntu Server 24.04 LTS Nodes
feat. Flannel Networking,
      Traefik Ingress Controller,
      Metallb Load Balancer,
      OpenEBS ZFS Local PV Storage,
      Elastic Cluster

Provisoned using Terraform and Ansible.

You can experiment with different storage solutions, as requirements for rook, longhorn or mayastor are met. Just deploy a different storage solution through helm in step 6. Basic manifests and and values are provided.

Make sure you have sufficent storage on your proxmox cluster. Best use thin-provisioned datastore.

Tip: If your terraform deployment does not finish, a provisioned machine might have memory deadlock and needs to be resetted through the proxmox gui. The deployment automatically continues when the machine is up again. 

---

0. Prerequisites:
    - Macos client with homebrew (https://brew.sh)
    - Git installed
    ```
    brew install git
    ```
    - Your ssh-key added to agent (https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
    ```
    ssh-add
    ```
    - Proxmox server (https://www.proxmox.com/en/proxmox-virtual-environment/get-started)    
    - Personal domain on the internet, otherwise you have to use kubectl port-forward to access the traefik dashboard and kibana

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
    cd ../proxmox
    ```
    - Change variables in ubuntu-2404-cloudinit.sh according to your proxmox environment
    ```
    # Change Parameters matching your environment 
    STORAGE="<your_proxmox_storage_name>"
    SSH_KEY="<your_ssh_key>"
    TF_USERPASS="<your_password_for_terraform_user>"
    ```
    - Use scp to copy script to home directory of root on proxmox server
    - Connect via ssh to your proxmox server and run the script

   Or use Proxmox GUI and
    - Start shell-session
    - Use editor to create ubuntu-2404-cloudinit.sh and copy contents of file from repository into editor
    - Change variables
    - Write changes and exit editor
    - Run ubuntu-2404-cloudinit.sh

3. Deploy the Cluster VMs with terraform and ansible
    - Create an api token through the gui for the newly created terraform-prov user
    - Enter terraform directory
    ```
    cd ../terraform
    ```
    - Change the variables in terraform-tfvars to work with your proxmox setup
    ```
    pm_api_url = "https://<your_proxmox_node_ip>:8006/api2/json"
    pm_api_token_id = "terraform-prov@pam!terraform"
    pm_api_token_secret = "<your_terraform_api_token>"
    cloudinit_template_name = "ubuntu-2404-ci"
    proxmox_node = "<your_proxmox_node_name>"
    ssh_key = "<your_ssh_key>"
    master_count = 1
    worker_count = 3
    storage_size = 250
    ```
    - Change vm specs according to your needs
    - Ansible playbooks get called by the terraform process and setup the cluster
    - The playbooks start when the vms are deployed and the hosts file gets written to the ansible directory by terraform
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
    - Use scp to copy the config file from kubernetes master to folder .kube in your home directory
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
    cd ../helm
    ./helmRepos.sh
    ```

6. Install openebs
    ```
    helm install openebs --namespace openebs openebs/openebs --set engines.replicated.mayastor.enabled=false --create-namespace
    ```
    - Create storageclass openebs-zfspv
    ```
    cd ../openebs
    kubectl create -f zfsSC.yaml
    ```
    Optional:
    - Benchmark your storage with dbench
    ```
    kubectl create -f dbench.yaml
    ```
    - Follow the dbench logs
    ```
    kubectl logs -f job/dbench
    ```
    - Clean up dbench
    ```
    kubectl delete -f dbench.yaml
    ```

7. Install metallb
    ```
    helm install metallb metallb/metallb -n metallb-system --create-namespace
    ```
    - edit the pool.yaml to your network addresses and create ip pool
    ```
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: first-pool
      namespace: metallb-system
    spec:
       addresses:
       - <your_pool_start_ip>-<your_pool_end_ip>
    ```
    ```
    cd ../metallb
    kubectl create -f pool.yaml
    ```
    - Create layer 2 advertisment
    ```
    kubectl create -f L2Advertisement.yaml
    ```

8. Install traefik
    - Customize values.yaml in traefik folder to your needs
    - Set your domain as matchRule for the dashboard ingressroute (starting in line 157)
    - In case you do not own a domain, disable the ingressroute by setting enabled to false
    ```
    ## Create an IngressRoute for the dashboard
    ingressRoute:
      dashboard:
        # -- Create an IngressRoute for the dashboard
        enabled: true
        # -- Additional ingressRoute annotations (e.g. for kubernetes.io/ingress.class)
        annotations: {}
        # -- Additional ingressRoute labels (e.g. for filtering IngressRoute by custom labels)
        labels: {}
        # -- The router match rule used for the dashboard ingressRoute
        matchRule: Host(`<traefik.yourdomain.xyz>`)
        # -- Specify the allowed entrypoints to use for the dashboard ingress route, (e.g. traefik, web, websecure).
        # By default, it's using traefik entrypoint, which is not exposed.
        # /!\ Do not expose your dashboard without any protection over the internet /!\
        entryPoints: ["websecure"]
        # -- Additional ingressRoute middlewares (e.g. for authentication)
        middlewares:
          - name: traefik-dashboard-auth
        # -- TLS options (e.g. secret containing certificate)
        tls:
          certResolver: myresolver
    ```
    - Change the static configuration to your needs (starting in line 570)
    - Setup acme resolver. You can test with staging server, just comment out the caserver line
    - If you do not own a domain, comment out api.insecure to access dashboard locally with kubectl port-forward
    ```
    # Configure Traefik static configuration
    # -- Additional arguments to be passed at Traefik's binary
    # All available options available on https://docs.traefik.io/reference/static-configuration/cli/
    ## Use curly braces to pass values: `helm install --set="additionalArguments={--providers.kubernetesingress.ingressclass=traefik-internal,--log.level=DEBUG}"`
    additionalArguments:
    #  - "--providers.kubernetesingress.ingressclass=traefik-internal"
    #  - "--log.level=DEBUG"
    #  - "--api.insecure"
      - "--api.dashboard=true"
      - "--serversTransport.insecureSkipVerify=true"
    #  - "--accesslog"
    #  - "--providers.kubernetescrd"
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=<your.email@yourdomain.xyz>"
      - "--certificatesresolvers.myresolver.acme.storage=/data/acme.json"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
    #  - "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
    ```
    - Install traefik with custom values
    ```
    cd ../traefik
    helm install traefik traefik/traefik -f values.yaml -n traefik --create-namespace
    ```
    - check loadbalancer external ip
    ```
    kubectl get svc -n traefik
    ```
    - Enable port forwarding to ports tcp 80 and tcp 443 to loadbalancer external ip in your router
    - If you want to expose the traefik dashboard create dns entry for <traefik.yourdomain.xyz> pointing to your wan ip (best use a dyndns service with cname)
    - Dashboard credentials are admin tr@efikd@sh
    - Optionally create your own dashboard credential token
    ```
    htpasswd -nb <your_user> <your_password> | openssl base64
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
    - If you did not expose the traefik dashboard to the internet, use kubernetes port forwarding and access dashboard at http://127.0.0.1:8080/dashboard/
    ```
    kubectl -n traefik port-forward $(kubectl -n traefik get pods --selector "app.kubernetes.io/name=traefik" --output=name) 8080:8080
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
    - Optionally edit file metricbeat_hosts (adapted from https://github.com/elastic/cloud-on-k8s/tree/main/config/recipes/beats)
    - Deploy elastic cluster with metricbeat
    ```
    cd elastic
    kubectl create -f metricbeat_hosts.yaml -n elastic
    ```
    - Cluster with single elasticsearch node and a 50GB volume plus kibana and metricbeat containers is created 
    - If you want to expose the kibana dashboard create dns entry for <kibana.yourdomain.xyz> pointing to your wan ip (best use a dyndns service with cname)
    - Edit kibanaIngressroute.yaml to point to your domain
    ```
    ---
    apiVersion: traefik.io/v1alpha1
    kind: IngressRoute
    metadata:
      name: kibana-https
      namespace: elastic

    spec:
      entryPoints:
        - websecure

      routes:
        - match: Host(`<kibana.yourdomain.xyz>`)
          kind: Rule
          services:
            - name: kibana-kb-http
              port: 5601
      tls:
        certResolver: myresolver
    ```
    - Create kibana ingressroute
    ```
    kubectl create -f kibanaIngressroute.yaml
    ```
    - Obtain elastic user password
    ```
    (kubectl get -n elastic secret elasticsearch-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'); echo
    ```
    - Log in to kibana with these credentials
    - If you do not own a domain and did not setup external access, use kubernetes port forwarding and access kibana via https://127.0.0.1:5601
    ```
    kubectl port-forward service/kibana-kb-http 5601 -n elastic
    ```
    
