#!/bin/bash -xe
exec > /var/log/jenkins-server.log 2>&1
set +e

function wait_for_jenkins()
{
  while (( 1 )); do
      echo "waiting for Jenkins to launch on port [8080] ..."
      nc -zv 127.0.0.1 8080
      if (( $? == 0 )); then
          echo "Jenkins successfully restarted"
          break
      fi
      sleep 120
  done
  echo "Jenkins launched"
}

function schedule_backup_job() 
{
  cat <<EOF > /build-artifacts/backup-to-s3.sh
echo 'tar /var/lib/jenkins directory'
set +e
cd /var/lib/jenkins
tar -cvf /build-artifacts/jenkins_backup.tar .
echo 'Upload jenkins_backup.tar to S3 bucket'
aws s3 cp /build-artifacts/jenkins_backup.tar s3://${backup_bucket_name}/
echo 'Remove files after succesful upload to S3'
rm -rf /build-artifacts/jenkins_backup.tar
EOF

  chmod +x /build-artifacts/backup-to-s3.sh
  echo "5 4 * * * /build-artifacts/backup-to-s3.sh > /dev/null" >> /var/spool/cron/crontabs/root
  chmod 600 /var/spool/cron/crontabs/root
}

function updating_jenkins_master_password ()
{
  cat > /build-artifacts/jenkinsHash.py <<EOF
import bcrypt
import sys
if not sys.argv[1]:
  sys.exit(10)
plaintext_pwd=sys.argv[1].encode('utf-8')
encrypted_pwd=bcrypt.hashpw(plaintext_pwd, bcrypt.gensalt(rounds=10, prefix=b"2a"))
isCorrect=bcrypt.checkpw(plaintext_pwd, encrypted_pwd)
if not isCorrect:
  sys.exit(20);
print ("{}".format(encrypted_pwd.decode("utf-8")))
EOF

  chmod +x /build-artifacts/jenkinsHash.py
  
  # Wait till /var/lib/jenkins/users/admin* folder gets created
  sleep 10

  cd /var/lib/jenkins/users/admin*
  pwd
  while (( 1 )); do
      echo "Waiting for Jenkins to generate admin user's config file ..."
      if [[ -f "./config.xml" ]]; then
          break
      fi
      sleep 10
  done
  echo "Admin config file created"
  admin_password=$(python3 /build-artifacts/jenkinsHash.py ${jenkins_admin_password} 2>&1)
  xmlstarlet -q ed --inplace -u "/user/properties/hudson.security.HudsonPrivateSecurityRealm_-Details/passwordHash" -v '#jbcrypt:'"$admin_password" config.xml

  # Restart
  systemctl restart jenkins
  sleep 30
  echo "Jenkins Admin password is changed"
}

function install_packages ()
{
  wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
  sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
  apt-get update
  apt-get upgrade -y
  apt install openjdk-8-jre xmlstarlet -y
  apt-get install jenkins -y
  systemctl enable jenkins
  systemctl restart jenkins
  ufw allow OpenSSH
  ufw enable
  ufw allow 8080
  sleep 10
  echo "Jenkins Installed successfully"
}

function configure_jenkins_server ()
{
  # Jenkins cli
  echo "installing the Jenkins cli ..."
  jenkins_dir="/var/lib/jenkins"
  plugins_dir="$jenkins_dir/plugins"

  #cp /var/cache/jenkins/war/WEB-INF/jenkins-cli.jar /var/lib/jenkins/jenkins-cli.jar
  wget -O $jenkins_dir/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
  # Getting initial password
  # PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
  PASSWORD="${jenkins_admin_password}"
  sleep 10

  cd $jenkins_dir

  # Open JNLP port
  xmlstarlet -q ed --inplace -u "/hudson/slaveAgentPort" -v 33453 config.xml

  cd $plugins_dir || { echo "unable to chdir to [$plugins_dir]"; exit 1; }

  # List of plugins that are needed to be installed 
  plugin_list="git-client git github-api github-oauth github MSBuild ssh-slaves workflow-aggregator ws-cleanup kubernetes workflow-aggregator configuration-as-code ansible docker-plugin aws-secrets-manager-credentials-provider artifactory pipeline-aws uno-choice role-strategy"

  # remove existing plugins, if any ...
  rm -rfv $plugin_list

  for plugin in $plugin_list; do
      echo "installing plugin [$plugin] ..."
      java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth admin:$PASSWORD install-plugin $plugin
  done

  # Restart jenkins after installing plugins
  java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:$PASSWORD safe-restart
  echo "Jenkins Configured successfully"
}

function create_cred() 
{
  while (( 1 )); do
    echo "waiting for Jenkins to launch on port [8080] ..."
    nc -zv 127.0.0.1 8080
    if (( $? == 0 )); then
        jenkins_dir="/var/lib/jenkins"
        cat /build-artifacts/create-node-credentials.groovy | java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:${jenkins_admin_password} groovy =
        echo "Jenkins SSH Credential Created successfully"
        break
    fi
    sleep 180
  done
}

### script starts here ###

install_packages
wait_for_jenkins
schedule_backup_job
## Create Restore Config Backup from s3
aws s3 cp s3://${backup_bucket_name}/jenkins_backup.tar /build-artifacts/
if [ -f "/build-artifacts/jenkins_backup.tar" ]
then
    tar -xvf /build-artifacts/jenkins_backup.tar -C /var/lib/jenkins/
    systemctl restart jenkins
else
  updating_jenkins_master_password
  wait_for_jenkins
  configure_jenkins_server
  wait_for_jenkins
  create_cred
fi

echo "Done"
exit 0