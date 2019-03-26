#!/bin/bash

DATA_DIR=/data/mysql_data
VERSION='mysql-5.7.18-linux-glibc2.5-x86_64'
SOURCE_DIR=/data/install_mysql
LOG_DIR=/data/mysql_logs
BIN=/data/mysql_bin


install_mysql(){
        
        mkdir -p ${LOG_DIR}/logs1
        mkdir -p ${LOG_DIR}/logs2
        mkdir -p ${DATA_DIR}/mysql1
        mkdir -p ${DATA_DIR}/mysql2
         
        yum install cmake make gcc gcc-c++  ncurses-devel bison-devel -y
        
        id mysql &>/dev/null
        if [ $? -ne 0 ];then
                useradd mysql -s /sbin/nologin -M
        fi
        
        #chown -R mysql:mysql ${BIN}
        chown -R mysql:mysql ${LOG_DIR}
        chown -R mysql:mysql ${DATA_DIR}
        cd $SOURCE_DIR
        tar zxvf $VERSION.tar.gz
        mv ${SOURCE_DIR}/$VERSION ${BIN}
        chown -R mysql:mysql ${BIN}
            
        touch ${LOG_DIR}/logs1/mysqld.log
        touch ${LOG_DIR}/logs2/mysqld.log
        chown -R root:mysql ${LOG_DIR}/logs1/mysqld.log
        chown -R root:mysql ${LOG_DIR}/logs2/mysqld.log
        chmod +w ${LOG_DIR}/logs1/mysqld.log
        chmod +w ${LOG_DIR}/logs2/mysqld.log
        chown -R mysql:mysql ${DATA_DIR}
        rm -rf ${DATA_DIR}/mysql1/*
        rm -rf ${DATA_DIR}/mysql2/*

        #add path
        cat /etc/profile | grep "${BIN}/bin"
        if [[ $? -ne 0 ]];then
          echo "export PATH=$PATH:$BIN/bin" >> /etc/profile
          source /etc/profile
        fi
 
        #初始化实例
        ${BIN}/bin/mysqld --initialize --basedir=$BIN --datadir=${DATA_DIR}/mysql1 --user=mysql &>> ${LOG_DIR}/logs1/mysqld.log
        ${BIN}/bin/mysqld --initialize --basedir=$BIN --datadir=${DATA_DIR}/mysql2 --user=mysql &>> ${LOG_DIR}/logs2/mysqld.log

        #mysqld --defaults-file=/etc/3306.cnf --initialize-insecure --user=mysql
        #mysqld --defaults-file=/etc/3307.cnf --initialize-insecure --user=mysql
        
        #启动多实例
        ${BIN}/bin/mysqld_multi --defaults-extra-file=/etc/my.cnf start 1-2
        
        #修改root密码
        #PASSWD="Lu3thum"
        #tmp_passwd1=`grep 'A temporary password' "${LOG_DIR}/logs1/mysqld.log" |awk -F: '{print $NF}'`
        #tmp_passwd2=`grep 'A temporary password' "${LOG_DIR}/logs2/mysqld.log" |awk -F: '{print $NF}'`
        #p1=`echo ${tmp_passwd1} |sed s/\t//g`
        #p2=`echo ${tmp_passwd2} |sed s/\t//g`
        #${BIN}/bin/mysql -uroot -p"$p1" -S /tmp/mysql.sock1 --connect-expired-password -D mysql -e "alter user root@'localhost' identified by '"$PASSWD"'"  
        #${BIN}/bin/mysql -uroot -p"$p2" -S /tmp/mysql.sock2 --connect-expired-password -D mysql -e "alter user root@'localhost' identified by '"$PASSWD"'"  
        sleep 10
        mysqladmin -uroot password "${PASSWD}" -P3306 -h127.0.0.1
        mysqladmin -uroot password "${PASSWD}" -P3307 -h127.0.0.1

        
        ${BIN}/bin/mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "GRANT SHUTDOWN ON *.* TO root@localhost IDENTIFIED BY 'Lu3thum';"
        ${BIN}/bin/mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "flush privileges;"
        ${BIN}/bin/mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "GRANT SHUTDOWN ON *.* TO root@localhost IDENTIFIED BY 'Lu3thum';"
        ${BIN}/bin/mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "flush privileges;"
        ${BIN}/bin/mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "grant replication slave on *.* to 'slave3306'@'127.0.0.1' identified by 'gogo3306';"
        str1=$(/data/mysql_bin/bin/mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "show master status\G"|grep "File";)
        binlogM=${str1#*: }
        str2=$(/data/mysql_bin/bin/mysql -h127.0.0.1 -P3306 -uroot -pLu3thum -e "show master status\G"|grep "Position";)
        PostionM=${str2#*: }

        ${BIN}/bin/mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "change master to master_host='127.0.0.1',master_port=3306,master_user='slave3306',master_password='gogo3306',master_log_file='"$binlogM"', master_log_pos="$PostionM";" 
        ${BIN}/bin/mysql -h127.0.0.1 -P3307 -uroot -pLu3thum -e "start slave;"
                 
}

install_mysql
