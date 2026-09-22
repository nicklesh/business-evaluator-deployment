#!/bin/bash

# Create all the necessary files for deployment

# Create root package.json
cat > package.json << 'EOF'
{
  "name": "business-idea-evaluator",
  "version": "1.0.0",
  "description": "Multi-agent business idea evaluator",
  "main": "backend/server.js",
  "scripts": {
    "start": "node backend/server.js",
    "dev": "concurrently \"cd backend && npm start\" \"cd frontend && npm start\"",
    "build": "cd frontend && npm install && npm run build",
    "heroku-postbuild": "cd frontend && npm install && npm run build"
  },
  "engines": {
    "node": "18.x"
  },
  "dependencies": {
    "concurrently": "^8.0.0"
  }
}
EOF

# Create Procfile for Heroku
cat > Procfile << 'EOF'
web: node backend/server.js
EOF

# Create railway.json
cat > railway.json << 'EOF'
{
  "build": {
    "builder": "nixpacks"
  },
  "deploy": {
    "startCommand": "node backend/server.js",
    "restartPolicyType": "on_failure",
    "restartPolicyMaxRetries": 3
  }
}
EOF

# Create vercel.json
cat > vercel.json << 'EOF'
{
  "buildCommand": "cd frontend && npm install && npm run build",
  "outputDirectory": "frontend/build",
  "devCommand": "npm run dev",
  "env": {
    "REACT_APP_API_URL": "@api_url"
  }
}
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
.env.local
dist/
build/
*.log
.DS_Store
.idea/
.vscode/
EOF

# Create backend files
mkdir -p backend
cd backend

cat > package.json << 'EOF'
{
  "name": "business-idea-evaluator-backend",
  "version": "1.0.0",
  "description": "Express backend for multi-agent business evaluator",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "uuid": "^9.0.0"
  }
}
EOF

cat > server.js << 'BACKEND'
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// In-memory storage
const runs = new Map();
const agents = new Map();
const artifacts = new Map();

// Middleware
app.use((req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.user_id = 'user_' + Math.random().toString(36).substring(7);
  next();
});

// Create run
app.post('/api/runs', async (req, res) => {
  const { idea, target_customer, problem, mode } = req.body;

  if (!idea) {
    return res.status(400).json({ error: 'Idea is required' });
  }

  const run_id = `run_${Date.now()}_${uuidv4().substring(0, 8)}`;
  const run = {
    run_id,
    user_id: req.user_id,
    idea,
    target_customer,
    problem,
    mode,
    status: 'running',
    current_stage: 'intake_planning',
    progress_percent: 0,
    created_at: new Date().toISOString(),
    agents: [],
    final_decision: null,
    decision_confidence: null
  };

  runs.set(run_id, run);
  simulateAgentExecution(run_id, req.body);

  res.status(201).json({
    run_id,
    status: 'running',
    created_at: run.created_at,
    link: `/runs/${run_id}`
  });
});

// Get run
app.get('/api/runs/:run_id', (req, res) => {
  const run = runs.get(req.params.run_id);
  if (!run) {
    return res.status(404).json({ error: 'Run not found' });
  }
  res.json(run);
});

// Get artifacts
app.get('/api/runs/:run_id/artifacts', (req, res) => {
  const runId = req.params.run_id;
  const runArtifacts = Array.from(artifacts.values()).filter(a => a.run_id === runId);
  res.json({ artifacts: runArtifacts });
});

// Get artifact content
app.get('/api/runs/:run_id/artifacts/:path', (req, res) => {
  const path = decodeURIComponent(req.params.path);
  const artifact = Array.from(artifacts.values()).find(a => a.path === path);
  if (!artifact) {
    return res.status(404).json({ error: 'Artifact not found' });
  }
  res.json(artifact);
});

// Get decision
app.get('/api/runs/:run_id/decision', (req, res) => {
  const run = runs.get(req.params.run_id);
  if (!run || !run.final_decision) {
    return res.status(404).json({ error: 'Decision not found' });
  }
  res.json({
    decision: run.final_decision,
    confidence_percent: run.decision_confidence,
    risk_adjusted_score: run.risk_adjusted_score || 7.5
  });
});

