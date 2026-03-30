import { motion } from 'framer-motion';
import { Copy, Check, X } from 'lucide-react';
import { useState } from 'react';

interface PromptOutputProps {
  prompt: string;
  mode: 'human' | 'ai' | 'creative';
  onClose: () => void;
}

export function PromptOutput({ prompt, mode, onClose }: PromptOutputProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(prompt);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const modeColors = {
    human: '#8B5CF6',
    ai: '#6366F1',
    creative: '#10B981',
  };

  const modeNames = {
    human: 'Human Mode',
    ai: 'AI Mode',
    creative: 'Creative',
  };

  return (
    <motion.div
      className="fixed inset-0 z-50 flex items-end"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      {/* Backdrop */}
      <motion.div
        className="absolute inset-0"
        style={{
          backgroundColor: 'rgba(0, 0, 0, 0.7)',
          backdropFilter: 'blur(10px)',
        }}
        onClick={onClose}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
      />

      {/* Sheet */}
      <motion.div
        className="relative w-full rounded-t-3xl overflow-hidden"
        style={{
          maxHeight: '80vh',
          backgroundColor: '#0f1420',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          borderBottom: 'none',
        }}
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={{ type: 'spring', damping: 30, stiffness: 300 }}
      >
        {/* Handle */}
        <div className="flex justify-center pt-4 pb-2">
          <div 
            className="w-12 h-1 rounded-full" 
            style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)' }}
          />
        </div>

        {/* Header */}
        <div className="px-6 pb-6">
          <div className="flex items-start justify-between mb-4">
            <div className="flex-1">
              <div 
                className="text-xs font-semibold mb-2 tracking-wide uppercase"
                style={{ color: modeColors[mode] }}
              >
                {modeNames[mode]}
              </div>
              <h2 className="text-2xl font-bold text-white">Enhanced Prompt</h2>
            </div>
            <button
              onClick={onClose}
              className="w-10 h-10 rounded-full flex items-center justify-center transition-colors"
              style={{ backgroundColor: 'rgba(255, 255, 255, 0.08)' }}
            >
              <X size={20} className="text-white/60" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="px-6 pb-6 overflow-y-auto" style={{ maxHeight: 'calc(80vh - 200px)' }}>
          <div
            className="rounded-2xl p-5 mb-6"
            style={{
              backgroundColor: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
            }}
          >
            <p className="text-white/85 leading-relaxed whitespace-pre-wrap text-base">
              {prompt}
            </p>
          </div>

          {/* Actions */}
          <div className="flex gap-3">
            <button
              onClick={handleCopy}
              className="flex-1 h-14 rounded-2xl font-semibold text-white transition-all flex items-center justify-center gap-2"
              style={{
                background: copied 
                  ? 'rgba(16, 185, 129, 0.2)' 
                  : `linear-gradient(135deg, ${modeColors[mode]}, ${modeColors[mode]}CC)`,
                border: copied ? '1px solid rgba(16, 185, 129, 0.3)' : 'none',
                boxShadow: copied ? 'none' : `0 4px 20px ${modeColors[mode]}30`,
              }}
            >
              {copied ? (
                <>
                  <Check size={20} />
                  Copied!
                </>
              ) : (
                <>
                  <Copy size={20} />
                  Copy Prompt
                </>
              )}
            </button>
          </div>
        </div>

        {/* Safe area */}
        <div className="h-8" />
      </motion.div>
    </motion.div>
  );
}