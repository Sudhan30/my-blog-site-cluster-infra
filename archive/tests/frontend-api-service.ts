// Frontend API Service for Same-Domain Setup
// This service uses the reverse proxy setup where API calls go to /api/

export class BlogApiService {
  private baseUrl = '/api'; // Same domain, just /api path
  private clientId = this.getOrCreateClientId();

  private getOrCreateClientId(): string {
    let clientId = localStorage.getItem('blog_client_id');
    if (!clientId) {
      clientId = crypto.randomUUID();
      localStorage.setItem('blog_client_id', clientId);
    }
    return clientId;
  }

  private async makeRequest<T>(url: string, options?: RequestInit): Promise<T> {
    try {
      const response = await fetch(`${this.baseUrl}${url}`, {
        ...options,
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers,
        },
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('API request failed:', error);
      throw error;
    }
  }

  // Posts API
  async getPosts(page = 1, limit = 10): Promise<{
    posts: Array<{
      id: number;
      slug: string;
      title: string;
      content: string;
      created_at: string;
      comment_count: number;
      like_count: number;
    }>;
    pagination: {
      page: number;
      limit: number;
      total: number;
      pages: number;
    };
  }> {
    return this.makeRequest(`/posts?page=${page}&limit=${limit}`);
  }

  async getPost(slug: string): Promise<{
    post: {
      id: number;
      slug: string;
      title: string;
      content: string;
      created_at: string;
      comment_count: number;
      like_count: number;
    };
  }> {
    return this.makeRequest(`/posts/${slug}`);
  }

  // Comments API
  async getComments(postId: number, page = 1, limit = 10): Promise<{
    postId: number;
    comments: Array<{
      id: number;
      display_name: string;
      content: string;
      created_at: string;
    }>;
    pagination: {
      page: number;
      limit: number;
      total: number;
      pages: number;
    };
  }> {
    return this.makeRequest(`/posts/${postId}/comments?page=${page}&limit=${limit}`);
  }

  async addComment(postId: number, content: string, displayName: string): Promise<{
    success: boolean;
    comment: {
      id: number;
      created_at: string;
    };
    clientId: string;
  }> {
    return this.makeRequest(`/posts/${postId}/comments`, {
      method: 'POST',
      body: JSON.stringify({
        content,
        displayName,
        clientId: this.clientId,
      }),
    });
  }

  // Likes API
  async getLikes(postId: number): Promise<{
    postId: number;
    likes: number;
    cached: boolean;
  }> {
    return this.makeRequest(`/posts/${postId}/likes`);
  }

  async likePost(postId: number): Promise<{
    success: boolean;
    likes: number;
    clientId: string;
  }> {
    return this.makeRequest(`/posts/${postId}/like`, {
      method: 'POST',
      body: JSON.stringify({
        clientId: this.clientId,
      }),
    });
  }

  // Analytics API
  async getAnalytics(period: '1d' | '7d' | '30d' | '90d' = '7d'): Promise<{
    totalLikes: number;
    totalComments: number;
    likesByDay: Array<{
      date: string;
      count: string;
    }>;
    commentsByDay: Array<{
      date: string;
      count: string;
    }>;
    period: string;
  }> {
    return this.makeRequest(`/analytics?period=${period}`);
  }

  // Health check
  async healthCheck(): Promise<{
    status: string;
    timestamp: string;
    uptime: number;
    memory: {
      rss: number;
      heapTotal: number;
      heapUsed: number;
    };
  }> {
    return this.makeRequest('/health');
  }
}

// Usage examples:

// Initialize the service
const apiService = new BlogApiService();

// Get all posts
const posts = await apiService.getPosts();

// Get single post
const post = await apiService.getPost('my-first-blog');

// Get comments for a post
const comments = await apiService.getComments(1);

// Add a comment
const newComment = await apiService.addComment(1, 'Great post!', 'John Doe');

// Get likes for a post
const likes = await apiService.getLikes(1);

// Like a post
const likeResult = await apiService.likePost(1);

// Get analytics
const analytics = await apiService.getAnalytics('7d');

// Health check
const health = await apiService.healthCheck();
