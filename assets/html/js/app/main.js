
/* ============================================================
 * SPARTITO VIEWER PREMIUM
 * Supporta: embed (Flutter), payload (Flutter HTML), URL (Web iframe), upload (standalone)
 * ============================================================ */

// --- Stato globale ---
let currentAbc = '';
let currentFileName = '';
let currentOriginalFile = null;  // Blob o Uint8Array del file originale
let currentZoom = 1.0;
let currentMeasuresPerLine = 4;
let currentOctaveOffset = 0;
let currentInstrument = 0;
let currentTranspose = 0;
let synthControl = null;
let tuneObject = null;
let allVoicesMeta = [];
let activeTrackIds = [];
let currentTrackInfo = [];

// --- Costanti ---
const TRACK_COLORS = [
  '#E74C3C','#3498DB','#2ECC71','#F39C12','#9B59B6',
  '#1ABC9C','#E67E22','#2C3E50','#8E44AD','#27AE60',
];

const INSTRUMENT_PRESETS = [
  { label: "Concerto (Do)", semis: 0 },
  { label: "Sib - tromba, clarinetto", semis: 2 },
  { label: "Sib basso - sax tenore", semis: 14 },
  { label: "Mib - sax contralto", semis: 9 },
  { label: "Mib basso - sax baritono", semis: 21 },
  { label: "Fa - corno", semis: 7 },
];

// --- Utility ---
function setStatus(msg, kind) {
  const el = document.getElementById('status');
  if (!el) return;
  el.textContent = msg;
  el.className = 'status' + (kind ? ' ' + kind : '');
  updateSummary();
}

function updateTitle(title) {
  const el = document.getElementById('current-title');
  if (el) el.textContent = title || '';
}

function updateSummary() {
  const summary = document.getElementById('controls-summary');
  if (!summary) return;
  const parts = [];
  if (currentInstrument !== 0) {
    parts.push(INSTRUMENT_PRESETS[currentInstrument]?.label || `Str. ${currentInstrument}`);
  }
  if (currentTranspose !== 0) parts.push(`${currentTranspose > 0 ? '+' : ''}${currentTranspose} semitoni`);
  if (currentOctaveOffset !== 0) parts.push(`${currentOctaveOffset > 0 ? '+' : ''}${currentOctaveOffset} ottave`);
  if (currentZoom !== 1.0) parts.push(`zoom ${Math.round(currentZoom * 100)}%`);
  summary.textContent = parts.length ? parts.join(' Â· ') : 'Pronto';
}

// --- Zoom ---
function setZoom(z) {
  currentZoom = Math.max(0.5, Math.min(2.5, z));
  const sheet = document.getElementById('sheet-music');
  if (sheet) {
    sheet.style.transform = `scale(${currentZoom})`;
    sheet.style.transformOrigin = 'top left';
    sheet.style.width = `${100 / currentZoom}%`;
  }
  const level = document.getElementById('zoom-level');
  if (level) level.textContent = `${Math.round(currentZoom * 100)}%`;
  updateSummary();
}

// --- Toggle pulsantiera ---
function toggleControls() {
  const bar = document.getElementById('controls-bar');
  const btn = document.getElementById('controls-toggle');
  if (!bar || !btn) return;
  bar.classList.toggle('collapsed');
  btn.textContent = bar.classList.contains('collapsed') ? '▸' : '▾';
}

// --- Trasposizione ---
function buildTransposeOptions() {
  const sel = document.getElementById('transposeSel');
  if (!sel) return;
  sel.innerHTML = '';
  for (let i = -24; i <= 24; i++) {
    const opt = document.createElement('option');
    opt.value = i;
    opt.textContent = i === 0 ? 'Originale' : (i > 0 ? `+${i}` : `${i}`);
    if (i === 0) opt.selected = true;
    sel.appendChild(opt);
  }
}

function buildInstrumentOptions() {
  const sel = document.getElementById('instrumentSel');
  if (!sel) return;
  sel.innerHTML = '';
  INSTRUMENT_PRESETS.forEach((p, idx) => {
    const opt = document.createElement('option');
    opt.value = idx;
    opt.textContent = p.label;
    sel.appendChild(opt);
  });
}

