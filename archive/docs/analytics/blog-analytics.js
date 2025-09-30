/**
 * Blog Analytics Library
 * Tracks pageviews, clicks, scroll depth, and user sessions
 */

class BlogAnalytics {
  constructor(config = {}) {
    this.config = {
      apiEndpoint: config.apiEndpoint || '/api/analytics',
      batchSize: config.batchSize || 10,
      flushInterval: config.flushInterval || 5000,
      debug: config.debug || false,
      ...config
    };
    
    this.uuid = this.getOrCreateUUID();
    this.sessionId = this.getOrCreateSessionId();
    this.eventQueue = [];
    this.sessionStartTime = Date.now();
    this.pageStartTime = Date.now();
    this.scrollDepth = 0;
    this.maxScrollDepth = 0;
    this.clickCount = 0;
    this.pageViewCount = 0;
    
    this.init();
  }
  
  // Initialize analytics tracking
  init() {
    this.trackPageView();
    this.setupEventListeners();
    this.startSession();
    this.startPeriodicFlush();
    this.trackPageExit();
  }
  
  // Get or create user UUID
  getOrCreateUUID() {
    let uuid = localStorage.getItem('blog_analytics_uuid');
    if (!uuid) {
      uuid = this.generateUUID();
      localStorage.setItem('blog_analytics_uuid', uuid);
    }
    return uuid;
  }
  
  // Get or create session ID
  getOrCreateSessionId() {
    let sessionId = sessionStorage.getItem('blog_analytics_session');
    if (!sessionId) {
      sessionId = this.generateUUID();
      sessionStorage.setItem('blog_analytics_session', sessionId);
    }
    return sessionId;
  }
  
  // Generate UUID v4
  generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
  
  // Track page view
  trackPageView() {
    const pageData = {
      uuid: this.uuid,
      session_id: this.sessionId,
      event_type: 'pageview',
      page_url: window.location.href,
      page_title: document.title,
      viewport_width: window.innerWidth,
      viewport_height: window.innerHeight,
      referrer: document.referrer,
      metadata: {
        user_agent: navigator.userAgent,
        language: navigator.language,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
      }
    };
    
    this.pageViewCount++;
    this.pageStartTime = Date.now();
    this.queueEvent(pageData);
    
    if (this.config.debug) {
      console.log('📊 Page view tracked:', pageData);
    }
  }
  
  // Setup event listeners
  setupEventListeners() {
    // Track clicks
    document.addEventListener('click', (e) => {
      this.trackClick(e);
    });
    
    // Track scroll depth
    let scrollTimeout;
    window.addEventListener('scroll', () => {
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(() => {
        this.trackScrollDepth();
      }, 100);
    });
    
    // Track time on page
    setInterval(() => {
      this.trackTimeOnPage();
    }, 30000); // Every 30 seconds
  }
  
  // Track click events
  trackClick(event) {
    const element = event.target;
    const clickData = {
      uuid: this.uuid,
      session_id: this.sessionId,
      event_type: 'click',
      page_url: window.location.href,
      page_title: document.title,
      element_id: element.id || null,
      element_class: element.className || null,
      element_text: element.textContent?.trim().substring(0, 100) || null,
      element_type: element.tagName.toLowerCase(),
      click_x: event.clientX,
      click_y: event.clientY,
      viewport_width: window.innerWidth,
      viewport_height: window.innerHeight,
      metadata: {
        href: element.href || null,
        alt: element.alt || null,
        title: element.title || null
      }
    };
    
    this.clickCount++;
    this.queueEvent(clickData);
    
    if (this.config.debug) {
      console.log('🖱️ Click tracked:', clickData);
    }
  }
  
  // Track scroll depth
  trackScrollDepth() {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const documentHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrollPercent = Math.round((scrollTop / documentHeight) * 100);
    
    if (scrollPercent > this.maxScrollDepth) {
      this.maxScrollDepth = scrollPercent;
      
      const scrollData = {
        uuid: this.uuid,
        session_id: this.sessionId,
        event_type: 'scroll',
        page_url: window.location.href,
        page_title: document.title,
        scroll_depth: scrollPercent,
        viewport_width: window.innerWidth,
        viewport_height: window.innerHeight
      };
      
      this.queueEvent(scrollData);
      
      if (this.config.debug) {
        console.log('📜 Scroll tracked:', scrollData);
      }
    }
  }
  
  // Track time on page
  trackTimeOnPage() {
    const timeOnPage = Date.now() - this.pageStartTime;
    
    const timeData = {
      uuid: this.uuid,
      session_id: this.sessionId,
      event_type: 'time_on_page',
      page_url: window.location.href,
      page_title: document.title,
      time_on_page: Math.round(timeOnPage / 1000), // Convert to seconds
      viewport_width: window.innerWidth,
      viewport_height: window.innerHeight
    };
    
    this.queueEvent(timeData);
    
    if (this.config.debug) {
      console.log('⏱️ Time on page tracked:', timeData);
    }
  }
  
