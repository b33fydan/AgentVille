import { useEffect, useState } from 'react';
import { soundManager } from '../../utils/soundManager';

export default function ShareModal({ card, title, onClose }) {
  const [loading, setLoading] = useState(true);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [copied, setCopied] = useState(false);

  // Generate preview on mount
  useEffect(() => {
    if (!card) return;

    setTimeout(async () => {
      try {
        const blob = await card.toBlob(card);
        const url = URL.createObjectURL(blob);
        setPreviewUrl(url);
        setLoading(false);
      } catch (e) {
        console.error('[ShareModal] Preview generation failed:', e);
        setLoading(false);
      }
    }, 100);
  }, [card]);

  const handleDownload = async () => {
    soundManager.play('shareCapture');
    try {
      const blob = await card.toBlob(card);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'agentville.png';
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('[ShareModal] Download failed:', e);
    }
  };

  const handleCopy = async () => {
    soundManager.play('buttonClick');
    try {
      const blob = await card.toBlob(card);
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (e) {
      console.error('[ShareModal] Copy failed:', e);
    }
  };

  const handleShare = async () => {
    soundManager.play('shareCapture');
    try {
      const blob = await card.toBlob(card);
      const file = new File([blob], 'agentville.png', { type: 'image/png' });

      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({ title: 'AgentVille', text: 'Check out my island!', files: [file] });
      } else {
        // Fallback: just download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'agentville.png';
        a.click();
        URL.revokeObjectURL(url);
      }
    } catch (e) {
      if (e.name !== 'AbortError') {
        console.error('[ShareModal] Share failed:', e);
      }
    }
  };

  if (!card) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm z-50">
      <div className="w-full max-w-md max-h-[90vh] flex flex-col rounded-lg border border-slate-700 bg-slate-900 p-6 shadow-2xl overflow-y-auto">
        {/* Header */}
        <h2 className="text-xl font-bold text-white mb-4">📸 {title || 'Your Card'}</h2>

        {/* Preview */}
        {loading ? (
          <div className="w-full aspect-square bg-slate-800 rounded-lg flex items-center justify-center mb-4">
            <div className="text-center">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-green-400 border-t-transparent mx-auto mb-2" />
              <div className="text-xs text-slate-400">Generating...</div>
            </div>
          </div>
        ) : previewUrl ? (
          <div className="mb-4 rounded-lg overflow-hidden border border-slate-700">
            <img src={previewUrl} alt="Card preview" className="w-full h-auto block" />
          </div>
        ) : null}

        {/* Action Buttons */}
        <div className="flex flex-col gap-2">
          <button
            onClick={handleDownload}
            disabled={loading}
            className="w-full flex items-center justify-center gap-2 rounded-lg px-4 py-3 font-bold bg-blue-600 hover:bg-blue-500 text-white transition-all active:scale-95 disabled:opacity-50"
          >
            📥 Download
          </button>

          <button
            onClick={handleCopy}
            disabled={loading || !navigator.clipboard}
            className="w-full flex items-center justify-center gap-2 rounded-lg px-4 py-3 font-bold bg-green-600 hover:bg-green-500 text-white transition-all active:scale-95 disabled:opacity-50"
          >
            {copied ? '✅ Copied!' : '📋 Copy'}
          </button>

          {navigator.canShare && (
            <button
              onClick={handleShare}
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 rounded-lg px-4 py-3 font-bold bg-purple-600 hover:bg-purple-500 text-white transition-all active:scale-95 disabled:opacity-50"
            >
              📤 Share
            </button>
          )}

          <button
            onClick={onClose}
            className="w-full rounded-lg px-4 py-3 font-bold text-slate-300 hover:text-white transition-all"
          >
            ✕ Close
          </button>
        </div>

        {/* Footer note */}
        <div className="mt-4 text-center text-xs text-slate-500">
          Share to Twitter, Discord, or social media!
        </div>
      </div>
    </div>
  );
}