// Simulate agent execution
function simulateAgentExecution(run_id, data) {
  const run = runs.get(run_id);
  const stages = [
    {
      name: 'intake_planning',
      agents: [
        { name: 'Research Planner', id: 'research_planner' }
      ],
      duration: 5000
    },
    {
      name: 'specialist_research',
      agents: [
        { name: 'Market Analyst', id: 'market_analyst' },
        { name: 'Tech Analyst', id: 'tech_analyst' },
        { name: 'Economics Analyst', id: 'economics_analyst' },
        { name: 'GTM Analyst', id: 'gtm_analyst' }
      ],
      duration: 15000
    },
    {
      name: 'quality_gates',
      agents: [
        { name: 'Evidence Review', id: 'evidence_review' },
        { name: 'Risk Analyst', id: 'risk_analyst' },
        { name: 'Red Team', id: 'red_team' },
        { name: 'QA Agent', id: 'qa_agent' }
      ],
      duration: 12000
    },
    {
      name: 'synthesis',
      agents: [
        { name: 'Synthesis Agent', id: 'synthesis_agent' },
        { name: 'Final Judge', id: 'final_judge' }
      ],
      duration: 8000
    }
  ];

  let currentTime = 0;

  stages.forEach((stage, stageIndex) => {
    setTimeout(() => {
      run.current_stage = stage.name;
      run.agents = [];

      stage.agents.forEach((agent, agentIndex) => {
        const agentData = {
          agent_id: agent.id,
          name: agent.name,
          status: 'running',
          output_artifact: null,
          failure_reason: null
        };
        run.agents.push(agentData);

        setTimeout(() => {
          agentData.status = 'completed';
          const artifactPath = `artifacts/stage_${stageIndex}_${agent.id}.md`;
          agentData.output_artifact = artifactPath;

          artifacts.set(artifactPath, {
            run_id: run_id,
            name: agent.name,
            path: artifactPath,
            status: 'completed',
            content: `# ${agent.name} Report\n\nThis is a sample artifact from ${agent.name}.`,
            evidence_quality: Math.floor(Math.random() * 40 + 60),
            claims: Math.floor(Math.random() * 5 + 3),
            verified_claims: Math.floor(Math.random() * 2 + 2)
          });

          run.progress_percent = Math.min(
            100,
            Math.floor((stageIndex + (agentIndex + 1) / stage.agents.length) / stages.length * 100)
          );
        }, (agentIndex + 1) * 1500);
      });
    }, currentTime);

    currentTime += stage.duration;
  });

  setTimeout(() => {
    run.status = 'completed';
    run.progress_percent = 100;
    run.final_decision = ['GO', 'REWORK', 'KILL'][Math.floor(Math.random() * 3)];
    run.decision_confidence = Math.random() * 0.4 + 0.6;
    run.risk_adjusted_score = Math.random() * 5 + 4;
  }, currentTime);
}

app.listen(PORT, () => {
  console.log(`Backend server running on port ${PORT}`);
});

module.exports = app;
BACKEND

cd ..

# Create frontend
mkdir -p frontend/src/pages frontend/src/styles frontend/public

cd frontend

cat > package.json << 'EOF'
{
  "name": "business-idea-evaluator-frontend",
  "version": "1.0.0",
  "description": "React frontend for multi-agent business idea evaluator",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.14.0",
    "react-scripts": "4.0.3"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": ["react-app"]
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  },
  "proxy": "http://localhost:5000"
}
EOF

cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="theme-color" content="#2196F3" />
  <meta name="description" content="Business Idea Evaluator - Rigorous, evidence-backed assessment" />
  <title>Business Idea Evaluator</title>
</head>
<body>
  <noscript>You need to enable JavaScript to run this app.</noscript>
  <div id="root"></div>
</body>
</html>
EOF

cat > src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<React.StrictMode><App /></React.StrictMode>);
EOF

cat > src/App.jsx << 'EOF'
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
EOF

cat > src/App.css << 'EOF'
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto; background: #f5f5f5; }
#root { min-height: 100vh; }
EOF

cat > src/pages/IdeaIntake.jsx << 'EOF'
import React, { useState } from 'react';
import '../styles/IdeaIntake.css';

