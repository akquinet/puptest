# Puptest General Information and Workflow

Puptest brings testing of puppet catalogues to a new level. It tests if updates in your modules and in your nodes cause node definitions to fail. Puptest runs integration tests (all modules in a certain version together with all node definitions) in an automated, parallelized manner. Puptest helps you to ensure that your changes do not destroy parts of your infrastructure just because a certain combination of module versions may have unintended side effects or a module itself contains a bug which was not detected during module testing according to http://docs.puppetlabs.com/guides/tests_smoke.html.

So far, Puptest only supports KVM as its virtualization backbone and Git as its SCM backbone. Anyone who would like to help structuring the project and implementing other virtualization engines or SCM backbones, please open a pull request and/or an issue. 

Puptest integrates Puppet, librarian-puppet, Git, KVM and a CI-Server of your choice (e.g. Jenkins) into a Framework, that supports parallelized evaluation of changes that affect node definitions directly and/or inidirectly. If all changes are tested successfully, Puptest will promote the changes by tagging the tested git commit and writing a change history into an orphan branch inside the tested Puppetmaster Git-Repository.

The following image shows the resulting QA-workflow if you integrate Puptest with Git, KVM and a CI-Server:

<img src="https://raw.githubusercontent.com/saheba/puptest/master/img/how_it_works.png" />


# Installation and Configuration of Puptest

## on your kvm host

### libvirt installation
install the minimally required version of libvirt which puptest depends on:
```shell
## as root

## on rhel/centos/fedora
yum -y install libxml2 libxml2-devel device-mapper-libs device-mapper-devel libpciaccess-devel libcurl-devel python-devel libnl-devel gcc
yum -y install libvirt python-virtinst
## on debian/ubuntu
apt-get install libxml2 libxml2-dev libdevmapper-dev libcurl4-openssl-dev libcurl4 python-dev libnl-dev gcc
apt-get install libvirt-bin virtinst

## now that we have all the compilation and runtime dependencies, we can upgrade libvirt i.e. libvirt-bin:
wget http://libvirt.org/sources/libvirt-1.0.6.tar.gz
tar xzf libvirt-1.0.6.tar.gz
cd libvirt-1.0.6
./configure --prefix=/usr --localstatedir=/var \
--sysconfdir=/etc --with-esx=yes
make
make install

## on rhel/centos/fedora you need to update the ld cache afterwards
ldconfig
```

your compilation and installation was successful, when:
```shell
virsh --version
```
returns 1.0.6.

### base vm setup and configuration
setup the base vm and the vm pool which will be used by puptest:
```shell
virsh pool-define-as puptest dir --target /opt/kvm
virsh pool-start puptest
virsh pool-autostart puptest
cd /opt/kvm

## cloning the base vm sample repository into your vm pool
git clone https://github.com/saheba/puptest_base_vm_sample.git
cd puptest_base_vm_sample
unzip puptest_base_vm_sample.zip
```

