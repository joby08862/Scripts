#!/bin/bash

DATA_DIR=/data/mysql_data
VERSION='mysql-5.7.23'
SOURCE_DIR=/data/install_mysql
LOG_DIR=/data/logs
BIN=/data/mysql_bin


install_mysql(){
        
        mkdir -p /data/mysql_logs/logs1
        mkdir -p /data/mysql_logs/logs2
        mkdir -p /data/mysql_data/mysql1
        mkdir -p /data/mysql_data/mysql2
         
        yum install cmake make gcc gcc-c++  ncurses-devel bison-devel -y
        
        id mysql &>/dev/null
        if [ $? -ne 0 ];then
                useradd mysql -s /sbin/nologin -M
        fi
        
        chown -R mysql:mysql ${BIN}
        chown -R mysql:mysql ${LOG_DIR}
        chown -R mysql:mysql ${DATA_DIR}
        cd $SOURCE_DIR
        tar zxvf $VERSION.tar.gz
        mv /data/install_mysql/$VERSION /data/mysql_bin

        if [ -d '/data/mysql_logs' ];then
            touch ${LOG_DIR}/logs1/mysqld.log
            touch ${LOG_DIR}/logs2/mysqld.log
            chown -R mysql:mysql ${LOG_DIR}/logs1/mysqld.log
            chown -R mysql:mysql ${LOG_DIR}/logs2/mysqld.log
        else
            echo "No logs directory and mysqld.log file!"
            exit $?
        fi
        chown -R mysql:mysql ${DATA_DIR}
        rm -rf ${DATA_DIR}/mysql1/*
        rm -rf ${DATA_DIR}/mysql2/*

        #add path
        echo "export PATH=$PATH:$INSTALL_DIR/bin" >> /etc/profile
        source /etc/profile
        
        #初始化实例
        /data/mysql_bin/bin/mysqld --initialize --basedir=$INSTALL_DIR --datadir=${DATA_DIR}/mysql1 --user=mysql
        /data/mysql_bin/bin/mysqld --initialize --basedir=$INSTALL_DIR --datadir=${DATA_DIR}/mysql2 --user=mysql

        #mysqld --defaults-file=/etc/3306.cnf --initialize-insecure --user=mysql
        #mysqld --defaults-file=/etc/3307.cnf --initialize-insecure --user=mysql
        
        #启动多实例
        mysqld_multi --defaults-extra-file=/etc/my.cnf start 1-2
        
        #修改root密码
        PASSWD="Lu3thum"
        tmp_passwd1=`grep 'A temporary password' "${LOG_DIR}/log1/mysqld.log" |awk -F: '{print $NF}'`
        tmp_passwd2=`grep 'A temporary password' "${LOG_DIR}/log2/mysqld.log" |awk -F: '{print $NF}'`
        mysql -uroot -p"$tmp_passwd1"  --connect-expired-password -D mysql -e "alter user root@'localhost' identified by '"$PASSWD"'"  
        mysql -uroot -p"$tmp_passwd2"  --connect-expired-password -D mysql -e "alter user root@'localhost' identified by '"$PASSWD"'"  
      
        #mysqladmin -uroot password "${PASSWD}" -P3306 -h127.0.0.1
        #mysqladmin -uroot password "${PASSWD}" -P3307 -h127.0.0.1

        
        mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "GRANT SHUTDOWN ON *.* TO root@localhost IDENTIFIED BY 'Lu3thum';"
        mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "flush privileges;"
        mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "GRANT SHUTDOWN ON *.* TO root@localhost IDENTIFIED BY 'Lu3thum';"
        mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "flush privileges;"
        mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "grant replication slave on *.* to 'slave3306'@'127.0.0.1' identified by 'gogo3306';"
        str1=$(mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "show master status\G"|grep "File";)
        binlogM=${str1#*: }
        str2=$(mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "show master status\G"|grep "Position";)
        PostionM=${str2#*: }

        mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "change master to master_host='127.0.0.1',master_port=3306,master_user='slave3306',master_password='gogo3306',master_log_file='"$binlogM"', master_log_pos="$PostionM";" 
        mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "start slave;"
                 
}

install_mysql
