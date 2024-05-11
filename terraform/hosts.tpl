[control_plane]
%{ for index, hostname in kubemaster_name ~}
${hostname} ansible_host=${kubemaster_ip[index]} ansible_user=ubuntu
%{ endfor ~}

[workers]
%{ for index, hostname in kubeworker_name ~}
${hostname} ansible_host=${kubeworker_ip[index]} ansible_user=ubuntu
%{ endfor ~}

[all:vars]
ansible_python_interpreter=/usr/bin/python3