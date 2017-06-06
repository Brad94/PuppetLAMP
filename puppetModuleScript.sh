cd /etc/puppet/modules
sudo mkdir apache #module name

cd apache
sudo mkdir {manifests,templates,files,examples}

cd manifests

cat <<EOT >> init.pp
class apache (
  $updatesys    = $::apache::params::updatesys,
  $apachename   = $::apache::params::apachename, #we need to call the params.pp file and the parameters into init.pp
  $conffile   = $::apache::params::conffile,
  $confsource = $::apache::params::confsource,
) inherits ::apache::params {

  exec { 'update system':
    command   => $updatesys,
    path      => '/usr/bin'
  }

  package { 'apache':
    name    => $apachename, #individual distro apache package names
    ensure  => present,
  }

  file { 'configuration-file':
    path    => $conffile,
    ensure  => file,
    source  => $confsource,
    notify  => Service['apache-service'], #Apache needs to restart
  }

  service { 'apache-service':
    name    => $apachename,
    hasrestart    => true,
  }

}
EOT

cat <<EOT >> params.pp
class apache::params {

  if $::osfamily == 'RedHat' { #checks which distro it is and gets the applicable apache package name
    $apachename     = 'httpd'
    $conffile       = '/etc/httpd/conf/httpd.conf' #path to httpd.conf
    $confsource     = 'puppet:///modules/apache/httpd.conf'
  } elsif $::osfamily == 'Debian' {
    $apachename     = 'apache2'
    $conffile       = '/etc/apache2/apache2.conf' #path to apache.conf
    $confsource     = 'puppet:///modules/apache/apache2.conf'
  } else {
    print "This is not a supported distro."
  }

}
EOT
cp httpd.conf /etc/puppet/modules/apache/files #copy httpd.conf and apache.conf to /etc/puppet/modules/apache/files/
cp apache.conf /etc/puppet/modules/apache/files
#Both files have been edited to turn KeepAlive settings to Off. This setting has been to httpd.conf.

cat <<EOT >> vhosts.pp 
class apache::vhosts {
        
  if $::osfamily == 'RedHat' {
    file { '/etc/httpd/conf.d/vhost.conf':
      ensure    => file,
      content   => template('apache/vhosts-rh.conf.erb'),
    }
    file { "/var/www/$servername":
      ensure    => directory,
    }
    file { "/var/www/$servername/public_html":
      ensure    => directory,
    }
    file { "/var/www/$servername/log":
    ensure    => directory,
    }
        
  } elsif $::osfamily == 'Debian' {
    file { "/etc/apache2/sites-available/$servername.conf":
      ensure  => file,
      content  => template('apache/vhosts-deb.conf.erb'),
    }
    file { "/var/www/$servername":
      ensure    => directory,
    }
    file { "/var/www/html/$servername/public_html":
      ensure    => directory,
    }
    file { "/var/www/html/$servername/logs":
      ensure    => directory,
    }
  } else {
    print "This is not a supported distro."
  }
        
}
EOT

cd /etc/puppet/modules/apache/templates/

cat <<EOT >> vhosts-rh.conf.erb #RedHat vhosts
<VirtualHost *:80>
    ServerAdmin <%= @adminemail %>
    ServerName <%= @servername %>
    ServerAlias www.<%= @servername %>
    DocumentRoot /var/www/<%= @servername -%>/public_html/
    ErrorLog /var/www/<%- @servername -%>/logs/error.log
    CustomLog /var/www/<%= @servername -%>/logs/access.log combined
</Virtual Host>
EOT

cat <<EOT >> vhosts-deb.conf.erb #Debian vhosts
<VirtualHost *:80>
    ServerAdmin <%= @adminemail %>
    ServerName <%= @servername %>
    ServerAlias www.<%= @servername %>
    DocumentRoot /var/www/html/<%= @servername -%>/public_html/
    ErrorLog /var/www/html/<%- @servername -%>/logs/error.log
    CustomLog /var/www/html/<%= @servername -%>/logs/access.log combined
    <Directory /var/www/html/<%= @servername -%>/public_html>
        Require all granted
    </Directory>
