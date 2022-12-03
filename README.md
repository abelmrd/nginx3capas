# práctica LEMP en tres capas con balanceador
Con el fin de obtener mayor escalabilidad y funcionalidad,en esta práctica separaremos servidor de nginx, mysql, nfs y balanceador. También obtendremos mayor seguridad y control sobre nuestro entorno de trabajo, poder administrar mejor los picos de trabajo dirigiendo la carga a cualquiera de los dos servidores nginx que tendrán replicado el sitio que implementaremos en el NFS. Utilizaremos este servidor para alojar los datos del sitio web ahi, y dotar de una capa extra de seguridad, además del PHP.

## Primer paso: Vagrant
Generamos un archivo vagrant con vagrant init
Vamos a explicar las líneas que modificamos o añadimos según las necesidades del proyecto


    config.vm.define "servernginx" do |servernginx|

    servernginx.vm.box = "debian/bullseye64"

    servernginx.vm.hostname = "AbelMonNginx"

    servernginx.vm.network "public_network"

    servernginx.vm.network "private_network", ip: "192.168.21.21"

    servernginx.vm.synced_folder "./","/vagrant"

    servernginx.vm.provision "shell", path: "scripte.sh"


* Vamos a definir el servidor como "servernginx". 

* Utilizaremos una debian bullseye.
* Le asignamos el nombre al servidor que nos requiere la práctica. 
* En este servidor añadimos interfaz pública y privada, ya que requiere salida a exterior y también conectarse al equipo MYSQL en red local. Este último servidor solo tendrá la red privada, por tanto, un único adaptador de red, con una ip local 192.168.21.22 /24 .
* En ambos casos definimos como la carpeta compartida la ruta /vagrant
Para dar un entorno listo para comenzar a configurar aprovisionaremos con dos scripts que previamente hemos hecho para ambas máquinas, al estar en la ruta del vagrant con poner el nombre en el path es suficiente.


## Scripts de aprovisionamiento
### Script nginx

```
echo " Actualizamos repositorios y paquetes"

    sudo apt update 
    sudo apt upgrade -y

echo "Instalación de paquetes lemp. Nginx "
      sudo apt -y install nginx 
    sudo systemctl reload nginx
    sudo apt -y install default-mysql-client
    sudo apt -y install nfs-common
    


```

* En este script vamos a actualizar repositorios y paquetes con update y upgrade.
* Instalaremos nginx mostrando algunos mensajes al usuario.
* Instalamos también mysql para conectarnos al servidor
* El módulo PHP-FPM lo instalaremos en NFS y utilizaremos el socket tcp para su funcionamiento. También el php-mysql.
* En el balanceador solamente instalaremos nginx, por lo que usamos este script quitando NFS y PHP.



### Script servidor Mysql

```
echo " Actualizamos paquetes"

    sudo apt update
    sudo apt upgrade -y

echo "Instalación de mysql"
    sudo apt -y install default-mysql-server
    

```
Comentaremos brevemente, ya que todas las líneas del script están comentadas.

* Actualización de paquetes y repositorios
* Instalamos la versión de mysql actual, que previamente buscamos con apt search la versión de nuestro debian.



### Script servidor NFS

```
echo "Instalacion de paquetes NFS"
    
    sudo apt -y install nfs-kernel-server
    sudo apt -y install php-mysql

echo " Instalacion de php"
    sudo apt -y install php-fpm
    

```
Comentaremos brevemente, ya que todas las líneas del script están comentadas.

* Actualización de paquetes y repositorios.
* Instalamos la versión de mysql actual más adecuada para nuestro debian, que previamente buscamos con apt search.
* Instalamos el interprete de php php-fpm y tambien el de sql, ya que esta tarea la haremos por socket tcp-ip y no en local.
* Posteriormente instalaremos otros paquetes php que necesita nuestro cms, como php-mbstring php-gd php-xml..


## Conectividad entre máquinas

