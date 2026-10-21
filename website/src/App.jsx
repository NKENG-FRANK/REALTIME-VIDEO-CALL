import { useState, useEffect } from 'react'
import logoImage from './assets/callwave-logo.png'
import heroLifestyle from './assets/hero_lifestyle.jpg'
import './App.css'

export default function App() {
  const [activeTab, setActiveTab] = useState('all')
  const [micMuted, setMicMuted] = useState(false)
  const [videoActive, setVideoActive] = useState(true)
  const [speakerOn, setSpeakerOn] = useState(true)
  const [callDuration, setCallDuration] = useState(258) // 04:18
  const [showInstallModal, setShowInstallModal] = useState(null) // 'android' | 'windows' | null
  const [copiedLink, setCopiedLink] = useState(false)

  // Call timer simulation for the mockup
  useEffect(() => {
    const timer = setInterval(() => {
      setCallDuration((prev) => prev + 1)
    }, 1000)
    return () => clearInterval(timer)
  }, [])

  const formatTimer = (seconds) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const copyShareLink = () => {
    navigator.clipboard?.writeText(window.location.origin)
    setCopiedLink(true)
    setTimeout(() => setCopiedLink(false), 2500)
  }

  return (
    <div className="callwave-site">
      {/* Background ambient accents */}
      <div className="ambient-glow glow-1" aria-hidden="true" />
      <div className="ambient-glow glow-2" aria-hidden="true" />

      {/* TOPBAR NAVIGATION */}
      <header className="site-header">
        <div className="header-inner">
          <a href="#" className="brand-link">
            <img src={logoImage} alt="CallWave Logo" className="brand-icon" />
            <span className="brand-text">
              Call<span>wave</span>
            </span>
          </a>

          <nav className="desktop-nav" aria-label="Main Navigation">
            <a href="#about" className="nav-link">About</a>
            <a href="#features" className="nav-link">Features</a>
            <a href="#how-it-works" className="nav-link">How it Works</a>
            <a href="#downloads" className="nav-link">Downloads</a>
            <a href="#security" className="nav-link">Sovereignty</a>
          </nav>

          <div className="header-actions">
            <a href="#downloads" className="btn-outline-pill">
              Web Client
            </a>
            <a href="#downloads" className="btn-primary-pill">
              Download App
            </a>
          </div>
        </div>
      </header>

      {/* MAIN HERO STAGE (INSPIRED BY USER TEMPLATE) */}
      <main className="hero-stage-container">
        <div className="hero-master-card">
          {/* LEFT GREEN GEOMETRIC SHAPE */}
          <div className="hero-green-wing">
            <div className="green-wing-content">
              <span className="future-eyebrow">THE FUTURE IS HERE</span>
              <h2 className="green-wing-title">
                The most efficient communication tool out there!
              </h2>
              <p className="green-wing-desc">
                CallWave allows students, families, and professionals to connect seamlessly with
                ultra-low latency, crystal-clear audio and HD video—customized for maximum stability
                even on challenging networks.
              </p>

              {/* Circular interactive feature badges matching template circles */}
              <div className="floating-badge-group">
                <div className="floating-circle-item" title="Ultra-Low Latency">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                    <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
                  </svg>
                  <span>&lt;35ms RTT</span>
                </div>
                <div className="floating-circle-item" title="100% Local Sovereignty">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                  <span>Sovereign</span>
                </div>
                <div className="floating-circle-item" title="Studio Grade Opus Audio">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                    <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
                    <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                    <line x1="12" y1="19" x2="12" y2="23" />
                  </svg>
                  <span>HD Voice</span>
                </div>
              </div>
            </div>
          </div>

          {/* CENTER HERO COPY & DOWNLOAD CTA */}
          <div className="hero-center-content">
            <div className="hero-eyebrow-tag">
              <span className="eyebrow-dot" />
              <span>INTRODUCING CALLWAVE</span>
            </div>

            <h1 className="hero-main-title">
              <span className="quote-mark">“</span>Skip the lag<span className="quote-mark">”</span>
              <br />
              and start enjoying your calls!
            </h1>

            <p className="hero-subtext">
              Real-time video & voice calls powered by peer-to-peer WebRTC and sovereign private
              hosting. Say goodbye to dropped conversations and foreign data servers.
            </p>

            {/* Platform Badges */}
            <div className="hero-cta-buttons">
              <a href="https://drive.google.com/uc?export=download&id=1jUA9oajBW75DMiAul-a2C_3QQ1tH5_f0" target="_blank" rel="noreferrer" className="platform-store-badge android-badge">
                <div className="badge-icon">
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993 0 .5511-.4483.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 0 0-.1521-.5676.416.416 0 0 0-.5676.1521l-2.0223 3.503C15.5902 8.4116 13.8533 8.082 12 8.082c-1.8533 0-3.5902.3296-5.1368.8677L4.8409 5.4467a.4161.4161 0 0 0-.5677-.1521.4157.4157 0 0 0-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396" />
                  </svg>
                </div>
                <div className="badge-texts">
                  <span className="badge-micro">DOWNLOAD APK</span>
                  <span className="badge-bold">Android Release</span>
                </div>
              </a>

              <a href="https://drive.google.com/uc?export=download&id=1ehSCso7-sgZT5S1-lKa3llt0CvYCmbGF" target="_blank" rel="noreferrer" className="platform-store-badge windows-badge">
                <div className="badge-icon">
                  <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.551H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-13.051-1.852" />
                  </svg>
                </div>
                <div className="badge-texts">
                  <span className="badge-micro">DOWNLOAD FOR</span>
                  <span className="badge-bold">Windows (64-bit)</span>
                </div>
              </a>
            </div>

            <div className="hero-spec-pills">
              <span>✓ v1.0.0 Stable</span>
              <span>✓ No Subscription</span>
              <span>✓ High-Quality Opus</span>
              <span>✓ Self-Hosted VPS</span>
            </div>
          </div>

          {/* FLOATING PHONE MOCKUP WITH ACTIVE CALL */}
          <div className="hero-mockup-wrapper">
            {/* Floating decorative diamond accents (from template design) */}
            <div className="decor-diamond diamond-top-left" aria-hidden="true" />
            <div className="decor-diamond diamond-mid-right" aria-hidden="true" />
            <div className="decor-diamond diamond-bottom" aria-hidden="true" />

            <div className="phone-device-frame">
              <div className="phone-earpiece" />
              <div className="phone-camera-lens" />

              <div className="phone-screen-content">
                {/* Status Bar */}
                <div className="screen-header">
                  <span className="screen-time">14:52</span>
                  <div className="screen-network-icons">
                    <span>5G</span>
                    <div className="battery-icon" />
                  </div>
                </div>

                {/* Call Status Header */}
                <div className="mockup-call-header">
                  <span className="live-pill">
                    <span className="live-dot" /> LIVE CALL
                  </span>
                  <span className="room-id">ROOM #CW-7821</span>
                </div>

                {/* Call Avatar & Active Ripples */}
                <div className="mockup-avatar-stage">
                  <div className={`avatar-ripple-ring ring-3 ${micMuted ? 'paused' : ''}`} />
                  <div className={`avatar-ripple-ring ring-2 ${micMuted ? 'paused' : ''}`} />
                  <div className={`avatar-ripple-ring ring-1 ${micMuted ? 'paused' : ''}`} />

                  <div className="mockup-avatar-main">
                    <span className="avatar-initials">NM</span>
                  </div>
                </div>

                <div className="mockup-caller-info">
                  <h3 className="caller-name">Nana & Mireille</h3>
                  <p className="call-duration">{formatTimer(callDuration)} • HD Audio</p>
                </div>

                {/* Waveform indicator */}
                <div className="audio-wave-visualizer" aria-hidden="true">
                  <span className="wave-bar b1" />
                  <span className="wave-bar b2" />
                  <span className="wave-bar b3" />
                  <span className="wave-bar b4" />
                  <span className="wave-bar b5" />
                  <span className="wave-bar b6" />
                  <span className="wave-bar b7" />
                  <span className="wave-bar b8" />
                </div>

                {/* In-Call Controls */}
                <div className="mockup-controls-bar">
                  <button
                    type="button"
                    className={`mockup-ctrl-btn ${micMuted ? 'active-red' : ''}`}
                    onClick={() => setMicMuted(!micMuted)}
                    title={micMuted ? 'Unmute Mic' : 'Mute Mic'}
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      {micMuted ? (
                        <>
                          <line x1="1" y1="1" x2="23" y2="23" />
                          <path d="M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6" />
                          <path d="M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23" />
                        </>
                      ) : (
                        <>
                          <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
                          <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                        </>
                      )}
                    </svg>
                  </button>

                  <button
                    type="button"
                    className={`mockup-ctrl-btn ${speakerOn ? 'active-green' : ''}`}
                    onClick={() => setSpeakerOn(!speakerOn)}
                    title="Toggle Speakerphone"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
                      <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07" />
                    </svg>
                  </button>

                  <button
                    type="button"
                    className={`mockup-ctrl-btn ${!videoActive ? 'active-red' : ''}`}
                    onClick={() => setVideoActive(!videoActive)}
                    title="Toggle Video"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <polygon points="23 7 16 12 23 17 23 7" />
                      <rect x="1" y="5" width="15" height="14" rx="2" ry="2" />
                    </svg>
                  </button>

                  <button
                    type="button"
                    className="mockup-ctrl-btn btn-hangup"
                    onClick={() => setCallDuration(0)}
                    title="Hang Up"
                  >
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08a.996.996 0 0 1 0-1.41C3.28 8.81 7.42 7.25 12 7.25s8.72 1.56 11.71 4.42c.39.39.39 1.02 0 1.41l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28-.79-.74-1.69-1.36-2.67-1.85-.33-.16-.56-.5-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* RIGHT AMBER GEOMETRIC SHAPE WITH LIFESTYLE IMAGE */}
          <div className="hero-amber-wing">
            <div className="amber-wing-backdrop" />
            <div className="lifestyle-image-holder">
              <img
                src={heroLifestyle}
                alt="Happy user enjoying crystal clear video call with CallWave"
                className="lifestyle-person-img"
              />
            </div>
          </div>
        </div>
      </main>

      {/* DOWNLOADS SECTION */}
      <section className="site-section downloads-section" id="downloads">
        <div className="section-container">
          <div className="section-header-center">
            <span className="section-tag">OFFICIAL RELEASES</span>
            <h2 className="section-title">Download CallWave for Any Device</h2>
            <p className="section-lead">
              Get the latest official builds for Android and Windows. Self-hosted, lightweight, and
              instant to set up.
            </p>

            <div className="filter-tab-bar">
              <button
                type="button"
                className={`tab-btn ${activeTab === 'all' ? 'active' : ''}`}
                onClick={() => setActiveTab('all')}
              >
                All Platforms
              </button>
              <button
                type="button"
                className={`tab-btn ${activeTab === 'android' ? 'active' : ''}`}
                onClick={() => setActiveTab('android')}
              >
                Android
              </button>
              <button
                type="button"
                className={`tab-btn ${activeTab === 'windows' ? 'active' : ''}`}
                onClick={() => setActiveTab('windows')}
              >
                Windows
              </button>
            </div>
          </div>

          <div className="downloads-cards-grid">
            {/* ANDROID CARD */}
            {(activeTab === 'all' || activeTab === 'android') && (
              <div className="download-platform-card featured-card">
                <div className="card-top-header">
                  <div className="card-platform-icon android-color">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993 0 .5511-.4483.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 0 0-.1521-.5676.416.416 0 0 0-.5676.1521l-2.0223 3.503C15.5902 8.4116 13.8533 8.082 12 8.082c-1.8533 0-3.5902.3296-5.1368.8677L4.8409 5.4467a.4161.4161 0 0 0-.5677-.1521.4157.4157 0 0 0-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396" />
                    </svg>
                  </div>
                  <div className="card-title-group">
                    <span className="card-badge">RECOMMENDED FOR MOBILE</span>
                    <h3 className="card-platform-name">Android Package</h3>
                    <p className="card-version-text">v1.0.0 Stable • 58 MB • APK Direct</p>
                  </div>
                </div>

                <div className="card-feature-list">
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Direct incoming call notifications & lockscreen UI</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Loudspeaker & earpiece auto-routing for phone calls</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Hardware-accelerated camera & microphone processing</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Compatible with Android 8.0 Oreo up to Android 15</span>
                  </div>
                </div>

                <div className="card-action-bar">
                  <a
                    href="https://drive.google.com/uc?export=download&id=1jUA9oajBW75DMiAul-a2C_3QQ1tH5_f0"
                    target="_blank" rel="noreferrer"
                    className="btn-download-main btn-green"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4">
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                      <polyline points="7 10 12 15 17 10" />
                      <line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                    Download APK Directly
                  </a>

                  <button
                    type="button"
                    className="btn-guide"
                    onClick={() => setShowInstallModal('android')}
                  >
                    Installation Guide
                  </button>
                </div>
              </div>
            )}

            {/* WINDOWS CARD */}
            {(activeTab === 'all' || activeTab === 'windows') && (
              <div className="download-platform-card">
                <div className="card-top-header">
                  <div className="card-platform-icon windows-color">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.551H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-13.051-1.852" />
                    </svg>
                  </div>
                  <div className="card-title-group">
                    <span className="card-badge">DESKTOP POWERHOUSE</span>
                    <h3 className="card-platform-name">Windows 64-bit</h3>
                    <p className="card-version-text">v1.0.0 Stable • Standalone ZIP</p>
                  </div>
                </div>

                <div className="card-feature-list">
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Single-instance mutex (Never creates duplicate processes)</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Minimizes quietly to system tray; instant wakeup</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Native C++ WebRTC stack with low CPU usage</span>
                  </div>
                  <div className="feature-item">
                    <span className="check-mark">✓</span>
                    <span>Windows 10 & Windows 11 (x64) compatible</span>
                  </div>
                </div>

                <div className="card-action-bar">
                  <a
                    href="https://drive.google.com/uc?export=download&id=1ehSCso7-sgZT5S1-lKa3llt0CvYCmbGF"
                    target="_blank" rel="noreferrer"
                    className="btn-download-main btn-amber"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4">
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                      <polyline points="7 10 12 15 17 10" />
                      <line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                    Download ZIP (x64)
                  </a>

                  <button
                    type="button"
                    className="btn-guide"
                    onClick={() => setShowInstallModal('windows')}
                  >
                    How to Run
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* Quick Join / Web Client Banner */}
          <div className="web-client-banner">
            <div className="banner-text">
              <h4>Want to test without installing?</h4>
              <p>
                CallWave works seamlessly across browsers on PC and Mobile via native WebRTC. Join any room in one click.
              </p>
            </div>
            <div className="banner-action">
              <button type="button" className="btn-secondary-white" onClick={copyShareLink}>
                {copiedLink ? 'Copied Site Link! ✓' : 'Share CallWave Link'}
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* WHAT CALLWAVE DOES / FEATURES */}
      <section className="site-section features-section" id="features">
        <div className="section-container">
          <div className="section-header-center">
            <span className="section-tag">ENGINEERED FOR EXCELLENCE</span>
            <h2 className="section-title">What Our Software Does</h2>
            <p className="section-lead">
              CallWave combines state-of-the-art WebRTC media streaming with private microservices
              to deliver a truly sovereign communication experience.
            </p>
          </div>

          <div className="features-grid">
            {/* Feature 1 */}
            <div className="feature-card">
              <div className="feature-icon icon-green">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
                </svg>
              </div>
              <h3>Sub-100ms Ultra-Low Latency</h3>
              <p>
                Direct peer-to-peer data transport ensures real-time conversations without awkward
                delays or talking over one another.
              </p>
            </div>

            {/* Feature 2 */}
            <div className="feature-card">
              <div className="feature-icon icon-amber">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                  <line x1="12" y1="19" x2="12" y2="23" />
                  <line x1="8" y1="23" x2="16" y2="23" />
                </svg>
              </div>
              <h3>Studio-Grade Opus Voice</h3>
              <p>
                Built-in acoustic echo cancellation (AEC), automatic gain control (AGC), and background
                noise suppression keep voices crisp on any device.
              </p>
            </div>

            {/* Feature 3 */}
            <div className="feature-card">
              <div className="feature-icon icon-coral">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <polygon points="23 7 16 12 23 17 23 7" />
                  <rect x="1" y="5" width="15" height="14" rx="2" ry="2" />
                </svg>
              </div>
              <h3>Adaptive HD Video</h3>
              <p>
                Dynamic resolution and bitrate scaling adapt in real time to fluctuating 3G/4G/5G
                connections without freezing or abruptly hanging up.
              </p>
            </div>

            {/* Feature 4 */}
            <div className="feature-card">
              <div className="feature-icon icon-green">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                </svg>
              </div>
              <h3>Sovereign &amp; Private by Design</h3>
              <p>
                Calls are end-to-end encrypted and orchestrated over private microservices. No foreign
                cloud telemetry, ad tracking, or call recording.
              </p>
            </div>

            {/* Feature 5 */}
            <div className="feature-card">
              <div className="feature-icon icon-amber">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                  <line x1="8" y1="21" x2="16" y2="21" />
                  <line x1="12" y1="17" x2="12" y2="21" />
                </svg>
              </div>
              <h3>Cross-Platform Windows &amp; Mobile</h3>
              <p>
                Seamless calling between Windows desktops and Android smartphones. Call your office PC
                from your mobile or join group rooms anywhere.
              </p>
            </div>

            {/* Feature 6 */}
            <div className="feature-card">
              <div className="feature-icon icon-coral">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                  <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </div>
              <h3>Room-Based Collaboration</h3>
              <p>
                Create named rooms for fast team check-ins, study groups, or family calls with live
                audio visualizers and active participant indicators.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="site-section how-section" id="how-it-works">
        <div className="section-container">
          <div className="section-header-center">
            <span className="section-tag">SIMPLICITY FIRST</span>
            <h2 className="section-title">How CallWave Works in 3 Steps</h2>
          </div>

          <div className="steps-row">
            <div className="step-card">
              <div className="step-badge">01</div>
              <h4>Download &amp; Launch</h4>
              <p>
                Grab the Android APK or Windows standalone bundle. No complicated installers or heavy
                runtimes needed.
              </p>
            </div>

            <div className="step-card">
              <div className="step-badge">02</div>
              <h4>Start or Join a Room</h4>
              <p>
                Log in to call a registered contact directly or spin up an instant room code to share
                with your group.
              </p>
            </div>

            <div className="step-card">
              <div className="step-badge">03</div>
              <h4>Talk Privately &amp; Freely</h4>
              <p>
                Enjoy high definition peer-to-peer audio and video backed by our secure local VPS
                infrastructure.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* LOCAL SOVEREIGNTY CALLOUT */}
      <section className="site-section sovereignty-section" id="security">
        <div className="section-container">
          <div className="sovereignty-banner">
            <div className="sovereignty-content">
              <span className="sovereignty-tag">LOCAL INFRASTRUCTURE</span>
              <h2>Your Conversations Stay In Cameroon.</h2>
              <p>
                Unlike foreign corporate platforms that route your voice and video data through overseas
                servers, CallWave runs on dedicated microservices designed for local sovereignty, fast
                peering, and strict privacy.
              </p>
              <div className="cameroon-flag-bar">
                <span className="c-stripe c-green" />
                <span className="c-stripe c-red"><span className="c-star">★</span></span>
                <span className="c-stripe c-yellow" />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="site-footer">
        <div className="footer-container">
          <div className="footer-col-main">
            <div className="footer-brand">
              <img src={logoImage} alt="CallWave" className="footer-logo" />
              <span>Callwave</span>
            </div>
            <p className="footer-motto">
              Next-generation real-time voice and video calling. Call strong. Stay sovereign.
            </p>
          </div>

          <div className="footer-links-group">
            <div className="footer-col">
              <h5>Platforms</h5>
              <a href="https://drive.google.com/uc?export=download&id=1jUA9oajBW75DMiAul-a2C_3QQ1tH5_f0" target="_blank" rel="noreferrer">Android APK (v1.0)</a>
              <a href="https://drive.google.com/uc?export=download&id=1ehSCso7-sgZT5S1-lKa3llt0CvYCmbGF" target="_blank" rel="noreferrer">Windows Desktop (x64)</a>
              <a href="#downloads">Web Client</a>
            </div>

            <div className="footer-col">
              <h5>Technology</h5>
              <a href="#features">WebRTC Engine</a>
              <a href="#features">Opus Adaptive Audio</a>
              <a href="#security">Private Microservices</a>
            </div>

            <div className="footer-col">
              <h5>Project</h5>
              <a href="https://github.com/NKENG-FRANK/REALTIME-VIDEO-CALL" target="_blank" rel="noreferrer">
                GitHub Repository ↗
              </a>
              <a href="#about">About CallWave</a>
              <a href="#downloads">Release Notes</a>
            </div>
          </div>
        </div>

        <div className="footer-bottom-bar">
          <p>© {new Date().getFullYear()} CallWave. Made with pride for Cameroon. All rights reserved.</p>
          <div className="system-health-pill">
            <span className="health-dot" /> VPS Services Online (144.91.89.100)
          </div>
        </div>
      </footer>

      {/* INSTALLATION GUIDE MODAL */}
      {showInstallModal && (
        <div className="modal-backdrop" onClick={() => setShowInstallModal(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <button
              type="button"
              className="modal-close-btn"
              onClick={() => setShowInstallModal(null)}
            >
              ×
            </button>

            {showInstallModal === 'android' ? (
              <>
                <div className="modal-header">
                  <div className="modal-icon android-color">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993 0 .5511-.4483.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 0 0-.1521-.5676.416.416 0 0 0-.5676.1521l-2.0223 3.503C15.5902 8.4116 13.8533 8.082 12 8.082c-1.8533 0-3.5902.3296-5.1368.8677L4.8409 5.4467a.4161.4161 0 0 0-.5677-.1521.4157.4157 0 0 0-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396" />
                    </svg>
                  </div>
                  <div>
                    <h3>How to Install on Android</h3>
                    <p>3 quick steps to install CallWave APK</p>
                  </div>
                </div>

                <div className="modal-steps-list">
                  <div className="modal-step">
                    <span className="step-num">1</span>
                    <p>
                      <strong>Download the APK file:</strong> Click the "Download APK Directly"
                      button to save `CallWave-Android.apk` to your phone's Download folder.
                    </p>
                  </div>
                  <div className="modal-step">
                    <span className="step-num">2</span>
                    <p>
                      <strong>Allow Installation from Unknown Sources:</strong> When opening the APK,
                      if Android asks for permission, tap <em>Settings</em> and toggle <em>Allow from this source</em>.
                    </p>
                  </div>
                  <div className="modal-step">
                    <span className="step-num">3</span>
                    <p>
                      <strong>Open and Grant Permissions:</strong> Launch CallWave and accept Camera,
                      Microphone, and Notification access so you can receive incoming calls even when
                      your screen is locked.
                    </p>
                  </div>
                </div>

                <div className="modal-footer">
                  <a
                    href="https://drive.google.com/uc?export=download&id=1jUA9oajBW75DMiAul-a2C_3QQ1tH5_f0"
                    target="_blank" rel="noreferrer"
                    className="btn-download-main btn-green"
                  >
                    Download APK Now (58 MB)
                  </a>
                </div>
              </>
            ) : (
              <>
                <div className="modal-header">
                  <div className="modal-icon windows-color">
                    <svg viewBox="0 0 24 24" fill="currentColor">
                      <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.551H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-13.051-1.852" />
                    </svg>
                  </div>
                  <div>
                    <h3>How to Run on Windows</h3>
                    <p>No installation required — portable package</p>
                  </div>
                </div>

                <div className="modal-steps-list">
                  <div className="modal-step">
                    <span className="step-num">1</span>
                    <p>
                      <strong>Download the ZIP bundle:</strong> Click "Download ZIP (x64)" to receive
                      `CallWave-Windows-x64.zip`.
                    </p>
                  </div>
                  <div className="modal-step">
                    <span className="step-num">2</span>
                    <p>
                      <strong>Extract to a folder:</strong> Right-click the downloaded zip file and
                      choose <em>Extract All...</em> to a folder of your choice (e.g. `C:\CallWave\`).
                    </p>
                  </div>
                  <div className="modal-step">
                    <span className="step-num">3</span>
                    <p>
                      <strong>Double-click `videocall.exe`:</strong> That's it! CallWave runs with
                      single-instance mutex protection, so multiple clicks will simply restore the
                      existing window.
                    </p>
                  </div>
                </div>

                <div className="modal-footer">
                  <a
                    href="https://drive.google.com/uc?export=download&id=1ehSCso7-sgZT5S1-lKa3llt0CvYCmbGF"
                    target="_blank" rel="noreferrer"
                    className="btn-download-main btn-amber"
                  >
                    Download Windows ZIP
                  </a>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
