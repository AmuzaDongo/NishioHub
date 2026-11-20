import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1",
});

// Interceptor to attach token
api.interceptors.request.use((config) => {
  const storedUser = localStorage.getItem("nishioHub_user");
  if (storedUser) {
    const parsedUser = JSON.parse(storedUser);
    if (parsedUser?.access_token) {
      config.headers.Authorization = `Bearer ${parsedUser.access_token}`;
    }
  }
  return config;
}, (error) => {
  return Promise.reject(error);
});

// Clear a stale session when the API rejects the token. The login/register
// calls also return 401 on bad credentials, so only clear when a token existed.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.response?.status === 401 && localStorage.getItem("nishioHub_user")) {
      localStorage.removeItem("nishioHub_user");
    }
    return Promise.reject(error);
  }
);

export default api;
