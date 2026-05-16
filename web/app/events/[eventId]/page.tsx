"use client";

export const dynamic = "force-dynamic";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import Image from "next/image";
import { Heart } from "lucide-react";

interface Photo {
  id: string;
  photo_url: string;
  caption: string;
  created_at: string;
  views_count: number;
}

interface Event {
  id: string;
  title: string;
  description: string;
  cover_image_url: string;
  event_type: string;
  expires_at: string;
}

export default function EventPage({
  params,
}: {
  params: Promise<{ eventId: string }>;
}) {
  const [eventId, setEventId] = useState<string | null>(null);
  const [event, setEvent] = useState<Event | null>(null);
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const supabase = createClient();

  useEffect(() => {
    params.then((p) => setEventId(p.eventId));
  }, [params]);

  useEffect(() => {
    if (!eventId) return;

    const fetchEventData = async () => {
      try {
        setLoading(true);

        // Fetch event
        const { data: eventData, error: eventError } = await supabase
          .from("events")
          .select("*")
          .eq("id", eventId)
          .single();

        if (eventError) throw eventError;
        setEvent(eventData);

        // Fetch photos
        const { data: photosData, error: photosError } = await supabase
          .from("photos")
          .select("*")
          .eq("event_id", eventId)
          .eq("is_deleted", false)
          .order("created_at", { ascending: false });

        if (photosError) throw photosError;
        setPhotos(photosData || []);

        // Subscribe to realtime updates
        const subscription = supabase
          .channel(`event_${eventId}`)
          .on(
            "postgres_changes",
            {
              event: "*",
              schema: "public",
              table: "photos",
              filter: `event_id=eq.${eventId}`,
            },
            (payload) => {
              if (payload.eventType === "INSERT") {
                setPhotos((prev) => [payload.new as Photo, ...prev]);
              }
            }
          )
          .subscribe();

        return () => {
          subscription.unsubscribe();
        };
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load event");
      } finally {
        setLoading(false);
      }
    };

    fetchEventData();
  }, [eventId, supabase]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-orange-50">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
          <p className="mt-4 text-gray-600">Loading event...</p>
        </div>
      </div>
    );
  }

  if (error || !event) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-50 to-orange-50">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-4">
            Oops! Event not found
          </h1>
          <p className="text-gray-600 mb-8">{error}</p>
          <a
            href="/"
            className="inline-block bg-primary text-white px-8 py-3 rounded-lg font-semibold hover:bg-opacity-90"
          >
            Back to Home
          </a>
        </div>
      </div>
    );
  }

  const isExpired = new Date(event.expires_at) < new Date();

  return (
    <main className="min-h-screen bg-gradient-to-br from-purple-50 to-orange-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="flex items-start justify-between">
            <div>
              <h1 className="text-4xl font-bold text-gray-900 mb-2">
                {event.title}
              </h1>
              {event.description && (
                <p className="text-gray-600 mb-4">{event.description}</p>
              )}
              <div className="flex gap-4">
                <span className="inline-block bg-primary text-white px-3 py-1 rounded-full text-sm font-semibold capitalize">
                  {event.event_type}
                </span>
                {isExpired && (
                  <span className="inline-block bg-red-100 text-red-800 px-3 py-1 rounded-full text-sm font-semibold">
                    Event Ended
                  </span>
                )}
              </div>
            </div>
            <a
              href="/"
              className="text-gray-600 hover:text-primary font-semibold"
            >
              Back
            </a>
          </div>
        </div>
      </div>

      {/* Gallery */}
      <div className="max-w-7xl mx-auto px-6 py-12">
        {photos.length === 0 ? (
          <div className="text-center py-20">
            <div className="inline-block text-6xl mb-4">📸</div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              No photos yet
            </h2>
            <p className="text-gray-600">
              Share the event link with guests to start collecting photos!
            </p>
          </div>
        ) : (
          <>
            <h2 className="text-2xl font-bold text-gray-900 mb-8">
              {photos.length} Photo{photos.length !== 1 ? "s" : ""}
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {photos.map((photo) => (
                <div
                  key={photo.id}
                  className="group relative overflow-hidden rounded-lg bg-white shadow-md hover:shadow-lg transition-shadow"
                >
                  <div className="relative aspect-square overflow-hidden">
                    <Image
                      src={photo.photo_url}
                      alt={photo.caption || "Event photo"}
                      fill
                      className="object-cover group-hover:scale-105 transition-transform"
                    />
                  </div>
                  <div className="p-4">
                    {photo.caption && (
                      <p className="text-gray-700 mb-3">{photo.caption}</p>
                    )}
                    <div className="flex items-center justify-between text-sm text-gray-500">
                      <span>
                        {new Date(photo.created_at).toLocaleDateString()}
                      </span>
                      <div className="flex items-center gap-1">
                        <Heart className="w-4 h-4" />
                        <span>{photo.views_count}</span>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </main>
  );
}
