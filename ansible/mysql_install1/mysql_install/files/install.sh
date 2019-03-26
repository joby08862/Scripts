#!/bin/bash

INSTALL_DIR=/data/mysql_bin
Mysql_log=/data/mysql_logs/logs1
DATADIR=/data/mysql_data/mysql1
BOOST_VERSION='boost_1_59_0'
VERSION='mysql-5.7.23'
SOURCE_DIR=/data/install_mysql

#camke install mysql5.7.X
install_mysql(){
     PASSWD='Lu3thum'
        #mkdir -p /data/mysql_bin
        mkdir -p /data/mysql_logs/logs1
        mkdir -p /data/mysql_logs/logs2
        mkdir -p /data/mysql_data/mysql1
        mkdir -p /data/mysql_data/mysql2
        yum install cmake make gcc gcc-c++  ncurses-devel bison-devel -y
        id mysql &>/dev/null
        if [ $? -ne 0 ];then
                useradd mysql -s /sbin/nologin -M
        fi
        chown -R mysql:mysql $INSTALL_DIR
        chown -R mysql:mysql /data/mysql_logs
        chown -R mysql:mysql /data/mysql_data
        cd $SOURCE_DIR
        tar zxvf $BOOST_VERSION.tar.gz
        tar zxvf $VERSION.tar.gz
        mv /data/install_mysql/$VERSION /data/mysql_bin
        cd /data/mysql_bin
        cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
        -DMYSQL_DATADIR=$DATADIR \
        -DMYSQL_UNIX_ADDR=/tmp/mysql.sock1 \
        -DDEFAULT_CHARSET=utf8 \
        -DDEFAULT_COLLATION=utf8_general_ci \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_MYISAM_STORAGE_ENGINE=1 \
        -DWITH_PARTITION_STORAGE_ENGINE=1 \
        -DWITH_BOOST=/data/install_mysql/$BOOST_VERSION \
        -DENABLED_LOCAL_INFILE=1 \
        -DEXTRA_CHARSETS=all

        make -j `grep processor /proc/cpuinfo | wc -l`
        make install
        if [ $? -ne 0 ];then
                echo "install mysql is failed!"
                exit $?
        fi
        sleep 2

        #MySQL initialization and startup
        #cp -p /data/mysql_bin/support-files/mysql.server /etc/init.d/mysqld
        # chmod +x /etc/init.d/mysqld
        if [ -d '/data/mysql_logs' ];then
            touch $Mysql_log/mysqld.log
            touch /data/mysql_logs/logs2/mysqld.log
            chown -R mysql:mysql $Mysql_log/mysqld.log
            chown -R mysql:mysql /data/mysql_logs/logs2/mysqld.log
        else
            echo "No logs directory and mysqld.log file!"
            exit $?
        fi
        chown -R mysql:mysql $DATADIR
        rm -f $DATADIR/*
        rm -f /data/mysql_data/mysql2/*
        #/data/mysql_bin/bin/mysqld --initialize --basedir=$INSTALL_DIR --datadir=$DATADIR --user=mysql
        #/etc/init.d/mysqld start
        cp /data/install_mysql/3306.cnf /etc/
        cp /data/install_mysql/3307.cnf /etc/


        #add path
        echo "export PATH=$PATH:$INSTALL_DIR/bin" >> /etc/profile
        source /etc/profile
        
        #初始化
        mysqld --defaults-file=/etc/3306.cnf --initialize-insecure --user=mysql
        mysqld --defaults-file=/etc/3307.cnf --initialize-insecure --user=mysql
        
        # if [ $? -ne 0 ];then
        #         echo "mysql start is failed!"
        #         exit $?
        #fi
        #chkconfig --add mysqld
        #chkconfig mysqld on
        #root_pass=`grep 'temporary password' $Mysql_log/mysqld.log | awk '{print $11}'`
        #$INSTALL_DIR/bin/mysql --connect-expired-password -uroot -p$root_pass -e "alter user 'root'@'localhost' identified by '$PASSWD';"
        
        #启动
        mysqld_multi --defaults-extra-file=/etc/my.cnf --log=/data/mysql_logs/mult.log start 1-2
        
        #修改root密码
        mysqladmin -uroot password "${PASSWD}" -P3306 -h127.0.0.1
        mysqladmin -uroot password "${PASSWD}" -P3307 -h127.0.0.1

        
        #if [ $? -eq 0 ];then
        #        echo "+---------------------------+"
        #        echo "+------mysql安装完成--------+"
        #        echo "+---------------------------+"
        #fi
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