// --- Multi-tune ---
let tuneChunks = [];

function splitTunebook(abcText) {
  const lines = abcText.split(/\r?\n/);
  const chunks = [];
  let current = [];
  let inTune = false;
  lines.forEach(line => {
    if (/^X:\s*\d+/.test(line)) {
      if (inTune && current.length) {
        chunks.push(current.join('\n'));
      }
      current = [line];
      inTune = true;
    } else if (inTune) {
      current.push(line);
    }
  });
  if (current.length) chunks.push(current.join('\n'));
  
  const result = chunks
    .filter(chunk => /^X:\s*\d+/m.test(chunk))
    .map(chunk => {
      const m = chunk.match(/^T:\s*(.+)$/m);
      return { title: m ? m[1].trim() : "Senza titolo", abc: chunk.trim() };
    });
  
  console.log('[splitTunebook] chunks trovati:', result.length);
  result.forEach((t, i) => console.log('  [' + (i+1) + ']', t.title));
  return result;
}

function setupTuneSelector(abc) {
  console.log('[setupTuneSelector] CALLED');
  
  // ðŸ”¥ Definisci splitTunebook se non esiste
  if (typeof splitTunebook !== 'function') {
    console.log('[setupTuneSelector] splitTunebook non definito, lo definisco qui');
    window.splitTunebook = function(abcText) {
      // Normalizza: rimuovi righe vuote multiple all'inizio
      const lines = abcText.split(/\r?\n/);
      const chunks = [];
      let current = [];
      let inTune = false;
      lines.forEach(line => {
        if (/^X:\s*\d+/.test(line)) {
          if (inTune && current.length) {
            chunks.push(current.join('\n'));
          }
          current = [line];
          inTune = true;
        } else if (inTune) {
          current.push(line);
        }
        // righe fuori da un tune (prima del primo X:) vengono ignorate
      });
      if (current.length) chunks.push(current.join('\n'));
      
      // Mappa + filtro chunk vuoti (senza X:)
      const result = chunks
        .filter(chunk => /^X:\s*\d+/m.test(chunk))
        .map(chunk => {
          const m = chunk.match(/^T:\s*(.+)$/m);
          return { title: m ? m[1].trim() : "Senza titolo", abc: chunk.trim() };
        });
      
      console.log('[splitTunebook] chunks trovati:', result.length);
      result.forEach((t, i) => console.log('  [' + (i+1) + ']', t.title));
      return result;
    };
  }
  
  const tuneCount = (abc.match(/^X:\s*\d+/gm) || []).length;
  const wrap = document.getElementById('tune-selector-wrap');
  const sel = document.getElementById('tuneSel');
  
  console.log('[setupTuneSelector] tuneCount:', tuneCount);
  console.log('[setupTuneSelector] abc.length:', abc.length);
  console.log('[setupTuneSelector] wrap exists:', !!wrap);
  console.log('[setupTuneSelector] sel exists:', !!sel);
  
  if (!wrap || !sel) {
    console.error('[setupTuneSelector] wrap o sel non trovati! Esco.');
    return;
  }
  
  if (tuneCount > 1) {
    window.tuneChunks = window.splitTunebook(abc);
    console.log('[setupTuneSelector] tuneChunks:', window.tuneChunks.length);
    sel.innerHTML = '';
    window.tuneChunks.forEach((t, i) => {
      const opt = document.createElement('option');
      opt.value = i;
      opt.textContent = (i + 1) + '. ' + t.title;
      sel.appendChild(opt);
    });
    wrap.style.display = 'flex';
    console.log('[setupTuneSelector] Dropdown popolato e mostrato');
  } else {
    window.tuneChunks = [];
    wrap.style.display = 'none';
    console.log('[setupTuneSelector] Solo 1 brano, dropdown nascosto');
  }
}
// --- Rendering principale ---

  /* ============================================================
   * PULIZIA ABC (aggiunto da 02-fix-viewer.ps1)
   * ============================================================ */
  function cleanAbcText(abc) {
    if (!abc) return abc;
    return abc
      .replace(/\uFEFF/g, '')
      .replace(/\u00A0/g, ' ')
      .replace(/\r\n?/g, '\n');
  }

  function ensureVoiceNames(abc) {
    if (!abc) return abc;
    var names = { '1': 'Melodia', '2': 'Armonia', '3': 'Basso' };
    var vIdx = 0;
    abc = abc.replace(/^V:(\S+)([^\n]*)$/gm, function(m, id, rest) {
      vIdx++;
      if (/nm=/.test(rest)) return m;
      return 'V:' + id + rest + ' nm="' + (names[id] || ('Voce ' + vIdx)) + '"';
    });
    var voices = [];
    var re = /^V:\s*(\S+)/gm;
    var mm;
    while ((mm = re.exec(abc)) !== null) { voices.push(mm[1]); }
    var uniq = [];
    voices.forEach(function(v){ if (uniq.indexOf(v) < 0) uniq.push(v); });
    if (uniq.length > 1 && !/^%%score\b/m.test(abc)) {
      abc = abc.replace(/^(K:.*)$/m, '$1\n%%score (' + uniq.join(' ') + ')');
    }
    return abc;
  }

  function normalizeAbcForAbcjs(abc) {
    return ensureVoiceNames(cleanAbcText(abc));
  }

  async function renderAndPlay(abc, transposeSemitones) {
  abc = normalizeAbcForAbcjs(abc);
  currentAbc = abc;
  document.body.classList.add('loaded');
  const titleMatch = abc.match(/^T:\s*(.+)$/m);
  if (titleMatch) updateTitle(titleMatch[1].trim());
  const abcOut = document.getElementById('abc-output');
  if (abcOut) abcOut.value = abc;
  const outPanel = document.getElementById('output-panel');
  if (outPanel) outPanel.style.display = 'block';

  const totalTranspose = (transposeSemitones || 0) + (currentOctaveOffset * 12);

  const opts = {
    responsive: 'resize',
    add_classes: true,
    visualTranspose: totalTranspose,
    staffwidth: 750,
    generateParts: true,
    wrap: { preferredMeasuresPerLine: currentMeasuresPerLine || 4 },
    showMeasureNumbers: true,   // numeri di battuta (se supportato dalla versione)
  // Opzioni accordi
  jazzchords: false,
  germanAlphabet: false,
  // Opzioni layout
  staffsep: 12,
  scale: 1.0
  };

  const visualObjs = ABCJS.renderAbc('sheet-music', abc, opts);
  tuneObject = visualObjs[0];

  setZoom(currentZoom);  // riapplica zoom dopo render

  // Audio
  const audioDiv = document.getElementById('audio-controls');
  if (audioDiv) audioDiv.innerHTML = '';
  if (!ABCJS.synth.supportsAudio()) return;

  const cursorControl = {
    beatSubdivisions: 2,
    onStart: () => {
      const svg = document.querySelector('#sheet-music svg');
      if (!svg) return;
      let cursor = svg.querySelector('.abcjs-cursor');
      if (!cursor) {
        cursor = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        cursor.setAttribute('class', 'abcjs-cursor');
        svg.appendChild(cursor);
      }
      cursor.setAttribute('x1', 0); cursor.setAttribute('x2', 0);
      cursor.setAttribute('y1', 0); cursor.setAttribute('y2', 0);
    },
    onEvent: (ev) => {
      document.querySelectorAll('#sheet-music .highlight').forEach(n => n.classList.remove('highlight'));
      if (ev.elements) {
        ev.elements.forEach(group => group.forEach(n => n.classList.add('highlight')));
      }
      const cursor = document.querySelector('#sheet-music svg .abcjs-cursor');
      if (cursor && ev.left !== undefined) {
        cursor.setAttribute('x1', ev.left - 2);
        cursor.setAttribute('x2', ev.left - 2);
        cursor.setAttribute('y1', ev.top);
        cursor.setAttribute('y2', ev.top + ev.height);
      }
    },
    onFinished: () => {
      document.querySelectorAll('#sheet-music .highlight').forEach(n => n.classList.remove('highlight'));
    }
  };

  synthControl = new ABCJS.synth.SynthController();
  synthControl.load('#audio-controls', cursorControl, {
    displayLoop: true, displayRestart: true, displayPlay: true, displayProgress: true, displayWarp: true
  });

  const synth = new ABCJS.synth.CreateSynth();
  await synth.init({ visualObj: tuneObject });
  await synthControl.setTune(tuneObject, false);
}

