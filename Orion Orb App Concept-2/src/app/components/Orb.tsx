import { motion } from 'framer-motion';
import { Mic } from 'lucide-react';

interface OrbProps {
  mode: 'human' | 'ai' | 'creative';
  isProcessing: boolean;
}

export function Orb({ isProcessing }: OrbProps) {
  return (
    <div className="relative flex flex-col items-center justify-center w-full" style={{ height: '360px' }}>
      {/* Main orb container */}
      <div className="relative" style={{ width: '280px', height: '280px' }}>
        {/* Outer glow */}
        <motion.div
          className="absolute inset-0 rounded-full"
          style={{
            background: 'radial-gradient(circle, rgba(139, 92, 246, 0.4) 0%, rgba(99, 102, 241, 0.3) 30%, rgba(59, 130, 246, 0.2) 50%, transparent 70%)',
            filter: 'blur(40px)',
          }}
          animate={{
            scale: isProcessing ? [1, 1.1, 1] : [1, 1.05, 1],
            opacity: isProcessing ? [0.6, 0.8, 0.6] : [0.5, 0.7, 0.5],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />

        {/* Dark orb body */}
        <div
          className="absolute inset-8 rounded-full flex items-center justify-center"
          style={{
            background: 'radial-gradient(circle at 30% 30%, #2a2d3e 0%, #1a1d2e 50%, #0f1218 100%)',
            boxShadow: `
              0 0 60px rgba(139, 92, 246, 0.3),
              0 0 100px rgba(99, 102, 241, 0.2),
              inset 0 -20px 40px rgba(0, 0, 0, 0.6),
              inset 0 20px 40px rgba(255, 255, 255, 0.05)
            `,
          }}
        >
          {/* Microphone icon */}
          <motion.div
            animate={{
              scale: isProcessing ? [1, 1.1, 1] : 1,
            }}
            transition={{
              duration: 0.5,
              repeat: isProcessing ? Infinity : 0,
            }}
          >
            <Mic size={64} style={{ color: '#ffffff', strokeWidth: 1.5 }} />
          </motion.div>
        </div>

        {/* Subtle inner glow ring */}
        <div
          className="absolute rounded-full pointer-events-none"
          style={{
            inset: '28px',
            border: '1px solid rgba(139, 92, 246, 0.2)',
            boxShadow: 'inset 0 0 30px rgba(139, 92, 246, 0.1)',
          }}
        />
      </div>

      {/* "Tap to speak" text */}
      <p className="mt-8 text-base" style={{ color: 'rgba(255, 255, 255, 0.5)' }}>
        Tap to speak
      </p>
    </div>
  );
}