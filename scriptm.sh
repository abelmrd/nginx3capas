echo " Actualizamos paquetes"

    sudo apt update
    sudo apt upgrade -y

echo "Instalacion de mysql"
    sudo apt -y install default-mysql-server
    

# Definimos variables para la creacion de usuario mysql

        #usuariodb="abel"
        #passdb="11111111"
############################

#echo "Crear usuario para MYSQL y modificar password de root"


# modificamos root del servidor para ponerle la pass 1234
#sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';"
# damos todos los privilegios a root desde cualquier ip

#sudo mysql -u root <<EOF
#alter user 'root'@'localhost' identified by '1234'
#EOF
#sudo mysql -u root -e "CREATE USER '$usuariodb'@'192.168.21.21' IDENTIFIED BY '$passdb';"
#creamos el usuario que definimos en variable 
#sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$usuariodb'@'192.168.21.21';"
# le damos todos los permisos a este user en la ip del apache
#sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '1234';"
#sudo mysql -u root -e "FLUSH PRIVILEGES;"
#sudo systemctl reload mysql-server

#sudo ip route del default
#sudo ip route add default via 172.17.10.1