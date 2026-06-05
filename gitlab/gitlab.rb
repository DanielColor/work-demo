external_url 'http://192.168.1.x:6060'
nginx['listen_port'] = 80
gitlab_rails['time_zone'] = 'Asia/Taipei'

# LDAP
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = {
  'main' => {
    'label' => 'LDAP',
    'host' => '192.168.1.x',
    'port' => 389,
    'uid' => 'mail',
    'bind_dn' => 'cn=admin,dc=example,dc=com',
    'password' => ENV['LDAP_PASSWORD'],
    'encryption' => 'plain',
    'verify_certificates' => false,
    'timeout' => 20,
    'active_directory' => false,
    'allow_username_or_email_login' => false,
    'base' => 'dc=example,dc=com',
    'attributes' => {
      'username' => ['mail', 'uid'],
      'email' => ['mail'],
      'name' => 'cn'
    }
  }
}

# Monitoring
prometheus_monitoring['enable'] = false
gitlab_rails['prometheus_address'] = ''

# Logging
gitlab_rails['log_level'] = 'warn'
nginx['error_log_level'] = 'warn'
logging['logrotate_frequency'] = "daily"
logging['logrotate_rotate'] = 7
logging['logrotate_compress'] = "compress"
logging['logrotate_method'] = "copytruncate"

# Security
gitlab_rails['gitlab_signup_enabled'] = false

# Resources
puma['worker_processes'] = 2
puma['min_threads'] = 1
puma['max_threads'] = 4
sidekiq['concurrency'] = 5
gitlab_kas['enable'] = false
