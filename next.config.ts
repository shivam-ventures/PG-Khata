import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      {
        protocol: "https",
        // Supabase Storage public bucket URLs (tenant photos, ID documents, complaint photos)
        hostname: "*.supabase.co",
      },
    ],
  },
};

export default nextConfig;
