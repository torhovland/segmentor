import { QueryClient, QueryClientProvider } from 'react-query';
import Activities from './Activities';
import './App.css';
import Login from './Login';
import Sync from './Sync';

const queryClient = new QueryClient()

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <div className="App">
        <header className="App-header">
          <Login></Login>
          <Sync></Sync>
          <Activities></Activities>
        </header>
      </div>
    </QueryClientProvider>
  );
}

export default App;
