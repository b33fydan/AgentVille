import { Component } from 'react';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    console.error('AgentVille crash:', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 32, color: '#fff', fontFamily: 'monospace', background: '#0f172a', minHeight: '100vh' }}>
          <h1 style={{ color: '#f87171' }}>AgentVille crashed</h1>
          <pre style={{ whiteSpace: 'pre-wrap', color: '#fbbf24', marginTop: 16 }}>
            {this.state.error?.message || 'Unknown error'}
          </pre>
          <pre style={{ whiteSpace: 'pre-wrap', color: '#94a3b8', marginTop: 8, fontSize: 12 }}>
            {this.state.error?.stack}
          </pre>
          <button
            onClick={() => { localStorage.clear(); window.location.reload(); }}
            style={{ marginTop: 24, padding: '12px 24px', background: '#3b82f6', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 14 }}
          >
            Clear data and reload
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
