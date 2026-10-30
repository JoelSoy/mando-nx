# Ingeniería inversa de Mario Kart 8 Deluxe (datos de carrera)

Hallazgos del 2026-10-29 y 2026-10-30 sobre MK8D 4.0.1 (build de `main` `2452C49BC26EC159`). Las direcciones fijas solo valen para esta build.

## Pista (sin ingeniería inversa)

- Al cargar cada carrera, el juego abre `content:/Course/<carpeta>/course_model.szs`. Se ve con `DM_FS=1`.
- En los menús abre `Course/Gu_Menu`, que es el fondo del menú.
- Hay 108 carpetas en total. Para pasar de carpeta a nombre en español se usa `UI/EUes/message.sarc` → `Common.msbt`:
  - pistas base: 1401–1416;
  - retro: 1441–1456;
  - DLC: 1481–1496;
  - batalla: 11401–11408;
  - Pase de pistas extras: `Cnsw_<w><s>` → 11700 + (w−1)·8 + s.
- Verificado en vivo: `Gu_FirstCircuit` (Estadio Mario Kart), `Gu_WaterPark` (Parque Acuático), `Gu_Cake`, `Gu_DossunIseki` y `Gu_MarioCircuit`. También comprobé `Cnsw_12` (Circuito Toad) y `Cnsw_68` (Senda Arco Iris Wii) por sus objetos.

## Posición, vuelta y monedas (memoria)

- MK8D es de 64 bits. La base de `main` cambia en cada arranque; se lee del log (`main: base 0x…`).
- **Corredor** (tabla virtual `main+0x12CAC28`, uno por kart, 12 en carrera):

  | Campo | Significado |
  |---|---|
  | `+0x38` | índice del corredor (0 = jugador 1) |
  | `+0x40` | posición, base 0 (0 = 1.º) |
  | `+0x44` | vuelta, base 0 |
  | `+0x50` | monedas |

- **Dueño** (tabla virtual `main+0x125ada8`, uno solo): `+0x60` es la cantidad de corredores y `+0x68` el puntero al arreglo de corredores (`sead::PtrArray`).
- Ningún puntero desde `main` apunta directo a esos objetos. Por eso, al abrir `Course/…`, el Mac busca en el heap la palabra con la tabla virtual del dueño y luego valida en cada lectura (tablas virtuales e índice).
- Verificado contra capturas en varias carreras de dos copas.

## Personaje y kart

- **Modelo del kart** (tabla virtual `main+0x125a288`, uno por corredor, creados en el orden de los corredores, cada uno en su propio heap). Junto a los números guarda los nombres de archivo que usa (`Driver/Yoshi.bfres`, `Kart/Body/BodyB_Std.bfres`…), lo que permitió comprobarlos:

  | Campo | Significado |
  |---|---|
  | `+0x08` | personaje (`+0x0c`: su color) |
  | `+0x14` | carrocería |
  | `+0x18` | ala |
  | `+0x20` | ruedas |

- Los números siguen las listas del propio juego: el menú arma en el heap una tabla de nombres internos (`Mario`, `Luigi`…, `K_Std`…, `T_Std`…, `G_Std`…) y otra con el número de mensaje de cada uno (`Common.msbt`: 1001… personajes, 1101… carrocerías, 1201… ruedas, 1251… alas). La app tiene los nombres en español en ese orden (`app/lib/games/mk8_racers.dart`, `mk8_karts.dart`).
- Los personajes del Pase se llaman `DrvChr0N` en los archivos: son el número 43 + N (Birdo 44 … Pauline 51).
- Verificado: Yoshi en moto estándar con ruedas Leaf; luego, elegidos en el menú, Rey Boo (40) en Torbellino (15) con ruedas Leaf (20) y Superala (0). Las CPU coinciden con la pantalla de resultados (Birdo, Funky Kong, Bowsitos, Aldeano…).
- También existe, en el objeto de la partida, una tabla por jugador local (cuatro columnas: personaje, carrocería, ruedas, ala), pero sin forma estable de encontrarla; no se usa.

## Objeto

