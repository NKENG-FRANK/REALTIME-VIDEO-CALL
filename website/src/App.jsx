import { useState } from 'react'
import brandImage from '../Calwave Glass Background.png'
import './App.css'

const navItems = ['Home', 'About us', 'Download']

const connectionTypes = [
  {
    title: 'One-to-one calls',
    description: 'Catch up with family, talk with a colleague, or connect directly with a customer.',
  },
  {
    title: 'Group calls',
    description: 'Bring friends, classmates, or teammates into one shared conversation.',
  },
  {
    title: 'Conferences',
    description: 'Gather a larger group for a meeting, class, or community conversation.',
  },
]

const aboutPrinciples = [
  {
    title: 'Made for Cameroon',
    description: 'A communication experience shaped around the people and communities it is here to serve.',
  },
  {
    title: 'Conversations that keep going',
    description: 'CallWave is built to help calls hold together when network conditions are difficult.',
  },
  {
    title: 'Your data stays home',
    description: 'CallWave’s promise is local hosting, so your calls and information remain in Cameroon.',
  },
]

const downloadSteps = [
  {
    title: 'Choose your device',
    description: 'Use the device you plan to call from, and check back here for the available CallWave download.',
  },
  {
    title: 'Get ready to connect',
    description: 'Before a call, make sure your device has a working microphone, camera, and internet connection.',
  },
  {
    title: 'Start with your people',
    description: 'Once CallWave is available to install, create your account or join a room to begin a conversation.',
  },
]

