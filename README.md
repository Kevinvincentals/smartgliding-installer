# SmartGliding Platform Installer

## Dansk

### SmartGliding installer

Dette installationsscript sætter automatisk SmartGliding platformen op - et omfattende digitalt flyvnings-logningssystem designet specifikt til svæveflyverklubber. Scriptet giver en enkelt-kommando installation, der håndterer al den tekniske kompleksitet bag kulisserne.

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Kevinvincentals/smartgliding-installer/main/install.sh | bash
```

### Hvad gør scriptet?

`install.sh` scriptet udfører følgende opgaver:

1. **Systemdetektion**: Detekterer automatisk din Linux distribution og arkitektur
2. **Docker Installation**: Installerer Docker Engine hvis det ikke allerede er til stede
3. **Platform Opsætning**: Downloader og konfigurerer SmartGliding platform komponenterne
4. **Service Udrulning**: Starter alle nødvendige services ved hjælp af Docker Compose
5. **Sundhedstjek**: Verificerer at alle services kører korrekt
6. **Klar til Brug**: Giver dig URL'en til at fuldføre den indledende opsætning

### Hvad bliver installeret?

- **SmartGliding Web Applikation**: Hovedbrugergrænsefladen til flyvnings-logning
- **OGN Backend Service**: Forbinder til Open Glider Network for real-time tracking
- **MongoDB Database**: Gemmer alle flyvningsdata og klubinformation
- **Watchtower**: Holder automatisk din installation opdateret med de seneste versioner

### Systemkrav

**Minimum:**
- **Hardware**: Raspberry Pi 4 eller tilsvarende
- **CPU**: 2 kerner
- **RAM**: 2 GB
- **Lagerplads**: 8 GB ledig plads
- **Operativsystem**: Ubuntu eller Debian Linux
- **Arkitektur**: AMD64 (x86_64) eller ARM64 (aarch64)
- **Rettigheder**: Almindelig bruger med sudo adgang (anbefalet) eller root adgang
- **Netværk**: Internetforbindelse til download af komponenter

**Anbefalet:**
- **CPU**: 2-4 kerner
- **RAM**: 4 GB
- **Lagerplads**: 64 GB ledig plads

---

## English

### SmartGliding installer

This installation script automatically sets up the SmartGliding platform - a comprehensive digital flight logging system designed specifically for gliding clubs. The script provides a one-command installation that handles all the technical complexity behind the scenes.

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Kevinvincentals/smartgliding-installer/main/install.sh | bash
```

### What does the script do?

The `install.sh` script performs the following tasks:

1. **System Detection**: Automatically detects your Linux distribution and architecture
2. **Docker Installation**: Installs Docker Engine if not already present
3. **Platform Setup**: Downloads and configures the SmartGliding platform components
4. **Service Deployment**: Starts all required services using Docker Compose
5. **Health Checking**: Verifies that all services are running correctly
6. **Ready for Use**: Provides you with the URL to complete the initial setup

### What gets installed?

- **SmartGliding Web Application**: The main user interface for flight logging
- **OGN Backend Service**: Connects to the Open Glider Network for real-time tracking
- **MongoDB Database**: Stores all flight data and club information
- **Watchtower**: Automatically keeps your installation updated with the latest versions

### System Requirements

**Minimum:**
- **Hardware**: Raspberry Pi 4 or equivalent
- **CPU**: 2 cores
- **RAM**: 2 GB
- **Storage**: 8 GB free space
- **Operating System**: Ubuntu or Debian Linux
- **Architecture**: AMD64 (x86_64) or ARM64 (aarch64)
- **Privileges**: Regular user with sudo access (recommended) or root access
- **Network**: Internet connection for downloading components

**Recommended:**
- **CPU**: 2-4 cores
- **RAM**: 4 GB
- **Storage**: 64 GB free space

---

## License

This project is licensed under the MIT License - see the script header for details.

**Author**: Kevin Vincent Als <kevin@connect365.dk> 