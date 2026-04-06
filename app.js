const DEPLOY_S3_BUCKET_NAME = '__DEPLOY_S3_BUCKET_NAME__';
const DEPLOY_S3_REGION = '__DEPLOY_S3_REGION__';
const DEPLOY_TRACKS_PREFIX = '__DEPLOY_TRACKS_PREFIX__';
const DEPLOY_ENABLE_MOCK_MODE = '__DEPLOY_ENABLE_MOCK_MODE__';

const CONFIG = {
  bucketName: DEPLOY_S3_BUCKET_NAME.startsWith('__DEPLOY_')
    ? 'YOUR_PUBLIC_BUCKET_NAME'
    : DEPLOY_S3_BUCKET_NAME,
  region: DEPLOY_S3_REGION.startsWith('__DEPLOY_') ? 'us-east-1' : DEPLOY_S3_REGION,
  // Optional: set to a path like "tracks/" if your files are inside a folder.
  prefix: DEPLOY_TRACKS_PREFIX.startsWith('__DEPLOY_') ? '' : DEPLOY_TRACKS_PREFIX,
  // If true and bucketName is not configured, the site renders test entries.
  enableMockMode: DEPLOY_ENABLE_MOCK_MODE.startsWith('__DEPLOY_')
    ? true
    : DEPLOY_ENABLE_MOCK_MODE === 'true',
};


const MOCK_TRACKS = [
  {
    title: 'Mock Track - Sunrise Demo',
    date: '2026-01-08T14:22:00Z',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    thumbCandidates: ['https://picsum.photos/seed/sunrise-demo/96/96.jpg'],
  },
  {
    title: 'Mock Track - Night Session',
    date: '2025-11-14T03:18:00Z',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    thumbCandidates: ['https://picsum.photos/seed/night-session/96/96.jpg'],
  },
  {
    title: 'Mock Track - Studio Preview',
    date: '2025-09-02T19:40:00Z',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    thumbCandidates: ['https://picsum.photos/seed/studio-preview/96/96.jpg'],
  },
];

const AUDIO_EXTENSIONS = ['.mp3', '.wav', '.m4a', '.ogg', '.flac'];
const statusEl = document.getElementById('status');
const sortSelect = document.getElementById('sortBy');
const trackListEl = document.getElementById('trackList');

let tracks = [];

function formatTime(totalSeconds) {
  if (!Number.isFinite(totalSeconds)) return '0:00';
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = Math.floor(totalSeconds % 60)
    .toString()
    .padStart(2, '0');
  return `${minutes}:${seconds}`;
}

function formatDate(isoString) {
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) return 'Unknown date';
  return date.toLocaleString();
}

function fileBaseName(key) {
  const fileName = key.split('/').pop() ?? key;
  return fileName.replace(/\.[^.]+$/, '');
}

function objectUrl(key) {
  const encodedKey = key
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');

  return `https://${CONFIG.bucketName}.s3.${CONFIG.region}.amazonaws.com/${encodedKey}`;
}

function thumbnailCandidates(key) {
  const cleanKey = key.replace(/\.[^.]+$/, '');
  return [`${cleanKey}.png`, `${cleanKey}.jpg`, `${cleanKey}.jpeg`];
}

function parseTracks(xmlText) {
  const doc = new DOMParser().parseFromString(xmlText, 'application/xml');
  const parseError = doc.querySelector('parsererror');

  if (parseError) {
    throw new Error('Could not parse S3 XML response.');
  }

  const objectNodes = [...doc.querySelectorAll('Contents')];

  return objectNodes
    .map((node) => {
      const key = node.querySelector('Key')?.textContent?.trim();
      const lastModified = node.querySelector('LastModified')?.textContent?.trim();

      if (!key || !lastModified) {
        return null;
      }

      const lowered = key.toLowerCase();
      if (!AUDIO_EXTENSIONS.some((ext) => lowered.endsWith(ext))) {
        return null;
      }

      return {
        key,
        title: fileBaseName(key),
        date: lastModified,
        audioUrl: objectUrl(key),
        thumbCandidates: thumbnailCandidates(key).map(objectUrl),
      };
    })
    .filter(Boolean);
}

function sortTracks(value) {
  const sorted = [...tracks];

  switch (value) {
    case 'date-asc':
      sorted.sort((a, b) => new Date(a.date) - new Date(b.date));
      break;
    case 'alpha-asc':
      sorted.sort((a, b) => a.title.localeCompare(b.title));
      break;
    case 'alpha-desc':
      sorted.sort((a, b) => b.title.localeCompare(a.title));
      break;
    case 'date-desc':
    default:
      sorted.sort((a, b) => new Date(b.date) - new Date(a.date));
      break;
  }

  return sorted;
}

function attachThumbFallback(imgEl, candidates, index = 0) {
  if (index >= candidates.length) {
    imgEl.src =
      'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="100%" height="100%" fill="%23ECEFF4"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="%23717B8C" font-size="12">No image</text></svg>';
    return;
  }

  imgEl.src = candidates[index];
  imgEl.onerror = () => attachThumbFallback(imgEl, candidates, index + 1);
}