// --- Filtro tracce ---
function filterTracks(abc, trackIds) {
  if (!trackIds || trackIds.length === 0) return abc;
  const lines = abc.split('\n');
  const filtered = [];
  let inVoice = false;
  let currentVoice = null;
  for (let line of lines) {
    const m = line.match(/^V:(\S+)/);
    if (m) {
      currentVoice = m[1];
      inVoice = trackIds.includes(currentVoice);
      if (inVoice) filtered.push(line);
      continue;
    }
    if (inVoice) {
      if (line.trim() === '' || line.match(/^%%/)) {
        filtered.push(line); inVoice = false; currentVoice = null;
      } else filtered.push(line);
    } else {
      if (line.match(/^X:|^T:|^C:|^M:|^L:|^K:|^%%/)) filtered.push(line);
    }
  }
  return filtered.join('\n');
}

function renderTrackSelector(trackInfo) {
  const container = document.getElementById('tracks-container');
  if (!container) return;
  container.innerHTML = '<span style="font-size:0.8rem;color:var(--ink-soft);margin-right:6px;">🎵 Tracce:</span>';
  activeTrackIds = trackInfo.map(t => t.id);
  trackInfo.forEach((track, idx) => {
    const chip = document.createElement('span');
    chip.className = 'track-chip active';
    chip.innerHTML = `
      <span class="track-color" style="background:${track.color}"></span>
      <span class="track-index" style="font-weight:bold;font-size:0.7rem;opacity:0.6;">${idx + 1}</span>
      ${track.label}
    `;
    chip.dataset.trackId = track.id;
    chip.dataset.active = 'true';
    chip.addEventListener('click', function() {
      const isActive = this.dataset.active === 'true';
      this.dataset.active = isActive ? 'false' : 'true';
      this.classList.toggle('active');
      activeTrackIds = [];
      document.querySelectorAll('.track-chip').forEach(ch => {
        if (ch.dataset.active === 'true') activeTrackIds.push(ch.dataset.trackId);
      });
      if (activeTrackIds.length > 0) {
        const filteredAbc = filterTracks(currentAbc, activeTrackIds);
        renderAndPlay(filteredAbc, currentTranspose);
      }
    });
    container.appendChild(chip);
  });
  container.style.display = 'flex';
}

