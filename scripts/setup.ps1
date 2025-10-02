# Script de configuration initiale pour le projet Jenkins CI/CD
# Usage: .\scripts\setup.ps1

param(
    [switch]$SkipPrerequisites,
    [switch]$Verbose
)

# Configuration des couleurs
$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Log-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Cyan"
}

function Log-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" "Green"
}

function Log-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Log-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Check-Prerequisites {
    Log-Info "Vérification des prérequis..."
    
    # Docker
    try {
        $dockerVersion = docker --version
        Log-Success "Docker trouvé: $dockerVersion"
    }
    catch {
        Log-Error "Docker n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    }
    
    # Docker Compose
    try {
        $composeVersion = docker-compose --version
        Log-Success "Docker Compose trouvé: $composeVersion"
    }
    catch {
        Log-Error "Docker Compose n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    }
    
    # Node.js
    try {
        $nodeVersion = node --version
        Log-Success "Node.js trouvé: $nodeVersion"
    }
    catch {
        Log-Warning "Node.js n'est pas installé. Recommandé pour le développement local."
    }
    
    # Git
    try {
        $gitVersion = git --version
        Log-Success "Git trouvé: $gitVersion"
    }
    catch {
        Log-Error "Git n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    }
}

function Setup-Environment {
    Log-Info "Configuration de l'environnement..."
    
    # Création du fichier .env s'il n'existe pas
    if (-not (Test-Path ".env")) {
        Log-Info "Création du fichier .env..."
        Copy-Item "src\.env" ".env"
        Log-Success "Fichier .env créé"
    }
    
    # Création des répertoires nécessaires
    $directories = @(
        "logs",
        "reports", 
        "artifacts",
        "nginx",
        "scripts\sql"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Log-Success "Répertoires créés"
}

function Install-Dependencies {
    Log-Info "Installation des dépendances Node.js..."
    
    if ((Test-Path "src") -and (Test-Path "src\package.json")) {
        Push-Location "src"
        try {
            npm install
            Log-Success "Dépendances Node.js installées"
        }
        finally {
            Pop-Location
        }
    }
    else {
        Log-Warning "Répertoire src ou package.json non trouvé"
    }
}

function Setup-Jenkins {
    Log-Info "Configuration de Jenkins..."
    
    # Création du répertoire Jenkins
    if (-not (Test-Path "jenkins\jobs\demo-pipeline")) {
        New-Item -ItemType Directory -Path "jenkins\jobs\demo-pipeline" -Force | Out-Null
    }
    
    # Configuration des plugins Jenkins
    $pluginsContent = @"
blueocean:latest
docker-workflow:latest
git:latest
pipeline-stage-view:latest
build-timeout:latest
timestamper:latest
ws-cleanup:latest
ant:latest
gradle:latest
workflow-aggregator:latest
github-branch-source:latest
pipeline-github-lib:latest
pipeline-stage-view:latest
sonar:latest
html-publisher:latest
junit:latest
coverage:latest
"@
    
    Set-Content -Path "jenkins\plugins.txt" -Value $pluginsContent
    Log-Success "Configuration Jenkins préparée"
}

function Setup-Database {
    Log-Info "Configuration de la base de données..."
    
    $sqlContent = @"
-- Script d'initialisation de la base de données
CREATE DATABASE IF NOT EXISTS demo_app;
CREATE DATABASE IF NOT EXISTS sonarqube;

-- Utilisateur pour SonarQube
CREATE USER IF NOT EXISTS 'sonar'@'%' IDENTIFIED BY 'sonar_password';
GRANT ALL PRIVILEGES ON sonarqube.* TO 'sonar'@'%';

-- Tables de démonstration
USE demo_app;

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('John Doe', 'john@example.com'),
('Jane Smith', 'jane@example.com')
ON DUPLICATE KEY UPDATE name=name;

FLUSH PRIVILEGES;
"@
    
    Set-Content -Path "scripts\init-db.sql" -Value $sqlContent
    Log-Success "Script de base de données créé"
}

function Setup-Nginx {
    Log-Info "Configuration Nginx..."
    
    if (-not (Test-Path "nginx\ssl")) {
        New-Item -ItemType Directory -Path "nginx\ssl" -Force | Out-Null
    }
    
    $nginxContent = @"
events {
    worker_connections 1024;
}

http {
    upstream jenkins {
        server jenkins:8080;
    }
    
    upstream demo-app {
        server demo-app:3000;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location /jenkins {
            proxy_pass http://jenkins;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
        
        location / {
            proxy_pass http://demo-app;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
    }
}
"@
    
    Set-Content -Path "nginx\nginx.conf" -Value $nginxContent
    Log-Success "Configuration Nginx créée"
}

function Show-NextSteps {
    Write-Host ""
    Log-Success "Configuration terminée avec succès!"
    Write-Host ""
    Log-Info "Prochaines étapes:"
    Write-Host "  1. Démarrer les services: docker-compose up -d"
    Write-Host "  2. Accéder à Jenkins: http://localhost:8080"
    Write-Host "  3. Accéder à l'application: http://localhost:3000"
    Write-Host "  4. Accéder à SonarQube: docker-compose --profile analysis up -d"
    Write-Host ""
    Log-Info "Pour plus d'informations, consultez le README.md"
}

# Fonction principale
function Main {
    Write-Host ""
    Write-ColorOutput "🚀 Configuration du projet Jenkins CI/CD Demo" "Magenta"
    Write-ColorOutput "=============================================" "Magenta"
    Write-Host ""
    
    Log-Info "Début de la configuration..."
    Write-Host ""
    
    if (-not $SkipPrerequisites) {
        Check-Prerequisites
    }
    
    Setup-Environment
    Install-Dependencies
    Setup-Jenkins
    Setup-Database
    Setup-Nginx
    
    Show-NextSteps
}

# Point d'entrée
try {
    Main
}
catch {
    Log-Error "Erreur lors de la configuration: $($_.Exception.Message)"
    exit 1
}