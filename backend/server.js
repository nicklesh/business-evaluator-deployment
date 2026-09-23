const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 5000;
const path = require('path');

app.use(cors());
app.use(express.json());

// Serve static files from frontend build
app.use(express.static(path.join(__dirname, '../frontend/build')));

// In-memory storage
const runs = new Map();
const agents = new Map();
const artifacts = new Map();

// Health check endpoint (no auth required)
app.get('/', (req, res) => {
  res.json({ 
    status: 'healthy',
    service: 'Business Idea Evaluator API',
    version: '1.0.0',
    message: 'Send requests to /api/runs with Authorization header'
  });
});

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

// ============================================
// SPA FALLBACK - Serve React Router paths
// ============================================

// Any unmatched routes serve index.html for React Router
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/build/index.html'));
});

app.listen(PORT, () => {
  console.log(`Backend server running on port ${PORT}`);
});

module.exports = app;