export default function IdeaIntake({ onRunCreated, authToken }) {
  const [formData, setFormData] = useState({
    idea: '',
    target_customer: '',
    problem: '',
    mode: 'full'
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:5000';
      const response = await fetch(`${apiUrl}/api/runs`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authToken}`
        },
        body: JSON.stringify(formData)
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to create run');
      }

      const data = await response.json();
      onRunCreated(data.run_id);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  return (
    <div className="intake-container">
      <div className="intake-card">
        <h1>Business Idea Evaluator</h1>
        <p className="subtitle">Get rigorous, evidence-backed assessment in ~15 minutes</p>
        
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="idea">Your Business Idea *</label>
            <textarea
              id="idea"
              name="idea"
              value={formData.idea}
              onChange={handleChange}
              placeholder="Describe your business idea in a few sentences..."
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="target_customer">Target Customer *</label>
            <input
              type="text"
              id="target_customer"
              name="target_customer"
              value={formData.target_customer}
              onChange={handleChange}
              placeholder="Who is your ideal customer?"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="problem">Problem Being Solved *</label>
            <textarea
              id="problem"
              name="problem"
              value={formData.problem}
              onChange={handleChange}
              placeholder="What problem does your idea solve?"
              required
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button type="submit" disabled={loading} className="submit-btn">
            {loading ? 'Evaluating...' : 'Start Evaluation'}
          </button>
        </form>
      </div>
    </div>
  );
}
EOF

cat > src/pages/WorkflowDashboard.jsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import '../styles/WorkflowDashboard.css';

export default function WorkflowDashboard({ authToken }) {
  const { run_id } = useParams();
  const [run, setRun] = useState(null);
  const [artifacts, setArtifacts] = useState([]);
  const [selectedArtifact, setSelectedArtifact] = useState(null);
  const [decision, setDecision] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const pollIntervalRef = React.useRef(null);

  useEffect(() => {
    loadRunState();
    pollIntervalRef.current = setInterval(() => {
      loadRunState();
    }, 3000);

    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, [run_id, authToken]);

  async function loadRunState() {
    try {
      const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:5000';
      const response = await fetch(`${apiUrl}/api/runs/${run_id}`, {
        headers: { 'Authorization': `Bearer ${authToken}` }
      });

      if (!response.ok) throw new Error('Failed to load run');
      const data = await response.json();
      setRun(data);
      setLoading(false);
      setError('');

      const artifactsRes = await fetch(`${apiUrl}/api/runs/${run_id}/artifacts`, {
        headers: { 'Authorization': `Bearer ${authToken}` }
      });
      if (artifactsRes.ok) {
        setArtifacts(await artifactsRes.json()).artifacts || [];
      }

      if (data.status === 'completed') {
        const decisionRes = await fetch(`${apiUrl}/api/runs/${run_id}/decision`, {
          headers: { 'Authorization': `Bearer ${authToken}` }
        });
        if (decisionRes.ok) {
          setDecision(await decisionRes.json());
        }
        if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
      }
    } catch (err) {
      console.error('Load error:', err);
      setError('Failed to load run state');
      setLoading(false);
    }
  }

  if (loading) return <div className="workflow-loading"><div className="loading-spinner"></div><p>Loading...</p></div>;
  if (error) return <div className="workflow-error"><p>{error}</p></div>;

  return (
    <div className="workflow-dashboard">
      <div className="workflow-header">
        <h2>{run?.idea?.substring(0, 60)}...</h2>
        <div className="progress-bar">
          <div className="progress-fill" style={{ width: `${run?.progress_percent || 0}%` }}>
            {run?.progress_percent || 0}%
          </div>
        </div>
      </div>

      <div className="workflow-grid">
        <div className="workflow-left">
          <h3>📊 Workflow Stages</h3>
          <div className="workflow-stages">
            {run?.agents?.map(agent => (
              <div key={agent.agent_id} className={`stage-box status-${agent.status}`}>
                <div className="stage-name">{agent.name}</div>
                <div className="stage-status">
                  {agent.status === 'completed' && '✅'}
                  {agent.status === 'running' && '🔄'}
                  {' ' + agent.status}
                </div>
              </div>
            ))}
          </div>

          {decision && (
            <div className="decision-panel">
              <h3>🎯 Final Decision</h3>
              <div className="decision-box">
                <div className="decision-label">{decision.decision}</div>
                <div className="decision-confidence">Confidence: {(decision.confidence_percent * 100).toFixed(0)}%</div>
              </div>
            </div>
          )}
        </div>

        <div className="workflow-right">
          <h3>📁 Artifacts</h3>
          {artifacts.length === 0 ? (
            <p className="no-artifacts">No artifacts yet...</p>
          ) : (
            <div className="artifacts-list">
              {artifacts.map(art => (
                <div key={art.path} className="artifact-item" onClick={() => setSelectedArtifact(art)}>
                  <div className="artifact-name">{art.name}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/styles/IdeaIntake.css << 'EOF'
.intake-container { max-width: 800px; margin: 0 auto; padding: 40px 20px; }
.intake-card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
h1 { margin-bottom: 10px; color: #333; }
.subtitle { color: #666; margin-bottom: 30px; }
.form-group { margin-bottom: 20px; }
label { display: block; margin-bottom: 8px; font-weight: 600; color: #333; }
input, textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-family: inherit; }
textarea { min-height: 100px; }
.submit-btn { background: #2196F3; color: white; padding: 12px 24px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
.submit-btn:hover { background: #1976D2; }
.error-message { color: #d32f2f; background: #ffebee; padding: 12px; border-radius: 4px; margin-bottom: 20px; }
EOF

cat > src/styles/WorkflowDashboard.css << 'EOF'
.workflow-dashboard { max-width: 1200px; margin: 0 auto; padding: 40px 20px; }
.workflow-header { margin-bottom: 40px; }
.workflow-header h2 { font-size: 24px; color: #333; margin-bottom: 16px; }
.progress-bar { height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
.progress-fill { height: 100%; background: linear-gradient(90deg, #2196F3, #4CAF50); transition: width 0.3s; display: flex; align-items: center; justify-content: center; color: white; font-size: 10px; }
.workflow-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; }
.workflow-left h3, .workflow-right h3 { margin-bottom: 20px; font-size: 16px; color: #333; }
.workflow-stages { display: grid; grid-template-columns: 1fr; gap: 12px; margin-bottom: 40px; }
.stage-box { padding: 16px; border: 1px solid #ddd; border-radius: 4px; background: #f9f9f9; }
.stage-box.status-completed { border-color: #4CAF50; background: #f1f8f4; }
.stage-box.status-running { border-color: #2196F3; background: #f0f7ff; }
.stage-name { font-weight: 600; color: #333; margin-bottom: 4px; }
.stage-status { font-size: 13px; color: #666; }
.decision-panel { margin-top: 40px; padding-top: 40px; border-top: 1px solid #e0e0e0; }
.decision-box { padding: 20px; border: 2px solid #FFC107; border-radius: 8px; background: #f9f9f9; }
.decision-label { font-size: 32px; font-weight: 700; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 1px; }
.decision-confidence { font-size: 14px; color: #666; }
.workflow-right { background: #f9f9f9; padding: 24px; border-radius: 8px; }
.artifacts-list { display: grid; grid-template-columns: 1fr; gap: 12px; }
.artifact-item { padding: 12px; border: 1px solid #ddd; border-radius: 4px; background: white; cursor: pointer; }
.artifact-item:hover { border-color: #2196F3; box-shadow: 0 2px 8px rgba(33,150,243,0.1); }
.artifact-name { font-weight: 600; color: #333; }
.no-artifacts { padding: 20px; text-align: center; color: #999; }
.workflow-loading { text-align: center; padding: 60px 20px; }
.loading-spinner { width: 40px; height: 40px; border: 4px solid #e0e0e0; border-top-color: #2196F3; border-radius: 50%; animation: spin 0.6s linear infinite; margin: 0 auto 20px; }
@keyframes spin { to { transform: rotate(360deg); } }
.workflow-error { padding: 20px; background: #ffebee; border: 1px solid #ef5350; border-radius: 4px; color: #c62828; }
@media (max-width: 900px) { .workflow-grid { grid-template-columns: 1fr; } }
EOF

echo "Setup complete!"

