wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
sudo dpkg -i puppetlabs-release-pc1-trusty.deb
sudo apt-get -y update
sudo apt-get install -y puppet-agent
echo '52.30.70.51 puppet' >> /etc/hosts #change IP to current master IP
sudo /opt/puppetlabs/bin/puppet agent --test

puppet agent --configprint runinterval


#https://www.theregister.co.uk/2016/02/09/puppet_getting_hold_of_the_strings/?page=1