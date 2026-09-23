const copy = {
  en: {
    navFeatures:'Features', navInstall:'Install', source:'Source', eyebrow:'FREE · OPEN SOURCE · LOCAL FIRST',
    heroTitle:'Keep the work running.<br><em>Even when the lid closes.</em>',
    heroBody:'A compact menu bar utility that keeps your Mac awake while Claude Code, Cursor, Docker, or Ollama works — with battery and thermal guardrails built in.',
    download:'Download LidRun free', howInstall:'Installation guide', requirement:'macOS 13 or newer', unsigned:'Unnotarized build',
    trust1:'No account', trust2:'No subscription', trust3:'No outbound telemetry', trust4:'Data stays local',
    featuresEye:'SMALL, BUT CAPABLE', featuresTitle:'Focus on the work, not your power settings.',
    f1Title:'Auto Mode', f1Body:'Stays awake when it detects Claude Code, Cursor, Docker, or Ollama. Optional extended detection for Python, Node, SSH/rsync, Xcode builds, and large network transfers (&gt;~1 MB/s), plus custom process rules.',
    f2Title:'Closed-Lid Mode', f2Body:'Keep working with the lid shut. Without setup it needs the charger (a macOS limitation). Turn on “Full Closed-Lid” in Settings: enter your admin password once to install a sudoers rule that only allows <code>pmset -a disablesleep 0|1</code>, so it works on battery too. Sleep is restored on every stop, safety stop, quit, and app launch; a safety checklist is shown before first use.',
    f3Title:'Safety first', f3Body:'Stops when the charger is unplugged (Only When Charging), on low battery (and puts the Mac to sleep before it dies), or when macOS reports serious/critical thermal state. A watchdog caps maximum runtime. If a safety stop happens with the lid shut, the Mac sleeps immediately.',
    f4Title:'Run Command', f4Body:'<code>apprun -- &lt;command&gt;</code> keeps the Mac awake until the command exits, returns its exit code, uses the app’s safety settings, and posts a <code>command_finished</code> webhook. <code>apprun --sleep -- &lt;command&gt;</code> sleeps the Mac when it finishes.',
    f5Title:'Alerts &amp; webhooks', f5Body:'macOS notifications plus Discord, Slack, Teams, or generic JSON webhooks, with an optional bearer token.',
    f6Title:'One-click updates &amp; local reports', f6Body:'An in-app “Update to vX” button. Weekly reports and the JSONL activity log stay on your Mac. Global shortcuts ⌃⌥A/S/L/X.',
    installEye:'INSTALL IN ONE MINUTE', installTitle:'One command. No Gatekeeper prompt.', copy:'Copy', copied:'Copied', gatekeeper:'Paste this into Terminal. It downloads the latest build, verifies its SHA-256, and installs it to Applications without a Gatekeeper warning. Installed copies update from inside the app.',
    step1Title:'Or download the DMG', step1Body:'Drag LidRun Personal.app into the Applications folder.',
    step2Title:'Open the app once', step2Body:'macOS blocks it because the free build is not Apple-notarized. Click Done.',
    step3Title:'Open Anyway', step3Body:'Go to System Settings → Privacy &amp; Security and click Open Anyway. macOS remembers your choice.',
    q1:'Is LidRun Personal really free?', a1:'Yes. There is no paid tier, time limit, or usage tracking.',
    q2:'Why does macOS warn on first launch?', a2:'The free build is not notarized with a paid Apple Developer account. Use the Terminal install command, or System Settings → Privacy &amp; Security → Open Anyway once.',
    q3:'Does Closed-Lid work on every Mac?', a3:'Out of the box, Closed-Lid needs the charger because that is what macOS allows. To run on battery with the lid shut, turn on Full Closed-Lid in Settings. Either way, keep the vents clear, never put a running Mac in a bag, and test with non-critical work first.',
    q4:'Is LidRun Personal related to lidrun.com?', a4:'No. This is an independent open-source project, not affiliated with the commercial LidRun at lidrun.com. The app was renamed “LidRun Personal” to avoid confusion.',
    navDonate:'Sponsor', donateEye:'SUPPORT THE PROJECT', donateTitle:'Free forever. Chip in if it helps.',
    donateBody:'LidRun Personal will always be free and open source, with no paid tier. Donations buy development time and go toward an Apple Developer account ($99/year) so the app can be notarized and install without Gatekeeper warnings.',
    donateGithub:'One-time or monthly', donateCoffee:'A small one-time tip', donateBank:'Bank transfer (VietQR)', donateBankName:'Bank', donateAccount:'Account', donateHolder:'Account holder',
    ctaTitle:'Do not let one sleep event end a long-running job.', footer:'Built for long-running work.',
    panelReady:'Ready', panelCharging:'Charging', panelAutoMode:'Auto Mode', panelKeepAwake:'Keep Awake', panelChargingOnly:'Only When Charging', panelTimer:'Timer', panelClosedLid:'Closed-Lid Mode', panelCooling:'Cooling', panelStop:'Stop',
    panelStatus:'Status', panelProtected:'Protected', panelTasks:'Tasks &amp; Reports', panelNotifications:'Notifications &amp; Webhooks', panelSettings:'Settings', panelQuit:'Quit LidRun', panelUpdate:'Update to v0.1.15'
  }
};

// Donation channels: a card shows only when its value is filled in.
const donate = { github: 'https://github.com/sponsors/vuluu2k', coffee: 'https://buymeacoffee.com/vuluu04032j', vietqr: { bank: 'vietcombank', bankName: 'Vietcombank', account: '2898709170', name: 'LUU CONG QUANG VU' } };
function renderDonate() {
  const { github, coffee, vietqr } = donate;
  const qr = vietqr.bank && vietqr.account && vietqr.name;
  const card = (id, on) => Object.assign(document.querySelector(id), { hidden: !on });
  card('#donate-github', github).href = github;
  card('#donate-coffee', coffee).href = coffee;
  const qrCard = card('#donate-vietqr', qr);
  if (qr) {
    Object.assign(qrCard.querySelector('img'), {
      src: `https://img.vietqr.io/image/${encodeURIComponent(vietqr.bank)}-${encodeURIComponent(vietqr.account)}-compact2.png?accountName=${encodeURIComponent(vietqr.name)}`,
      alt: `VietQR ${vietqr.bank} ${vietqr.account} ${vietqr.name}`
    });
    qrCard.querySelector('.qr-bank').textContent = vietqr.bankName || vietqr.bank;
    qrCard.querySelector('.qr-account').textContent = vietqr.account;
    qrCard.querySelector('.qr-name').textContent = vietqr.name;
  }
  document.querySelector('#donate').hidden = !(github || coffee || qr);
}
renderDonate();

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
const copyButton = document.querySelector('#copy-command');
copyButton.addEventListener('click', async () => {
  const command = document.querySelector('#install-command');
  try { await navigator.clipboard.writeText(command.textContent); } catch { getSelection().selectAllChildren(command); return; }
  copyButton.textContent = language === 'en' ? copy.en.copied : 'Đã chép';
  setTimeout(() => copyButton.textContent = language === 'en' ? copy.en.copy : original.copy, 1500);
});
document.querySelector('#install-command').textContent = `curl -fsSL ${new URL('install.sh', location.href).href.split('#')[0]} | bash`;

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
