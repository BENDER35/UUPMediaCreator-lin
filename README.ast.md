<p align="center">
  <img src="Assets/logo.png" width="176"><br>
  <b>Una utilidá pa convertir conxuntos de ficheros de la Plataforma Unificada d'Actualizaciones (UUP) en ficheros de medios de Windows</b><br>
  <a href="./src">Códigu fonte</a> |
  <a href="./docs">Documentación</a> |
  <a href="./thirdparty">Biblioteques de terceros</a> |
  <a href="https://github.com/BENDER35/UUPMediaCreator-lin/releases">Descargues</a>
  <br><br>
</p>

> 🌐 **Llingües / Languages:** [English](./README.md) · [Español](./README.es.md) · Asturianu (esti ficheru)
> 📖 **Guía téunica / Technical guide:** [Español](./docs/GUIA_TECNICA.md) · [English](./docs/TECHNICAL_GUIDE.md)

## Readme

UUP Media Creator ye un conxuntu de ferramientes diseñaes pa ayudate a esplorar y baxar actualizaciones de la Plataforma Unificada d'Actualizaciones (UUP) de Microsoft, y pa dexate crear medios a partir d'elles cuando nun esiste una ferramienta fayadiza nel mundu.

Anguaño les ferramientes inclúin:

- UUPDownload: dexa esplorar, llograr y baxar actualizaciones dende UUP (Escritoriu de Windows, Windows 10X, Windows Holographic, Windows Server, Windows Mobile, Windows IoT, etc...)
- UUPMediaConverter: dexa convertir una actualización UUP baxada de Windows Desktop nuna imaxe ISO usable, pa un llector de DVD de la última década o a cencielles montala.

