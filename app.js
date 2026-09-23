const $ = (selector) => document.querySelector(selector);

const video = $('#video');
const screen = $('#screen');
const fileInput = $('#file-input');
const dropZone = $('#drop-zone');
const dragOverlay = $('#drag-overlay');
const playerChrome = $('#player-chrome');
const playerCard = $('#player-card');
const seek = $('#seek');
const volume = $('#volume');
const speedMenu = $('#speed-menu');
const speedButton = $('#speed-button');
const speedOptions = $('#speed-options');
const customSpeed = $('#custom-speed');
const speeds = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4];
let objectUrl = null;
let toastTimeout;
let dragDepth = 0;
let hideControlsTimeout;
let suppressVideoClick = false;

function showControls() {
  if (!video.src) return;
  playerCard.classList.remove('chrome-hidden');
  clearTimeout(hideControlsTimeout);
  if (!video.paused && speedMenu.hidden) {
    hideControlsTimeout = setTimeout(() => {
      if (!playerChrome.querySelector(':focus-visible') && speedMenu.hidden && !video.paused) {
        playerCard.classList.add('chrome-hidden');
      }
    }, 2800);
  }
}

function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.classList.add('visible');
  clearTimeout(toastTimeout);
  toastTimeout = setTimeout(() => toast.classList.remove('visible'), 3100);
}

function formatTime(seconds) {
  if (!Number.isFinite(seconds)) return '00:00';
  const total = Math.floor(Math.max(0, seconds));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatSize(bytes) {
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function isVideoFile(file) {
  return Boolean(file && (file.type.startsWith('video/') || /\.(mp4|m4v|mov|webm|ogv|ogg|mkv|avi|wmv)$/i.test(file.name)));
}

function openFile(file) {
  if (!isVideoFile(file)) {
    showToast('请选择视频文件');
    return;
  }
  video.pause();
  if (objectUrl) URL.revokeObjectURL(objectUrl);
  objectUrl = URL.createObjectURL(file);
  video.src = objectUrl;
  video.load();
  video.playbackRate = Number(customSpeed.value);
  dropZone.hidden = true;
  playerChrome.hidden = false;
  playerCard.classList.add('has-video');
  showControls();
  $('#center-play').hidden = false;
  $('#file-name').textContent = file.name;
  $('#file-name').title = file.name;
  $('#file-size').textContent = formatSize(file.size);
  $('#current-time').textContent = '00:00';
  $('#duration').textContent = '00:00';
  seek.value = 0;
  updateRangeFill(seek);
  video.play().catch(() => {
    // Browsers may require a second tap before starting media with sound.
    syncPlayState();
  });
}

function syncPlayState() {
  const playing = !video.paused && !video.ended;
  playerCard.classList.toggle('is-playing', playing);
  $('#play-button').setAttribute('aria-label', playing ? '暂停' : '播放');
  $('#center-play').setAttribute('aria-label', playing ? '暂停视频' : '播放视频');
  $('#center-play').hidden = playing || !video.src;
  if (playing) showControls();
  else {
    clearTimeout(hideControlsTimeout);
    playerCard.classList.remove('chrome-hidden');
  }
}

async function togglePlay() {
  if (!video.src) return;
  if (video.paused) {
    try { await video.play(); } catch { showToast('无法播放此视频，请检查文件格式'); }
  } else {
    video.pause();
  }
}

function skip(seconds) {
  if (!Number.isFinite(video.duration)) return;
  video.currentTime = Math.max(0, Math.min(video.duration, video.currentTime + seconds));
}

function updateRangeFill(input) {
  const min = Number(input.min || 0);
  const max = Number(input.max || 100);
  const percentage = ((Number(input.value) - min) / (max - min)) * 100;
  input.style.background = `linear-gradient(to right, var(--accent) ${percentage}%, #484b4f ${percentage}%)`;
}

function setSpeed(rate) {
  const value = Math.min(4, Math.max(0.25, Number(rate)));
  video.playbackRate = value;
  customSpeed.value = value;
  $('#speed-value').textContent = `${value}×`;
  $('#custom-speed-value').textContent = `${value.toFixed(2)}×`;
  speedButton.setAttribute('aria-label', `播放速度：${value} 倍`);
  speedOptions.querySelectorAll('button').forEach(button => {
    button.classList.toggle('active', Number(button.dataset.speed) === value);
    button.setAttribute('aria-pressed', String(Number(button.dataset.speed) === value));
  });
  updateRangeFill(customSpeed);
}

function closeSpeedMenu() {
  speedMenu.hidden = true;
  speedButton.setAttribute('aria-expanded', 'false');
  showControls();
}

speeds.forEach(speed => {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'speed-option';
  button.dataset.speed = speed;
  button.textContent = `${speed}×`;
  button.setAttribute('aria-label', `${speed} 倍速`);
  button.addEventListener('click', () => { setSpeed(speed); closeSpeedMenu(); });
  speedOptions.append(button);
});
setSpeed(1);
updateRangeFill(volume);
updateRangeFill(seek);

$('#choose-button').addEventListener('click', () => fileInput.click());
$('#change-button').addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', () => {
  if (fileInput.files?.[0]) openFile(fileInput.files[0]);
  fileInput.value = '';
});

