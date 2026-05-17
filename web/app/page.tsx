"use client";

import Link from "next/link";
import { IPhoneMockup } from "@/components/iphone-mockup";

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-white via-purple-50 to-orange-50">
      {/* Navigation */}
      <nav className="flex items-center justify-between px-6 py-4 max-w-7xl mx-auto">
        <div className="text-2xl font-bold text-primary">Tetamu</div>
        <div className="flex gap-6">
          <Link href="/#features" className="text-gray-600 hover:text-primary">
            Features
          </Link>
          <Link href="/about" className="text-gray-600 hover:text-primary">
            About
          </Link>
          <Link href="/support" className="text-gray-600 hover:text-primary">
            Support
          </Link>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="px-6 py-12 md:py-20 max-w-7xl mx-auto">
        <div className="grid md:grid-cols-2 gap-8 items-center">
          <div>
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6 text-balance">
              Capture moments that disappear
            </h1>
            <p className="text-lg md:text-xl text-gray-600 mb-8 text-pretty">
              Share ephemeral photos with friends at weddings, parties, and events. 
              Photos auto-delete after being viewed—keeping memories fresh and exclusive.
            </p>
            <div className="flex flex-wrap gap-4">
              <a 
                href="https://apps.apple.com/fr/app/disposable-app/id6670355967?l=en-GB"
                target="_blank"
                rel="noopener noreferrer"
                className="bg-primary text-white px-8 py-3 rounded-lg font-semibold hover:bg-opacity-90 transition-all"
              >
                Download App
              </a>
              <Link 
                href="/about"
                className="border-2 border-primary text-primary px-8 py-3 rounded-lg font-semibold hover:bg-primary hover:text-white transition-all"
              >
                Learn More
              </Link>
            </div>
          </div>
          <div className="flex justify-center">
            <IPhoneMockup
              screenshot1="/screenshots/wedding-camera.png"
              screenshot2="/screenshots/house-party.png"
            />
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="px-6 py-20 bg-white">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">
            Why Tetamu?
          </h2>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              {
                title: "Ephemeral Photos",
                description: "Photos disappear after viewing, keeping moments exclusive",
              },
              {
                title: "Easy Sharing",
                description: "Share QR codes or links—no app download needed for guests",
              },
              {
                title: "Event-Based",
                description: "Organize photos by events—weddings, parties, celebrations",
              },
            ].map((feature, i) => (
              <div key={i} className="p-6 border border-gray-200 rounded-lg">
                <h3 className="text-xl font-semibold text-gray-900 mb-3">
                  {feature.title}
                </h3>
                <p className="text-gray-600">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="px-6 py-12 bg-gray-900 text-white">
        <div className="max-w-7xl mx-auto grid md:grid-cols-4 gap-8">
          <div>
            <h3 className="font-bold mb-4">Tetamu</h3>
            <p className="text-gray-400">Share ephemeral moments with friends</p>
          </div>
          <div>
            <h4 className="font-semibold mb-4">Product</h4>
            <ul className="text-gray-400 space-y-2">
              <li><Link href="/#features" className="hover:text-white">Features</Link></li>
              <li><Link href="/auth/login" className="hover:text-white">Login</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-4">Legal</h4>
            <ul className="text-gray-400 space-y-2">
              <li><Link href="/privacy" className="hover:text-white">Privacy</Link></li>
              <li><Link href="/terms" className="hover:text-white">Terms</Link></li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold mb-4">Contact</h4>
            <p className="text-gray-400">hello@disposable.app</p>
          </div>
        </div>
        <div className="mt-12 pt-8 border-t border-gray-700 text-center text-gray-400">
          <p>&copy; 2026 Tetamu. All rights reserved.</p>
        </div>
      </footer>
    </main>
  );
}
