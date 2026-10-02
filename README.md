# TLN03 — Automatización y Programabilidad de Redes

Laboratorio de telecomunicaciones desplegado con Docker, Containerlab y FRRouting. El proyecto implementa dos proveedores de Internet dual-stack, redundancia empresarial, enrutamiento dinámico, alta disponibilidad y servidores web Anycast.

## Autor

- Wilmer Augusto Curi Orosco
- Ingeniería de Telecomunicaciones
- UNI – FIEE

## Objetivo

Diseñar y automatizar una infraestructura de red tolerante a fallas que proporcione conectividad IPv4 e IPv6 a una red empresarial mediante dos proveedores de Internet.

El laboratorio permite comprobar:

- Enrutamiento interno con OSPF, OSPFv3 e IS-IS.
- iBGP con Route Reflectors.
- eBGP redundante entre proveedores.
- Políticas de seguridad y filtrado BGP.
- Redundancia de puertas de enlace mediante VRRP.
- NAT para el tráfico empresarial IPv4.
- Conectividad extremo a extremo IPv4 e IPv6.
- Servidores web redundantes mediante BGP Anycast.
- Conmutación automática ante fallas del acceso a un ISP o del servicio web.

## Arquitectura

~~~mermaid
flowchart TB
    Cliente["Cliente Firefox"]
    LAN["LAN empresarial - br-empresa"]
    CPE1["CPE ISP1 - VRRP MASTER"]
    CPE2["CPE ISP2 - VRRP BACKUP"]
    AS100["AS100 - OSPF, OSPFv3 e iBGP"]
    AS200["AS200 - IS-IS e iBGP"]
    WEB1["Servidor Web1 - AS65101"]
    WEB2["Servidor Web2 - AS65102"]

    Cliente --> LAN
    LAN --> CPE1
    LAN --> CPE2
    CPE1 --> AS100
    CPE2 --> AS200
    AS100 <--> AS200
    AS100 --> WEB1
    AS200 --> WEB2
~~~

Los dos servidores anuncian las mismas direcciones Anycast. Si Nginx deja de responder en uno de ellos, el anuncio BGP se retira y el tráfico cambia automáticamente al servidor disponible.

## Componentes

| Componente | Cantidad | Función |
|---|---:|---|
| AS100 | 11 routers en total | ISP con OSPF, OSPFv3 e iBGP |
| AS200 | 11 routers en total | ISP con IS-IS dual-stack e iBGP |
| Route Reflectors | 4 | Incluidos en los 11 routers de cada ISP; reflexión de rutas iBGP |
| Routers de borde | 4 | Incluidos en los 11 routers de cada ISP; interconexión eBGP redundante |
| CPE | 2 | Acceso empresarial, VRRP y NAT |
| Cliente Firefox | 1 | Pruebas gráficas desde la LAN |
| Servidores web | 2 | Servicio redundante BGP Anycast |
| Puente empresarial | 1 | Segmento LAN compartido |

La topología contiene:

- 28 nodos.
- 43 enlaces.
- 27 contenedores.
- 1 puente Linux externo.

## Protocolos y tecnologías

- IPv4 e IPv6.
- OSPF y OSPFv3.
- IS-IS nivel 2.
- iBGP y eBGP.
- Route Reflectors.
- BGP Anycast.
- VRRP.
- NAT IPv4.
- Prefix-lists.
- Route-maps.
- Maximum-prefix.
- Docker.
- Containerlab.
- FRRouting.
- Keepalived.
- Nginx.
- Firefox con interfaz web.

## Sistemas autónomos

| Sistema | ASN | Función |
|---|---:|---|
| ISP AS100 | 100 | Proveedor basado en OSPF |
| ISP AS200 | 200 | Proveedor basado en IS-IS |
| CPE-ISP1 | 65001 | Acceso empresarial por AS100 |
| CPE-ISP2 | 65002 | Acceso empresarial por AS200 |
| Servidor Web1 | 65101 | Servidor Anycast conectado a AS100 |
| Servidor Web2 | 65102 | Servidor Anycast conectado a AS200 |

