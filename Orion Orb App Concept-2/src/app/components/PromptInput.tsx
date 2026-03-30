import { useState } from 'react';
import { motion } from 'framer-motion';

interface PromptInputProps {
  onSubmit: (prompt: string) => void;
  isProcessing: boolean;
  mode: 'human' | 'ai' | 'creative';
}

export function PromptInput({ onSubmit, isProcessing }: PromptInputProps) {
  const [input, setInput] = useState('');

  const handleSubmit = () => {
    if (input.trim() && !isProcessing) {
      onSubmit(input);
      setInput('');
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  return (
    <div className="w-full max-w-md mx-auto px-6">
      <motion.button
        className="w-full py-4 rounded-full text-base font-medium transition-all duration-300"
        style={{
          backgroundColor: 'rgba(255, 255, 255, 0.08)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          color: 'rgba(255, 255, 255, 0.5)',
        }}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3 }}
        whileTap={{ scale: 0.98 }}
      >
        Type instead
      </motion.button>
      
      {/* Hidden input for functionality */}
      <input
        type="text"
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyPress={handleKeyPress}
        className="sr-only"
        disabled={isProcessing}
      />
    </div>
  );
}