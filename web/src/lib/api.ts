/**
 * High-Performance API Client for Khu Nyi Kal Sal Web Command Center.
 * Features automatic Bearer token injection, session handling, keepalive, and SWR fetchers.
 */

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "https://khunyikalsal-production.up.railway.app/api";

export interface ApiResponse<T = any> {
  data?: T;
  error?: string;
  status: number;
}

class ApiClient {
  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      "Content-Type": "application/json",
    };
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("admin_access_token");
      if (token) {
        headers["Authorization"] = `Bearer ${token}`;
      }
    }
    return headers;
  }

  async request<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const headers = { ...this.getHeaders(), ...(options.headers || {}) };

    try {
      const res = await fetch(url, {
        ...options,
        headers,
      });

      if (res.status === 401) {
        if (typeof window !== "undefined" && !endpoint.includes("/auth/login")) {
          localStorage.removeItem("admin_access_token");
          localStorage.removeItem("admin_user");
          window.location.href = "/login?expired=true";
        }
      }

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({ detail: res.statusText }));
        let message = "An unexpected error occurred.";
        if (typeof errorData.detail === "string") {
          message = errorData.detail;
        } else if (Array.isArray(errorData.detail)) {
          message = errorData.detail
            .map((e: any) => {
              const field = Array.isArray(e.loc) ? e.loc[e.loc.length - 1] : "";
              const msg = (e.msg || "").replace(/^Value error,\s*/i, "");
              return field && field !== "body"
                ? `${field.charAt(0).toUpperCase() + field.slice(1)}: ${msg}`
                : msg;
            })
            .filter(Boolean)
            .join(" | ");
        } else if (typeof errorData.detail === "object" && errorData.detail !== null) {
          message = errorData.detail.message || JSON.stringify(errorData.detail);
        }
        throw new Error(message);
      }

      return await res.json();
    } catch (err: any) {
      throw new Error(err.message || "Network connection error.");
    }
  }

  get<T = any>(endpoint: string) {
    return this.request<T>(endpoint, { method: "GET" });
  }

  post<T = any>(endpoint: string, body?: any) {
    return this.request<T>(endpoint, {
      method: "POST",
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  put<T = any>(endpoint: string, body?: any) {
    return this.request<T>(endpoint, {
      method: "PUT",
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  delete<T = any>(endpoint: string) {
    return this.request<T>(endpoint, { method: "DELETE" });
  }
}

export const api = new ApiClient();

// SWR Global Fetcher
export const fetcher = (url: string) => api.get(url);
