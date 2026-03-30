import { useState } from 'react';
import { Settings } from 'lucide-react';
import { Orb } from './components/Orb';
import { ModeSelector } from './components/ModeSelector';
import { PromptInput } from './components/PromptInput';
import { PromptOutput } from './components/PromptOutput';
import { Navigation } from './components/Navigation';

type Mode = 'human' | 'ai' | 'creative';

function App() {
  const [mode, setMode] = useState<Mode>('human');
  const [isProcessing, setIsProcessing] = useState(false);
  const [enhancedPrompt, setEnhancedPrompt] = useState<string | null>(null);

  const enhancePrompt = (userPrompt: string, selectedMode: Mode): string => {
    const prompts = {
      human: `I need thoughtful guidance on: ${userPrompt}

Please help me understand this in simple, clear language. Break it down into:
- What this means for me personally
- Practical first steps I can take today
- Things to consider or watch out for
- How to know if I'm making progress

Keep it conversational, encouraging, and easy to follow.`,

      ai: `Task: ${userPrompt}

Please provide a comprehensive response with the following structure:

1. CONTEXT & UNDERSTANDING
   - Clarify the core objective
   - Identify key considerations

2. STRUCTURED APPROACH
   - Step-by-step methodology
   - Best practices to follow

3. EXPECTED OUTCOMES
   - What success looks like
   - Potential variations or alternatives

4. REFINEMENT
   - Questions to help improve the approach
   - Areas for optimization

Format your response with clear headings, bullet points, and actionable insights.`,

      creative: `Creative Brief: ${userPrompt}

Let's explore this idea with imagination and depth:

🎨 CREATIVE VISION
- What's the big picture concept?
- What emotions or feelings should this evoke?
- What makes this unique or memorable?

✨ IMAGINATIVE DIRECTIONS
- 3-5 distinct creative approaches
- Visual, narrative, or experiential elements
- Unexpected angles or interpretations

🌟 BRINGING IT TO LIFE
- Concrete examples or metaphors
- Sensory details (look, feel, sound, mood)
- Story or brand elements

🚀 NEXT CREATIVE STEPS
- How to develop this further
- Resources or inspiration to explore

Think bold, think different, think beautiful.`,
    };

    return prompts[selectedMode];
  };

  const handlePromptSubmit = (userPrompt: string) => {
    setIsProcessing(true);
    
    // Simulate processing delay
    setTimeout(() => {
      const enhanced = enhancePrompt(userPrompt, mode);
      setEnhancedPrompt(enhanced);
      setIsProcessing(false);
    }, 1500);
  };

  const handleCloseOutput = () => {
    setEnhancedPrompt(null);
  };

  return (
    <div 
      className="min-h-screen text-white overflow-hidden relative"
      style={{
        background: 'linear-gradient(to bottom, #1a1d2e 0%, #0f1218 100%)',
      }}
    >
      {/* Status bar */}
      <div className="h-12" />

      {/* Header */}
      <div className="relative z-10 px-6 mb-8">
        <div className="flex items-center justify-center">
          <h1 className="text-4xl font-bold">Orion Orb</h1>
          
          {/* Settings button */}
          <button 
            className="absolute right-6 w-12 h-12 rounded-full flex items-center justify-center transition-all duration-200"
            style={{
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(20px)',
            }}
          >
            <Settings size={20} style={{ color: 'rgba(255, 255, 255, 0.6)' }} />
          </button>
        </div>
      </div>

      {/* Main content */}
      <div className="relative z-10 flex flex-col gap-6 pb-40">
        {/* Mode selector */}
        <ModeSelector selectedMode={mode} onModeChange={setMode} />

        {/* Orb */}
        <Orb mode={mode} isProcessing={isProcessing} />

        {/* Prompt input */}
        <PromptInput
          onSubmit={handlePromptSubmit}
          isProcessing={isProcessing}
          mode={mode}
        />
      </div>

      {/* Navigation */}
      <Navigation />

      {/* Output modal */}
      {enhancedPrompt && (
        <PromptOutput
          prompt={enhancedPrompt}
          mode={mode}
          onClose={handleCloseOutput}
        />
      )}

      {/* Subtle background gradient orbs */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden opacity-30">
        <div
          className="absolute"
          style={{
            top: '20%',
            left: '-10%',
            width: '300px',
            height: '300px',
            background: 'radial-gradient(circle, rgba(139, 92, 246, 0.2), transparent 70%)',
            filter: 'blur(80px)',
          }}
        />
        <div
          className="absolute"
          style={{
            bottom: '30%',
            right: '-10%',
            width: '350px',
            height: '350px',
            background: 'radial-gradient(circle, rgba(99, 102, 241, 0.2), transparent 70%)',
            filter: 'blur(80px)',
          }}
        />
      </div>
    </div>
  );
}

export default App;