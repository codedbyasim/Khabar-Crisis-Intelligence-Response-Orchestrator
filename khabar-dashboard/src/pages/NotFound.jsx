import React from 'react';
import { Link } from 'react-router-dom';

const NotFound = () => {
  return (
    <div style={styles.container}>
      <div style={styles.content}>
        <h1 style={styles.code}>404</h1>
        <h2 style={styles.title}>Page Not Found</h2>
        <p style={styles.description}>
          The page you're looking for doesn't exist.
        </p>
        <Link to="/" style={styles.link}>
          Back to Dashboard
        </Link>
      </div>
    </div>
  );
};

const styles = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 'calc(100vh - 73px)',
    padding: '20px',
  },
  content: {
    textAlign: 'center',
  },
  code: {
    fontSize: '96px',
    fontWeight: '800',
    margin: '0 0 16px 0',
    background: 'linear-gradient(to right, #ff3366, #00e5ff)',
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
  },
  title: {
    fontSize: '32px',
    fontWeight: '700',
    margin: '0 0 12px 0',
    color: '#f8fafc',
  },
  description: {
    fontSize: '16px',
    color: '#94a3b8',
    margin: '0 0 24px 0',
  },
  link: {
    display: 'inline-block',
    padding: '12px 24px',
    background: 'linear-gradient(135deg, #00e5ff, #0077aa)',
    color: '#030712',
    textDecoration: 'none',
    borderRadius: '12px',
    fontWeight: '700',
    transition: 'transform 0.2s ease',
    cursor: 'pointer',
  },
};

export default NotFound;