## Direccionamiento principal

| Segmento | IPv4 | IPv6 |
|---|---|---|
| LAN empresarial | `10.30.0.0/24` | `2001:db8:30::/64` |
| VIP VRRP | `10.30.0.1` | `2001:db8:30::1` |
| Cliente Firefox | `10.30.0.10` | `2001:db8:30::10` |
| WAN CPE-ISP1 | `192.0.2.0/30` | `2001:db8:100:10::/64` |
| WAN CPE-ISP2 | `192.0.2.4/30` | `2001:db8:200:10::/64` |
| Tránsito Web1 | `198.18.100.0/30` | `2001:db8:ff:100::/64` |
| Tránsito Web2 | `198.18.200.0/30` | `2001:db8:ff:200::/64` |
| Servicio Anycast | `203.0.113.10/32` | `2001:db8:500::10/128` |

> **Nota de diseño:** AS100 y AS200 reutilizan parte del direccionamiento
> privado de infraestructura (`10.0.0.0/24`, `172.16.0.0/16` y
> `fc10::/16`). Esto es intencional porque son dominios IGP aislados.
> Esos prefijos internos no se anuncian entre proveedores mediante eBGP;
> solamente se intercambian los prefijos autorizados por las prefix-lists.

## Requisitos

- Ubuntu Linux.
- Docker.
- Containerlab.
- Comandos `curl`, `ip` y `ss`.
- Acceso administrativo mediante `sudo`.
- Aproximadamente 8 GB de memoria RAM.
- Puerto TCP 3001 disponible.
- Archivo `frr_10.7.1-ssh.tar` proporcionado por el profesor o la imagen `frr:10.7.1-ssh` ya cargada en Docker.
- Conexión a Internet para descargar Firefox y las dependencias durante la primera construcción.

Versiones utilizadas durante las pruebas:

~~~text
Containerlab 0.79.0
FRRouting 10.7.1
~~~

## Estructura del proyecto

~~~text
.
├── docs/
│   └── evidencias/
│       ├── README.md
│       └── reproducibilidad-2026-10-02.log
├── images/
│   ├── base/
│   │   └── .gitkeep
│   ├── cpe/
│   │   ├── Dockerfile
│   │   ├── check-wan.sh
│   │   └── start-cpe.sh
│   └── web/
│       ├── Dockerfile
│       ├── default.conf
│       └── start-web.sh
├── pc01/
│   ├── configs/
│   ├── pc01.yml
│   └── pc01.yml.annotations.json
├── scripts/
│   ├── build.sh
│   ├── deploy.sh
│   ├── destroy.sh
│   ├── test-cpe-failover.sh
│   ├── test-web-failover.sh
│   └── validate.sh
└── README.md
~~~

## Imagen FRR proporcionada por el profesor

La imagen base `frr:10.7.1-ssh` es proporcionada por el profesor mediante Google Drive y no se descarga desde Docker Hub.

El archivo entregado se denomina:

~~~text
frr_10.7.1-ssh.tar
~~~

Antes de construir el laboratorio se puede cargar manualmente:

~~~bash
docker load -i frr_10.7.1-ssh.tar
~~~

También se puede colocar el archivo en la siguiente ubicación:

~~~text
images/base/frr_10.7.1-ssh.tar
~~~

En ese caso, `scripts/build.sh` cargará automáticamente la imagen cuando no se encuentre instalada. El archivo `.tar` no se almacena en Git porque corresponde a una imagen externa proporcionada para el curso.

## Construcción de las imágenes

Desde la raíz del proyecto:

~~~bash
./scripts/build.sh
~~~

El script carga la imagen FRR proporcionada por el profesor, descarga Firefox y construye las siguientes imágenes personalizadas:

~~~text
tln03-cpe:1.0
tln03-web:1.0
~~~

La imagen CPE contiene FRRouting, Keepalived y las herramientas necesarias para NAT. La imagen web contiene FRRouting, Nginx y el monitor encargado de retirar las direcciones Anycast cuando el servicio HTTP deja de responder.