Una vez comprobado que se instala todo sin problemas, vamos a realizar un ping entre ambos equipos.
``` Ping 192.168.21.22 ```
Al ejecutar desde nginx y desde nginx2 (192.168.21.21-30) nos da respuesta.

Para mostrarle al servidor Mysql cual es la ip donde tiene que permitir conexiones buscaremos el archivo "50-server.cnf" para cambiar este parámetro por la ip del servidor mysql. 
La ruta será la siguiente:
```
/etc/mysql/mariadb.conf.d/50-server.cnf
```
El parámetro a modificar por la ip de nuestro servidor mysql/mariaDb
```bind-address            = 192.168.21.22```

Podemos conectarnos al servidor mysql para comprobar que hay conexión, aunque lo haremos después una vez modifiquemos la contraseña del administrador.
```
mysql -u abel -p -h 192.168.21.22
```
Todo correcto, es hora de implementar nuestra aplicación.

## Configuración del servidor NFS

Utilizaremos este servidor para alojar los archivos del sitio en un único servidor, teniendo así réplicas exactas y homogéneas de la página alojada.
Este servidor propocionara los datos a los servidores nginx exportando una carpeta donde alojaremos nuestro sitio.
### Pasos para exportar la carpeta

Para comenzar creamos la carpeta que vamos a exportar, en este caso la alojaremos en www/var .

``sudo mkdir /var/www/drupal ``

Una vez hecho esto, vamos a modificar el archivo /etc/exports. Le indicaremos que carpeta y donde queremos compartirlo
y a su vez los permisos que le daremos. El contenido será en mi caso :

``` sudo nano /etc/exports ```

```
var/www/drupal          192.168.20.10(rw,sync,no_subtree_check)
var/www/drupal          192.168.20.11(rw,sync,no_subtree_check)
```

En último lugar reiniciarmos el servicio, y ya tendríamos el servicio funcionando en el servidor, faltaria montar los clientes.

``sudo systemctl restart nfs-kernel-server
``

### Instalacíon de paquetes PHP en NFS

Como comentamos anteriormente, nuestro gestor de contenido necesita instalar varias librerias php para utilizar nuestro CMS Drupal.
Las instalaremos todas, aunque si algunas nos falta en el proceso de instalación nos las solicitará.
```
sudo apt install php-dom
sudo apt install php-gd
sudo apt install php-mbstring
```
También necesitamos crear la carpeta  para poder instalar las traducciones al español, que estará alojada en /sites/default/files/translations

```sudo mkdir /sites/default/files/translations```


## Configuración de los servidores Nginx

El servidor nginx no interpretará el codigo php, por lo que unicamente configuraremos la carpeta de montaje de NFS, el archivo de configuración del sitio y algunos permisos.

- En primer lugar crearemos la carpeta que habiamos montado en el servidor nfs.

`` sudo mkdir /var/www/drupal ``

- Una vez creada procedemos a montar la carpeta

`` sudo mount 192.168.20.13:/var/www/drupal /var/www/drupal ``

- Por último podemos comprobar con df -h que se esta montando el recurso.

### Configuración del sitio
- Generamos un nuevo sitio para nuestro drupal

``nano /etc/nginx/sites-available/drupal``