// --- Conversione MusicXML -> ABC (dalla versione precedente) ---
const KIND_MAP = {
  "major":"","minor":"m","dominant":"7","major-seventh":"maj7","minor-seventh":"m7",
  "diminished":"dim","augmented":"aug","half-diminished":"m7b5","suspended-fourth":"sus4",
  "suspended-second":"sus2","major-sixth":"6","minor-sixth":"m6","dominant-ninth":"9",
  "major-ninth":"maj9","minor-ninth":"m9","diminished-seventh":"dim7","power":"5",
  "augmented-seventh":"aug7","major-11th":"maj11","dominant-13th":"13"
};
const MAJOR_KEYS = ["Cb","Gb","Db","Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#"];
const MINOR_KEYS = ["Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#","G#","D#","A#"];

function pitchToAbc(step, alter, octave) {
  const accMap = {"-2":"__","-1":"_","0":"","1":"^","2":"^^"};
  const acc = accMap[String(alter||0)] || "";
  let out;
  if (octave >= 5) out = step.toLowerCase() + "'".repeat(octave - 5);
  else if (octave === 4) out = step;
  else out = step + ",".repeat(4 - octave);
  return acc + out;
}

function chordSymbolFromHarmony(el) {
  const root = el.querySelector("root");
  if (!root) return null;
  const step = root.querySelector("root-step")?.textContent || "";
  const alter = parseInt(root.querySelector("root-alter")?.textContent || "0", 10);
  const kindEl = el.querySelector("kind");
  let kindVal = kindEl?.getAttribute("text") || kindEl?.textContent || "major";
  const acc = alter === 1 ? "#" : alter === -1 ? "b" : "";
  // Usa il KIND_MAP se disponibile, altrimenti normalizza il valore
  let suffix = "";
  if (KIND_MAP[kindVal] !== undefined) {
    suffix = KIND_MAP[kindVal];
  } else {
    // Pulisci: rimuovi suffissi strani tipo "-seventh", "-ninth", ecc.
    suffix = kindVal.replace(/-(major|minor|dominant|seventh|ninth|eleventh|thirteenth|diminished|augmented|half|suspended|second|fourth|sixth)/gi, "")
                    .replace(/^-+/, "")
                    .replace(/\s+/g, "");
  }
  let sym = step + acc + suffix;
  const bass = el.querySelector("bass bass-step");
  if (bass) sym += "/" + bass.textContent;
  return sym;
}

