"use client";

export const dynamic = "force-dynamic";

import { Suspense, useEffect, useRef, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

interface EventData {
  id: string;
  title: string;
  host_name: string;
  location: string;
  shots_per_guest: number;
  guest_limit: number;
  allow_voice_notes: boolean;
  voice_note_max_seconds: number;
  filter_style: "none" | "vintage";
  reveal_mode: "Immediately" | "At the end";
  duration_hours: number;
  starts_at: string;
  expires_at: string | null;
}

// ─── Vintage film filter ────────────────────────────────────────────────────
function applyVintageFilter(imageData: ImageData): ImageData {
  const data = imageData.data;
  const cx = imageData.width / 2;
  const cy = imageData.height / 2;
  const maxDist = Math.hypot(cx, cy);

  for (let y = 0; y < imageData.height; y++) {
    for (let x = 0; x < imageData.width; x++) {
      const idx = (y * imageData.width + x) * 4;
      const grain = (Math.random() - 0.5) * 18;

      let r = data[idx] + 10 + grain;
      let g = data[idx + 1] + 3 + grain * 0.75;
      let b = data[idx + 2] - 8 + grain * 0.55;

      const contrast = 1.08;
      r = (r - 128) * contrast + 128;
      g = (g - 128) * contrast + 128;
      b = (b - 128) * contrast + 128;

      const dist = Math.hypot(x - cx, y - cy);
      const vignette = 1 - Math.pow(dist / maxDist, 1.7) * 0.32;

      data[idx] = Math.max(0, Math.min(255, r * vignette));
      data[idx + 1] = Math.max(0, Math.min(255, g * vignette));
      data[idx + 2] = Math.max(0, Math.min(255, b * vignette));
    }
  }
  return imageData;
}

// ─── Shutter sound (Web Audio API) ──────────────────────────────────────────
function playShutter(ctx: AudioContext) {
  const now = ctx.currentTime;
  const clickOsc = ctx.createOscillator();
  const clickGain = ctx.createGain();
  clickOsc.type = "square";
  clickOsc.frequency.setValueAtTime(2300, now);
  clickOsc.frequency.exponentialRampToValueAtTime(800, now + 0.018);
  clickGain.gain.setValueAtTime(0.0001, now);
  clickGain.gain.exponentialRampToValueAtTime(0.18, now + 0.003);
  clickGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.028);
  clickOsc.connect(clickGain).connect(ctx.destination);
  clickOsc.start(now);
  clickOsc.stop(now + 0.032);
}

export default function ClipPageWrapper() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[#05070d] flex items-center justify-center">
        <div className="w-10 h-10 border-2 border-white/30 border-t-white rounded-full animate-spin" />
      </div>
    }>
      <ClipPage />
    </Suspense>
  );
}

