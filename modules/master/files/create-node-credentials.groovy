#!/usr/bin/env groovy

import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey
import com.cloudbees.plugins.credentials.CredentialsScope

instance = Jenkins.instance
domain = Domain.global()
store = instance.getExtensionList("com.cloudbees.plugins.credentials.SystemCredentialsProvider")[0].getStore()

privateKey = new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(
'''${ssh_key}'''
)

sshKey = new BasicSSHUserPrivateKey(
  CredentialsScope.GLOBAL,
  "${cred_id}",
  "ubuntu",
  privateKey,
  null,
  "Credentials Master uses to connect to node agents"
)

store.addCredentials(domain, sshKey)