function musicXmlToAbc(xmlText) {
  const doc = new DOMParser().parseFromString(xmlText, "application/xml");
  if (doc.querySelector("parsererror")) throw new Error("XML non valido.");

  const partList = Array.from(doc.querySelectorAll("part"));
  if (partList.length === 0) throw new Error("Nessuna parte trovata.");

  const title = doc.querySelector("work work-title")?.textContent
             || doc.querySelector("movement-title")?.textContent
             || "Brano senza titolo";
  const composer = doc.querySelector('identification creator[type="composer"]')?.textContent || "";

  let divisions = 1;
  let fifths = 0, mode = "major";
  let beats = 4, beatType = 4;
  let headerCaptured = false;
  let allPartsAbc = [];
  let voicesMeta = [];

  partList.forEach((part, partIndex) => {
    const partName = part.querySelector("part-name")?.textContent || ("Voce " + (partIndex + 1));
    const measures = Array.from(part.querySelectorAll("measure"));
    let bodyLines = [];
    let currentLine = "";
    let measureCount = 0;

    measures.forEach(measure => {
      const attrs = measure.querySelector("attributes");
      if (attrs) {
        const div = attrs.querySelector("divisions");
        if (div) divisions = parseFloat(div.textContent);
        const f = attrs.querySelector("key fifths");
        if (f && !headerCaptured) fifths = parseInt(f.textContent, 10);
        const m = attrs.querySelector("key mode");
        if (m && !headerCaptured) mode = m.textContent;
        const b = attrs.querySelector("time beats");
        const bt = attrs.querySelector("time beat-type");
        if (b && bt && !headerCaptured) {
          beats = parseInt(b.textContent, 10);
          beatType = parseInt(bt.textContent, 10);
        }
        headerCaptured = true;
      }
      const children = Array.from(measure.children);
      let beatsInMeasure = [];
      children.forEach(el => {
        if (el.tagName === "harmony") {
          const sym = chordSymbolFromHarmony(el);
          if (sym) beatsInMeasure.push({ type: "chordsym", sym });
        } else if (el.tagName === "note") {
          const isChordTone = !!el.querySelector("chord");
          const isRest = !!el.querySelector("rest");
          const d = el.querySelector("duration");
          const duration = d ? parseFloat(d.textContent) : divisions/2;
          let lenUnits = Math.max(1, Math.round(duration / (divisions/2)));
          const lenSuffix = lenUnits === 1 ? "" : String(lenUnits);
          let token;
          if (isRest) token = "z" + lenSuffix;
          else {
            const p = el.querySelector("pitch");
            const step = p.querySelector("step").textContent;
            const alter = parseInt(p.querySelector("alter")?.textContent || "0", 10);
            const octave = parseInt(p.querySelector("octave").textContent, 10);
            token = pitchToAbc(step, alter, octave) + lenSuffix;
            if (el.querySelector("tie[type='start'], notations tied[type='start']")) token += "-";
          }
          if (isChordTone && beatsInMeasure.length) {
            const last = beatsInMeasure[beatsInMeasure.length - 1];
            if (last.type === "note") last.pitches.push(token.replace(/[0-9]+$/, ""));
          } else {
            beatsInMeasure.push({ type: "note", pitches: [token], raw: !isRest });
          }
        }
      });
      beatsInMeasure.forEach(b => {
        if (b.type === "chordsym") currentLine += `"${b.sym}"`;
        else if (b.pitches.length > 1) currentLine += "[" + b.pitches.join("") + "] ";
        else currentLine += b.pitches[0] + " ";
      });
      currentLine += "| ";
      measureCount++;
      if (measureCount % 4 === 0) {
        bodyLines.push(currentLine.trim());
        currentLine = "";
      }
    });
    if (currentLine.trim()) bodyLines.push(currentLine.trim());

    let partAbc = "V:" + (partIndex + 1) + " clef=treble name=\"" + partName + "\"\n";
    partAbc += bodyLines.join("\n");
    allPartsAbc.push(partAbc);
    voicesMeta.push({
      id: String(partIndex + 1),
      label: partName,
      index: partIndex + 1,
      color: TRACK_COLORS[partIndex % TRACK_COLORS.length]
    });
  });

  const fi = Math.max(0, Math.min(14, fifths + 7));
  const keyLetter = (mode === "minor") ? MINOR_KEYS[fi] + "m" : MAJOR_KEYS[fi];

  let abc = `X:1\nT:${title}\n`;
  if (composer) abc += `C:${composer}\n`;
  abc += `M:${beats}/${beatType}\nL:1/8\nK:${keyLetter}\n`;
  if (allPartsAbc.length > 1) {
    abc += `%%score ` + allPartsAbc.map((_, i) => i + 1).join(" ") + "\n";
    abc += allPartsAbc.join("\n");
  } else {
    abc += allPartsAbc[0];
  }

  window._trackInfo = voicesMeta;
  return abc;
}

