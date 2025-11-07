# The MySQL ODBC Driver includes the `myodbc-installer` utility also
# This is useful for installing other drivers besides MySQL's

# Turnkey installation for MySQL's ODBC driver is available for Red Hat
# Linux, but not Debian.  We follow the tarball installation method:
#
# https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-installation-binary-unix-tarball.html
#

sudo apt install libodbc2  # for getting libodbc.so.2

export MYODBC_DOWNLOAD=mysql-connector-odbc-8.0.17-linux-debian10-x86-64bit
export MYODBC_VERSION=8.0
export MYODBC_FILE=libmyodbc8w.so


wget https://dev.mysql.com/get/Downloads/Connector-ODBC/${MYODBC_VERSION}/${MYODBC_DOWNLOAD}.tar.gz
gunzip ${MYODBC_DOWNLOAD}.tar.gz
tar xvf ${MYODBC_DOWNLOAD}.tar

sudo cp ${MYODBC_DOWNLOAD}/bin/* /usr/local/bin
sudo cp ${MYODBC_DOWNLOAD}/lib/* /usr/local/lib
