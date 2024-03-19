# All step to install zabbix in ubuntu 20.04 with mysql and apache

1. Install Zabbix repository

```sh
sudo wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu20.04_all.deb
sudo dpkg -i zabbix-release_6.4-1+ubuntu20.04_all.deb
sudo apt update
```
2.Install Zabbix server, frontend, agent
```sh
sudo apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
```

3. Install Mysql
    - install mysql
    ```sh
    sudo apt update
    sudo apt install mysql-server
    sudo systemctl start mysql.service
    ```
    - config mysql
    ```sh
    sudo mysql
    ```
- The following example changes the authentication method to mysql_native_password:
```sh 
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '(the blank to type your password for mysql)';
exit;
```
- check permission access to mysql by root account:
```sh
mysql -u root -p
```
when you type above script then You need to type in the password you just created above.
- Then go back to using the default authentication method using this command:
```sh
ALTER USER 'root'@'localhost' IDENTIFIED WITH auth_socket;
```
4. Create initial database
```sh
mysql -u root -p
```
```sh
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by '(the blank to type your password for mysql)';
grant all privileges on zabbix.* to zabbix@localhost;
set global log_bin_trust_function_creators = 1;
exit;
```
- On Zabbix server host import initial schema and data
```sh
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p zabbix
```
- Disable log_bin_trust_function_creators option after importing database schema.
```sh
mysql -uroot -p
```
```sh
set global log_bin_trust_function_creators = 0;
exit;
```
5.Configure the database for Zabbix server

- Edit file /etc/zabbix/zabbix_server.conf >> DBPassword=(your password for mysql)

6. Start Zabbix server and agent processes
```sh
	sudo systemctl restart zabbix-server zabbix-agent apache2
	sudo systemctl enable zabbix-server zabbix-agent apache2
```
7.Open Zabbix UI web page
*The default URL for Zabbix UI when using Apache web server is http://your server IP/zabbix