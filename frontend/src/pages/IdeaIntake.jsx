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
