pipeline {
    agent any
    options {
    ansiColor('xterm')
    timestamps ()
    }
    stages {
        stage('SCM') {
            steps {
                git branch: 'main', url: 'https://git.datwyler.com/infra/tf-ec2-create.git'
            }
        }
		stage('Copy terraform script to remote host') {
            steps {                sh '''#!/bin/bash
                ssh $remote_host "
                rm -rf $jenkins_dir
                mkdir -p $jenkins_dir"
                rsync -arv /var/lib/jenkins/workspace/$jenkins_dir $remote_host:$jenkins_dir'''
        }
    }
		stage('terraform init & plan') {
            steps {
                sh '''#!/bin/bash
                ssh $remote_host "
                cd /root/$jenkins_dir/$jenkins_dir/$server_dir_name
                terraform init
                terraform plan -input=false" '''
        }
    }
    	stage('terraform apply') {
            steps {
                sh '''#!/bin/bash
                ssh $remote_host "
                cd /root/$jenkins_dir/$jenkins_dir/$server_dir_name
                terraform apply -input=false --auto-approve" '''
        }
        input {
            message '    Ready to go?     Proceed or Abort'
        }
    }
    		stage('Create awsroot user') {
            steps {
                sh '''#!/bin/bash
                sleep 60
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$target_ip"
                ssh -o "StrictHostKeyChecking no" root@$target_ip "
                apt update
                hostnamectl set-hostname --static $hostname
                useradd awsroot " '''
        }
    }
    		stage('Zabbix Installation_ubuntu') {
                    when {
                         environment name: 'os', value: 'ubuntu'
                        }
            steps {
                sh '''#!/bin/bash
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$target_ip"
                ssh -o "StrictHostKeyChecking no" root@$target_ip "
                wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+focal_all.deb
                dpkg -i zabbix-release_5.0-1+focal_all.deb
                sudo apt update
                sudo apt install zabbix-agent
                sed -i 's/ServerActive=127.0.0.1/#ServerActive=127.0.0.1/g' /etc/zabbix/zabbix_agentd.conf
                sed -i 's/Hostname=Zabbix server/Hostname=$hostname/g' /etc/zabbix/zabbix_agentd.conf
                sed -i 's/Server=127.0.0.1/Server=zabbix.dat.datwyler.biz/g' /etc/zabbix/zabbix_agentd.conf
                sudo systemctl enable zabbix-agent
                sudo systemctl restart zabbix-agent " '''
        }
    }
            stage('Zabbix Installation_redhat') {
                    when {
                         environment name: 'os', value: 'redhat'
                        }
            steps {
                sh '''#!/bin/bash
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$target_ip"
                ssh -o "StrictHostKeyChecking no" root@$target_ip "
                yum install https://repo.zabbix.com/zabbix/4.4/rhel/8/x86_64/zabbix-release-4.4-1.el8.noarch.rpm -y
                yum update -y
                yum install zabbix-agent -y
                sed -i 's/ServerActive=127.0.0.1/#ServerActive=127.0.0.1/g' /etc/zabbix/zabbix_agentd.conf
                sed -i 's/Hostname=Zabbix server/Hostname=$hostname/g' /etc/zabbix/zabbix_agentd.conf
                sed -i 's/Server=127.0.0.1/Server=zabbix.dat.datwyler.biz/g' /etc/zabbix/zabbix_agentd.conf
                systemctl enable zabbix-agent
                systemctl restart zabbix-agent " '''
        }
    }
    		stage('Cortex Installation_ubuntu') {
                    when {
                         environment name: 'os', value: 'ubuntu'
                        }
            steps {
                sh '''#!/bin/bash
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$target_ip"
                ssh -o "StrictHostKeyChecking no" root@$target_ip "
                export GIT_SSL_NO_VERIFY=1
                git clone https://git.datwyler.com/infra/cortex-agent-file.git
                cd /root/cortex-agent-file/ubuntu
                dpkg -i 7.5.1.39945.deb " '''
        }
    }
        	stage('Cortex Installation_redhat') {
                    when {
                         environment name: 'os', value: 'redhat'
                        }
            steps {
                sh '''#!/bin/bash
                ssh-keygen -f "/root/.ssh/known_hosts" -R "$target_ip"
                ssh -o "StrictHostKeyChecking no" root@$target_ip "
                yum install git -y
                export GIT_SSL_NO_VERIFY=1
                git clone https://git.datwyler.com/infra/cortex-agent-file.git
                cd cortex-agent-file/rhel
                rpm -i 7.5.1.39945.rpm " '''
        }
    }
}
}