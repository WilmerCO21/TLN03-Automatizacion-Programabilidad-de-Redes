# Evidencias de validación

Esta carpeta contiene los resultados de la prueba integral realizada desde una copia clonada del repositorio.

## Resultado general

| Comprobación | Resultado |
|---|---|
| Carga de la imagen FRR proporcionada por el curso | OK |
| Construcción de las imágenes CPE y Web | OK |
| Topología Containerlab | 28 nodos y 43 enlaces |
| Contenedores activos | 27 de 27 |
| OSPF y OSPFv3 en AS100 | OK |
| IS-IS dual-stack en AS200 | OK |
| iBGP con ambos Route Reflectors | OK |
| eBGP entre ISP, CPE y servidores | OK |
| VRRP dual-stack | OK |
| NAT IPv4 | OK |
| HTTP Anycast IPv4 e IPv6 | OK |
| Failover CPE-ISP1 a CPE-ISP2 | OK |
| Failover Web1 a Web2 | OK |
| Estado posterior a las fallas | OK |

## Tiempos observados

- Transferencia de las VIP hacia CPE-ISP2: 1 segundo.
- Recuperación de CPE-ISP1: 11 segundos.
- Retiro de las rutas Anycast de Web1: 2 segundos.
- Transferencia del tráfico hacia Web2: inmediata en la comprobación.
- Recuperación del tráfico mediante Web1: 1 segundo.

## Registro completo

El archivo `reproducibilidad-2026-10-02.log` contiene la construcción, el despliegue, las validaciones y las pruebas de alta disponibilidad.