function ClipPage() {
  const rawSearchParams = useSearchParams();
  const supabase = createClient();

  // ── state ──
  const eventId = rawSearchParams.get("eventId");
  const [event, setEvent] = useState<EventData | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  // join flow
  const [screen, setScreen] = useState<"welcome" | "name" | "camera">("welcome");
  const [guestName, setGuestName] = useState("");
  const [nameInput, setNameInput] = useState("");
  const [termsAccepted, setTermsAccepted] = useState(false);

  // camera
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);

  const [useFront, setUseFront] = useState(false);
  const [shotsLeft, setShotsLeft] = useState(10);
  const [isUploading, setIsUploading] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [flashActive, setFlashActive] = useState(false);

  // voice notes
  const [voiceOpen, setVoiceOpen] = useState(false);
  const [recording, setRecording] = useState(false);
  const [voiceSeconds, setVoiceSeconds] = useState(0);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const voiceChunksRef = useRef<Blob[]>([]);
  const voiceTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // gallery
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [photos, setPhotos] = useState<{ id: string; photo_url: string; guest_name: string }[]>([]);

  // reveal gate
  const [isLocked, setIsLocked] = useState(false);
  const [revealAt, setRevealAt] = useState<Date | null>(null);

  // ── load event ──
  useEffect(() => {
    if (!eventId) {
      setLoadError("No event ID in URL.");
      return;
    }

    const localNameKey = `tetamu_name_${eventId}`;
    const localShotsKey = `tetamu_shots_${eventId}`;
    const savedName = localStorage.getItem(localNameKey);
    if (savedName) {
      setGuestName(savedName);
      setScreen("camera");
    }

    supabase
      .from("events")
      .select("*")
      .eq("id", eventId)
      .single()
      .then(({ data, error }) => {
        if (error || !data) {
          setLoadError("Event not found.");
          return;
        }
        setEvent(data as EventData);

        const savedShots = localStorage.getItem(localShotsKey);
        const shots = savedShots != null ? parseInt(savedShots) : data.shots_per_guest;
        setShotsLeft(Math.max(0, shots));

        // reveal gating
        if (data.reveal_mode === "At the end") {
          const start = new Date(data.starts_at);
          const reveal = new Date(start.getTime() + data.duration_hours * 3600 * 1000);
          setRevealAt(reveal);
          setIsLocked(Date.now() < reveal.getTime());
        }
      });
  }, [eventId]);

  // ── realtime photo subscription ──
  useEffect(() => {
    if (!eventId) return;
    fetchPhotos();
    const sub = supabase
      .channel(`photos_${eventId}`)
      .on("postgres_changes", {
        event: "INSERT",
        schema: "public",
        table: "photos",
        filter: `event_id=eq.${eventId}`,
      }, (payload) => {
        setPhotos((prev) => [payload.new as any, ...prev]);
      })
      .subscribe();
    return () => { sub.unsubscribe(); };
  }, [eventId]);

  const fetchPhotos = async () => {
    if (!eventId) return;
    const { data } = await supabase
      .from("photos")
      .select("id, photo_url, guest_name")
      .eq("event_id", eventId)
      .eq("is_deleted", false)
      .order("created_at", { ascending: false });
    setPhotos(data || []);
  };

  // ── camera ──
  const startCamera = useCallback(async () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: useFront ? "user" : { ideal: "environment" },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
    } catch {
      showToast("Camera blocked. Use upload fallback.");
    }
  }, [useFront]);

  useEffect(() => {
    if (screen === "camera") startCamera();
    return () => { streamRef.current?.getTracks().forEach((t) => t.stop()); };
  }, [screen, startCamera]);

  // ── join ──
  const joinEvent = async () => {
    if (!nameInput.trim() || !termsAccepted || !eventId) return;
    const name = nameInput.trim();
    await supabase.from("guests").insert({
      event_id: eventId,
      name,
      role: "guest",
      source: "web",
    });
    const localNameKey = `tetamu_name_${eventId}`;
    localStorage.setItem(localNameKey, name);
    setGuestName(name);
    setScreen("camera");
  };

  // ── capture ──
  const capture = async () => {
    if (shotsLeft <= 0 || isUploading || !event || !eventId) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;

    // unlock audio
    if (!audioCtxRef.current) {
      audioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    if (audioCtxRef.current.state === "suspended") await audioCtxRef.current.resume();
    playShutter(audioCtxRef.current);

    // flash
    setFlashActive(true);
    setTimeout(() => setFlashActive(false), 150);

    canvas.width = video.videoWidth || 1280;
    canvas.height = video.videoHeight || 720;
    const ctx = canvas.getContext("2d", { willReadFrequently: true })!;
    ctx.drawImage(video, 0, 0);

    if (event.filter_style === "vintage") {
      const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      ctx.putImageData(applyVintageFilter(imgData), 0, 0);
    }

    const blob = await new Promise<Blob>((res) =>
      canvas.toBlob((b) => res(b!), "image/jpeg", 0.92)
    );

    setIsUploading(true);
    const newShots = Math.max(0, shotsLeft - 1);
    setShotsLeft(newShots);
    localStorage.setItem(`tetamu_shots_${eventId}`, String(newShots));

    try {
      const safeName = guestName.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40);
      const path = `${eventId}/${safeName}_${Date.now()}.jpg`;
      const { error: storErr } = await supabase.storage
        .from("event-photos")
        .upload(path, blob, { contentType: "image/jpeg" });
      if (storErr) throw storErr;

      const { data: { publicUrl } } = supabase.storage.from("event-photos").getPublicUrl(path);

      const { error: dbErr } = await supabase.from("photos").insert({
        event_id: eventId,
        guest_name: guestName,
        photo_url: publicUrl,
        source: "web-camera",
        expires_at: event.expires_at,
      });
      if (dbErr) throw dbErr;

      // increment shots_taken on guest record
      await supabase
        .from("guests")
        .update({ shots_taken: supabase.rpc("increment" as any) })
        .eq("event_id", eventId)
        .eq("name", guestName);

      showToast("Snapped!");
    } catch {
      setShotsLeft(shotsLeft);
      localStorage.setItem(`tetamu_shots_${eventId}`, String(shotsLeft));
      showToast("Upload failed.");
    } finally {
      setIsUploading(false);
    }
  };

  // ── fallback upload ──
  const handleFileUpload = async (files: FileList | null) => {
    if (!files || !event || !eventId) return;
    for (const file of Array.from(files)) {
      if (shotsLeft <= 0) break;
      setIsUploading(true);
      const safeName = guestName.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40);
      const path = `${eventId}/${safeName}_${Date.now()}.jpg`;
      const { error: storErr } = await supabase.storage
        .from("event-photos")
        .upload(path, file, { contentType: file.type });
      if (!storErr) {
        const { data: { publicUrl } } = supabase.storage.from("event-photos").getPublicUrl(path);
        await supabase.from("photos").insert({
          event_id: eventId,
          guest_name: guestName,
          photo_url: publicUrl,
          source: "web-upload",
          expires_at: event.expires_at,
        });
        const newShots = Math.max(0, shotsLeft - 1);
        setShotsLeft(newShots);
        localStorage.setItem(`tetamu_shots_${eventId}`, String(newShots));
        showToast("Uploaded!");
      }
      setIsUploading(false);
    }
  };

  // ── voice notes ──
  const startVoice = async () => {
    if (!event?.allow_voice_notes || !eventId) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      voiceChunksRef.current = [];
      const mr = new MediaRecorder(stream);
      mr.ondataavailable = (e) => { if (e.data.size > 0) voiceChunksRef.current.push(e.data); };
      mr.onstop = async () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(voiceChunksRef.current, { type: "audio/webm" });
        if (blob.size > 0) {
          const safeName = guestName.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40);
          const path = `${eventId}/${safeName}_voice_${Date.now()}.webm`;
          const { error } = await supabase.storage
            .from("event-voice")
            .upload(path, blob, { contentType: "audio/webm" });
          if (!error) {
            const { data: { publicUrl } } = supabase.storage.from("event-voice").getPublicUrl(path);
            await supabase.from("voice_notes").insert({
              event_id: eventId,
              guest_name: guestName,
              voice_url: publicUrl,
              source: "web",
            });
            showToast("Voice note saved!");
          }
        }
      };
      mr.start();
      mediaRecorderRef.current = mr;
      setRecording(true);
      let secs = 0;
      voiceTimerRef.current = setInterval(() => {
        secs++;
        setVoiceSeconds(secs);
        if (event && secs >= event.voice_note_max_seconds) stopVoice();
      }, 1000);
    } catch {
      showToast("Microphone blocked.");
    }
  };

  const stopVoice = () => {
    mediaRecorderRef.current?.stop();
    mediaRecorderRef.current = null;
    if (voiceTimerRef.current) clearInterval(voiceTimerRef.current);
    setRecording(false);
    setVoiceSeconds(0);
  };

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2500);
  };

  // ── render ──
  if (loadError) {
    return (
      <div className="min-h-screen bg-[#05070d] flex items-center justify-center text-white p-6">
        <div className="text-center">
          <h1 className="text-2xl font-bold mb-2">Event not found</h1>
          <p className="text-white/60">{loadError}</p>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen bg-[#05070d] flex items-center justify-center">
        <div className="w-10 h-10 border-2 border-white/30 border-t-white rounded-full animate-spin" />
      </div>
    );
  }

  // Welcome screen
  if (screen === "welcome") {
    return (
      <div className="min-h-screen bg-[#05070d] flex items-center justify-center p-6">
        <div className="w-full max-w-sm bg-white/8 rounded-2xl p-8 border border-white/12 text-white text-center space-y-4">
          <p className="text-white/60 text-sm uppercase tracking-widest">Welcome to</p>
          <h1 className="text-2xl font-bold">{event.title}</h1>
          <p className="text-white/70 text-sm">Capture moments, leave voice notes, be part of the story.</p>
          <button
            onClick={() => setScreen("name")}
            className="w-full bg-[#E8D7FF] text-[#09121E] font-bold py-3 rounded-xl"
          >
            Join as Guest
          </button>
        </div>
      </div>
    );
  }

  // Name / terms screen
  if (screen === "name") {
    return (
      <div className="min-h-screen bg-[#05070d] flex items-center justify-center p-6">
        <div className="w-full max-w-sm bg-white/8 rounded-2xl p-8 border border-white/12 text-white space-y-4">
          <h2 className="text-xl font-bold">What&apos;s your name?</h2>
          <input
            type="text"
            maxLength={40}
            placeholder="Your name"
            value={nameInput}
            onChange={(e) => setNameInput(e.target.value)}
            className="w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 text-white placeholder:text-white/40 focus:outline-none focus:border-white/40"
          />
          <label className="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={termsAccepted}
              onChange={(e) => setTermsAccepted(e.target.checked)}
              className="mt-1 accent-[#E8D7FF]"
            />
            <span className="text-sm text-white/70">
              I accept the{" "}
              <a href="/terms" className="underline text-white/90">Terms</a> and{" "}
              <a href="/privacy" className="underline text-white/90">Privacy Policy</a>
            </span>
          </label>
          <button
            onClick={joinEvent}
            disabled={!nameInput.trim() || !termsAccepted}
            className="w-full bg-[#E8D7FF] text-[#09121E] font-bold py-3 rounded-xl disabled:opacity-40"
          >
            Continue
          </button>
        </div>
      </div>
    );
  }

  // Camera screen
  const shotsExhausted = shotsLeft <= 0;

  return (
    <div className="relative h-dvh w-full bg-black overflow-hidden flex flex-col">
      {/* Video feed */}
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        className="absolute inset-0 w-full h-full object-cover"
      />
      <canvas ref={canvasRef} className="hidden" />

      {/* Flash overlay */}
      {flashActive && <div className="absolute inset-0 bg-white z-20 pointer-events-none" />}

      {/* Top bar */}
      <div className="relative z-10 flex items-center justify-between px-4 pt-safe pt-4">
        <div className="bg-black/50 backdrop-blur rounded-xl px-3 py-1.5">
          <p className="text-white font-semibold text-sm truncate max-w-[180px]">{event.title}</p>
          <p className="text-white/60 text-xs">{event.host_name}</p>
        </div>
        <button
          onClick={() => setUseFront((f) => !f)}
          className="bg-black/50 backdrop-blur rounded-full w-10 h-10 flex items-center justify-center text-white text-lg"
        >
          🔄
        </button>
      </div>

      {/* Reveal lock — only shown inside gallery panel, not here */}

      {/* Bottom controls */}
      <div className="relative z-10 mt-auto pb-safe pb-6 px-6">
        {/* Shots counter */}
        <div className="flex justify-center mb-4">
          <div className="bg-black/50 backdrop-blur rounded-full px-5 py-1.5 text-white text-sm font-semibold">
            {shotsLeft} shots left
          </div>
        </div>

        {/* Main row */}
        <div className="flex items-center justify-between">
          {/* Gallery */}
          <button
            onClick={() => setGalleryOpen((o) => !o)}
            className="bg-black/50 backdrop-blur rounded-full w-12 h-12 flex items-center justify-center text-xl"
          >
            🖼
          </button>

          {/* Capture */}
          <button
            onClick={capture}
            disabled={shotsExhausted || isUploading}
            className="w-20 h-20 rounded-full border-4 border-white bg-white/20 flex items-center justify-center disabled:opacity-40 active:scale-95 transition-transform"
          >
            {isUploading ? (
              <div className="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <div className="w-14 h-14 rounded-full bg-white" />
            )}
          </button>

          {/* Voice note */}
          {event.allow_voice_notes ? (
            <button
              onClick={() => setVoiceOpen((o) => !o)}
              className="bg-black/50 backdrop-blur rounded-full w-12 h-12 flex items-center justify-center text-xl"
            >
              🎙
            </button>
          ) : (
            /* Upload fallback slot */
            <label className="bg-black/50 backdrop-blur rounded-full w-12 h-12 flex items-center justify-center text-xl cursor-pointer">
              ⬆
              <input
                type="file"
                accept="image/*"
                multiple
                className="hidden"
                onChange={(e) => handleFileUpload(e.target.files)}
              />
            </label>
          )}
        </div>
      </div>

      {/* Voice note panel */}
      {voiceOpen && (
        <div className="absolute bottom-32 left-4 right-4 z-20 bg-[#1a1e31]/95 backdrop-blur rounded-2xl p-5 text-white space-y-3">
          <p className="font-bold">Voice Guestbook</p>
          <p className="text-white/60 text-sm">Leave a voice note for {event.host_name}</p>
          <p className="text-center font-mono text-lg">
            {String(Math.floor(voiceSeconds / 60)).padStart(2, "0")}:
            {String(voiceSeconds % 60).padStart(2, "0")}
          </p>
          <div className="flex gap-3">
            <button
              onClick={startVoice}
              disabled={recording}
              className="flex-1 bg-[#E8D7FF] text-[#09121E] font-bold py-2.5 rounded-xl disabled:opacity-40"
            >
              Record
            </button>
            <button
              onClick={stopVoice}
              disabled={!recording}
              className="flex-1 bg-white/10 text-white font-bold py-2.5 rounded-xl disabled:opacity-40"
            >
              Stop
            </button>
          </div>
        </div>
      )}

      {/* Gallery panel */}
      {galleryOpen && (
        <div className="absolute inset-0 z-20 bg-[#05070d]/96 overflow-y-auto p-4">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-white font-bold text-lg">{photos.length} Photos</h2>
            <button onClick={() => setGalleryOpen(false)} className="text-white/60 text-2xl">✕</button>
          </div>
          {isLocked && revealAt ? (
            <div className="text-center mt-20 space-y-2">
              <p className="text-white font-bold text-lg">🔒 Memories locked</p>
              <p className="text-white/50 text-sm">Photos reveal at {revealAt.toLocaleString()}</p>
            </div>
          ) : photos.length === 0 ? (
            <p className="text-white/50 text-center mt-20">No photos yet — be the first!</p>
          ) : (
            <div className="grid grid-cols-3 gap-1">
              {photos.map((p) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  key={p.id}
                  src={p.photo_url}
                  alt={p.guest_name || "photo"}
                  className="w-full aspect-square object-cover rounded"
                  loading="lazy"
                />
              ))}
            </div>
          )}
        </div>
      )}

      {/* Upload fallback (when voice notes enabled, show upload in gallery) */}
      {event.allow_voice_notes && (
        <label className="absolute right-4 top-20 z-10 bg-black/50 backdrop-blur rounded-full w-10 h-10 flex items-center justify-center text-white cursor-pointer">
          ⬆
          <input
            type="file"
            accept="image/*"
            multiple
            className="hidden"
            onChange={(e) => handleFileUpload(e.target.files)}
          />
        </label>
      )}

      {/* Toast */}
      {toast && (
        <div className="absolute bottom-36 left-1/2 -translate-x-1/2 z-30 bg-black/80 text-white px-5 py-2 rounded-full text-sm font-medium pointer-events-none">
          {toast}
        </div>
      )}
    </div>
  );
}