## Despliegue

Para iniciar toda la infraestructura:

~~~bash
./scripts/deploy.sh
~~~

El script realiza automáticamente las siguientes acciones:

1. Comprueba Docker y Containerlab.
2. Valida el archivo `pc01/pc01.yml`.
3. Comprueba las imágenes necesarias.
4. Construye las imágenes personalizadas cuando no existen.
5. Crea y activa el puente `br-empresa`.
6. Verifica que el puerto TCP 3001 esté disponible.
7. Despliega la topología con Containerlab.
8. Espera el inicio de los servicios.
9. Comprueba que existan 27 contenedores activos.

Si el laboratorio ya posee los 27 contenedores activos, `deploy.sh` ejecuta la validación automática y evita crear un segundo despliegue.

## Validación automática

Para comprobar el estado completo de la infraestructura:

~~~bash
./scripts/validate.sh
~~~

El validador comprueba:

- Sintaxis de la topología.
- Cantidad de contenedores activos.
- Vecindades OSPF IPv4.
- Vecindades OSPFv3.
- Vecindades IS-IS.
- Sesiones iBGP IPv4 e IPv6.
- Sesiones eBGP entre proveedores, CPE y servidores Anycast.
- Elección del MASTER VRRP.
- Rutas predeterminadas de los CPE.
- Reglas NAT IPv4.
- Estado de ambos servidores Nginx.
- Acceso al servicio Anycast IPv4.
- Acceso al servicio Anycast IPv6.
- Interfaz gráfica de Firefox.

Resultado esperado:

~~~text
OK: TODAS LAS PRUEBAS TLN03 FUERON SUPERADAS
~~~

## Prueba de redundancia de los CPE

Para simular una falla del enlace WAN hacia ISP1:

~~~bash
./scripts/test-cpe-failover.sh
~~~

La prueba realiza el siguiente proceso:

1. Comprueba que CPE-ISP1 posea las VIP.
2. Verifica HTTP IPv4 e IPv6.
3. Desactiva temporalmente la interfaz WAN de CPE-ISP1.
4. Comprueba que CPE-ISP2 asuma las VIP.
5. Verifica la continuidad del servicio mediante ISP2.
6. Restaura la interfaz de CPE-ISP1.
7. Comprueba la recuperación del estado MASTER.
8. Ejecuta nuevamente las pruebas HTTP.

Resultado esperado:

~~~text
OK: FAILOVER CPE ISP1/ISP2 SUPERADO
~~~

## Prueba de redundancia web

Para simular la falla del servicio principal:

~~~bash
./scripts/test-web-failover.sh
~~~

La prueba realiza el siguiente proceso:

1. Comprueba que Web1 atienda IPv4 e IPv6.
2. Detiene únicamente Nginx en Web1.
3. Espera que se retiren sus direcciones Anycast.
4. Comprueba que el tráfico cambie a Web2.
5. Restaura Nginx en Web1.
6. Comprueba que el servicio regrese a Web1.

Resultado esperado:

~~~text
OK: FAILOVER WEB ANYCAST SUPERADO
~~~

## Acceso a Firefox

Desde la propia máquina Ubuntu:

~~~text
https://127.0.0.1:3001
~~~

Desde otra computadora conectada a la misma red:

~~~text
https://DIRECCION_IP_DE_UBUNTU:3001
~~~

El navegador puede presentar una advertencia por el certificado local. Se debe aceptar la excepción para ingresar.

Desde Firefox se puede abrir el servicio Anycast utilizando:

~~~text
http://203.0.113.10
~~~

Para probar IPv6:

~~~text
http://[2001:db8:500::10]
~~~

## Apagado del laboratorio

Para destruir la topología de forma ordenada:

~~~bash
./scripts/destroy.sh
~~~

Este comando elimina:

- Contenedores del laboratorio.
- Enlaces virtuales administrados por Containerlab.
- Archivos temporales de Containerlab.
- Entradas creadas en `/etc/hosts`.
- Configuración SSH temporal de Containerlab.