</Virtual Host>
EOT

cd /etc/puppet/modules/apache/manifests/

sudo puppet parser validate init.pp params.pp vhosts.pp #check if any errors

cd /etc/puppet/modules/apache/examples/

cat <<EOT >> init.pp
$serveremail = 'webmaster@example.com'
$servername = 'example.com'
        
include apache
include apache::vhosts
EOT

sudo puppet apply --noop init.pp #Test run the module

cd /etc/puppet/manifests/

cat <<EOT >> site.pp
node 'ubuntuhost.example.com' {
  $adminemail = 'webmaster@example.com'
  $servername = 'hostname.example.com'
        
  include accounts
  include apache
  include apache::vhosts
        
  resources { 'firewall':
    purge => true,
  }
        
  Firewall {
    before        => Class['firewall::post'],
    require       => Class['firewall::pre'],
  }
        
  class { ['firewall::pre', 'firewall::post']: }
        
  }

node 'centoshost.example.com' {
  $adminemail = 'webmaster@example.com'
  $servername = 'hostname.example.com'
        
  include accounts
  include apache
  include apache::vhosts
        
  resources { 'firewall':
    purge => true,
  }
        
  Firewall {
    before        => Class['firewall::post'],
    require       => Class['firewall::pre'],
  }
        
  class { ['firewall::pre', 'firewall::post']: }
        
  }
EOT

sudo puppet agent -t

sudo puppet module install puppetlabs-mysql #Download MySQL from PuppetLabs

cd /etc/puppet/

cat <<EOT >> hiera.yaml
:backends: #defines that you are writing data in YAML
  - yaml
:yaml:
  :datadir: /etc/puppet/hieradata #the directory where the Hiera data will be stored.
:hierarchy: #denotes that your data will be saved in files under the node directory as a file named after the node’s FQDN
  - "nodes/%{::fqdn}"
  - common
EOT

cd /etc/puppet/
sudo mkdir -p hieradata/nodes
cd hieradata/nodes
sudo puppet cert list --all
sudo touch {ubuntuhost.example.com.yaml,centoshost.example.com.yaml}
#Use the puppet cert command to list what nodes are available, then create a YAML file for each, using the FQDN as the file’s name:

cat <<EOT >> ubuntuhost.example.com.yaml
databases:
  webdata1:
   user: 'username'
   password: 'password'
   grant: 'ALL'
EOT

cat <<EOT >> centoshost.example.com.yaml
databases:
  webdata2:
   user: 'username'
   password: 'password'
   grant: 'ALL'
EOT

cd /etc/puppet/hieradata/

cat <<EOT >> common.yaml
mysql::server::root_password: 'password'
EOT

cd /etc/puppet/modules/mysql/manifests

cat <<EOT >> database.pp
class mysql::database {

  include mysql::server

  create_resources('mysql::db', hiera_hash('databases'))
}
EOT
#Include include mysql::database within your site.pp file for both nodes.


cd /etc/puppet/modules
sudo mkdir php
cd php
sudo mkdir {files,manifests,examples,templates}

cat <<EOT >> init.pp
class php {
        
  $phpname = $osfamily ? {
    'Debian'    => 'php5',
    'RedHat'    => 'php',
    default     => warning('This distribution is not supported by the PHP module'),
  }
        
  package { 'php':
    name    => $phpname, #As different names per distro
    ensure  => present,
  }
          
  package { 'php-pear':
    ensure  => present,
  }
          
  service { 'php-service': #to ensure that PHP is on and set to start at boot:
    name    => $phpname,
    ensure  => running,
    enable  => true,
  }
        
}
EOT

#Add include php to the hosts in your sites.pp file and run puppet agent -t on your agent nodes to pull in any changes to your servers.