async function extractMusicXmlFromMxl(arrayBuffer) {
  const zip = await JSZip.loadAsync(arrayBuffer);
  let targetPath = null;
  const containerFile = zip.file("META-INF/container.xml");
  if (containerFile) {
    const t = await containerFile.async("string");
    const doc = new DOMParser().parseFromString(t, "application/xml");
    targetPath = doc.querySelector("rootfile")?.getAttribute("full-path");
  }
  if (!targetPath) {
    targetPath = Object.keys(zip.files).find(n => /\.(musicxml|xml)$/i.test(n) && !/container\.xml$/i.test(n));
  }
  if (!targetPath || !zip.file(targetPath)) throw new Error("MusicXML non trovato nel file .mxl");
  return await zip.file(targetPath).async("string");
}

// --- Handler controlli ---
function setupControls() {
  buildTransposeOptions();
  buildInstrumentOptions();

  const controlsToggle = document.getElementById('controls-toggle');
  if (controlsToggle) controlsToggle.addEventListener('click', toggleControls);

  const openFileBtn = document.getElementById('openFileBtn');
  if (openFileBtn) openFileBtn.addEventListener('click', () => {
    document.body.classList.remove('loaded');
    window.scrollTo(0, 0);
  });

  const zoomIn = document.getElementById('zoomIn');
  if (zoomIn) zoomIn.addEventListener('click', () => setZoom(currentZoom + 0.1));

  const zoomOut = document.getElementById('zoomOut');
  if (zoomOut) zoomOut.addEventListener('click', () => setZoom(currentZoom - 0.1));

  const zoomReset = document.getElementById('zoomReset');
  if (zoomReset) zoomReset.addEventListener('click', () => setZoom(1.0));

  const stopBtn = document.getElementById('stopBtn');
  if (stopBtn) stopBtn.addEventListener('click', () => { if (synthControl) synthControl.pause(); });

  const transposeSel = document.getElementById('transposeSel');
  if (transposeSel) transposeSel.addEventListener('change', (e) => {
    currentTranspose = parseInt(e.target.value, 10);
    if (currentAbc) renderAndPlay(currentAbc, currentTranspose);
  });

  const instrumentSel = document.getElementById('instrumentSel');
  if (instrumentSel) instrumentSel.addEventListener('change', (e) => {
    currentInstrument = parseInt(e.target.value, 10);
    const preset = INSTRUMENT_PRESETS[currentInstrument];
    if (preset && preset.semis !== null) {
      currentTranspose = preset.semis;
      if (transposeSel) transposeSel.value = preset.semis;
      if (currentAbc) renderAndPlay(currentAbc, currentTranspose);
    }
  });

  const octaveSel = document.getElementById('octaveSel');
  if (octaveSel) octaveSel.addEventListener('change', (e) => {
    currentOctaveOffset = parseInt(e.target.value, 10);
    if (currentAbc) renderAndPlay(currentAbc, currentTranspose);
  });

  const tuneSel = document.getElementById('tuneSel');
  if (tuneSel) tuneSel.addEventListener('change', async (e) => {
    const idx = parseInt(e.target.value, 10);
    const chunks = window.tuneChunks || (typeof tuneChunks !== 'undefined' ? tuneChunks : []) || [];
    console.log('[tuneSel] change -> idx:', idx, 'chunks.length:', chunks.length);
    if (chunks[idx]) {
      console.log('[tuneSel] Carico brano:', chunks[idx].title);
      await renderAndPlay(chunks[idx].abc, currentTranspose);
    }
  });

  const mplSel = document.getElementById('measuresPerLine');
  if (mplSel) mplSel.addEventListener('change', (e) => {
    currentMeasuresPerLine = parseInt(e.target.value, 10) || 4;
    if (currentAbc) renderAndPlay(currentAbc, currentTranspose);
  });

  // Download
  const dlBtn = document.getElementById('downloadBtn');
  if (dlBtn) {
    dlBtn.addEventListener('click', (e) => {
      e.preventDefault();
      if (!currentOriginalFile) return;
      const blob = new Blob([currentOriginalFile], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = currentFileName || 'spartito.mxl';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  }
}

// --- Caricamento file/ABC ---
async function processContent(content, type, fileName) {
  currentFileName = fileName || 'spartito';
  setStatus('Elaborazione...', '');

  try {
    let abc;
    if (type === 'mxl_base64') {
      const binary = atob(content);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      currentOriginalFile = bytes;
      const xmlText = await extractMusicXmlFromMxl(bytes.buffer);
      abc = musicXmlToAbc(xmlText);
    } else if (type === 'musicxml') {
      currentOriginalFile = new TextEncoder().encode(content);
      abc = musicXmlToAbc(content);
    } else if (type === 'mxl_bytes') {
      currentOriginalFile = content;
      const xmlText = await extractMusicXmlFromMxl(content.buffer || content);
      abc = musicXmlToAbc(xmlText);
    } else if (type === 'abc') {
      currentOriginalFile = new TextEncoder().encode(content);
      abc = content;
    } else {
      throw new Error('Tipo non supportato: ' + type);
    }

    setupTuneSelector(abc);

    if (window._trackInfo && window._trackInfo.length > 0) {
      renderTrackSelector(window._trackInfo);
    } else {
      const tc = document.getElementById('tracks-container');
      if (tc) tc.style.display = 'none';
    }

    await renderAndPlay(abc, currentTranspose);
    setStatus('Pronto.', 'ok');
  } catch (err) {
    console.error(err);
    setStatus('Errore: ' + err.message, 'error');
  }
}

// --- Rileva modalitÃ  ---
function detectMode() {
  if (window.__FORCE_MODE__) return window.__FORCE_MODE__;
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode');
  if (mode) return mode;
  if (window.__ABC_VIEWER_PAYLOAD__) return 'payload';
  if (params.get('docId') || params.get('id')) return 'url';
  return 'standalone';
}

// --- Avvio ---
window.addEventListener('DOMContentLoaded', async () => {
  setupControls();

  const mode = detectMode();

  if (mode === 'standalone') {
    // Handler sorgente standalone
    const processBtn = document.getElementById('processBtn');
    if (processBtn) processBtn.addEventListener('click', async () => {
      const fileInput = document.getElementById('fileInput');
      const textInput = document.getElementById('inputText');
      try {
        let content, type, fileName;
        if (fileInput.files.length) {
          const file = fileInput.files[0];
          fileName = file.name;
          if (/\.mxl$/i.test(file.name)) {
            content = await file.arrayBuffer();
            type = 'mxl_bytes';
          } else {
            content = await file.text();
            type = /^\s*</.test(content) ? 'musicxml' : 'abc';
          }
        } else if (textInput.value.trim()) {
          content = textInput.value.trim();
          type = /^\s*</.test(content) ? 'musicxml' : 'abc';
          fileName = 'incollato.abc';
        } else {
          throw new Error('Inserisci contenuto o carica un file');
        }
        await processContent(content, type, fileName);
      } catch (e) {
        setStatus(e.message, 'error');
      }
    });
    return;
  }

  // ModalitÃ  embed: nascondi header e source panel, mostra solo output
  document.body.classList.add('embed-mode');

  if (mode === 'payload' && window.__ABC_VIEWER_PAYLOAD__) {
    const p = window.__ABC_VIEWER_PAYLOAD__;
    currentTranspose = p.transpose || 0;
    currentInstrument = p.instrument || 0;
    if (p.zoom) setZoom(p.zoom);
    const tSel = document.getElementById('transposeSel');
    if (tSel) tSel.value = currentTranspose;
    await processContent(p.abc, p.contentType || 'abc', p.fileName || 'spartito');
  }

  if (mode === 'url') {
    const params = new URLSearchParams(window.location.search);
    const docId = params.get('docId') || params.get('id');
    const fileName = params.get('fileName') || 'spartito.mxl';
    const apiBase = params.get('apiBase') || '';
    try {
      const res = await fetch(`${apiBase}/api/mxl-temp/${docId}/content`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const buffer = await res.arrayBuffer();
      currentFileName = fileName;
      currentOriginalFile = new Uint8Array(buffer);
      const xmlText = await extractMusicXmlFromMxl(buffer);
      const abc = musicXmlToAbc(xmlText);
      setupTuneSelector(abc);
      if (window._trackInfo && window._trackInfo.length > 0) {
        renderTrackSelector(window._trackInfo);
      }
      await renderAndPlay(abc, 0);
      setStatus('Pronto.', 'ok');
    } catch (e) {
      setStatus('Errore: ' + e.message, 'error');
    }
  }

  if (mode === 'flutter') {
    // Espone la funzione per Flutter
    window.loadFromFlutter = async function(base64Content, type) {
      await processContent(base64Content, type === 'mxl' ? 'mxl_base64' : type, 'spartito');
    };
  }
});

// Espone loadFromFlutter sempre (Flutter lo chiama via JS dopo onLoadStop)
window.loadFromFlutter = async function(base64Content, type) {
  console.log('[loadFromFlutter] type:', type, 'b64 len:', base64Content.length);
  try {
    // Decodifica base64 -> stringa UTF-8 (vale per ABC e per MusicXML testuale)
    const binary = atob(base64Content);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const text = new TextDecoder('utf-8').decode(bytes);

    if (type === 'abc' || type === 'musicxml') {
      await processContent(text, type, 'spartito');
    } else if (type === 'mxl') {
      // Se in futuro passi il binario MXL grezzo
      await processContent(base64Content, 'mxl_base64', 'spartito');
    } else {
      await processContent(text, 'abc', 'spartito');
    }

    window.__LOAD_FROM_FLUTTER_CALLED__ = true;
  } catch (e) {
    console.error('[loadFromFlutter] Errore:', e);
  }
};