Se conservan:

- Las imágenes Docker.
- El puente `br-empresa`.
- Las configuraciones del proyecto.
- El historial de Git.

## Flujo recomendado

Para utilizar el proyecto desde una instalación nueva:

~~~bash
git clone https://github.com/WilmerCO21/TLN03-Automatizacion-Programabilidad-de-Redes.git

cd TLN03-Automatizacion-Programabilidad-de-Redes

# Copiar la imagen entregada por el profesor.
cp /RUTA/AL/ARCHIVO/frr_10.7.1-ssh.tar images/base/

./scripts/build.sh
./scripts/deploy.sh
./scripts/validate.sh
~~~

Para ejecutar las pruebas de alta disponibilidad:

~~~bash
./scripts/test-cpe-failover.sh
./scripts/test-web-failover.sh
~~~

Para finalizar:

~~~bash
./scripts/destroy.sh
~~~

## Solución de problemas

### El puerto 3001 está ocupado

Comprobar el proceso:

~~~bash
ss -ltnp | grep ':3001'
~~~

No se debe desplegar una segunda instancia mientras el puerto esté ocupado.

### El laboratorio ya está desplegado

Comprobar los contenedores:

~~~bash
docker ps --filter label=containerlab=pc01
~~~

Validar el laboratorio existente:

~~~bash
./scripts/validate.sh
~~~

Para realizar un despliegue limpio:

~~~bash
./scripts/destroy.sh
./scripts/deploy.sh
~~~

### El puente empresarial no existe

El script `deploy.sh` lo crea automáticamente. También puede crearse manualmente:

~~~bash
sudo ip link add br-empresa type bridge
sudo ip link set br-empresa up
~~~

### Un contenedor no inicia

Consultar su registro:

~~~bash
docker logs NOMBRE_DEL_CONTENEDOR
~~~

Mostrar todos los contenedores del laboratorio:

~~~bash
docker ps -a --filter label=containerlab=pc01
~~~

### Firefox no abre

Comprobar que el puerto esté escuchando:

~~~bash
ss -ltnp | grep ':3001'
~~~

Comprobar el contenedor:

~~~bash
docker ps --filter name=clab-pc01-cliente-firefox
~~~

## Resultados obtenidos

Las pruebas realizadas confirmaron:

- 27 de 27 contenedores activos.
- Cinco vecinos OSPF IPv4 en AS100-P2.
- Cinco vecinos OSPFv3 en AS100-P2.
- Cinco vecinos IS-IS en AS200-P2.
- Diez sesiones iBGP IPv4 en cada Route Reflector.
- Diez sesiones iBGP IPv6 en cada Route Reflector.
- Un único CPE MASTER para IPv4 e IPv6.
- NAT IPv4 operativo en ambos CPE.
- Acceso HTTP IPv4 e IPv6.
- Conmutación automática de CPE-ISP1 a CPE-ISP2.
- Recuperación automática de CPE-ISP1.
- Conmutación automática de Web1 a Web2.
- Recuperación automática de Web1.
- Retiro de rutas Anycast cuando Nginx falla.
- Continuidad del servicio durante las pruebas.

## Evidencias de validación

Los resultados de la prueba limpia, las validaciones de protocolos y las pruebas de conmutación se encuentran en:

- [Resumen de evidencias](docs/evidencias/README.md)
- [Registro completo de reproducibilidad](docs/evidencias/reproducibilidad-2026-10-02.log)

## Conclusión

El laboratorio demuestra una arquitectura empresarial dual-stack tolerante a fallas. La combinación de OSPF, OSPFv3, IS-IS, iBGP, eBGP, VRRP, NAT y BGP Anycast permite conservar la conectividad ante la caída de un proveedor o de un servidor web.

Los scripts incluidos permiten construir, desplegar, validar, probar y destruir el laboratorio de forma reproducible.

~~~text
OK: PROYECTO TLN03 COMPLETAMENTE OPERATIVO
~~~
