import { useState, useEffect } from 'react'
import './App.css'

interface FileInfo {
  name: string;
  path: string;
  is_directory: boolean;
  size?: number;
  modified?: string;
  mime_type?: string;
}

function App() {
  const [files, setFiles] = useState<FileInfo[]>([]);
  const [currentPath, setCurrentPath] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string>('');

  const fetchFiles = async (path: string = '') => {
    setLoading(true);
    setError('');

    try {
      const response = await fetch(`http://localhost:3000/api/browse?path=${encodeURIComponent(path)}`);
      if (!response.ok) {
        throw new Error('Failed to fetch files');
      }
      const data = await response.json();
      setFiles(data);
      setCurrentPath(path);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFiles();
  }, []);

  const navigateToPath = (path: string) => {
    fetchFiles(path);
  };

  const goBack = () => {
    const pathParts = currentPath.split('/').filter(part => part);
    if (pathParts.length > 0) {
      pathParts.pop();
      const newPath = pathParts.join('/');
      fetchFiles(newPath);
    }
  };

  const formatSize = (bytes?: number): string => {
    if (!bytes) return '-';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
  };

  return (
    <div className="app">
      <header className="header">
        <h1>📁 Offline NAS Viewer</h1>
        <div className="path-nav">
          <button onClick={goBack} disabled={!currentPath || loading}>
            ← Back
          </button>
          <span className="current-path">/{currentPath}</span>
        </div>
      </header>

      <main className="main">
        {loading && <div className="loading">Loading...</div>}
        {error && <div className="error">Error: {error}</div>}

        {!loading && !error && (
          <div className="file-list">
            {files.map((file, index) => (
              <div
                key={index}
                className={`file-item ${file.is_directory ? 'directory' : 'file'}`}
                onClick={() => file.is_directory && navigateToPath(file.path)}
              >
                <div className="file-icon">
                  {file.is_directory ? '📁' : '📄'}
                </div>
                <div className="file-info">
                  <div className="file-name">{file.name}</div>
                  <div className="file-details">
                    {!file.is_directory && <span>Size: {formatSize(file.size)}</span>}
                    {file.modified && <span>Modified: {file.modified}</span>}
                    {file.mime_type && <span>Type: {file.mime_type}</span>}
                  </div>
                </div>
              </div>
            ))}
            {files.length === 0 && !loading && (
              <div className="empty-message">No files or directories found</div>
            )}
          </div>
        )}
      </main>
    </div>
  )
}

export default App
