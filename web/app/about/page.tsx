export default function About() {
  return (
    <main className="min-h-screen bg-white">
      <nav className="flex items-center gap-4 px-6 py-4 max-w-7xl mx-auto">
        <a href="/" className="text-primary font-bold hover:underline">
          ← Back
        </a>
        <h1 className="text-2xl font-bold">About Disposable</h1>
      </nav>

      <article className="max-w-3xl mx-auto px-6 py-12">
        <h2 className="text-3xl font-bold mb-6">Our Mission</h2>
        <p className="text-gray-700 mb-6 leading-relaxed">
          Disposable is built for the modern event experience. We believe that photos taken 
          at special moments—weddings, parties, celebrations—should be cherished, not archived. 
          By making photos ephemeral, we create a sense of exclusivity and presence.
        </p>

        <h2 className="text-3xl font-bold mb-6 mt-12">How It Works</h2>
        <ol className="list-decimal list-inside space-y-4 text-gray-700">
          <li>Host creates an event and generates a shareable link or QR code</li>
          <li>Guests scan or tap the link—no app download needed</li>
          <li>Guests take photos and upload them to the shared gallery</li>
          <li>Photos appear in real-time for all guests to see</li>
          <li>After the event ends, photos automatically expire</li>
        </ol>

        <h2 className="text-3xl font-bold mb-6 mt-12">Why Ephemeral?</h2>
        <p className="text-gray-700 leading-relaxed">
          Ephemeral content creates authenticity. Without worrying about permanence, 
          guests feel free to be themselves. The temporary nature makes each moment special.
        </p>
      </article>
    </main>
  );
}
