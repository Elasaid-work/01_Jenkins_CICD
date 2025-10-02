# Stage 1: Build stage
FROM node:18-alpine AS builder

# Métadonnées
LABEL maintainer="DevOps Engineer"
LABEL description="Jenkins CI/CD Demo Application"
LABEL version="1.0.0"

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances
COPY src/package*.json ./

# Installer les dépendances (y compris devDependencies pour les tests)
RUN npm ci --only=production && npm cache clean --force

# Copier le code source
COPY src/ .

# Stage 2: Production stage
FROM node:18-alpine AS production

# Installer dumb-init pour une gestion correcte des signaux
RUN apk add --no-cache dumb-init

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Définir le répertoire de travail
WORKDIR /app

# Changer la propriété du répertoire
RUN chown -R nodejs:nodejs /app

# Basculer vers l'utilisateur non-root
USER nodejs

# Copier les fichiers depuis le stage builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./
COPY --from=builder --chown=nodejs:nodejs /app/app.js ./

# Exposer le port
EXPOSE 3000

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Commande de démarrage avec dumb-init
CMD ["dumb-init", "node", "app.js"]