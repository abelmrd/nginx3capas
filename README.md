![](imagenes/portada.PNG)






# Índice
  
1. [Objetivo](#id1)
2. [Configuración Vagrant](#id2)
3. [Script de aprovisionamiento](#id3)
    1. [Script Nginx](#id4)
    2. [Script Mysql](#id5)
    3. [Script NFS](#id6)
4. [Pruebas de conectividad](#id7)
5. [Configuración servidor NFS](#id8)
    1. [Exportar carpeta](#id9)
    2. [Paquetes PHP](#id10)
6. [Configuración servidor MYSQL](#id11)
7. [Configuración servidor Nginx](#id12)
    1. [Configuración del sitio](#id13)
8. [Implementación de la aplicación](#id14)
9. [Balanceador de carga](#id15)
10. [Servidor en modo seguro](#id16)
11. [Contenido del github](#id17)











# Práctica LEMP en tres capas <a name="id1"></a>
Con el fin de obtener mayor escalabilidad y funcionalidad,en esta práctica separaremos servidor de nginx, mysql, nfs y balanceador. También obtendremos mayor seguridad y control sobre nuestro entorno de trabajo, poder administrar mejor los picos de trabajo dirigiendo la carga a cualquiera de los dos servidores nginx que tendrán replicado el sitio que implementaremos en el NFS. Utilizaremos este servidor para alojar los datos del sitio web ahi, y dotar de una capa extra de seguridad, además del PHP.

Las capas serán:
+ Balanceador, al que accede el usuario
+ Servidor web Nginx y servidor NFS
+ Servidor Mysql

## Primer paso: Vagrant <a name="id2"></a>
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
* En este servidor añadimos interfaz pública para descargar los paquetes. Luego se la quitaremos, solo el balanceador sera visible. Dos privadas para conectarse al equipo MYSQL en red local y al servidor NFS. 
* En ambos casos definimos como la carpeta compartida la ruta /vagrant por si fuera de utilidad.


Para comenzar, cconfiguraremos los aprovisionamientos de los scripts para las cuatro máquinas, al estar en la ruta del vagrant con poner el nombre en el path es suficiente.


## Scripts de aprovisionamiento <a name="id3"></a>
### Script nginx <a name="id4"></a>

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
* Instalamos el cliente de NFS para importar almacenamiento compartido del servidor NFS.
* En el balanceador solamente instalaremos nginx, por lo que usamos este script quitando NFS y PHP.



### Script servidor Mysql <a name="id5"></a>

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
Posteriormente iniciaremos sl script seguro para establecer la contraseña de root.



### Script servidor NFS <a name="id6"></a>

```
echo "Instalación de paquetes NFS"
    
    sudo apt -y install nfs-kernel-server
    sudo apt -y install php-mysql

echo " Instalación de php"
    sudo apt -y install php-fpm
    

```
Comentaremos brevemente, ya que todas las líneas del script están comentadas.

* Actualización de paquetes y repositorios.
* Instalamos la versión de mysql actual más adecuada para nuestro debian, que previamente buscamos con apt search.
* Instalamos el interprete de php php-fpm y también el de sql, ya que esta tarea la haremos por socket tcp-ip y no en local.
* Posteriormente instalaremos otros paquetes php que necesita nuestro cms, como php-mbstring php-gd php-xml..


## Conectividad entre máquinas <a name="id7"></a>

Una vez comprobado que se instala todo sin problemas, vamos a realizar un ping entre ambos equipos.
``` Ping 192.168.21.22 ```
Al ejecutar desde nginx y desde nginx2 (192.168.21.21-30) nos da respuesta.
También probamos la conexión entre el servidor NFS y ambas máquinas de nginx. Con mysql también tendrá conexión, tiene que conectarse
con la base de datos. Al definir el nombre de las redes virtuales, todo queda encapsulado.
Todos los equipos dan ping entre ellos, a excepción del balanceador con mysql que efectivamente no debe dar ping.

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

## Configuración del servidor NFS <a name="id8"></a>

Utilizaremos este servidor para alojar los archivos del sitio en un único servidor, teniendo así réplicas exactas y homogéneas de la página alojada.
Este servidor propocionara los datos a los servidores nginx exportando una carpeta donde alojaremos nuestro sitio.
### Pasos para exportar la carpeta <a name="id9"></a>

Para comenzar creamos la carpeta que vamos a exportar, en este caso la alojaremos en www/var .

``sudo mkdir /var/www/drupal ``

Una vez hecho esto, vamos a modificar el archivo /etc/exports. Le indicaremos que carpeta y donde queremos compartirlo
y a su vez los permisos que le daremos. El contenido será en mi caso :

``` sudo nano /etc/exports ```

```
var/www/drupal          192.168.20.10(rw,sync,no_subtree_check)
var/www/drupal          192.168.20.11(rw,sync,no_subtree_check)
```

En último lugar reiniciaremos el servicio, y ya tendríamos el servicio funcionando en el servidor, faltaría montar los clientes.

``sudo systemctl restart nfs-kernel-server
``

#### Configuración de puerto para php

Editaremos el archivo ubicado en /etc/php/7.4/fpm/pool.d/www.conf para cambiar la directiva listen.
Le pondremos el valor 0.0.0.0:9000 para que escuche cualquier ip por ese puerto, que será el que utilizaremos para 
comunicar las máquinas y que el php sea interpretado por el servidor NFS en lugar del nginx.

``
 sudo nano /etc/php/7.4/fpm/pool.d/www.conf
 listen = 0.0.0.0:9000
``

### Instalacíon de paquetes PHP en NFS <a name="id10"></a>

Como comentamos anteriormente, nuestro gestor de contenido necesita instalar varias librerias php para utilizar nuestro CMS Drupal.
Las instalaremos todas, aunque si alguna nos falta en el proceso de instalación nos las solicitará.
```
sudo apt install php
sudo apt install php-dom
sudo apt install php-gd
sudo apt install php-mbstring
```
También necesitamos crear la carpeta  para poder instalar las traducciones al español, que estará alojada en /sites/default/files/translations

```sudo mkdir /sites/default/files/translations```

## Configuración de la base de datos para Drupal <a name="id11"></a>
1. Ejecutamos el script mysql_secure_installation para modificar la contraseña de root y dar mayor seguridad.
2. Nos conectamos a la base de datos y creamos la base de datos y el usuario. En este caso será drupaldb la base de datos, el usuario drupal y la contraseña 11111111. Veamos cuales serían los comandos a ejecutar en mysql.

```CREATE DATABASE drupaldb;```

```CREATE USER 'drupal'@'%' IDENTIFIED BY '11111111';```

2. Le damos todos los privilegios al usuario y actualizamos privilegios .

```GRANT ALL PRIVILEGES ON *drupaldb.* TO 'drupal'@'%'`;```

```FLUSH PRIVILEGES;```


Nota: lo ideal en una situación real sería proporcionar acceso sólo a los host que realmente tienen permiso para acceder a esta base de datos, que podríamos especificarlo con 'drupal'@'host'. Como vamos a implementarlo de modo local no es necesario hilar tan fino.



## Configuración de los servidores Nginx <a name="id12"></a>

El servidor nginx no interpretará el código php, por lo que únicamente configuraremos la carpeta de montaje de NFS, el archivo de configuración del sitio y algunos permisos.

- En primer lugar, crearemos la carpeta que habíamos montado en el servidor nfs.

`` sudo mkdir /var/www/drupal ``

- Una vez creada procedemos a montar la carpeta

`` sudo mount 192.168.20.13:/var/www/drupal /var/www/drupal ``

- Por último podemos comprobar con df -h que se esta montando el recurso.

### Configuración del sitio <a name="id13"></a>
- Generamos un nuevo sitio para nuestro drupal en el servidor nginx

``nano /etc/nginx/sites-available/drupal``

El contenido será el siguiente, donde definimos principalmente el socket a utilizar, la ubicación de la carpeta y la seguridad.
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

- Comprobamos que la configuración es correcta con el comando ``nginx -t ``
- Una vez aplicada esta configuración, haremos un enlace para activar el sitio. También borraremos el default.

``ln -s /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/``

- El último paso será descomentar la línea server_names_hash_bucket_size 64; del archivo /etc/nginx/nginx.conf
- Una vez hecho, reiniciamos nginx y ya tenemos configurado el sitio para drupal. 

## Implementación de aplicación <a name="id14"></a>

#### Pasos para la instalación del gestor de contenido Drupal

1. Descargamos drupal en el servidor NFS y lo descomprimimos con tar

 ``sudo wget https://ftp.drupal.org/files/projects/drupal-8.8.5.tar.gz``

   `` sudo tar -xvzf drupal-8.8.5.tar.gz ``

2. Movemos los archivos de la aplicación a una nueva carpeta creada en /www/var/.
En nuestra práctica será /www/var/drupal.

``mv * /var/www/drupal``

3. Aplicamos cambio de propietario a toda la carpeta para dar permisos a nginx.

``` sudo chown -R www-data:www-data drupal```

4. Reiniciamos nginx
```sudo systemctl restart nginx```

5. Ya podemos acceder por nuestra ip al instalador. 
Habrá que ir rellenando los pasos con la base de datos que anteriormente creamos, el usuario para acceder etc.


## Creación de balanceador de carga <a name="id15"></a>

La configuración del servidor que actuará como balanceador, será nuestro frontal, por tanto, el único servidor visible de cara al usuario final. Para acceder a nuestros sitios web de nginx lo harán a través de esta ip.
La configuración es sencilla, sólo debemos configurar el archivo default de sites-available e implementar las siguientes líneas, o bien borrarlo y crear uno nuevo con este contenido:

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



## Puesta en marcha del modo seguro a nuestra aplicación <a name="id16"></a>

Con esta última y definitiva configuración en el balanceador, tendremos el sistema funcionando en modo cifrado SSL.
El certificado lo generaremos nosotros mismos en local, para un ejemplo real habría que utilizar alguna certificadora como cerftbot.

El comando a utilizar será el siguiente, donde le decimos el nombre que va a generar y también la ruta donde lo va a depositar.

``
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/drupal.key -out /etc/ssl/certs/drupal.pem
``

Definiremos el puerto de escucha como el 443, le indicaremos donde están los certificados generados con el comando anterior
y por último le decimos al servidor que el certificado ha sido verificado.
Por tanto, la configuración del sitio en el balanceador será la siguiente:

```
upstream backend {
 server 192.168.20.10;
 server 192.168.20.11;
}
server {
        listen 80;
        listen [::]:80;
         location / {
        proxy_pass http://backend;
        }
}

server {

listen 443 ssl;
listen [::]:443 ssl;

ssl_certificate     /etc/ssl/certs/drupal.pem;
ssl_certificate_key /etc/ssl/private/drupal.key;

location / {
    proxy_pass                http://backend;
proxy_ssl_trusted_certificate /etc/ssl/private/drupal.key;
}
}

```

#### Contenido del github  <a name="id17"></a>

Los archivos alojados al sitio son:
+ Carpeta imágenes, donde figuran alguna imagen del readme
+ README.md -explicativo
+ Vagrantfile -archivo de configuración de vagrant
+ Video drupal.mp4 -video funcionamiento de aplicación
+ nfs-drupal.mkv -video carpetas exportadas
+ scriptb.sh -script vagrant de balanceador

+ scripte.sh -script vagrant de nginx

+ scriptm.sh -script vagrant de mysql

+ scriptn.sh -script vagrant de NFS