function App() {
  const [activePage, setActivePage] = useState('Home')

  const renderPage = () => {
    if (activePage === 'Home') {
      return (
        <>
          <section className="content-panel hero-panel">
            <div className="hero-copy">
              <p className="eyebrow"><span className="eyebrow-dot" /> Made for Cameroon</p>
              <h1>Good calls bring us closer.</h1>
              <p className="hero-lead">
                CALLWAVE is made for Cameroon and hosted in Cameroon—bringing family,
                friends, classmates, and colleagues together in one simple place.
              </p>
              <div className="hero-call-types" aria-label="CallWave call types">
                <span>One-to-one</span>
                <span>Group calls</span>
                <span>Conferences</span>
              </div>
              <div className="cta-row">
                <a className="primary-btn" href="#call-options">Explore CallWave <span aria-hidden="true">↗</span></a>
              </div>
              <p className="home-tagline">CALLWAVE. <span>Call strong. Stay sovereign.</span></p>
            </div>
            <div className="call-preview" aria-label="Illustration of a CallWave group call">
              <div className="preview-window">
                <div className="preview-topbar">
                  <div className="preview-brand"><span /> CALLWAVE</div>
                  <span className="preview-status"><i /> LIVE CONVERSATION</span>
                </div>
                <div className="preview-stage">
                  <div className="participant participant-main">
                    <span className="participant-avatar avatar-one">A</span>
                    <span className="participant-name">Ama</span>
                    <span className="participant-caption">On the call</span>
                  </div>
                  <div className="participant participant-side participant-green">
                    <span className="participant-avatar avatar-two">N</span>
                    <span className="participant-name">Nana</span>
                  </div>
                  <div className="participant participant-side participant-yellow">
                    <span className="participant-avatar avatar-three">M</span>
                    <span className="participant-name">Mireille</span>
                  </div>
                </div>
                <div className="preview-controls" aria-hidden="true">
                  <span className="control control-mic">⌁</span>
                  <span className="control control-camera">▣</span>
                  <span className="control control-end">×</span>
                </div>
              </div>
              <span className="preview-sticker">Close, even<br />when far away.</span>
            </div>
          </section>

          <section className="content-panel detail-panel" id="call-options">
            <div className="panel-header-block">
              <p className="eyebrow">One app, many ways to connect</p>
              <h2>Make room for every conversation.</h2>
            </div>
            <div className="info-grid">
              {connectionTypes.map((type, index) => (
                <article className="info-card" key={type.title}>
                  <span className="card-number">0{index + 1}</span>
                  <h3>{type.title}</h3>
                  <p>{type.description}</p>
                </article>
              ))}
            </div>
          </section>

          <section className="local-promise-band">
            <div className="promise-heading">
              <p className="eyebrow"><span className="eyebrow-dot" /> Rooted at home</p>
              <h2>Your conversations.<br />Your people. Your country.</h2>
            </div>
            <div className="promise-copy">
              <p>
                Bad network? Keep talking. CALLWAVE is built to hold your calls together
                even when the connection struggles.
              </p>
              <p>
                Your data stays home. No foreign servers, no wondering who is holding your
                conversations. Connect with family, colleagues, classmates, and customers
                without fear.
              </p>
              <span className="promise-signoff">Hosted in Cameroon <i /> Made for connection</span>
            </div>
          </section>
        </>
      )
    }

    if (activePage === 'About us') {
      return (
        <>
          <section className="content-panel about-panel">
            <div className="panel-header-block">
              <p className="eyebrow">About CallWave</p>
              <h2>Communication should bring people closer—not make them worry about where their conversations go.</h2>
            </div>
            <p className="about-text">
              CallWave is built around a simple idea: people in Cameroon deserve a reliable
              way to speak with the people who matter to them. Whether it is a family catch-up,
              a class, a team discussion, or a customer conversation, CallWave aims to make
              joining and staying connected feel straightforward.
            </p>
            <p className="about-text">
              Its promise is local: made for Cameroon, hosted in Cameroon, and focused on
              keeping calls and information close to home.
            </p>
          </section>
          <section className="content-panel detail-panel">
            <div className="panel-header-block">
              <p className="eyebrow">What guides us</p>
              <h2>Built around the way people connect.</h2>
            </div>
            <div className="info-grid">
              {aboutPrinciples.map((principle, index) => (
                <article className="info-card" key={principle.title}>
                  <span className="card-number">0{index + 1}</span>
                  <h3>{principle.title}</h3>
                  <p>{principle.description}</p>
                </article>
              ))}
            </div>
          </section>
        </>
      )
    }

    return (
      <>
        <section className="content-panel download-panel">
          <div className="panel-header-block">
            <p className="eyebrow">Download</p>
            <h2>Get ready to connect with CallWave.</h2>
            <p className="about-text">
              Follow these simple steps to prepare. Official download options will be listed
              here when they are available.
            </p>
          </div>
          <div className="download-box">
            {downloadSteps.map((step, index) => (
              <article className="download-step" key={step.title}>
                <span className="step-number">0{index + 1}</span>
                <div>
                  <h3>{step.title}</h3>
                  <p>{step.description}</p>
                </div>
              </article>
            ))}
          </div>
        </section>
        <section className="content-panel detail-panel">
          <div className="panel-header-block">
            <p className="eyebrow">Before your first call</p>
            <h2>A few quick checks can make joining easier.</h2>
          </div>
          <div className="info-grid">
            <article className="info-card">
              <span className="card-number">01</span>
              <h3>Check your connection</h3>
              <p>Choose the strongest connection available to you before starting a call.</p>
            </article>
            <article className="info-card">
              <span className="card-number">02</span>
              <h3>Check your audio</h3>
              <p>Make sure your microphone is connected and allowed for the app or browser.</p>
            </article>
            <article className="info-card">
              <span className="card-number">03</span>
              <h3>Find a comfortable place</h3>
              <p>A quieter spot can help everyone hear and follow the conversation.</p>
            </article>
          </div>
        </section>
      </>
    )
  }

  return (
    <div className="callwave-app">
      <header className="topbar">
        <div className="brand-wrap">
          <img src={brandImage} alt="CallWave logo" className="brand-logo" />
        </div>

        <nav className="main-nav" aria-label="Main navigation">
          {navItems.map((item) => (
            <button
              key={item}
              type="button"
              className={activePage === item ? 'nav-btn active' : 'nav-btn'}
              aria-current={activePage === item ? 'page' : undefined}
              onClick={() => setActivePage(item)}
            >
              {item}
            </button>
          ))}
        </nav>
      </header>

      {renderPage()}
      <footer className="site-footer">
        <span className="footer-brand">CALLWAVE<span>.</span></span>
        <p>Made for Cameroon. Call strong. Stay sovereign.</p>
        <span className="footer-colors" aria-hidden="true"><i /><i /><i /></span>
      </footer>
    </div>
  )
}

export default App