function createTrackItem(track) {
  const li = document.createElement('li');
  li.className = 'track-item';

  const meta = document.createElement('div');
  meta.className = 'track-meta';

  const titleWrap = document.createElement('div');
  titleWrap.className = 'track-title-wrap';

  const title = document.createElement('span');
  title.className = 'track-title';
  title.textContent = track.title;

  const thumb = document.createElement('img');
  thumb.className = 'thumb';
  thumb.alt = `${track.title} thumbnail`;
  attachThumbFallback(thumb, track.thumbCandidates);

  titleWrap.append(title, thumb);

  const date = document.createElement('time');
  date.className = 'track-date';
  date.dateTime = track.date;
  date.textContent = formatDate(track.date);

  meta.append(titleWrap, date);

  const controls = document.createElement('div');
  controls.className = 'player-controls';

  const playBtn = document.createElement('button');
  playBtn.className = 'play-btn';
  playBtn.type = 'button';
  playBtn.textContent = 'Play';

  const scrub = document.createElement('input');
  scrub.className = 'scrub';
  scrub.type = 'range';
  scrub.min = '0';
  scrub.max = '100';
  scrub.value = '0';
  scrub.step = '0.1';
  scrub.setAttribute('aria-label', `Scrub ${track.title}`);

  const volume = document.createElement('input');
  volume.className = 'volume';
  volume.type = 'range';
  volume.min = '0';
  volume.max = '1';
  volume.step = '0.01';
  volume.value = '1';
  volume.setAttribute('aria-label', `Volume for ${track.title}`);

  const timeLabel = document.createElement('span');
  timeLabel.className = 'time';
  timeLabel.textContent = '0:00 / 0:00';

  const audio = document.createElement('audio');
  audio.src = track.audioUrl;
  audio.preload = 'metadata';

  playBtn.addEventListener('click', () => {
    if (audio.paused) {
      audio.play().catch(() => {
        statusEl.textContent = `Playback failed for ${track.title}. Ensure the object is public and CORS is enabled on the bucket.`;
      });
    } else {
      audio.pause();
    }
  });

  volume.addEventListener('input', () => {
    audio.volume = Number(volume.value);
  });

  scrub.addEventListener('input', () => {
    if (Number.isFinite(audio.duration) && audio.duration > 0) {
      audio.currentTime = (Number(scrub.value) / 100) * audio.duration;
    }
  });

  audio.addEventListener('loadedmetadata', () => {
    timeLabel.textContent = `${formatTime(audio.currentTime)} / ${formatTime(audio.duration)}`;
  });

  audio.addEventListener('timeupdate', () => {
    if (Number.isFinite(audio.duration) && audio.duration > 0) {
      scrub.value = ((audio.currentTime / audio.duration) * 100).toString();
    }
    timeLabel.textContent = `${formatTime(audio.currentTime)} / ${formatTime(audio.duration)}`;
  });

  audio.addEventListener('play', () => {
    playBtn.textContent = 'Pause';
  });

  audio.addEventListener('pause', () => {
    playBtn.textContent = 'Play';
  });

  audio.addEventListener('ended', () => {
    scrub.value = '0';
    playBtn.textContent = 'Play';
  });

  controls.append(playBtn, scrub, volume, timeLabel);
  li.append(meta, controls, audio);

  return li;
}

function renderTrackList() {
  trackListEl.replaceChildren();

  const sortedTracks = sortTracks(sortSelect.value);

  for (const track of sortedTracks) {
    trackListEl.append(createTrackItem(track));
  }
}

function loadMockTracks() {
  tracks = [...MOCK_TRACKS];
  statusEl.textContent = `Mock mode: loaded ${tracks.length} sample track${tracks.length === 1 ? '' : 's'}.`;
  renderTrackList();
}

async function loadTracks() {
  if (!CONFIG.bucketName || CONFIG.bucketName === 'YOUR_PUBLIC_BUCKET_NAME') {
    if (CONFIG.enableMockMode) {
      loadMockTracks();
      return;
    }

    statusEl.textContent =
      'Set CONFIG.bucketName in app.js to your public bucket name first.';
    return;
  }

  const params = new URLSearchParams({ 'list-type': '2' });
  if (CONFIG.prefix) params.append('prefix', CONFIG.prefix);

  const listUrl = `https://${CONFIG.bucketName}.s3.${CONFIG.region}.amazonaws.com/?${params.toString()}`;

  try {
    const response = await fetch(listUrl);
    if (!response.ok) {
      throw new Error(`Bucket listing failed with status ${response.status}.`);
    }

    const text = await response.text();
    tracks = parseTracks(text);

    if (tracks.length === 0) {
      statusEl.textContent =
        'No supported audio files found. Add audio files (.mp3, .wav, .m4a, .ogg, .flac) to your bucket.';
      return;
    }

    statusEl.textContent = `Loaded ${tracks.length} track${tracks.length === 1 ? '' : 's'}.`;
    renderTrackList();
  } catch (error) {
    statusEl.textContent = `Error loading tracks: ${error.message} Check bucket public access and CORS.`;
  }
}

sortSelect.addEventListener('change', renderTrackList);
loadTracks();
