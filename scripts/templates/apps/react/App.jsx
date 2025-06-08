import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch('/api/data')
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok');
        }
        return response.json();
      })
      .then(data => {
        setData(data);
        setLoading(false);
      })
      .catch(error => {
        setError(error.message);
        setLoading(false);
      });
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1>React Application</h1>
        <p>GitLab-Centered DevOps Suite</p>
      </header>
      <main>
        <section className="content">
          {loading ? (
            <p>Loading data...</p>
          ) : error ? (
            <p className="error">Error: {error}</p>
          ) : (
            <div>
              <h2>Data Items</h2>
              <ul className="items-list">
                {data.map(item => (
                  <li key={item.id} className="item">
                    {item.name}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </section>
      </main>
      <footer>
        <p>&copy; {new Date().getFullYear()} GitLab-Centered DevOps Suite</p>
      </footer>
    </div>
  );
}

export default App;
