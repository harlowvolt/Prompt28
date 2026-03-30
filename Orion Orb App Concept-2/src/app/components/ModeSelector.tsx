import { motion } from 'framer-motion';

interface ModeSelectorProps {
  selectedMode: 'human' | 'ai' | 'creative';
  onModeChange: (mode: 'human' | 'ai' | 'creative') => void;
}

export function ModeSelector({ selectedMode, onModeChange }: ModeSelectorProps) {
  const modes = [
    { id: 'ai' as const, label: 'AI Mode' },
    { id: 'human' as const, label: 'Human Mode' },
  ];

  return (
    <div className="w-full max-w-md mx-auto px-6">
      <div className="flex items-center justify-center gap-3 mb-3">
        {modes.map((mode) => {
          const isSelected = selectedMode === mode.id;
          
          return (
            <motion.button
              key={mode.id}
              onClick={() => onModeChange(mode.id)}
              className="flex-1 py-3 rounded-full text-sm font-medium transition-all duration-300"
              style={{
                backgroundColor: isSelected 
                  ? 'rgba(139, 92, 246, 0.3)' 
                  : 'rgba(255, 255, 255, 0.08)',
                border: `1px solid ${isSelected ? 'rgba(139, 92, 246, 0.5)' : 'rgba(255, 255, 255, 0.1)'}`,
                color: isSelected ? '#ffffff' : 'rgba(255, 255, 255, 0.5)',
              }}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              {mode.label}
            </motion.button>
          );
        })}
      </div>
      
      {/* Description text */}
      <p className="text-center text-sm" style={{ color: 'rgba(255, 255, 255, 0.4)' }}>
        {selectedMode === 'human' ? 'Writes like a real person, not an AI' : 'Optimized for AI tools'}
      </p>
    </div>
  );
}