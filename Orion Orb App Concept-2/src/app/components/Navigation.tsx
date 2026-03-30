import { Home, Star, Clock, TrendingUp } from 'lucide-react';

export function Navigation() {
  const navItems = [
    { icon: Home, label: 'Home', active: true },
    { icon: Star, label: 'Favorites', active: false },
    { icon: Clock, label: 'History', active: false },
    { icon: TrendingUp, label: 'Trending', active: false },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50">
      <div 
        className="mx-4 mb-5 rounded-3xl overflow-hidden"
        style={{
          backgroundColor: 'rgba(15, 20, 32, 0.9)',
          backdropFilter: 'blur(40px)',
          border: '1px solid rgba(255, 255, 255, 0.06)',
          boxShadow: '0 -8px 32px rgba(0, 0, 0, 0.3)',
        }}
      >
        <div className="flex items-center justify-around px-1 py-1.5">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.label}
                className="flex flex-col items-center justify-center gap-1 py-2.5 px-5 rounded-2xl transition-all duration-200"
                style={{
                  backgroundColor: item.active ? 'rgba(99, 102, 241, 0.15)' : 'transparent',
                }}
              >
                <Icon
                  size={22}
                  style={{
                    color: item.active ? '#818CF8' : 'rgba(255, 255, 255, 0.4)',
                    strokeWidth: item.active ? 2.5 : 2,
                  }}
                />
                <span
                  className="text-xs font-medium tracking-tight"
                  style={{
                    color: item.active ? '#818CF8' : 'rgba(255, 255, 255, 0.4)',
                  }}
                >
                  {item.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
      
      {/* Safe area padding */}
      <div className="h-6" />
    </div>
  );
}