- **Casilla de objetos en pantalla** (tabla virtual `main+0x127e110`, un solo objeto cuando juega una persona):

  | Campo | Significado |
  |---|---|
  | `+0x200`, `+0x204` | estado de cada casilla: 3 = lo tienes, 2 = gira la ruleta, 0 = vacía |
  | `+0x210`, `+0x214` | objeto de cada casilla (−1 = ninguno; al usarlo, el número queda pero el estado pasa a 0) |

- El juego no escribe los nombres de los objetos. El orden sale de una tabla del código (`main+0xf21e7c`, de número de objeto → cuadro de la animación de íconos `ItemPtn` en `UI/cmn/race.sarc` `rc_L_ItemBox_00`):

  | Nº | Objeto | Nº | Objeto | Nº | Objeto |
  |---|---|---|---|---|---|
  | 0 | Plátano | 8 | Superestrella | 16 | Superbocina |
  | 1 | Caparazón verde | 9 | Bill Bala | 17 | Triple plátano |
  | 2 | Caparazón rojo | 10 | Rayo | 18 | Triple caparazón verde |
  | 3 | Champiñón | 11 | Champiñón dorado | 19 | Triple caparazón rojo |
  | 4 | Bob-omb | 12 | Flor de fuego | 20 | Ocho loco |
  | 5 | Blooper | 13 | Planta Piraña | 21 | Pluma |
  | 6 | Caparazón azul | 14 | Flor bumerán | 22 | Boo |
  | 7 | Triple champiñón | 15 | Moneda | | |

- Comprobados en pantalla: plátano (0), caparazón verde (1), caparazón rojo (2), champiñón (3) y moneda (15). El resto sale de la tabla del juego.
- Límite: es la casilla de la pantalla, no la del corredor. Con varios jugadores locales hay una por jugador y no se sabe cuál es de quién, así que el Mac solo la manda con un jugador. La casilla propia de cada corredor no apareció (no es un int32 simple).

## Herramienta: `DM_CTL scan` (nxnative `dm/host/hle_scan.c`)

Busca valores en la memoria del juego mientras corre, sin volcar a disco.

| Comando | Qué hace |
|---|---|
| `scan i32 <v> [max]` | busca lugares con ese valor (o rango) |
| `scan =`, `scan changed`, `scan same` | filtra los candidatos |
| `scan rec` + captura | graba una columna de valores |
| `scan match c=v …` | elige columnas válidas después, mirando las capturas |
| `scan ptr64 <dir> <rango>` | busca punteros de 64 bits |
| `scan seq i32 <paso máx> v0 v1 …` | busca arreglos de registros que contengan esos valores en orden (por ejemplo, los personajes de los 12 corredores según la pantalla de resultados) |
| `scan list` | muestra los candidatos |

- Para no pausar el juego, córrelo **sin ventana** (sin `DM_WINDOW`).
- `scan match` borra los candidatos que no cumplen: empieza por las condiciones seguras. La ruleta de objetos engaña a las capturas (muestra objetos que no son el final); usa solo momentos estables.
- Guiones de prueba (scratch, temporales): `run_game.sh`, `to_race.sh`, `step.sh`, `ptr.sh`, `recloop.sh` y `sheet` (une capturas en una sola imagen).

## Estado

Implementado:

- **Host:** `remote_race.c`, más los hooks en `hle_fs.c` (`dm_fs_opened`) y `hle_svc.c` (`dm_guest_heap`). Envía el mensaje `race` con `crs`, `pos`, `lap`, `coin`, `drv`, `body`, `tire`, `wing`, `itm` e `itm2`. Lo cubren `t_remote_feed`, `t_remote_race` y `t_remote_udp`.
- **App:** `RaceInfo`, `games/courses.dart`, `games/mk8_racers.dart`, `games/mk8_karts.dart` y las dos líneas de carrera en la tarjeta del juego.
- **Verificado con el juego real:** un teléfono simulado (`remote_phone.py`) recibió la pista, la posición, la vuelta, las monedas, Rey Boo con su kart, y el champiñón (`itm` 3) mientras estaba en la casilla y −1 al usarlo, y coincidieron con capturas.

Pendiente:

- jugadores 2–4 en pantalla dividida (posición y kart supuestos; objetos sin dueño conocido);
- la casilla de objetos propia de cada corredor.
