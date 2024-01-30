FROM centos:7

ENV NAGIOS_VERSION=4.5.0 \
    PLUGINS_VERSION=2.4.7 \
    NRDP_VERSION=2.0.5 \
    ADMINUSER=nagiosadmin \
    ADMINPASS=nagios \
    NRDP_TOKEN=testtoken

# Install nagios and nagios plugins dependencies
RUN yum update -y
RUN yum install -y gcc glibc glibc-common wget unzip httpd php gd gd-devel perl postfix openssl-devel make

WORKDIR /tmp

# Download nagios source
RUN wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz && \
    tar xzf nagioscore.tar.gz

WORKDIR /tmp/nagioscore-nagios-${NAGIOS_VERSION}/

# compile
RUN ./configure
RUN make all

# Create user and group
RUN make install-groups-users && \
    usermod -a -G nagios apache

#Install Binaries, HTML, and CGIs files
RUN make install && \
    make install-daemoninit && \
    systemctl enable httpd.service && \
    make install-commandmode && \
    make install-config && \
    make install-webconf

# Create nagios user account
RUN htpasswd -b -c /usr/local/nagios/etc/htpasswd.users ${ADMINUSER} ${ADMINPASS}

RUN yum install -y gcc glibc glibc-common make gettext automake autoconf wget openssl-devel net-snmp net-snmp-utils epel-release
RUN yum install -y perl-Net-SNMP

WORKDIR /tmp

# Download nagios pluguin source
RUN wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-${PLUGINS_VERSION}.tar.gz && \
tar zxf nagios-plugins.tar.gz

WORKDIR /tmp/nagios-plugins-release-${PLUGINS_VERSION}/

# Compile and install
RUN ./tools/setup && \
    ./configure && \
    make && \
    make install

#Installing NRDP
WORKDIR /tmp
RUN wget -O nrdp.tar.gz https://github.com/NagiosEnterprises/nrdp/archive/${NRDP_VERSION}.tar.gz && \
    tar xzf nrdp.tar.gz && \
    cd /tmp/nrdp-${NRDP_VERSION}/ && \
    mkdir -p /usr/local/nrdp && \
    cp -r clients server LICENSE* CHANGES* /usr/local/nrdp && \
    chown -R nagios:nagios /usr/local/nrdp && \
    cp nrdp.conf /etc/httpd/conf.d/ && \
    sed -i "s#//\"mysecrettoken\",.*#\t\"${NRDP_TOKEN}\",#g" /usr/local/nrdp/server/config.inc.php

# Copy start services scripts
COPY start.sh /nagios/start.sh

CMD ["/bin/bash", "/nagios/start.sh"]
