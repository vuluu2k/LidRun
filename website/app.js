const copy = {
  en: {
    navFeatures:'Features', navInstall:'Install', source:'Source', eyebrow:'FREE · OPEN SOURCE · LOCAL FIRST',
    heroTitle:'Keep the work running.<br><em>Even when the lid closes.</em>',
    heroBody:'A compact menu bar utility that keeps your Mac awake while Claude Code, Cursor, Docker, or Ollama works — with battery and thermal guardrails built in.',
    download:'Download LidRun free', howInstall:'Installation guide', requirement:'macOS 13 or newer', unsigned:'Unnotarized build',
    trust1:'No account', trust2:'No subscription', trust3:'No outbound telemetry', trust4:'Data stays local',
    featuresEye:'SMALL, BUT CAPABLE', featuresTitle:'Focus on the work, not your power settings.',
    f1Title:'Auto Mode', f1Body:'Automatically stays awake when Claude Code, Cursor, Docker, Ollama, or a custom process is active.',
    f2Title:'Closed-Lid Mode', f2Body:'Keeps a session running with the lid closed and an external display. Results depend on hardware and power conditions.',
    f3Title:'Safety first', f3Body:'Stops on low battery, lost charging, or dangerous heat. Shows real CPU, battery, thermal, and fan readings.',
    f4Title:'Alerts & webhooks', f4Body:'macOS notifications plus webhooks for Discord, Slack, Teams, and custom JSON endpoints.',
    f5Title:'Global shortcuts', f5Body:'Control Auto Mode, Keep Awake, Closed-Lid, and Stop without leaving the keyboard.',
    f6Title:'Local reports', f6Body:'JSONL activity logs and weekly reports stay on your Mac. No analytics and no account.',
    installEye:'INSTALL IN ONE MINUTE', installTitle:'Three steps. No Terminal.', gatekeeper:'LidRun is ad-hoc signed to stay free and is not Apple-notarized. Use Control-click → Open for both the DMG and app on first launch.',
    step1Title:'Control-click the DMG', step1Body:'In Downloads, Control-click or right-click the DMG → Open → Open.',
    step2Title:'Drag LidRun into Applications', step2Body:'Open the DMG and drag LidRun.app into the Applications folder.',
    step3Title:'Control-click the app', step3Body:'In Applications, Control-click LidRun → Open → Open. The panel appears below its moon icon in the menu bar.',
    q1:'Is LidRun really free?', a1:'Yes. There is no paid tier, time limit, or usage tracking.',
    q2:'Why does macOS warn on first launch?', a2:'The free build is not notarized with a paid Apple Developer account. Use Control-click → Open once.',
    q3:'Does Closed-Lid work on every Mac?', a3:'It cannot be guaranteed on every setup. macOS, power, external displays, and hardware can affect it. Test with a non-critical task first.',
    ctaTitle:'Do not let one sleep event end a long-running job.', footer:'Built for long-running work.'
  }
};

let language = localStorage.getItem('lidrun-language') || 'vi';
const original = Object.fromEntries([...document.querySelectorAll('[data-i18n]')].map(el => [el.dataset.i18n, el.innerHTML]));
function setLanguage(next) {
  language = next;
  document.documentElement.lang = next;
  document.querySelectorAll('[data-i18n]').forEach(el => el.innerHTML = (next === 'en' ? copy.en : original)[el.dataset.i18n]);
  document.querySelector('#language').textContent = next === 'en' ? 'VI' : 'EN';
  localStorage.setItem('lidrun-language', next);
}
document.querySelector('#language').addEventListener('click', () => setLanguage(language === 'vi' ? 'en' : 'vi'));
setLanguage(language);

document.querySelector('#year').textContent = new Date().getFullYear();

const github = location.hostname.endsWith('.github.io') && location.pathname.split('/')[1];
if (github) {
  const source = document.querySelector('#source-link');
  source.href = `https://github.com/${location.hostname.split('.')[0]}/${github}`;
  source.hidden = false;
}

let currentRelease = { version: '0.1.0' };
fetch('download.json').then(r => r.ok ? r.json() : Promise.reject()).then(release => {
  currentRelease = release;
  document.querySelectorAll('.download-link').forEach(link => link.href = release.url);
  document.querySelector('#version').textContent = `v${release.version}`;
  document.querySelector('#checksum').textContent = release.sha256;
}).catch(() => {});

document.querySelectorAll('.download-link').forEach(link => link.addEventListener('click', async event => {
  event.preventDefault();
  try {
    const response = await fetch(link.href);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const temporaryLink = document.createElement('a');
    temporaryLink.href = URL.createObjectURL(await response.blob());
    temporaryLink.download = `LidRun-${currentRelease.version}-unsigned.dmg`;
    temporaryLink.click();
    setTimeout(() => URL.revokeObjectURL(temporaryLink.href), 1000);
  } catch {
    location.href = link.href;
  }
}));
