# Docker Image Naming Convention

## 🎯 **Proper Image Separation**

Your Docker images are now properly separated to avoid conflicts:

### **Image Names:**

1. **`blog-site`** - Angular Frontend
   - **Repository**: `docker.io/sudhan03/blog-site`
   - **Source**: Your `my-blog-site-sudhanverse` repository
   - **Purpose**: Serves your Angular blog frontend
   - **Deployment**: `clusters/prod/apps/blog/deployment.yaml`

2. **`blog-site-backend`** - Node.js API Backend
   - **Repository**: `docker.io/sudhan03/blog-site-backend`
   - **Source**: This repository (`my-blog-site-cluster-infra`)
   - **Purpose**: Handles API requests, database operations
   - **Deployment**: `clusters/prod/apps/backend/deployment.yaml`

3. **`blog-site-infra`** - Infrastructure Components (Future Use)
   - **Repository**: `docker.io/sudhan03/blog-site-infra`
   - **Purpose**: For any infrastructure-specific components
   - **Status**: Reserved for future use

## 📋 **Updated Files:**

### **Kubernetes Manifests:**
- ✅ `clusters/prod/apps/blog/deployment.yaml` → Uses `blog-site`
- ✅ `clusters/prod/apps/backend/deployment.yaml` → Uses `blog-site-backend`
- ✅ `clusters/prod/apps/backend/imagerepository.yaml` → Monitors `blog-site-backend`

### **GitHub Actions Workflows:**
- ✅ `.github/workflows/build-and-deploy.yml` → Builds both images
- ✅ `.github/workflows/blog-update-listener.yml` → Updates `blog-site`
- ✅ `.github/workflows/build-blog-from-external.yml` → Builds `blog-site`

### **Flux Image Automation:**
- ✅ Blog ImageRepository → Monitors `docker.io/sudhan03/blog-site`
- ✅ Backend ImageRepository → Monitors `docker.io/sudhan03/blog-site-backend`

## 🔄 **Build & Deploy Flow:**

### **Blog Frontend Updates:**
1. **Push to** `my-blog-site-sudhanverse` repository
2. **Builds** `docker.io/sudhan03/blog-site:latest`
3. **Triggers** webhook to this repository
4. **Updates** blog deployment manifest
5. **Flux CD** deploys new blog image

### **Backend Updates:**
1. **Push to** this repository (`my-blog-site-cluster-infra`)
2. **Builds** `docker.io/sudhan03/blog-site-backend:latest`
3. **Flux Image Automation** detects new image
4. **Updates** backend deployment automatically
5. **Flux CD** deploys new backend image

## 🎉 **Benefits:**

✅ **No More Conflicts** - Each component has its own image  
✅ **Independent Updates** - Frontend and backend can be updated separately  
✅ **Clear Separation** - Easy to identify which image serves what purpose  
✅ **Scalable** - Ready for additional components (blog-site-infra)  

## 🚀 **Next Steps:**

1. **Commit changes**: `git add . && git commit -m "Update Docker image names"`
2. **Push to trigger**: `git push origin main`
3. **Update your blog repo** with the new workflow
4. **Test the integration** by making a change to your blog repo

Your infrastructure is now properly organized with clear image separation! 🎯
