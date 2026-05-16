export default function Support() {
  return (
    <main className="min-h-screen bg-white">
      <nav className="flex items-center gap-4 px-6 py-4 max-w-7xl mx-auto">
        <a href="/" className="text-primary font-bold hover:underline">
          ← Back
        </a>
        <h1 className="text-2xl font-bold">Support</h1>
      </nav>

      <article className="max-w-3xl mx-auto px-6 py-12">
        <h2 className="text-3xl font-bold mb-8">Help & Support</h2>

        <div className="space-y-8">
          <section>
            <h3 className="text-2xl font-semibold mb-4">Getting Started</h3>
            <div className="space-y-4">
              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  How do I create an event?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Download the Disposable app, tap the + button, and fill in your event details. 
                  You&apos;ll get a shareable QR code and link instantly.
                </p>
              </details>

              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  How do guests upload photos?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Guests scan the QR code or tap your shared link. They can upload photos instantly 
                  without downloading the app or creating an account.
                </p>
              </details>

              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  When do photos disappear?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  You set the expiration time when creating the event. After that time, 
                  all photos automatically disappear forever. This is what makes Disposable special!
                </p>
              </details>
            </div>
          </section>

          <section>
            <h3 className="text-2xl font-semibold mb-4">Features</h3>
            <div className="space-y-4">
              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  Can I retake photos?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Yes! The app lets guests retake photos as many times as needed before uploading. 
                  Get the perfect shot every time.
                </p>
              </details>

              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  Can I edit my event after creating it?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Yes, you can edit most event details before guests start uploading. 
                  Some settings like expiration time are locked for security.
                </p>
              </details>

              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  Is there a limit to photos?
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  You can set a maximum number of photos when creating the event. 
                  Common limits are 10-100 photos depending on your plan.
                </p>
              </details>
            </div>
          </section>

          <section>
            <h3 className="text-2xl font-semibold mb-4">Troubleshooting</h3>
            <div className="space-y-4">
              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  Photos aren&apos;t uploading
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Check your internet connection. Ensure the event hasn&apos;t expired and 
                  the photo limit hasn&apos;t been reached. Try uploading again.
                </p>
              </details>

              <details className="border border-gray-200 rounded-lg p-4 cursor-pointer hover:bg-gray-50">
                <summary className="font-semibold text-gray-900">
                  I can&apos;t see the QR code
                </summary>
                <p className="text-gray-600 mt-4 leading-relaxed">
                  Make sure location services are enabled. Try refreshing the app. 
                  Contact support if the issue persists.
                </p>
              </details>
            </div>
          </section>

          <section className="mt-12 pt-8 border-t border-gray-200">
            <h3 className="text-2xl font-semibold mb-4">Still Need Help?</h3>
            <p className="text-gray-600 mb-4">
              We&apos;re here to help! Reach out to our support team:
            </p>
            <div className="space-y-3">
              <p>
                <strong>Email:</strong>{" "}
                <a href="mailto:support@disposable.app" className="text-primary hover:underline">
                  support@disposable.app
                </a>
              </p>
              <p>
                <strong>Response time:</strong> Usually within 24 hours
              </p>
            </div>
          </section>
        </div>
      </article>
    </main>
  );
}