  // Start user session
  startSession() {
    const sessionData = {
      session_id: this.sessionId,
      uuid: this.uuid,
      entry_page: window.location.href,
      referrer: document.referrer,
      device_type: this.getDeviceType(),
      browser: this.getBrowser(),
      os: this.getOS()
    };
    
    this.sendEvent(`${this.config.apiEndpoint}/session`, sessionData);
    
    if (this.config.debug) {
      console.log('🚀 Session started:', sessionData);
    }
  }
  
  // Track page exit
  trackPageExit() {
    window.addEventListener('beforeunload', () => {
      this.endSession();
    });
    
    // Fallback for mobile browsers
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') {
        this.endSession();
      }
    });
  }
  
  // End user session
  endSession() {
    const totalTime = Date.now() - this.sessionStartTime;
    
    const sessionEndData = {
      session_id: this.sessionId,
      exit_page: window.location.href,
      total_time: Math.round(totalTime / 1000),
      page_views: this.pageViewCount,
      clicks: this.clickCount,
      scroll_depth: this.maxScrollDepth
    };
    
    // Send immediately (navigator.sendBeacon for reliability)
    if (navigator.sendBeacon) {
      navigator.sendBeacon(
        `${this.config.apiEndpoint}/session/end`,
        JSON.stringify(sessionEndData)
      );
    } else {
      this.sendEvent(`${this.config.apiEndpoint}/session/end`, sessionEndData, true);
    }
    
    if (this.config.debug) {
      console.log('🏁 Session ended:', sessionEndData);
    }
  }
  
  // Queue event for batch sending
  queueEvent(eventData) {
    this.eventQueue.push(eventData);
    
    if (this.eventQueue.length >= this.config.batchSize) {
      this.flushEvents();
    }
  }
  
  // Flush queued events
  flushEvents() {
    if (this.eventQueue.length === 0) return;
    
    const eventsToSend = [...this.eventQueue];
    this.eventQueue = [];
    
    this.sendEvent(`${this.config.apiEndpoint}/track`, {
      events: eventsToSend
    });
    
    if (this.config.debug) {
      console.log(`📤 Flushed ${eventsToSend.length} events`);
    }
  }
  
  // Start periodic flush
  startPeriodicFlush() {
    setInterval(() => {
      this.flushEvents();
    }, this.config.flushInterval);
  }
  
  // Send event to server
  async sendEvent(endpoint, data, sync = false) {
    try {
      const options = {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      };
      
      if (sync) {
        // Synchronous request for critical events
        const xhr = new XMLHttpRequest();
        xhr.open('POST', endpoint, false);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.send(JSON.stringify(data));
      } else {
        // Asynchronous request
        await fetch(endpoint, options);
      }
    } catch (error) {
      if (this.config.debug) {
        console.error('❌ Analytics error:', error);
      }
    }
  }
  
  // Track custom event
  trackCustom(eventName, metadata = {}) {
    const customData = {
      uuid: this.uuid,
      session_id: this.sessionId,
      event_type: 'custom',
      event_name: eventName,
      page_url: window.location.href,
      page_title: document.title,
      metadata: metadata
    };
    
    this.queueEvent(customData);
    
    if (this.config.debug) {
      console.log('🎯 Custom event tracked:', customData);
    }
  }
  
  // Get device type
  getDeviceType() {
    const width = window.innerWidth;
    if (width < 768) return 'mobile';
    if (width < 1024) return 'tablet';
    return 'desktop';
  }
  
  // Get browser name
  getBrowser() {
    const ua = navigator.userAgent;
    if (ua.includes('Chrome')) return 'Chrome';
    if (ua.includes('Firefox')) return 'Firefox';
    if (ua.includes('Safari')) return 'Safari';
    if (ua.includes('Edge')) return 'Edge';
    return 'Unknown';
  }
  
  // Get operating system
  getOS() {
    const ua = navigator.userAgent;
    if (ua.includes('Windows')) return 'Windows';
    if (ua.includes('Mac')) return 'macOS';
    if (ua.includes('Linux')) return 'Linux';
    if (ua.includes('Android')) return 'Android';
    if (ua.includes('iOS')) return 'iOS';
    return 'Unknown';
  }
  
  // Get analytics dashboard data
  async getDashboardData(days = 7) {
    try {
      const response = await fetch(`${this.config.apiEndpoint}/dashboard?days=${days}`);
      return await response.json();
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      return null;
    }
  }
}

// Auto-initialize if script is loaded
if (typeof window !== 'undefined') {
  window.BlogAnalytics = BlogAnalytics;
  
  // Auto-start analytics
  window.blogAnalytics = new BlogAnalytics({
    debug: false // Set to true for development
  });
  
  // Make it globally available
  window.trackEvent = (eventName, metadata) => {
    window.blogAnalytics.trackCustom(eventName, metadata);
  };
}
