
# ---------- Stage 1: build the React frontend into static files ----------
# 1. Base image for the build step so stage 02 can pull from it
#       named: build 
FROM node:18-alpine AS build    

# 2. Working directory for the build
WORKDIR /app

# Install dependencies first [cached layer unless those files (below) change]
COPY frontend/package.json frontend/package-lock.json frontend/.npmrc ./
RUN npm ci

# Copy the frontend source and produce the static build in /app/build
COPY frontend/ ./
ARG REACT_APP_API_BASE=https://rcc-backend-671k.onrender.com/api
ENV REACT_APP_API_BASE=$REACT_APP_API_BASE
ARG REACT_APP_GOOGLE_CLIENT_ID=19997375921-2gilqn8bicr3tc93j66gkthbvcm88f8f.apps.googleusercontent.com
ENV REACT_APP_GOOGLE_CLIENT_ID=$REACT_APP_GOOGLE_CLIENT_ID
RUN npm run build

# ---------- Stage 2: serve the static site with Nginx ----------
# 1. Base web server image
FROM nginx:alpine

# 2. Clean the default Nginx index files
RUN rm -rf /usr/share/nginx/html/*

# 3. Copy the site into the Nginx document root (+ SPA routing config)
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html

# 4. Expose the standard web server port
EXPOSE 80

# 5. Run Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
