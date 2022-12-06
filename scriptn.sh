echo " Actualizamos repositorios y paquetes"

    sudo apt update 
    sudo apt upgrade -y

echo "Instalacion de paquetes NFS"
    
    sudo apt -y install nfs-kernel-server

echo " Instalacion de php"
    sudo apt -y install php-fpm
    sudo apt -y install php-mysql

   # sudo mount 192.168.20.13:/var/www/joomla /var/www/joomla

    #sudo apt -y install phpmyadmin php-mbstring php-zip php-gd php-json php-curl php-intl php-soap php-xml php-xmlrpc
    #instalamos adminer y lo movemos al www
 #sudo wget https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1-mysql.php
 #sudo find / -type f -name *adminer* -exec mv {} /var/www/adminer.php \; 




#echo "Instalamos git"

    sudo apt -y install git



