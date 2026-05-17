import type { Metadata, Viewport } from "next";
import "./globals.css";
import "../css/iphone-mockup.css";

export const metadata: Metadata = {
  title: "Tetamu - Event Photo Sharing",
  description:
    "Share ephemeral moments with friends. Capture, share, and watch memories disappear.",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Tetamu",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  minimumScale: 1,
  maximumScale: 5,
  userScalable: true,
  viewportFit: "cover",
  themeColor: "#000000",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="apple-touch-icon" href="/icon-192.png" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black" />
        <meta name="apple-mobile-web-app-title" content="Tetamu" />
      </head>
      <body className="bg-gray-50">{children}</body>
    </html>
  );
}
