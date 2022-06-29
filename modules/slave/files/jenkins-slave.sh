#!/bin/bash -xe
exec > /var/log/jenkins-slave.log 2>&1
set +e

function install_jre ()
{
  apt-get update
  apt-get upgrade -y
  apt-get install openjdk-8-jre docker.io -y
}

function wait_for_jenkins ()
{
    echo "Waiting jenkins to launch ..."
    while (( 1 )); do
        echo "Waiting for Jenkins"
        nc -zv ${server_ip} 443
        if (( $? == 0 )); then
            break
        fi
        sleep 120
    done
    echo "Jenkins launched"
}

function slave_setup()
{
    # Wait till jar file gets available
    ret=1
    while (( $ret != 0 )); do
        wget -O /opt/jenkins-cli.jar https://${server_ip}/jnlpJars/jenkins-cli.jar --no-check-certificate
        ret=$?
        echo "jenkins cli ret [$ret]"
    done

    ret=1
    while (( $ret != 0 )); do
        wget -O /opt/slave.jar https://${server_ip}/jnlpJars/slave.jar --no-check-certificate
        ret=$?
        echo "jenkins slave ret [$ret]"
    done
    
    mkdir -p /opt/jenkins-slave
    chown -R ubuntu:ubuntu /opt/jenkins-slave

    # Register_slave
    JENKINS_URL="https://${server_ip}"
    USERNAME="${jenkins_username}"
    PASSWORD="${jenkins_password}"

    SLAVE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
    NODE_NAME=$(echo "ansible-$SLAVE_IP" | tr '.' '-')
    NODE_SLAVE_HOME="/home/ubuntu"
    EXECUTORS=4
    SSH_PORT=22

    LABELS="build ansible linux docker awscli"
    USERID="ubuntu"

    mkdir -p /home/ubuntu/.ssh/
    echo "${ssh_cert}" >> /home/ubuntu/.ssh/authorized_keys
    
    cd /opt
    
    # Creating CMD utility for jenkins-cli commands
    jenkins_cmd="java -jar /opt/jenkins-cli.jar -noCertificateCheck -s $JENKINS_URL -auth $USERNAME:$PASSWORD"

    # Waiting for Jenkins to load all plugins
    while (( 1 )); do

      count=$($jenkins_cmd list-plugins 2>/dev/null | wc -l)
      ret=$?

      echo "count [$count] ret [$ret]"

      if (( $count > 0 )); then
          break
      fi

      sleep 30
    done

    # For Deleting Node, used when testing
    $jenkins_cmd delete-node $NODE_NAME
    
    # Generating node.xml for creating node on Jenkins server
    cat > /build-artifacts/node.xml <<EOF
<slave>
  <name>$NODE_NAME</name>
  <description>Linux Slave</description>
  <remoteFS>$NODE_SLAVE_HOME</remoteFS>
  <numExecutors>$EXECUTORS</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.33.0">
    <host>$SLAVE_IP</host>
    <port>$SSH_PORT</port>
    <credentialsId>${cred_id}</credentialsId>
    <launchTimeoutSeconds>60</launchTimeoutSeconds>
    <maxNumRetries>10</maxNumRetries>
    <retryWaitTime>15</retryWaitTime>
    <sshHostKeyVerificationStrategy class="hudson.plugins.sshslaves.verifiers.NonVerifyingKeyVerificationStrategy"/>
    <tcpNoDelay>true</tcpNoDelay>
  </launcher>
  <label>$LABELS</label>
  <nodeProperties/>
  <userId>$USERID</userId>
</slave>
EOF
  sleep 10
  
  # Creating node using node.xml
  $jenkins_cmd create-node $NODE_NAME < /build-artifacts/node.xml
}

install_jre
wait_for_jenkins
slave_setup

echo "Done"
exit 0