El contenido sera el siguiente, donde definimos principalmente el socket a utilizar, la ubicación de la carpeta y la seguridad.
```
server {
    listen 80;
    listen [::]:80;
    root /var/www/drupal;
    index  index.php index.html index.htm;
    server_name  _;
    client_max_body_size 100M;
    autoindex off;
    location ~ \..*/.*\.php$ {
        return 403;
    }
    location ~ ^/sites/.*/private/ {
        return 403;
    }
    # Block access to scripts in site files directory
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        try_files $uri /index.php?$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }

    location ~ '\.php$|^/update.php' {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 192.168.20.13:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }
    location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }
}
```
- Una vez aplicada esta configuración, haremos un enlace para activar el sitio.
``ln -s /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/```
- El último paso sera descomentar la linea server_names_hash_bucket_size 64; del archivo /etc/nginx/nginx.conf
- Una vez reiniciado nginx, tenemos acceso a nuestro drupal desde nuestra ip. 

## Implementación de aplicación

#### Pasos para la instalación del gestor de contenido Drupal

1. Descargamos drupal en el servidor NFS y lo descomprimimos con tar
 ``sudo wget https://ftp.drupal.org/files/projects/drupal-8.8.5.tar.gz
    sudo tar -xvzf drupal-8.8.5.tar.gz ``
2. Movemos los archivos de la aplicación a una nueva carpeta creada en /www/var/.
En nuestra práctica será /www/var/drupal.
3. Aplicamos cambio de propietario a www-data

``` sudo chown -R www-data:www-data drupal```


# Add index.php to the list if you are using PHP
        index index.php index.html index.htm index.nginx-debian.html;```
7. Modificamos el dueño de los archivos para dárselos a nginx estando en la ruta de los archivos. ```sudo chown -R www-data.www-data *```
8. Configuramos el archivo config.php para indicarle los parámetros de nuestro usuario y base de datos que tiene que utilizar en la ejecución de la aplicación. Los definimos como abel y 11111111.
9. Reiniciamos nginx
```sudo systemctl restart nginx```

#### Configuración de la base de datos para Drupal
1. Ejecutamos el script mysql_secure_installation para modificar la contraseña de root y dar mayor seguridad.
2. Nos conectamos a la base de datos y creamos la base de datos y el usuario. En este caso sera drupaldb la base de datos, el usuario drupal y la contraseña 11111111. Veamos cuales serian los comandos a ejecutar en mysql.
```CREATE DATABASE drupaldb;```
```CREATE USER 'drupal'@'%' IDENTIFIED BY '11111111';```
2. Le damos todos los privilegios al usuario y actualizamos privilegios .
```GRANT ALL PRIVILEGES ON *drupaldb.* TO 'drupal'@'%'`;```
```FLUSH PRIVILEGES;```


Nota: lo ideal en una situación real sería proporcionar acceso sólo a los host que realmente tienen permiso para acceder a esta base de datos, que podríamos especificarlo con 'drupal'@'host'. Como vamos a implementarlo de modo local no es necesario hilar tan fino.







Cambiamos los permisos para darle acceso completo a nginx
chown -R www-data:www-data drupal










## Creación de balanceador de carga

La configuración del servidor que actuara como balanceador, será nuestro frontal, por tanto, el único servidor visible de cara al usuario final. Para acceder a nuestros sitios web de nginx lo harán a través de esta ip.
La configuración es sencilla, solo debemos configurar el archivo default de sites-available e implementar las siguientes líneas, o bien borrarlo y crear uno nuevo con este contenido:

```      
upstream backend {

 server 192.168.20.10;
 server 192.168.20.11;
}

server {


        location / {
        proxy_pass http://backend;
        }
}
```

### Contenido del archivo y algoritmo 

Lo podemos resumir como el archivo donde indicamos que servidores son los que tienen el sitio web, los cuales debe balancear.
Ponemos las dos líneas de nuestros dos servidores. Le ponemos de nombre backend, por tanto, el proxy pass será el mismo.
En este caso no definimos el orden que el balanceador tendrá a la hora de dirigir las peticiones del servidor.
Por defecto utilizara el algoritmo round robin, que alternativamente va enviando cada petición a uno diferente de forma equitativa.
En esta práctica he cambiado el contenido de la aplicación, añadiendo un "1" y un "2" en el texto "DEMO APP" en los distintos servidores, por lo que a la hora de actualizar podemos ver como aplica esta regla y cada vez nos muestra un servidor diferente sin tener en cuenta la cantidad de peticiones, saturación o cualquier otro algoritmo.