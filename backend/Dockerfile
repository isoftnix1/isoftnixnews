# ---- Stage 1: Builder ----
FROM node:20-alpine AS builder

WORKDIR /app

# Copy only package files first for efficient layer caching
COPY package.json package-lock.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# ---- Stage 2: Production ----
FROM node:20-alpine AS production

WORKDIR /app

# Copy installed node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy all application source code
COPY . .

# Expose the port the app runs on
EXPOSE 5000

# Set NODE_ENV to production
ENV NODE_ENV=production

# Run as non-root user
USER node

# Start the server
CMD ["node", "server.js"]