document.addEventListener('dragenter', event => {
  if (!event.dataTransfer?.types.includes('Files')) return;
  event.preventDefault();
  dragDepth++;
  dragOverlay.classList.add('visible');
});
document.addEventListener('dragover', event => {
  if (!event.dataTransfer?.types.includes('Files')) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = 'copy';
});
document.addEventListener('dragleave', event => {
  if (!event.dataTransfer?.types.includes('Files')) return;
  dragDepth = Math.max(0, dragDepth - 1);
  if (dragDepth === 0) dragOverlay.classList.remove('visible');
});
document.addEventListener('drop', event => {
  if (!event.dataTransfer?.files.length) return;
  event.preventDefault();
  dragDepth = 0;
  dragOverlay.classList.remove('visible');
  openFile(event.dataTransfer.files[0]);
});

video.addEventListener('loadedmetadata', () => {
  $('#duration').textContent = formatTime(video.duration);
  seek.disabled = !Number.isFinite(video.duration);
});
video.addEventListener('timeupdate', () => {
  $('#current-time').textContent = formatTime(video.currentTime);
  if (Number.isFinite(video.duration) && video.duration > 0) {
    seek.value = Math.round((video.currentTime / video.duration) * 1000);
    updateRangeFill(seek);
  }
});
video.addEventListener('play', syncPlayState);
video.addEventListener('pause', syncPlayState);
video.addEventListener('ended', syncPlayState);
video.addEventListener('error', () => {
  if (video.src) showToast('浏览器无法解码此视频，请尝试 MP4（H.264）或 WebM');
});
video.addEventListener('volumechange', () => {
  playerCard.classList.toggle('is-muted', video.muted || video.volume === 0);
  $('#mute-button').setAttribute('aria-label', video.muted ? '取消静音' : '静音');
  volume.value = video.volume;
  updateRangeFill(volume);
});

$('#play-button').addEventListener('click', togglePlay);
$('#center-play').addEventListener('click', togglePlay);
video.addEventListener('click', () => {
  if (suppressVideoClick) {
    suppressVideoClick = false;
    return;
  }
  togglePlay();
});
video.addEventListener('pointerdown', event => {
  if (event.pointerType !== 'mouse' && playerCard.classList.contains('chrome-hidden')) {
    suppressVideoClick = true;
    showControls();
  }
});
playerCard.addEventListener('pointermove', showControls);
playerChrome.addEventListener('focusin', showControls);
playerChrome.addEventListener('focusout', () => setTimeout(showControls, 0));
$('#back-button').addEventListener('click', () => skip(-10));
$('#forward-button').addEventListener('click', () => skip(10));
seek.addEventListener('input', () => {
  if (!Number.isFinite(video.duration)) return;
  video.currentTime = Number(seek.value) / 1000 * video.duration;
  updateRangeFill(seek);
});
volume.addEventListener('input', () => {
  video.volume = Number(volume.value);
  video.muted = video.volume === 0;
});
$('#mute-button').addEventListener('click', () => { video.muted = !video.muted; });
speedButton.addEventListener('click', () => {
  speedMenu.hidden = !speedMenu.hidden;
  speedButton.setAttribute('aria-expanded', String(!speedMenu.hidden));
  showControls();
});
customSpeed.addEventListener('input', () => setSpeed(customSpeed.value));
document.addEventListener('pointerdown', event => {
  if (!speedMenu.hidden && !speedMenu.contains(event.target) && !speedButton.contains(event.target)) closeSpeedMenu();
});

const pipButton = $('#pip-button');
if (document.pictureInPictureEnabled && 'requestPictureInPicture' in video) {
  pipButton.hidden = false;
  pipButton.addEventListener('click', async () => {
    try {
      if (document.pictureInPictureElement) await document.exitPictureInPicture();
      else await video.requestPictureInPicture();
    } catch { showToast('此浏览器暂时无法开启画中画'); }
  });
}
$('#fullscreen-button').addEventListener('click', async () => {
  try {
    if (document.fullscreenElement) await document.exitFullscreen();
    else if (playerCard.requestFullscreen) await playerCard.requestFullscreen();
    else if (video.webkitEnterFullscreen) video.webkitEnterFullscreen();
  } catch { showToast('此浏览器暂时无法进入全屏'); }
});

document.addEventListener('keydown', event => {
  if (!video.src) return;
  if (event.key === 'Escape') { closeSpeedMenu(); return; }
  if (['INPUT', 'BUTTON'].includes(document.activeElement?.tagName)) return;
  if (event.code === 'Space') { event.preventDefault(); togglePlay(); }
  else if (event.key === 'ArrowLeft') { event.preventDefault(); skip(-1); }
  else if (event.key === 'ArrowRight') { event.preventDefault(); skip(1); }
  else if (event.key.toLowerCase() === 'm') video.muted = !video.muted;
  else if (event.key.toLowerCase() === 'f') $('#fullscreen-button').click();
});
window.addEventListener('beforeunload', () => { if (objectUrl) URL.revokeObjectURL(objectUrl); });
