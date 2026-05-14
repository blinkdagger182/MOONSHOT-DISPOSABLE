document.addEventListener("DOMContentLoaded", async () => {
  const firebaseConfig = {
    apiKey: "AIzaSyD8KiOWHusg_tdH7BORIbbZDZN9Ej0dNSo",
    authDomain: "disposable-53b41.firebaseapp.com",
    projectId: "disposable-53b41",
    storageBucket: "disposable-53b41.firebasestorage.app",
    messagingSenderId: "440372368924",
    appId: "1:440372368924:web:0d678b0f660cc09190f1d9"
  };

  if (!firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
  }

  const db = firebase.firestore();
  const storage = firebase.storage();

  const urlParams = new URLSearchParams(window.location.search);
  const eventId = urlParams.get("eventId");

  const el = {
    welcomeScreen: document.getElementById("welcomeScreen"),
    nameScreen: document.getElementById("nameScreen"),
    startJoinBtn: document.getElementById("startJoinBtn"),
    continueFlowBtn: document.getElementById("continueFlowBtn"),
    welcomeEventName: document.getElementById("welcomeEventName"),
    guestNameInputFlow: document.getElementById("guestNameInputFlow"),
    termsCheckFlow: document.getElementById("termsCheckFlow"),
    eventName: document.getElementById("eventName"),
    eventMeta: document.getElementById("eventMeta"),
    shotsLeft: document.getElementById("shotsLeft"),
    shotsLeftSmall: document.getElementById("shotsLeftSmall"),
    cameraFeed: document.getElementById("cameraFeed"),
    cameraFallback: document.getElementById("cameraFallback"),
    captureBtn: document.getElementById("captureBtn"),
    switchCameraBtn: document.getElementById("switchCameraBtn"),
    flashHintBtn: document.getElementById("flashHintBtn"),
    settingsBtn: document.getElementById("settingsBtn"),
    zoomBtn: document.getElementById("zoomBtn"),
    voiceNoteBtn: document.getElementById("voiceNoteBtn"),
    fallbackUpload: document.getElementById("fallbackUpload"),
    captureCanvas: document.getElementById("captureCanvas"),
    snapOverlay: document.getElementById("snapOverlay"),
    snapPreview: document.getElementById("snapPreview"),
    voiceSection: document.getElementById("voiceSection"),
    recordVoiceBtn: document.getElementById("recordVoiceBtn"),
    stopVoiceBtn: document.getElementById("stopVoiceBtn"),
    voiceTimer: document.getElementById("voiceTimer"),
    voiceHint: document.getElementById("voiceHint"),
    lockedSection: document.getElementById("lockedSection"),
    lockedMessage: document.getElementById("lockedMessage"),
    downloadAllBtn: document.getElementById("downloadAllBtn"),
    openGalleryBtn: document.getElementById("openGalleryBtn"),
    gallerySection: document.getElementById("gallerySection"),
    photoGrid: document.getElementById("photoGrid"),
    toast: document.getElementById("toast")
  };

  if (!eventId) {
    document.body.innerHTML = "<h1 style='padding:2rem;color:white'>Event not found</h1>";
    return;
  }

  const eventRef = db.collection("events").doc(eventId);
  const imagesRef = eventRef.collection("images");
  const participantsRef = eventRef.collection("participants");

  const localNameKey = `tetamu_guest_name_${eventId}`;
  const localShotsKey = `tetamu_guest_shots_${eventId}`;

  let stream = null;
  let useFrontCamera = false;
  let eventData = null;
  let guestName = localStorage.getItem(localNameKey) || "";
  let imagesCache = [];
  let isUploading = false;
  let audioCtx = null;
  let audioUnlocked = false;
  let torchSupported = false;
  let torchOn = false;
  let mediaRecorder = null;
  let voiceChunks = [];
  let voiceTimerId = null;
  let voiceStartedAt = 0;

  const state = {
    maxShots: 10,
    shotsLeft: 10
  };

  function showToast(message) {
    el.toast.textContent = message;
    el.toast.classList.remove("hidden");
    window.setTimeout(() => el.toast.classList.add("hidden"), 2400);
  }

  function updateShotsUI() {
    el.shotsLeft.textContent = String(Math.max(0, state.shotsLeft));
    if (el.shotsLeftSmall) {
      el.shotsLeftSmall.textContent = String(Math.max(0, state.shotsLeft));
    }
    el.captureBtn.disabled = state.shotsLeft <= 0 || isUploading;
  }

  function getVideoTrack() {
    if (!stream) return null;
    const tracks = stream.getVideoTracks();
    return tracks && tracks.length > 0 ? tracks[0] : null;
  }

  async function detectTorchSupport() {
    const track = getVideoTrack();
    torchSupported = false;
    if (!track) return;

    try {
      const caps = track.getCapabilities ? track.getCapabilities() : {};
      torchSupported = Boolean(caps && caps.torch);
    } catch (_) {
      torchSupported = false;
    }

    const icon = torchOn ? "⚡︎" : "⚡";
    el.flashHintBtn.textContent = icon;
  }

  async function setTorch(enabled) {
    const track = getVideoTrack();
    if (!track || !torchSupported) return false;
    try {
      await track.applyConstraints({ advanced: [{ torch: enabled }] });
      torchOn = enabled;
      el.flashHintBtn.textContent = torchOn ? "⚡︎" : "⚡";
      return true;
    } catch (error) {
      console.warn("Torch apply failed:", error);
      return false;
    }
  }

  function playSnapEffect(previewDataUrl) {
    if (el.snapPreview && previewDataUrl) {
      el.snapPreview.style.backgroundImage = `url(${previewDataUrl})`;
      el.snapPreview.classList.remove("hidden");
      el.snapPreview.classList.remove("active");
      void el.snapPreview.offsetWidth;
      el.snapPreview.classList.add("active");
      window.setTimeout(() => {
        el.snapPreview.classList.remove("active");
        el.snapPreview.classList.add("hidden");
      }, 980);
    }

    if (el.snapOverlay) {
      el.snapOverlay.classList.remove("hidden");
      el.snapOverlay.classList.remove("active");
      void el.snapOverlay.offsetWidth;
      el.snapOverlay.classList.add("active");
      window.setTimeout(() => {
        el.snapOverlay.classList.remove("active");
        el.snapOverlay.classList.add("hidden");
      }, 470);
    }
  }

  async function unlockAudioContext() {
    try {
      if (!audioCtx) {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return false;
        audioCtx = new Ctx();
      }
      if (audioCtx.state === "suspended") {
        await audioCtx.resume();
      }
      audioUnlocked = audioCtx.state === "running";
      return audioUnlocked;
    } catch (error) {
      console.warn("Audio unlock failed:", error);
      return false;
    }
  }

  function playShutterSound() {
    try {
      if (!audioCtx || audioCtx.state !== "running" || !audioUnlocked) return;

      const ctx = audioCtx;
      const now = ctx.currentTime;

      // Sharp high click (shutter trigger)
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

      // Mechanical body clack
      const bodyOsc = ctx.createOscillator();
      const bodyGain = ctx.createGain();
      bodyOsc.type = "triangle";
      bodyOsc.frequency.setValueAtTime(340, now + 0.008);
      bodyOsc.frequency.exponentialRampToValueAtTime(118, now + 0.11);
      bodyGain.gain.setValueAtTime(0.0001, now + 0.006);
      bodyGain.gain.exponentialRampToValueAtTime(0.14, now + 0.02);
      bodyGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.14);
      bodyOsc.connect(bodyGain).connect(ctx.destination);
      bodyOsc.start(now + 0.008);
      bodyOsc.stop(now + 0.15);

      // Short film-advance hiss/noise tail
      const sampleRate = ctx.sampleRate;
      const noiseLen = Math.floor(sampleRate * 0.09);
      const noiseBuffer = ctx.createBuffer(1, noiseLen, sampleRate);
      const noiseData = noiseBuffer.getChannelData(0);
      for (let i = 0; i < noiseLen; i += 1) {
        noiseData[i] = (Math.random() * 2 - 1) * (1 - i / noiseLen);
      }
      const noise = ctx.createBufferSource();
      noise.buffer = noiseBuffer;
      const noiseFilter = ctx.createBiquadFilter();
      noiseFilter.type = "bandpass";
      noiseFilter.frequency.setValueAtTime(1450, now);
      noiseFilter.Q.setValueAtTime(0.8, now);
      const noiseGain = ctx.createGain();
      noiseGain.gain.setValueAtTime(0.0001, now + 0.018);
      noiseGain.gain.exponentialRampToValueAtTime(0.06, now + 0.03);
      noiseGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.11);
      noise.connect(noiseFilter).connect(noiseGain).connect(ctx.destination);
      noise.start(now + 0.018);
      noise.stop(now + 0.12);
    } catch (error) {
      console.warn("Shutter sound unavailable:", error);
    }
  }

  function animateSnapIntoGallery(previewDataUrl) {
    const target = el.voiceNoteBtn || el.openGalleryBtn;
    const stage = document.querySelector(".camera-stage");
    if (!target || !stage || !previewDataUrl) return;

    const stageRect = stage.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();

    const chip = document.createElement("div");
    chip.className = "snap-fly-chip";
    chip.style.backgroundImage = `url(${previewDataUrl})`;
    chip.style.left = `${stageRect.left + stageRect.width / 2 - 54}px`;
    chip.style.top = `${stageRect.top + stageRect.height / 2 - 72}px`;
    document.body.appendChild(chip);

    // Hold the frozen frame first, then fly to gallery.
    window.setTimeout(() => {
      window.requestAnimationFrame(() => {
        chip.style.left = `${targetRect.left + targetRect.width / 2 - 20}px`;
        chip.style.top = `${targetRect.top + targetRect.height / 2 - 20}px`;
        chip.style.width = "40px";
        chip.style.height = "40px";
        chip.style.opacity = "0.1";
        chip.style.transform = "rotate(8deg)";
      });
    }, 560);

    window.setTimeout(() => {
      chip.remove();
      if (target.animate) {
        target.animate(
          [
            { transform: "scale(1)" },
            { transform: "scale(1.12)" },
            { transform: "scale(1)" }
          ],
          { duration: 620, easing: "ease-out" }
        );
      }
    }, 2280);
  }

  function loadStoredShots() {
    const raw = localStorage.getItem(localShotsKey);
    if (raw == null) {
      state.shotsLeft = state.maxShots;
      return;
    }
    const parsed = Number(raw);
    state.shotsLeft = Number.isFinite(parsed) ? Math.max(0, parsed) : state.maxShots;
  }

  function persistShots() {
    localStorage.setItem(localShotsKey, String(state.shotsLeft));
  }

  function renderImages() {
    el.photoGrid.innerHTML = "";
    for (const imageUrl of imagesCache) {
      const img = document.createElement("img");
      img.src = imageUrl;
      img.alt = "Event Image";
      img.loading = "lazy";
      el.photoGrid.appendChild(img);
    }
  }

  async function fetchEvent() {
    const doc = await eventRef.get();
    if (!doc.exists) {
      throw new Error("Event does not exist");
    }

    eventData = doc.data();
    el.eventName.textContent = eventData.eventName || "Event";
    el.eventMeta.textContent = `${eventData.userName || "Host"} created this event.`;
    el.welcomeEventName.textContent = eventData.eventName || "Tetamu Event";
    if (eventData.allowVoiceNotes === false) {
      el.voiceNoteBtn.classList.add("hidden");
    }

    const configuredShots = Number(eventData.numberOfPhotos);
    state.maxShots = Number.isFinite(configuredShots) && configuredShots > 0 ? configuredShots : 10;
    if (!localStorage.getItem(localShotsKey)) {
      state.shotsLeft = state.maxShots;
      persistShots();
    } else {
      loadStoredShots();
    }
    updateShotsUI();
  }

  async function fetchImages() {
    const snapshot = await imagesRef.orderBy("timestamp", "asc").get();
    imagesCache = snapshot.docs
      .map((d) => d.data())
      .filter((data) => Boolean(data.url))
      .map((data) => data.url);
    renderImages();
  }

  async function registerParticipant() {
    if (!guestName) return;

    const existing = await participantsRef.where("name", "==", guestName).limit(1).get();
    if (!existing.empty) return;

    await participantsRef.add({
      name: guestName,
      role: "guest",
      joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
      photosTakenWeb: 0,
      source: "web"
    });
  }

  function applyDisposableFilmLook(imageData, width, height) {
    const data = imageData.data;
    const cx = width / 2;
    const cy = height / 2;
    const maxDist = Math.hypot(cx, cy);

    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const idx = (y * width + x) * 4;
        let r = data[idx];
        let g = data[idx + 1];
        let b = data[idx + 2];

        const grain = (Math.random() - 0.5) * 18;

        r = r + 10 + grain;
        g = g + 3 + grain * 0.75;
        b = b - 8 + grain * 0.55;

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

  async function processBlobToDisposable(blob) {
    const img = new Image();
    const imageUrl = URL.createObjectURL(blob);

    await new Promise((resolve, reject) => {
      img.onload = resolve;
      img.onerror = reject;
      img.src = imageUrl;
    });

    const canvas = el.captureCanvas;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });

    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const processed = applyDisposableFilmLook(imageData, canvas.width, canvas.height);
    ctx.putImageData(processed, 0, 0);

    URL.revokeObjectURL(imageUrl);

    return await new Promise((resolve) => {
      canvas.toBlob((outBlob) => resolve(outBlob), "image/jpeg", 0.92);
    });
  }

  async function captureFromCamera() {
    if (state.shotsLeft <= 0 || isUploading) return;

    if (!stream) {
      await startCamera();
      if (!stream) {
        showToast("Camera not ready. Use Upload Photo fallback.");
        return;
      }
    }

    const video = el.cameraFeed;
    const canvas = el.captureCanvas;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });

    const width = video.videoWidth || 1280;
    const height = video.videoHeight || 720;

    canvas.width = width;
    canvas.height = height;
    ctx.drawImage(video, 0, 0, width, height);

    const rawBlob = await new Promise((resolve) => canvas.toBlob((blob) => resolve(blob), "image/jpeg", 0.95));
    if (!rawBlob) {
      showToast("Could not capture image.");
      return;
    }

    const previewDataUrl = canvas.toDataURL("image/jpeg", 0.5);
    playShutterSound();
    playSnapEffect(previewDataUrl);
    animateSnapIntoGallery(previewDataUrl);
    await uploadCapturedBlob(rawBlob, true);
  }

  async function uploadCapturedBlob(blob, fromCameraCapture = false) {
    if (state.shotsLeft <= 0 || isUploading) return;
    if (!guestName) {
      showToast("Enter your name first.");
      return;
    }

    isUploading = true;
    const previousShots = state.shotsLeft;
    state.shotsLeft = Math.max(0, state.shotsLeft - 1);
    persistShots();
    updateShotsUI();

    try {
      const styledBlob = await processBlobToDisposable(blob);
      if (!styledBlob) {
        throw new Error("Image processing failed");
      }

      const safeName = guestName.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40);
      const fileName = `${safeName}_${Date.now()}.jpg`;
      const storagePath = `events/${eventId}/${fileName}`;
      const storageRef = storage.ref().child(storagePath);

      await storageRef.put(styledBlob, {
        contentType: "image/jpeg",
        customMetadata: {
          user: guestName,
          eventId
        }
      });

      const downloadURL = await storageRef.getDownloadURL();

      await imagesRef.add({
        url: downloadURL,
        owner: guestName,
        source: "web-camera",
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      });

      const participantQuery = await participantsRef.where("name", "==", guestName).limit(1).get();
      if (!participantQuery.empty) {
        const docRef = participantQuery.docs[0].ref;
        await docRef.set({ photosTakenWeb: firebase.firestore.FieldValue.increment(1) }, { merge: true });
      }

      await fetchImages();
      showToast(fromCameraCapture ? "Snapped and uploaded." : "Uploaded.");
    } catch (error) {
      console.error(error);
      state.shotsLeft = previousShots;
      persistShots();
      updateShotsUI();
      showToast("Upload failed. Try again.");
    } finally {
      isUploading = false;
      updateShotsUI();
    }
  }

  async function handleFallbackFiles(fileList) {
    if (!fileList || fileList.length === 0) return;
    for (const file of Array.from(fileList)) {
      if (state.shotsLeft <= 0) break;
      await uploadCapturedBlob(file);
    }
    el.fallbackUpload.value = "";
  }

  async function startCamera() {
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
    }

    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: useFrontCamera ? "user" : { ideal: "environment" },
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        }
      });

      el.cameraFeed.srcObject = stream;
      el.cameraFallback.classList.add("hidden");
      await el.cameraFeed.play();
      await detectTorchSupport();
    } catch (error) {
      console.warn("Camera access failed:", error);
      el.cameraFallback.classList.remove("hidden");
      showToast("Camera permission blocked. Use Upload Photo fallback.");
    }
  }

  async function downloadAll() {
    if (imagesCache.length === 0) {
      showToast("No photos yet.");
      return;
    }

    const zip = new JSZip();
    const folder = zip.folder("event_photos");

    await Promise.all(imagesCache.map(async (url, index) => {
      const response = await fetch(url);
      const blob = await response.blob();
      folder.file(`photo_${index + 1}.jpg`, blob);
    }));

    const content = await zip.generateAsync({ type: "blob" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(content);
    link.download = `${eventData?.eventName || "event"}.zip`;
    link.click();
    URL.revokeObjectURL(link.href);
  }

  function setupJoinFlow() {
    if (guestName) {
      el.welcomeScreen.classList.add("hidden");
      el.nameScreen.classList.add("hidden");
      registerParticipant().catch(console.error);
      applyRevealState();
      return;
    }
    el.startJoinBtn.addEventListener("click", () => {
      el.welcomeScreen.classList.add("hidden");
      el.nameScreen.classList.remove("hidden");
    });

    el.continueFlowBtn.addEventListener("click", async () => {
      await unlockAudioContext();
      const value = el.guestNameInputFlow.value.trim();
      if (!value) {
        showToast("Please enter your name.");
        return;
      }

      if (!el.termsCheckFlow.checked) {
        showToast("Accept terms to continue.");
        return;
      }

      guestName = value;
      localStorage.setItem(localNameKey, guestName);
      if (!localStorage.getItem(localShotsKey)) {
        state.shotsLeft = state.maxShots;
        persistShots();
      }

      try {
        await registerParticipant();
        el.nameScreen.classList.add("hidden");
        applyRevealState();
        showToast(`Welcome, ${guestName}`);
      } catch (error) {
        console.error(error);
        showToast("Could not join event right now.");
      }
    });
  }

  function formatTimer(ms) {
    const total = Math.floor(ms / 1000);
    const mins = String(Math.floor(total / 60)).padStart(2, "0");
    const secs = String(total % 60).padStart(2, "0");
    return `${mins}:${secs}`;
  }

  function applyRevealState() {
    if (!eventData) return;
    const revealMode = eventData.reveal || "Immediately";
    const durationHours = Number(eventData.duration || 24);
    const start = eventData.startTime?.toDate ? eventData.startTime.toDate() : new Date();
    const revealAt = new Date(start.getTime() + durationHours * 3600 * 1000);
    const locked = revealMode === "At the end" && Date.now() < revealAt.getTime();
    el.lockedSection.classList.toggle("hidden", !locked);
    if (locked) {
      el.lockedMessage.textContent = `Memories reveal at ${revealAt.toLocaleString()}.`;
    }
  }

  async function uploadVoiceNote(blob) {
    if (!blob || !guestName) return;
    const safeName = guestName.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 40);
    const fileName = `${safeName}_voice_${Date.now()}.webm`;
    const storagePath = `events/${eventId}/voice/${fileName}`;
    const storageRef = storage.ref().child(storagePath);
    await storageRef.put(blob, {
      contentType: "audio/webm",
      customMetadata: { user: guestName, eventId }
    });
    const downloadURL = await storageRef.getDownloadURL();
    await eventRef.collection("voiceNotes").add({
      url: downloadURL,
      owner: guestName,
      source: "web-voice",
      timestamp: firebase.firestore.FieldValue.serverTimestamp()
    });
    showToast("Voice note uploaded.");
  }

  async function startVoiceRecording() {
    try {
      const vStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      voiceChunks = [];
      mediaRecorder = new MediaRecorder(vStream);
      mediaRecorder.ondataavailable = (e) => {
        if (e.data && e.data.size > 0) voiceChunks.push(e.data);
      };
      mediaRecorder.onstop = async () => {
        vStream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(voiceChunks, { type: "audio/webm" });
        voiceChunks = [];
        if (blob.size > 0) {
          await uploadVoiceNote(blob);
        }
      };
      mediaRecorder.start();
      voiceStartedAt = Date.now();
      el.recordVoiceBtn.disabled = true;
      el.stopVoiceBtn.disabled = false;
      voiceTimerId = window.setInterval(() => {
        el.voiceTimer.textContent = formatTimer(Date.now() - voiceStartedAt);
      }, 200);
    } catch (error) {
      console.error(error);
      showToast("Microphone permission blocked.");
    }
  }

  function stopVoiceRecording() {
    if (!mediaRecorder) return;
    mediaRecorder.stop();
    mediaRecorder = null;
    el.recordVoiceBtn.disabled = false;
    el.stopVoiceBtn.disabled = true;
    if (voiceTimerId) {
      window.clearInterval(voiceTimerId);
      voiceTimerId = null;
    }
    el.voiceTimer.textContent = "00:00";
  }

  el.captureBtn.addEventListener("pointerdown", () => { unlockAudioContext(); }, { passive: true });
  el.captureBtn.addEventListener("click", captureFromCamera);
  el.switchCameraBtn.addEventListener("click", async () => {
    await unlockAudioContext();
    if (torchOn) {
      await setTorch(false);
    }
    useFrontCamera = !useFrontCamera;
    await startCamera();
  });
  el.flashHintBtn.addEventListener("click", () => {
    unlockAudioContext();
    if (torchSupported) {
      setTorch(!torchOn).then((ok) => {
        if (!ok) showToast("Torch failed on this device/browser.");
      });
      return;
    }
    playSnapEffect();
    showToast("Torch unsupported here. Using screen flash fallback.");
  });
  if (el.settingsBtn) {
    el.settingsBtn.addEventListener("click", () => {
      unlockAudioContext();
      showToast("Settings from host app are applied automatically.");
    });
  }
  if (el.zoomBtn) {
    el.zoomBtn.addEventListener("click", () => {
      unlockAudioContext();
      showToast("Zoom is currently fixed at 1x for browser consistency.");
    });
  }
  if (el.voiceNoteBtn) {
    el.voiceNoteBtn.addEventListener("click", () => {
      el.voiceSection.classList.toggle("hidden");
    });
  }
  if (el.recordVoiceBtn) {
    el.recordVoiceBtn.addEventListener("click", startVoiceRecording);
  }
  if (el.stopVoiceBtn) {
    el.stopVoiceBtn.addEventListener("click", stopVoiceRecording);
  }
  el.fallbackUpload.addEventListener("change", (e) => {
    unlockAudioContext();
    handleFallbackFiles(e.target.files).catch(console.error);
  });
  el.downloadAllBtn.addEventListener("click", () => {
    downloadAll().catch((error) => {
      console.error(error);
      showToast("Could not create ZIP.");
    });
  });
  el.openGalleryBtn.addEventListener("click", () => {
    el.gallerySection.classList.toggle("hidden");
  });

  try {
    await fetchEvent();
    await fetchImages();
    setupJoinFlow();
    applyRevealState();

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      el.cameraFallback.classList.remove("hidden");
      showToast("Browser camera API not supported. Use Upload Photo fallback.");
    } else {
      await startCamera();
    }

    window.setInterval(() => {
      fetchImages().catch(console.error);
    }, 15000);
  } catch (error) {
    console.error(error);
    document.body.innerHTML = "<h1 style='padding:2rem;color:white'>Event unavailable</h1>";
  }
});
