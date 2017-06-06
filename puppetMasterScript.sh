wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
sudo dpkg -i puppetlabs-release-pc1-trusty.deb
sudo apt-get -y update
sudo apt-get install -y puppetserver
sudo service puppetserver start

sudo /opt/puppetlabs/bin/puppet cert list
sudo /opt/puppetlabs/bin/puppet cert sign [[nameofcertificate]]