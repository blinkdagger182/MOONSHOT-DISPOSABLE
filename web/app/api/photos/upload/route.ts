import { createClient } from "@/lib/supabase/server";
import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const file = formData.get("file") as File;
    const eventId = formData.get("eventId") as string;
    const caption = formData.get("caption") as string;
    const guestName = (formData.get("guestName") as string) || "Guest";

    if (!file || !eventId) {
      return NextResponse.json(
        { error: "Missing required fields" },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    // Verify event exists and is not expired
    const { data: event, error: eventError } = await supabase
      .from("events")
      .select("expires_at")
      .eq("id", eventId)
      .single();

    if (eventError || !event) {
      return NextResponse.json({ error: "Event not found" }, { status: 404 });
    }

    if (event.expires_at && new Date(event.expires_at) < new Date()) {
      return NextResponse.json(
        { error: "Event has expired" },
        { status: 410 }
      );
    }

    // Generate unique filename
    const fileExt = file.name.split(".").pop();
    const fileName = `${eventId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${fileExt}`;
    const buffer = await file.arrayBuffer();

    // Upload to Supabase Storage
    const { data: storageData, error: storageError } = await supabase.storage
      .from("event-photos")
      .upload(fileName, buffer, {
        contentType: file.type,
      });

    if (storageError) {
      return NextResponse.json(
        { error: "Failed to upload photo" },
        { status: 500 }
      );
    }

    // Get public URL
    const {
      data: { publicUrl },
    } = supabase.storage.from("event-photos").getPublicUrl(fileName);

    // Save photo metadata to database
    const { data: photo, error: photoError } = await supabase
      .from("photos")
      .insert({
        event_id: eventId,
        photo_url: publicUrl,
        guest_name: guestName,
        caption: caption || null,
        source: "web-upload",
        expires_at: event.expires_at,
      })
      .select()
      .single();

    if (photoError) {
      return NextResponse.json(
        { error: "Failed to save photo metadata" },
        { status: 500 }
      );
    }

    return NextResponse.json({ photo }, { status: 201 });
  } catch (error) {
    console.error("Upload error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
