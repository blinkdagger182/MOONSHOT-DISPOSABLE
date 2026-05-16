export default function Privacy() {
  return (
    <main className="min-h-screen bg-white">
      <nav className="flex items-center gap-4 px-6 py-4 max-w-7xl mx-auto">
        <a href="/" className="text-primary font-bold hover:underline">
          ← Back
        </a>
        <h1 className="text-2xl font-bold">Privacy Policy</h1>
      </nav>

      <article className="max-w-3xl mx-auto px-6 py-12">
        <p className="text-gray-600 mb-8">Last updated: May 2026</p>

        <h2 className="text-2xl font-bold mb-4">Introduction</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          Disposable (&quot;we,&quot; &quot;us,&quot; or &quot;our&quot;) operates the Disposable application. 
          This page informs you of our policies regarding the collection, use, and disclosure of personal data 
          when you use our service.
        </p>

        <h2 className="text-2xl font-bold mb-4">Information Collection and Use</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          We collect information you provide directly, such as when you create an account, 
          participate in an event, or contact us. This may include your email, name, photos, 
          and profile information.
        </p>

        <h2 className="text-2xl font-bold mb-4">Photo Data</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          Uploaded photos are stored temporarily and automatically deleted after the event 
          concludes or after the retention period expires. We do not store photos permanently.
        </p>

        <h2 className="text-2xl font-bold mb-4">Contact Us</h2>
        <p className="text-gray-700">
          If you have questions about this Privacy Policy, please contact us at privacy@disposable.app
        </p>
      </article>
    </main>
  );
}
