import React from 'react';

const SkillsPanel: React.FC = () => {
  return (
    <div className="skills-panel">
      <h2>Skills Panel</h2>
      <div className="skills-grid">
        <div className="skill-card">
          <h3>Reminders</h3>
          <p>Set and manage your reminders</p>
        </div>
        <div className="skill-card">
          <h3>Weather</h3>
          <p>Get weather information</p>
        </div>
        <div className="skill-card">
          <h3>Timer</h3>
          <p>Set timers and alarms</p>
        </div>
        <div className="skill-card">
          <h3>Notes</h3>
          <p>Take and organize notes</p>
        </div>
        <div className="skill-card">
          <h3>Calculator</h3>
          <p>Perform calculations</p>
        </div>
      </div>
    </div>
  );
};

export default SkillsPanel;