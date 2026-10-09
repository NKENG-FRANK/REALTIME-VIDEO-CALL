import { useState } from 'react'
import './App.css'

const navItems = ['Home', 'About us', 'Download']

const homeFeatures = [
  'HD video calls with crystal-clear sound',
  'Team rooms for quick collaboration',
  'Smart meeting links and instant invites',
]

const aboutData = {
  title: 'CallWave makes communication feel natural.',
  description:
    'We built CallWave to help teams, families, and creators connect in seconds with smooth video, reliable audio, and secure communication tools.',
  values: [
    'Simple and friendly experience',
    'Built for everyday calls and meetings',
    'Fast setup across mobile and desktop',
  ],
}

const downloadSteps = [
  'Download CallWave for your device',
  'Create your account or join a room',
  'Start sharing video and audio instantly',
]

function App() {
  const [activePage, setActivePage] = useState('Home')

  const renderPage = () => {
    if (activePage === 'Home') {
      return (
        <section className="content-panel hero-panel">
          <div className="hero-copy">
            <p className="eyebrow">CallWave</p>
            <h1>Better conversations start here.</h1>
            <p className="lead">
              Connect instantly with video calls, clear voice, and fast team meetings in one simple app.
            </p>
            <div className="cta-row">
              <button type="button" className="primary-btn">Start call</button>
              <button type="button" className="secondary-btn">Watch demo</button>
            </div>
          </div>

          <div className="feature-boxes">
            {homeFeatures.map((item) => (
              <div key={item} className="feature-card">
                <span className="feature-icon">●</span>
                <p>{item}</p>
              </div>
            ))}
          </div>
        </section>
      )
    }

    if (activePage === 'About us') {
      return (
        <section className="content-panel about-panel">
          <div className="panel-header-block">
            <p className="eyebrow">About us</p>
            <h2>{aboutData.title}</h2>
          </div>

          <p className="about-text">{aboutData.description}</p>

          <div className="value-list">
            {aboutData.values.map((value) => (
              <div key={value} className="value-item">
                <span className="bullet green" />
                <p>{value}</p>
              </div>
            ))}
          </div>
        </section>
      )
    }

    return (
      <section className="content-panel download-panel">
        <div className="panel-header-block">
          <p className="eyebrow">Download</p>
          <h2>Get CallWave on your device.</h2>
        </div>

        <div className="download-box">
          {downloadSteps.map((step, index) => (
            <div key={step} className="download-step">
              <span className="step-number">0{index + 1}</span>
              <p>{step}</p>
            </div>
          ))}
        </div>

        <button type="button" className="primary-btn download-btn">Download now</button>
      </section>
    )
  }

  return (
    <div className="callwave-app">
      <header className="topbar">
        <div className="brand-wrap">
          <div className="brand-mark">C</div>
          <div className="brand-text">
            <strong>CallWave</strong>
            <span>Audio & video</span>
          </div>
        </div>

        <nav className="main-nav" aria-label="Main navigation">
          {navItems.map((item) => (
            <button
              key={item}
              type="button"
              className={activePage === item ? 'nav-btn active' : 'nav-btn'}
              onClick={() => setActivePage(item)}
            >
              {item}
            </button>
          ))}
        </nav>
      </header>

      {renderPage()}
    </div>
  )
}

export default App
