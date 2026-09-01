import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import './index.css'
import { AuthProvider } from './lib/AuthContext'
import { LeagueDataProvider } from './lib/LeagueDataContext'
import Layout from './Layout'
import Home from './pages/Home'
import Teams from './pages/Teams'
import TeamDetail from './pages/TeamDetail'
import Standings from './pages/Standings'
import TradeHub from './pages/TradeHub'
import FreeAgency from './pages/FreeAgency'
import Scouting from './pages/Scouting'
import News from './pages/News'
import Guide from './pages/Guide'
import CommissionerTools from './pages/CommissionerTools'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AuthProvider>
      <LeagueDataProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<Layout />}>
              <Route path="/" element={<Home />} />
              <Route path="/teams" element={<Teams />} />
              <Route path="/teams/:teamId" element={<TeamDetail />} />
              <Route path="/cap-tracker" element={<Navigate to="/teams" replace />} />
              <Route path="/standings" element={<Standings />} />
              <Route path="/trade-hub" element={<TradeHub />} />
              <Route path="/free-agency" element={<FreeAgency />} />
              <Route path="/scouting" element={<Scouting />} />
              <Route path="/news" element={<News />} />
              <Route path="/guide" element={<Guide />} />
              <Route path="/commissioner" element={<CommissionerTools />} />
            </Route>
          </Routes>
        </BrowserRouter>
      </LeagueDataProvider>
    </AuthProvider>
  </StrictMode>,
)
