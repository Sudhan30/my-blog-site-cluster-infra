# 🌐 Cloudflare Page Rules Configuration

## **Problem**: 
Cloudflare is blocking API requests with JavaScript challenges, preventing your backend from being accessible.

## **Solution**: Configure Page Rules to bypass challenges for API routes

### **Page Rules to Create in Cloudflare Dashboard:**

1. **Go to**: `https://dash.cloudflare.com/` → Your Domain → Page Rules

2. **Create these rules (in order of priority):**

#### **Rule 1: API Routes - Bypass Challenge**
```
URL Pattern: blog.sudharsana.dev/api/*
Settings:
  ✅ Security Level: Essentially Off
  ✅ Disable Security
  ✅ Cache Level: Bypass
  ✅ Browser Cache TTL: Respect Existing Headers
```

#### **Rule 2: Health Check - Bypass Challenge**
```
URL Pattern: blog.sudharsana.dev/api/health
Settings:
  ✅ Security Level: Essentially Off
  ✅ Disable Security
  ✅ Cache Level: Bypass
  ✅ Browser Cache TTL: Respect Existing Headers
```

#### **Rule 3: Metrics - Bypass Challenge**
```
URL Pattern: blog.sudharsana.dev/api/metrics
Settings:
  ✅ Security Level: Essentially Off
  ✅ Disable Security
  ✅ Cache Level: Bypass
  ✅ Browser Cache TTL: Respect Existing Headers
```

### **Alternative: Firewall Rules (More Granular)**

If you prefer Firewall Rules over Page Rules:

1. **Go to**: `https://dash.cloudflare.com/` → Your Domain → Security → WAF → Firewall Rules

2. **Create Rule**:
```
Field: URI Path
Operator: starts with
Value: /api/
Action: Bypass
```

## **Expected Results After Configuration:**

```bash
# These should work without challenges:
curl https://blog.sudharsana.dev/api/health
curl https://blog.sudharsana.dev/api/posts
curl https://blog.sudharsana.dev/api/posts/1/likes
```

## **Temporary Workaround (While Configuring):**

Use a different subdomain for API or disable Cloudflare proxy temporarily:

```bash
# If you have a direct IP or different subdomain:
curl http://your-server-ip:3001/health
# or
curl https://api.sudharsana.dev/health  # if you create this subdomain
```

## **Verification Steps:**

1. **Create the Page Rules** (takes 1-2 minutes to propagate)
2. **Test API endpoints**:
   ```bash
   curl https://blog.sudharsana.dev/api/health
   curl https://blog.sudharsana.dev/api/posts
   ```
3. **Check for JSON responses** instead of HTML challenge pages

## **Why This Happens:**

- **Cloudflare Bot Protection**: Treats API requests as potential bots
- **No User-Agent**: `curl` requests look automated
- **JavaScript Challenge**: Requires browser execution to pass
- **API Routes**: Need special handling for programmatic access

## **Best Practices:**

1. **Separate API Subdomain**: Consider `api.sudharsana.dev` for cleaner separation
2. **API Authentication**: Add API keys for additional security
3. **Rate Limiting**: Implement your own rate limiting in the backend
4. **Monitoring**: Watch Cloudflare analytics for blocked requests
