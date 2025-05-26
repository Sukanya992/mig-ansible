---
- hosts: all
  become: yes  # Ensure commands run as root
  tasks:
    - name: Install tools
      yum:
        name:
          - yum-utils
          - wget
          - git
          - python3
          - python3-pip
          - epel-release
        state: present
        update_cache: yes

    - name: Add Docker repository
      shell: yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      args:
        creates: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      yum:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Start and enable Docker service
      systemd:
        name: docker
        state: started
        enabled: yes
        
    - name: Install Harness Delegate (Docker-based)
      shell: >
        docker run -d --cpus=1 --memory=2g --network=bridge
        -e DELEGATE_NAME=docker-delegate-ansible-vm-iacm
        -e NEXT_GEN=true
        -e DELEGATE_TYPE=DOCKER
        -e ACCOUNT_ID=ucHySz2jQKKWQweZdXyCog
        -e DELEGATE_TOKEN=NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY=
        -e DELEGATE_TAGS=""
        -e MANAGER_HOST_AND_PORT=https://app.harness.io us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.05.85801

    - name: Install Python Docker SDK and dependencies
      pip:
        name:
          - docker
          - requests
        executable: pip3
        
    - name: Pull Docker image from DockerHub
      docker_image:
        name: sukanya996/bule-green:green-46
        source: pull

    - name: Run Docker container for your app
      docker_container:
        name: my-app
        image: sukanya996/bule-green:green-46
        state: started
        restart_policy: always
        ports:
          - "5000:5000"  # Change this based on your app
