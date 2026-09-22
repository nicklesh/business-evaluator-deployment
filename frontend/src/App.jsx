import React, { useState } from 'react';
import { BrowserRouter, Routes, Route, useNavigate } from 'react-router-dom';
import IdeaIntake from './pages/IdeaIntake';
import WorkflowDashboard from './pages/WorkflowDashboard';
import './App.css';

function AppRoutes() {
  const navigate = useNavigate();
  const [authToken] = useState(() => {
    let token = localStorage.getItem('auth_token');
    if (!token) {
      token = 'test_token_' + Math.random().toString(36).substring(7);
      localStorage.setItem('auth_token', token);
    }
    return token;
  });

  const handleRunCreated = (run_id) => {
    navigate(`/dashboard/${run_id}`);
  };

  return (
    <Routes>
      <Route path="/" element={<IdeaIntake onRunCreated={handleRunCreated} authToken={authToken} />} />
      <Route path="/dashboard/:run_id" element={<WorkflowDashboard authToken={authToken} />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  );
}
