# SmartGliding Platform Installer

## English

### What is this?

This installation script automatically sets up the SmartGliding platform - a comprehensive digital flight logging system designed specifically for gliding clubs. The script provides a one-command installation that handles all the technical complexity behind the scenes.

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

- **Operating System**: Ubuntu or Debian Linux
- **Architecture**: AMD64 (x86_64) or ARM64 (aarch64)
- **Privileges**: Regular user with sudo access (recommended) or root access
- **Network**: Internet connection for downloading components

### How to use

1. Download the script: `wget https://your-domain.com/install.sh`
2. Make it executable: `chmod +x install.sh`
3. Run the installer: `./install.sh`
4. Follow the instructions to complete setup at `http://your-server-ip:3000/install`

---

## Dansk

### Hvad er dette?

Dette installationsscript sætter automatisk SmartGliding platformen op - et omfattende digitalt flyvnings-logningssystem designet specifikt til svæveflyverklubber. Scriptet giver en enkelt-kommando installation, der håndterer al den tekniske kompleksitet bag kulisserne.

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

- **Operativsystem**: Ubuntu eller Debian Linux
- **Arkitektur**: AMD64 (x86_64) eller ARM64 (aarch64)
- **Rettigheder**: Almindelig bruger med sudo adgang (anbefalet) eller root adgang
- **Netværk**: Internetforbindelse til download af komponenter

### Sådan bruges det

1. Download scriptet: `wget https://your-domain.com/install.sh`
2. Gør det eksekverbart: `chmod +x install.sh`
3. Kør installeren: `./install.sh`
4. Følg instruktionerne for at fuldføre opsætningen på `http://din-server-ip:3000/install`

---

## License

This project is licensed under the MIT License - see the script header for details.

**Author**: Kevin Vincent Als <kevin@connect365.dk> 