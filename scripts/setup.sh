#!/bin/bash

# Script de configuration initiale pour le projet Jenkins CI/CD
# Usage: ./scripts/setup.sh

set -e

echo "🚀 Configuration du projet Jenkins CI/CD Demo"
echo "============================================="

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    log_success "Docker trouvé: $(docker --version)"
    
    # Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    log_success "Docker Compose trouvé: $(docker-compose --version)"
    
    # Node.js (pour le développement local)
    if ! command -v node &> /dev/null; then
        log_warning "Node.js n'est pas installé. Recommandé pour le développement local."
    else
        log_success "Node.js trouvé: $(node --version)"
    fi
    
    # Git
    if ! command -v git &> /dev/null; then
        log_error "Git n'est pas installé. Veuillez l'installer d'abord."
        exit 1
    fi
    log_success "Git trouvé: $(git --version)"
}

# Configuration de l'environnement
setup_environment() {
    log_info "Configuration de l'environnement..."
    
    # Création du fichier .env s'il n'existe pas
    if [ ! -f ".env" ]; then
        log_info "Création du fichier .env..."
        cp src/.env .env
        log_success "Fichier .env créé"
    fi
    
    # Création des répertoires nécessaires
    mkdir -p {
        logs,
        reports,
        artifacts,
        nginx,
        scripts/sql
    }
    log_success "Répertoires créés"
    
    # Configuration des permissions
    chmod +x scripts/*.sh
    log_success "Permissions configurées"
}

# Installation des dépendances Node.js
install_dependencies() {
    log_info "Installation des dépendances Node.js..."
    
    if [ -d "src" ] && [ -f "src/package.json" ]; then
        cd src
        npm install
        cd ..
        log_success "Dépendances Node.js installées"
    else
        log_warning "Répertoire src ou package.json non trouvé"
    fi
}

# Configuration de Jenkins
setup_jenkins() {
    log_info "Configuration de Jenkins..."
    
    # Création du répertoire Jenkins s'il n'existe pas
    mkdir -p jenkins/jobs/demo-pipeline
    
    # Copie de la configuration Jenkins
    if [ -f "jenkins/Jenkinsfile" ]; then
        log_success "Jenkinsfile trouvé"
    else
        log_warning "Jenkinsfile non trouvé dans jenkins/"
    fi
    
    # Configuration des plugins Jenkins (liste)
    cat > jenkins/plugins.txt << EOF
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
EOF
    
    log_success "Configuration Jenkins préparée"
}

# Configuration de la base de données
setup_database() {
    log_info "Configuration de la base de données..."
    
    # Script d'initialisation de la base de données
    cat > scripts/init-db.sql << EOF
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
EOF
    
    log_success "Script de base de données créé"
}

# Configuration Nginx
setup_nginx() {
    log_info "Configuration Nginx..."
    
    mkdir -p nginx/ssl
    
    cat > nginx/nginx.conf << EOF
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
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        location / {
            proxy_pass http://demo-app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
    
    log_success "Configuration Nginx créée"
}

# Fonction principale
main() {
    echo
    log_info "Début de la configuration..."
    echo
    
    check_prerequisites
    setup_environment
    install_dependencies
    setup_jenkins
    setup_database
    setup_nginx
    
    echo
    log_success "Configuration terminée avec succès!"
    echo
    log_info "Prochaines étapes:"
    echo "  1. Démarrer les services: docker-compose up -d"
    echo "  2. Accéder à Jenkins: http://localhost:8080"
    echo "  3. Accéder à l'application: http://localhost:3000"
    echo "  4. Accéder à SonarQube: docker-compose --profile analysis up -d"
    echo
    log_info "Pour plus d'informations, consultez le README.md"
}

# Exécution du script
main "$@"