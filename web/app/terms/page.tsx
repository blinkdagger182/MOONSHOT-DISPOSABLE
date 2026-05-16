export default function Terms() {
  return (
    <main className="min-h-screen bg-white">
      <nav className="flex items-center gap-4 px-6 py-4 max-w-7xl mx-auto">
        <a href="/" className="text-primary font-bold hover:underline">
          ← Back
        </a>
        <h1 className="text-2xl font-bold">Terms of Service</h1>
      </nav>

      <article className="max-w-3xl mx-auto px-6 py-12">
        <p className="text-gray-600 mb-8">Last updated: May 2026</p>

        <h2 className="text-2xl font-bold mb-4">Agreement to Terms</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          By accessing and using Disposable, you accept and agree to be bound by the terms 
          and provision of this agreement. If you do not agree to abide by the above, 
          please do not use this service.
        </p>

        <h2 className="text-2xl font-bold mb-4">Use License</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          Permission is granted to temporarily download one copy of the materials (information or software) 
          on Disposable&apos;s service for personal, non-commercial transitory viewing only. 
          This is the grant of a license, not a transfer of title, and under this license you may not:
        </p>
        <ul className="list-disc list-inside space-y-2 text-gray-700 mb-6">
          <li>Modify or copy the materials</li>
          <li>Use the materials for any commercial purpose or for any public display</li>
          <li>Attempt to decompile or reverse engineer any software contained on the service</li>
          <li>Remove any copyright or other proprietary notations from the materials</li>
        </ul>

        <h2 className="text-2xl font-bold mb-4">Photo Ownership</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          Users retain ownership of photos they upload. By uploading to Disposable, 
          you grant us a license to store and display these photos for the duration of the event.
        </p>

        <h2 className="text-2xl font-bold mb-4">Disclaimer</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          The materials on Disposable&apos;s service are provided on an &apos;as is&apos; basis. 
          Disposable makes no warranties, expressed or implied, and hereby disclaims and negates 
          all other warranties including, without limitation, implied warranties or conditions of 
          merchantability, fitness for a particular purpose, or non-infringement of intellectual property.
        </p>

        <h2 className="text-2xl font-bold mb-4">Contact Us</h2>
        <p className="text-gray-700">
          If you have questions about these Terms, please contact us at legal@disposable.app
        </p>
      </article>
    </main>
  );
}
