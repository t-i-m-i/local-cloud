# Recipe for the app's image. An image is a frozen snapshot (OS + Node + our
# code) that Docker can start as a container anywhere.

# Start from an official small Linux image that already has Node 24 installed.
FROM node:24-alpine

# Everything below happens inside /app in the image.
WORKDIR /app

# Copy only the dependency lists first. Docker caches each step, so the slow
# "npm ci" step is re-run only when these two files change, not on every code edit.
COPY package.json package-lock.json ./

# Install only production dependencies (no TypeScript tooling needed to run).
RUN npm ci --omit=dev

# Now copy the application code itself.
COPY src ./src

# Do not run as root inside the container: if the app were hacked, the attacker
# would have fewer rights. The node image ships with a ready-made "node" user.
USER node

# Documentation only: the app listens on port 3000.
EXPOSE 3000

# The command that runs when the container starts. Node 24 runs .ts files directly.
CMD ["node", "src/server.ts"]
