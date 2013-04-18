#!/bin/bash
# author: wangkai
# date: 2013-04-06

INSTALL_DIR='/root/opt'
TOOLS_DIR='/opt/deploy/bin'

DEPLOY_GIT='git@github.com:qbox/deploy.git'
OPTOOLS_GIT='git@github.com:qbox/optools.git'
 
function configure_env() {
    echo 'configure_env'
    sed -i 's/^UMASK.*/UMASK 027/g' '/etc/login.defs'
    useradd -s /bin/bash -m /home/qboxserver qboxserver
    chmod a+rx /home/qboxserver
    useradd -s /bin/jenkins_deploy.sh -m build
    mkdir -p "/home/build/{builds, packages}"
    chown build.build -R /home/build/
    apt-get install git
    apt-get install gcc make -y
    apt-get install python-setuptools -y
    easy_install pssh
    easy_install ipython
}
 
function install_puppet() {
    echo 'install_puppet'
    codename=$(lsb_release -c|awk '{print $2}')
    wget -O /tmp/puppetlabs-release-$codename.deb http://apt.puppetlabs.com/puppetlabs-release-$codename.deb
    dpkg -i /tmp/puppetlabs-release-$codename.deb
    apt-get update
    apt-get install -y puppetmaster
    rm -f /tmp/puppetlabs-release-$codename.deb
}
 
function create_stepping_stone() {
    echo 'del old dir ----'
    rm -rf $INSTALL_DIR
    echo 'create new dir ----'
    mkdir -p $INSTALL_DIR/stepping_stone/{bin,etc,logs,share,docs}
    mkdir -p $INSTALL_DIR/stepping_stone/etc/{conf,keys}
    mkdir -p $INSTALL_DIR/stepping_stone/share/deploy_package/
 
    echo 'create deploy ----'
    cd $INSTALL_DIR
    git clone $DEPLOY_GIT
    if [[ $? -ne 0 ]]; then
        echo "git clone deploy failed."
        exit 1
    fi

    echo 'create puppet configure direcoty link ---'
    rm -rf /etc/puppet
    ln -s $INSTALL_DIR/deploy/system/production_puppet/ /etc/puppet
    /etc/init.d/puppetmaster restart
 
    echo 'create deploy for steping_stone ----'
    cd $INSTALL_DIR/stepping_stone/share
    git clone $DEPLOY_GIT
 
    echo 'create optools and builds ----'
    cd $INSTALL_DIR/stepping_stone/share/deploy_package
    git clone $OPTOOLS_GIT
    ln -s /home/build/builds $INSTALL_DIR/stepping_stone/share/deploy_package/builds
 
    echo 'copy stepping_stone tools ----'
    cp -vr $INSTALL_DIR/stepping_stone/share/deploy/system/stepping_stone/* $INSTALL_DIR/stepping_stone/
    chmod 600 -R $INSTALL_DIR/stepping_stone/etc/keys/

    echo 'copy build user shell ----'
    cp -v $INSTALL_DIR/stepping_stone/share/scripts/jenkins_deploy.sh /bin/jenkins_deploy.sh
    chmod a+x /bin/jenkins_deploy.sh

    echo 'install qiniu command (qlogin, qdo, qview, qhistory, qdoc ...) ----'
    mkdir -p $TOOLS_DIR
    chmod a+rx /opt/deploy
    chmod a+rx /opt/deploy/bin
    for pname in "deploy" "do" "view" "history" "doc" "ssh"
    do
        sed "s/PROGRAM_PATH/\/root\/opt\/stepping_stone\/bin\/_$pname/g" $INSTALL_DIR/stepping_stone/share/scripts/c_shell.c > /tmp/t.c
        gcc /tmp/t.c -o /tmp/q$pname
        mv /tmp/q$pname $TOOLS_DIR
        rm -f /tmp/t.c
    done
    chmod a+x $TOOLS_DIR/q*
    chmod u+s $TOOLS_DIR/q*
    sed -i '/export PATH=$PATH:\/opt\/deploy\/bin/d' /etc/profile
    echo "export PATH=\$PATH:$TOOLS_DIR" >> /etc/profile
    source /etc/profile
}
 
function main() {
    configure_env
    install_puppet
    create_stepping_stone
}
 
main
