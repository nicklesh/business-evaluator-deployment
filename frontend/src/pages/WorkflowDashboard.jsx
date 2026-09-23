import React, { useState, useEffect, useCallback } from 'react';
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

  const loadRunState = useCallback(async () => {
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
        const artifactsData = await artifactsRes.json();
        setArtifacts(artifactsData.artifacts || []);
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
  }, [run_id, authToken]);

  useEffect(() => {
    loadRunState();
    pollIntervalRef.current = setInterval(() => {
      loadRunState();
    }, 3000);
    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, [loadRunState]);

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
            <>
              <div className="artifacts-list">
                {artifacts.map(art => (
                  <div key={art.path} className="artifact-item" onClick={() => setSelectedArtifact(art)}>
                    <div className="artifact-name">{art.name}</div>
                  </div>
                ))}
              </div>

              {selectedArtifact && (
                <div className="selected-artifact-panel">
                  <h3>📄 {selectedArtifact.name}</h3>
                  <div className="artifact-content">
                    <pre>{JSON.stringify(selectedArtifact.content, null, 2)}</pre>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