adjust path in the xml definition to your pool path (if it is not /opt/kvm, e.g. if you cloned the sample repository it is: /opt/kvm/puptest_base_vm_sample) and if you are on rhel/centos/fedora, replace '/usr/bin/kvm' with '/usr/libexec/qemu-kvm' and 'pc-1.1' with 'pc' inside the xml definition (for details about this see: http://serverfault.com/questions/358252/error-internal-error-process-exited-while-connecting-to-monitor-supported-mach)

then add the base vm to virsh:
```shell
virsh define /opt/kvm/puptest_base_vm_sample/puptest_base.xml
```

## on your puppetmaster

### install git
```shell
yum install git
## or on debian systems
apt-get install git
```

make sure that your git is at least on version 1.7.10.4 and at max 1.8.2.3 by running 'git --version'. If it is not (this is probably the case on rhel and centos systems), install it from source:
```shell
wget https://www.kernel.org/pub/software/scm/git/git-1.8.2.3.tar.gz
tar xzf git-1.8.2.3.tar.gz
cd git-1.8.2.3
./configure
make
make prefix=/usr install
git --version
## should give the following output
git version 1.8.2.3
```
Please open a pull request, when you successfully used Puptest with a git version newer than 1.8.2.3. So far, only the versions 1.7.10.4 and 1.8.2.3 have been tested successfully.

### install puppet server
for instructions see: http://docs.puppetlabs.com/guides/install_puppet/pre_install.html#next-install-puppet

you have to make /etc/puppet a git repository and push it to a remote/a git server from which Puptest will later pull changes, analyse them with test runs and in which puptest will promote the changes

#### replace /etc/puppet directory with sample git repository
it is highly recommended to configure your own puppet server based on the sample puppet repository to get things up and running before you later add puppet security (e.g. set autosign back to false). 

```shell
##as root
/etc/init.d/puppetmaster stop
mv /etc/puppet /etc/puppet-backup
git clone https://github.com/saheba/puppetmaster-sample.git /etc/puppet
cd /etc/puppet
git remote rm origin
git remote add origin YOUR_GIT_SERVER/YOUR_REPO.git
git push --all
/etc/init.d/puppetmaster start
```

### configure puppetmaster as a jenkins slave
for instructions see:
https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds#Distributedbuilds-Differentwaysofstartingslaveagents

the user account you use to let your jenkins execute jobs on your puppetmaster will be called CI-user in the following steps

### add CI-user to sudoers
ci	ALL=(ALL) 	ALL

### install rvm and ruby
The following steps are a multi-user installation of rvm and ruby according to the detailed installation instructions at: http://rvm.io/rvm/install

```shell
su - ci
## as CI-user
\curl -sSL https://get.rvm.io | sudo bash -s stable --ruby
exit
## now you are root again to allow CI-user to install gems
usermod -aG rvm ci
## and to set the default system ruby version to the default rvm ruby version
mv /usr/bin/ruby /usr/bin/ruby-syspkg
ln -s /usr/local/rvm/rubies/default/bin/ruby /usr/bin/ruby
## to check the puppetmaster still works with the new ruby version, run:
/etc/init.d/puppetmaster restart

## check everything went well with
su - ci
which ruby
## this command should print out the latest stable release version of ruby (2.1.1)
groups | grep rvm
## this command should return 'rvm' as its result
```

### as the CI-user: install dependencies of puptest

If you get error messages during the following steps, please make sure that the CI-user is in the group 'rvm'.

```shell
## as root
## IMPORTANT: perform the same libvirt-installation as you did on your kvm host

gem install librarian-puppet json puppet inifile thor
git clone https://github.com/saheba/ruby-git.git
cd ruby-git
git checkout multiple_merges
gem build git.gemspec
gem install git-1.2.6.2.gem

## as ci: do not forget to set git global username and email:
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### as the CI-user: install puptest
```shell
git clone https://github.com/saheba/puptest.git
cd puptest
gem build puptest.gemspec
```

The last lines of the build output should look like this:
```shell
Successfully built RubyGem
  Name: puptest
  Version: 0.0.1
  File: puptest-0.0.1.gem
```

You can then go ahead and install the puptest gem:
```shell
gem install puptest-0.0.1.gem
```

If you run:
```shell
puptest
```
you should get the following output now:
```shell
Commands:
  puptest audit -m, --pp-conf-file=PP_CONF_FILE -t, --conf-file=CONF_FILE  # ...
  puptest help [COMMAND]                                                   # ...

```

### as the CI-user: configure puptest
the CI-user needs read and write permissions inside /etc/puppet:
```shell
## as root
chgrp -R ci /etc/puppet
chmod -R 775 /etc/puppet
## this changes the repository, so you have to push these changes to your remote:
cd /etc/puppet
git commit -a -m "permissions for ci set"
git push --all
```

```shell
cd /etc
mkdir puptest
cd puptest
wget https://raw.githubusercontent.com/saheba/puptest/master/test/puptest.conf
wget https://raw.githubusercontent.com/saheba/puptest/master/test/vmpool/puptest-base_rsa.pub
wget https://raw.githubusercontent.com/saheba/puptest/master/test/vmpool/puptest-base_rsa
```

Inside /etc/puptest/puptest.conf change:
- the repo_url to your puppetmaster git repository containing your manifests, your puppet.conf, templates, etc.
- the vm_host_url if your puppetmaster is on a separate system than your virtualization environment, the default value localhost has to be changed to the ip or url of your virtualization host
- the pool_vm_identity_file to /etc/puptest/puptest-base_rsa if you use the standard puptest_base vm or to the rsa private key file you referenced in /root/.ssh/authorized_keys in your own puptest_base vm.
- the vol_pool_path to the directory that you have defined as your kvm pool 

on your virtualization host:
start the puptest_base vm and change the callback_server url from 192.168.122.1 inside /etc/pptconnect.rb to your puppetmaster ip or url. The credentials of the sample vm are: root, pw: puptest-base .
Also if you have set up your own base vm make sure, that
1) you have placed the small callback client script https://raw.githubusercontent.com/saheba/puptest/master/test/vmpool/puppet-base_etc_pptconnect.rb under /etc/pptconnect.rb:
```shell
server_ip = segments[0]+'.'+segments[1]+'.'+segments[2]+'.1'
server_ip = 'your.puppetmaster.domain'
```

and 2) you have added the following line at the end of /etc/rc.local in your base vm:
```shell
/usr/bin/ruby /etc/pptconnect.rb
```