> ℹ️ **Sobre esti fork:** esti repositoriu ye un fork centráu en Linux. Dambes ferramientes de llinia de comandu compílense y verifíquense pa funcionar **en Linux** (x64/arm64), Windows y macOS, con especial atención a poder baxar **versiones antigües de Windows** (dómina de Windows 7/8.1/10). Mira [Dependencies](#dependencies) y [Ciclu de vida de soporte de Windows](#ciclu-de-vida-de-soporte-de-windows-10).

## Dependencies

Les ferramientes son aplicaciones .NET, polo que se requier un runtime de .NET. Mientres el desarrollu úsase'l SDK de .NET **10**, y los binarios publíquense pa les plataformes indicaes embaxo. Cuando executes dende'l códigu fonte (o una compilación dependiente del framework) instala:

| Plataforma | Requisitu |
|----------|----------|
| **Windows** | Runtime de .NET 10 (o SDK). Pa crear ISOs d'edición base **nun se precisen privilexos d'alministrador**. |
| **Linux** | Runtime de .NET 10 (o SDK) + `genisoimage` (aporta `mkisofs`) pa la creación d'ISOs + `libwim` (wimlib) — el `libwim.so` nativu pa Linux **inclúise** nos binarios publicaos. |

Comandos d'instalación:

```bash
# Ubuntu / Debian
sudo apt-get install genisoimage
sudo apt-get install dotnet-runtime-10.0   # or the .NET 10 SDK
```

```bash
# Arch Linux
sudo pacman -S genisoimage dotnet-runtime
```

```bash
# Fedora
sudo dnf install genisoimage dotnet-runtime-10.0
```

```bash
# macOS
brew install cdrtools   # provides mkisofs/genisoimage
```

> **Nota sobre `libfuse2`:** les versiones antigües d'esti proyeutu indicaben `libfuse2` pal montaxe de VHD en Linux. Esti fork **nun** contién nengún códigu de montaxe VHD/FUSE pa Linux (el montaxe de discos virtuales ye namái de Windows), polo que `libfuse2` **nun ye necesariu** en Linux.

### Publicar pa Linux

Apórtase un script de conveniencia:

```bash
./publish_linux.sh            # linux-x64
./publish_linux.sh arm64      # linux-arm64
```

Publica tanto `UUPDownload` como `UUPMediaConverter` como executables d'un solu ficheru en `publish/artifacts/linux-<arch>/CLI`.

### Publicar pa Windows

En Windows apórtase un script `.cmd` por arquiteutura. Namás precisen el **SDK de .NET 10** (sen Visual Studio); caúno ye un envoltoriu finu sobre l'ayudante xenérico `publish.cmd`:

| Script | Arquiteutura | Destín habitual |
|--------|--------------|------------------|
| `publish_win_x64.cmd` | 64 bits | Windows 10 1607+ / Windows 11 |
| `publish_win_x86.cmd` | 32 bits | Windows 10 1607+ |
| `publish_win_arm64.cmd` | ARM64 | Windows 11 |
| `publish_win_legacy.cmd` | 32 bits **y** 64 bits | **Windows 7 SP1 / 8 / 8.1** y posteriores |

Cada script xenera executables autocontenidos d'un solu ficheru:

- `publish_win_x64.cmd`, `publish_win_x86.cmd` y `publish_win_arm64.cmd` → `publish\artifacts\win-<arch>\CLI`
- `publish_win_legacy.cmd` → `publish\artifacts\win-legacy-x86\CLI` y `publish\artifacts\win-legacy-x64\CLI`

Pa cualquier otru runtime, llama directamente al ayudante: `publish.cmd <rid> [tfm]`; por exemplu `publish.cmd linux-x64`, `publish.cmd osx-arm64` o `publish.cmd win-x64 net6.0`.

#### Compilación heredada (Windows antiguo)

La compilación predeterminada usa **.NET 10**, que **namái funciona en Windows 10 1607 o posterior**. Pa executala en **Windows 7 SP1, 8 o 8.1**, `publish_win_legacy.cmd` usa **.NET 6** (el postrer runtime de .NET que funciona en Windows 7 SP1) y xenera executables autocontenidos, polo que **nun fai falta instalar nengún runtime de .NET na máquina de destino**.

La máquina de destino sigue precisando los requisitos habituales de Windows 7: el Universal C Runtime (**KB2999226**), el soporte de firma de códigu SHA-2 (**KB4474419**) y **KB2533623**.

> **Nota:** .NET 6 yá nun ta soportáu (les sos correiciones de seguridá terminaron en payares de 2024). La compilación heredada esiste namái pa poder executar la ferramienta en sistemes operativos que .NET 10 yá nun almite; siempre que seya posible, usa la compilación predeterminada (.NET 10).

## Ciclu de vida de soporte de Windows 10

Esta ferramienta pue baxar y crear medios pa **Windows 10 y Windows 11**, incluyíes versiones antigües de Windows 10 (1709, 1803, 1809, 1903...). Por eso, has de conocer l'estáu actual de soporte de los sistemes operativos que vas desplegar:

| Productu | Fin del soporte ordinariu | Fin de les Actualizaciones de Seguridá Estendíes (ESU) |
|---------|-----------------------------------|-------------------------------------|
| Windows 10 (Home / Pro / toes les ediciones minoristes) | **14 d'ochobre de 2025** | **12 d'ochobre de 2027** (ESU de consumu, incluyida la inscripción hasta esa fecha) · hasta **ochobre de 2028** pa les ESU comerciales (añales, de pagu) |
| Windows 8.1 | 10 de xineru de 2023 | 10 de xineru de 2026 (ESU finalizaes) |
| Windows 7 | 14 de xineru de 2020 | 10 de xineru de 2023 (ESU finalizaes) |
| Windows Server 2012 / 2012 R2 | 10 d'ochobre de 2023 | 13 d'ochobre de 2026 (ESU finalizaes) |

Fuentes: [Microsoft – Fin de soporte de Windows](https://www.microsoft.com/en-us/windows/end-of-support), [Microsoft – Windows 10 Consumer ESU](https://www.microsoft.com/en-us/windows/extended-security-updates).

## ⚠️ Rotación de certificaos de Windows Update (2027) — llee enantes de desplegar

Microsoft ta **rotando los certificaos raíz** usaos pa establecer conexones de confianza con Windows Update. Dalgunos d'estos certificaos caduquen el **17 de mayu de 2027** y el **19 de xunu de 2027**.

- Los dispositivos con versiones de Windows compatibles que sigan recibiendo actualizaciones mensuales van llograr los certificaos nuevos automáticamente y **non** se van ver afeutaos.
- Los dispositivos con **Windows 7, Windows 8.1 y Windows 10 ensin ESU** (o cualquier compilación yá ensin soporte) que **nun puedan recibir los certificaos raíz nuevos** **van dexar de conectase a Windows Update** y van dexar de recibir actualizaciones dafechu.
- Si vas desplegar o caltener medios antiguos de Windows con esta ferramienta, planifícalo en consecuencia: inscribe l'equipu en ESU (Windows 8/10), migra a una versión de Windows compatible, o aplica la actualización manual de certificaos raíz de confianza **enantes de les fecha llende de mayu/xunu de 2027**.

Fonte: [Microsoft Tech Community – Prepare for Windows Update certificate rotation in 2027](https://techcommunity.microsoft.com/blog/windows-itpro-blog/prepare-for-windows-update-certificate-rotation-in-2027/4562463)

## Funciones almitíes por sistema operativu

| Función                                                                                  | Windows | Linux (3) | macOS  |
|------------------------------------------------------------------------------------------|---------|--------|--------|
| Baxar ficheros de UUP (UUPDownload)                                                 | ✅       | ✅       | ✅       |
| Reanudar descargues anteriores de UUP (UUPDownload)                                          | ✅       | ✅       | ✅       |
| Descifrar cargues útiles ESRP de UUP (UUPDownload)                                          | ✅       | ✅       | ✅       |
| Verificar cargues útiles baxaes de UUP (UUPDownload)                                     | ✅       | ✅       | ✅       |
| Amosar compilaciones disponibles de UUP (argumentu get-builds) (UUPDownload)                     | ✅       | ✅       | ✅       |
| Convertir ficheros UUP d'escritoriu nuna ISO d'una edición base (UUPMediaConverter)          | ✅       | ✅       | ✅       |
| Nun riquir privilexos d'alministrador pa imaxes ISO d'edición base                   | ✅       | ✅       | ✅       |
| CLI disponible                                                                            | ✅       | ✅       | ✅       |
| Soporte ARM64 (o seya, funciona nel dispositivu de @sinclairinat0r (TM))                                 | ✅       | ✅       | ✅       |
| Convertir ficheros UUP d'escritoriu nuna ISO de toles ediciones posibles (UUPMediaConverter)     | ✅       | ❌       | ❌       |
| Entornu de preinstalación ISO cercanu al orixinal (UUPMediaConverter)                    | ✅       | ❌       | ❌       |
| ISO creada con CDImage Mastering Utility con UDF y sector d'arranque (UUPMediaConverter)      | ✅       | ❌       | ❌       |
| ISO creada con mkisofs con UDF y sector d'arranque (UUPMediaConverter)                        | ❌       | ✅   (1) | ✅   (2) |
| Integración d'actualizaciones de ficheros (UUPMediaConverter)                                              | ❌       | ❌       | ❌       |
| Crear imáxenes Hololens, Mobile, 10X, IoT                                               | ❌       | ❌       | ❌       |
| UUPDownload fácil d'usar (vendrá llueu, prometémoslo)                                     | ❌       | ❌       | ❌       |

(1): requier ```apt-get install genisoimage```

(2): requier ```brew install cdrtools```

(3): los binarios publicaos son executables autocontenidos d'un solu ficheru, polo que **nun** se requier el runtime de .NET. Inclúise'l ```libwim.so``` (wimlib) que s'usa pa crear la ISO. `libfuse2` **nun** ye necesariu nesti fork.

## Usu

UUPDownload pue ser un pocu complicáu d'usar pa delles persones. Como referencia, equí ta'l conxuntu actual de parámetros que puedes usar:

| Canal                               | Comandu |
|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Retail (Windows 10, Desktop)          | -s Professional -v 10.0.19043.1 -r Retail -b Retail -c vb_release -t [your architecture] |
| Retail (Windows 10 ESU, Desktop)      | -s Professional -v 10.0.19045.1 -r Retail -b Retail -c vb_release -u -t [your architecture] |
| Retail (Windows 11, Desktop)          | -s Professional -v 10.0.26100.1 -r Retail -b Retail -c ge_release -t [your architecture] |
| Retail (IoT)                          | -s IoTUAP -v 10.0.17763.1 -r Retail -b Retail -c rs5_release -t [your architecture] |
| Retail (Holographic)                  | -s Holographic -v 10.0.20346.1 -r Retail -b Retail -c fe_release -t [your architecture] |
| Retail (Mobile)                       | -s MobileCore -v 10.0.15254.1 -r Retail -b Retail -c feature2 -t [your architecture] |
| Retail (Team)                         | -s PPIPro -v 10.0.19043.1 -r Retail -b Retail -c vb_release -t [your architecture] |
| Retail (Server)                       | -s DatacenterServer -v 10.0.20348.1 -r Retail -b Retail -c fe_release -t [your architecture] |
| Release Preview (Windows 10, Desktop) | -s Professional -v 10.0.19043.1 -r External -b ReleasePreview -c vb_release -t [your architecture] |
| Release Preview (Windows 11, Desktop) | -s Professional -v 10.0.26100.1 -r External -b ReleasePreview -c ge_release -t [your architecture] |
| Release Preview (HCI)                 | -s AzureStackHCIServerCore -v 10.0.22000.1 -r External -b ReleasePreview -c rs_prerelease -t [your architecture] |
| Beta (Windows 10, Desktop)            | -s Professional -v 10.0.19045.1 -r External -b Beta -c vb_release -t [your architecture] |
| Beta (Windows 11, Desktop)            | -s Professional -v 10.0.26100.1 -r External -b Beta -c ge_release -t [your architecture] |
| Beta (Holographic)                    | -s Holographic -v 10.0.19043.1 -r External -b Beta -c vb_release -t [your architecture] |
| Beta (Team)                           | -s PPIPro -v 10.0.19043.1 -r External -b Beta -c vb_release -t [your architecture] |
| Dev (Desktop)                         | -s Professional -v 10.0.26100.1 -r External -b Dev -c rs_prerelease -t [your architecture] |
| Dev (Holographic)                     | -s Holographic -v 10.0.19043.1 -r External -b Dev -c vb_release -t [your architecture] |
| Dev (Team)                            | -s PPIPro -v 10.0.19043.1 -r External -b Dev -c vb_release -t [your architecture] |
| Canary (Desktop)                      | -s Professional -v 10.0.26100.1 -r External -b CanaryChannel -c rs_prerelease -t [your architecture] |

> **Rames de Windows 11 (2026):** Windows 11 sírvese agora dende la rama **GE (Germanium)**. Usa `-c ge_release` pa **Retail**, **Release Preview** y **Beta** de Windows 11; y `-c rs_prerelease` pa **Dev** y **Canary**. L'antigua rama `ni_release` (21H2/22H2/23H2) yá nun se sirve nos canales Beta/Release Preview, polo que usala xunto con `-y` devuelve *"No updates found"*. Verificáu contra los servidores reales: Beta = `10.0.26220.9606 (ge_release_svc_betaflt_prod1)`, Dev = `10.0.26340.9616 (ge_prerelease_im)`, Canary = `10.0.28020.2207`.

> **Beta de Windows 10:** Microsoft sigue sirviendo'l canal **Beta** de Windows 10 — responde cola compilación más nueva de Windows 10 22H2 (`10.0.19045.6396`, `vb_release_svc_prod3.250923-1751`). Usa `-s Professional -v 10.0.19045.1 -r External -b Beta -c vb_release -t [your architecture]` **sen `-y`** pa llograr siempre la última compilación Beta disponible. El canal **Dev** de Windows 10 agora devuelve compilaciones de Windows 11.

> **Windows 10 ESU (Extended Security Updates):** Windows 10 22H2 llegó al fin del soporte el **2025-10-14**; les actualizaciones mensuales publicaes darréu namái s'ufierten a dispositivos inscritos nel programa ESU. Añade `-u` (`--esu`) a `request-download` — o usa la entrada **`Retail (Windows 10 ESU)`** de `get-builds` — pa informar de que'l dispositivu ta inscritu en ESU. Los servidores entregarán entós la compilación ESU, p. ex. `10.0.19045.7727 (vb_release_svc_im.260912-0526)`, pa **x86**, **amd64** y **arm64**. Exemplu: `-s Professional -v 10.0.19045.1 -r Retail -b Retail -c vb_release -u -e Professional -l en-US`. Sen `-u` namái llogras la última compilación normal de 22H2 (`10.0.19045.6456`).

> **Fiabilidá:** los servidores de Windows Update a vegaes responds con un conxuntu vacíu cuando se faen munches peticiones seguíes. `UUPDownload` agora espera y **reintenta una vez** enantes d'informar de *"No updates found"*, tanto en `get-builds` como en `request-download`.

> **Baxar versiones antigües de Windows 10:** el conxuntu UUP más antiguu que Microsoft sigue sirviendo ye **Windows 10 1709 (RS3, `rs3_release`)**, darréu 1803 (`rs4_release`), 1809 (`rs5_release`), 1903 (`19h1_release`) y 22H2 (`vb_release`). **Windows 10 1703 (RS2, `rs2_release`) y anteriores (1607, 1511, 1507) yá nun tán disponibles** — Microsoft retirólos de los servidores. Usa'l verbu `get-builds` pa ver qué s'ufierta anguaño y `-y` pa afitar una versión exacta, p. ex. 1809: `-s Professional -v 10.0.17763.1217 -r Retail -b Retail -c rs5_release -y -e Professional -l en-US`.

> **ISOs de Windows Insider Preview:** la [páxina oficial de descarga d'Insider Preview](https://www.microsoft.com/software-download/windowsinsiderpreviewiso) de Microsoft agora namái ufre **Windows 11** (les ISOs Insider de Windows 10 elimináronse). Pa llograr medios de Windows 10 —incluyíes versiones antigües— usa `UUPDownload` como se muestra enriba.

**CONSEYU 1:** Pues añadir ```-e [Edition to download]``` pa llograr namái los ficheros necesarios pa una edición concreta

**CONSEYU 2:** Pues añadir ```-l [Language to download]``` pa llograr namái los ficheros necesarios pa una llingua concreta

### Importante

El parámetro ```-v``` __non__ s'usa pa especificar qué versión de Windows quies baxar. Los parámetros que usa UUPDownload enriba utilícense pa dici-y a Windows Update **qué** versión de Windows tas executando anguaño. Por tanto, ```-v``` s'usa pa dici-y a Windows Update la to versión actual de Windows. Nunca llogres versiones inferiores al valor especificáu en ```-v``` y dalgunes peticiones tampoco te van dar la versión indicada en ```-v```, sinón namái versions más nueves. Si, sicasí, quies baxar una versión bien concreta con ```-v``` __entós__ has d'usar la opción -y pa indicar a Windows Update que namái quies esta versión.

## Cómo contribuyir

Yes llibre de contribuyir a esti proyeutu; de fecho, agradeceríamos cualquier mena d'ayuda. Pero por favor ten en cuenta los puntos siguientes si lo faes:

- Intenta caltener el to PR con un conxuntu razonable de commits
- Intenta nun camudar funcionalidaes ayenes al to PR
- Evita camudar tola aplicación; si crees que ye necesario, abre un issue pa que lo alderiquemos ente collaboradores.

## Errores

Esti proyeutu, como too en ciencies de la computación, nun ta llibre d'errores. Si atopes daqué mal, por favor abre un issue nel rastreador. Incluyi la versión de la ferramienta, según el sistema operativu nel que la executes y cualesquier otru detalle que ayude a reproducir el problema.
