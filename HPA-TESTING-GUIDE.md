# HPA Testing Guide

This guide shows you how to test if your HorizontalPodAutoscaler (HPA) is working as expected.

## 🎯 Quick HPA Test

### 1. Check HPA Status
```bash
# Check if HPA exists and is configured
kubectl get hpa -n web -l app=blog

# Get detailed HPA information
kubectl describe hpa blog-hpa -n web
```

### 2. Check Current Pod Count
```bash
# See current number of pods
kubectl get pods -n web -l app=blog

# Watch pods in real-time
kubectl get pods -n web -l app=blog -w
```

### 3. Check Resource Usage
```bash
# Check current resource usage
kubectl top pods -n web -l app=blog

# Check node resource usage
kubectl top nodes
```

## 🚀 Manual Load Testing

### Method 1: Using hey (Recommended)
```bash
# Install hey if not already installed
go install github.com/rakyll/hey@latest

# Generate load for 5 minutes with 200 concurrent users
hey -z 300s -c 200 https://blog.sudharsana.dev/

# Generate load for 10 minutes with 100 concurrent users
hey -z 600s -c 100 https://blog.sudharsana.dev/
```

### Method 2: Using curl in a loop
```bash
# Generate load with curl
for i in {1..1000}; do
  curl -s https://blog.sudharsana.dev/ > /dev/null &
done
wait
```

### Method 3: Using Apache Bench (ab)
```bash
# Install apache2-utils if not already installed
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd                   # macOS

# Generate load with ab
ab -n 10000 -c 100 https://blog.sudharsana.dev/
```

## 📊 Monitoring HPA During Load Test

### Real-time Monitoring
```bash
# Watch HPA status in real-time
kubectl get hpa -n web -l app=blog -w

# Watch pods in real-time
kubectl get pods -n web -l app=blog -w

# Watch resource usage
watch kubectl top pods -n web -l app=blog
```

### Check HPA Events
```bash
# Check HPA scaling events
kubectl get events -n web --field-selector involvedObject.name=blog-hpa --sort-by='.lastTimestamp'

# Check all scaling events
kubectl get events -n web --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp'
```

## 🔍 What to Look For

### ✅ HPA is Working If:

1. **Pods Scale Up**: When you generate load, you should see:
   - CPU usage increases
   - HPA detects high CPU usage
   - New pods are created
   - Pod count increases

2. **Pods Scale Down**: When load decreases, you should see:
   - CPU usage decreases
   - HPA detects low CPU usage
   - Pods are terminated
   - Pod count decreases (but not below minimum)

3. **HPA Events**: You should see events like:
   ```
   SuccessfulRescale: New size: 4; reason: cpu resource utilization (percentage of request) above target
   SuccessfulRescale: New size: 2; reason: All metrics below target
   ```

### ❌ HPA is NOT Working If:

1. **No Scaling**: Pod count remains constant regardless of load
2. **No Events**: No scaling events in HPA
3. **Error Messages**: HPA shows error conditions
4. **Metrics Issues**: "unknown" or "0%" CPU utilization

## 🛠️ Troubleshooting

### Check HPA Configuration
```bash
# Verify HPA configuration
kubectl get hpa blog-hpa -n web -o yaml

# Check if metrics server is running
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

### Check Deployment Resources
```bash
# Verify deployment has resource requests
kubectl get deployment blog -n web -o yaml | grep -A 10 resources
```

### Check Metrics Server
```bash
# Check if metrics server is available
kubectl top nodes
kubectl top pods -n web -l app=blog
```

## 📈 Expected Behavior

### During Load Test:
1. **Initial State**: 2 pods (minimum)
2. **Load Applied**: CPU usage increases
3. **Scaling Up**: HPA creates more pods (up to 10 maximum)
4. **Load Removed**: CPU usage decreases
5. **Scaling Down**: HPA removes pods (down to 2 minimum)

### Timeline:
- **0-30s**: Load applied, CPU usage increases
- **30-60s**: HPA detects high CPU, starts scaling up
- **60-120s**: New pods created, load distributed
- **120-180s**: Load removed, CPU usage decreases
- **180-240s**: HPA detects low CPU, starts scaling down
- **240-300s**: Pods removed, back to minimum

## 🎯 Quick Test Commands

### Run Complete Test
```bash
# Use the automated test script
./test-hpa-functionality.sh test

# Or run individual tests
./test-hpa-functionality.sh check
./test-hpa-functionality.sh cpu-load 300
./test-hpa-functionality.sh http-load 300 50
```

### Manual Test Sequence
```bash
# 1. Check initial status
kubectl get hpa -n web -l app=blog
kubectl get pods -n web -l app=blog

# 2. Generate load
hey -z 300s -c 200 https://blog.sudharsana.dev/ &

# 3. Monitor scaling
kubectl get hpa -n web -l app=blog -w

# 4. Check final status
kubectl get pods -n web -l app=blog
kubectl get events -n web --field-selector involvedObject.name=blog-hpa
```

## 📊 Performance Expectations

### Good HPA Performance:
- **Scale Up Time**: 1-3 minutes after load applied
- **Scale Down Time**: 3-5 minutes after load removed
- **CPU Target**: Should maintain around 60% CPU usage
- **Pod Count**: Should scale between 2-10 pods based on load

### Load Test Results:
- **200 concurrent users**: Should scale to 4-6 pods
- **100 concurrent users**: Should scale to 3-4 pods
- **50 concurrent users**: Should scale to 2-3 pods

## 🚨 Common Issues

### Issue 1: HPA Not Scaling
**Symptoms**: Pod count remains constant
**Solutions**:
- Check if metrics server is running
- Verify deployment has resource requests
- Check HPA configuration

### Issue 2: Slow Scaling
**Symptoms**: Takes too long to scale up/down
**Solutions**:
- Adjust HPA stabilization windows
- Check cluster resource availability
- Verify metrics server performance

### Issue 3: No Metrics
**Symptoms**: CPU utilization shows as "unknown"
**Solutions**:
- Restart metrics server
- Check metrics server logs
- Verify node metrics collection

## 🎉 Success Criteria

Your HPA is working correctly if:

✅ **Pods scale up** when load increases  
✅ **Pods scale down** when load decreases  
✅ **CPU utilization** is maintained around target  
✅ **Scaling events** are logged  
✅ **Performance** remains stable during scaling  
✅ **No errors** in HPA status  

---

**Happy Testing!** 🚀

*This guide helps you verify that your HPA is working as expected and can handle load automatically.*
