// ============= Card Generator =============
// Canvas 2D shareable card generator
// Four card types: season, quote, riot, island

class CardGenerator {
  constructor() {
    this.fonts = {
      heading: 'bold 32px Arial, sans-serif',
      subheading: 'bold 24px Arial, sans-serif',
      body: '18px Arial, sans-serif',
      quote: 'italic 26px Georgia, serif',
      small: '14px Arial, sans-serif',
      tiny: '12px Arial, sans-serif'
    };
  }

  // ===== CORE METHODS =====

  async generateCard(type, data) {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');

    // Set dimensions based on type
    switch (type) {
      case 'season':
        canvas.width = 1080;
        canvas.height = 1350;
        break;
      case 'quote':
        canvas.width = 1080;
        canvas.height = 1080;
        break;
      case 'riot':
        canvas.width = 1080;
        canvas.height = 1350;
        break;
      case 'island':
        canvas.width = 1200;
        canvas.height = 675;
        break;
    }

    // Render based on type
    try {
      switch (type) {
        case 'season':
          await this.renderSeasonCard(ctx, canvas, data);
          break;
        case 'quote':
          this.renderQuoteCard(ctx, canvas, data);
          break;
        case 'riot':
          this.renderRiotCard(ctx, canvas, data);
          break;
        case 'island':
          await this.renderIslandCard(ctx, canvas, data);
          break;
      }
    } catch (e) {
      console.error('[CardGenerator] Error rendering card:', e);
    }

    return canvas;
  }

  // ===== CANVAS HELPERS =====

  drawGradientBg(ctx, w, h, color1, color2) {
    const gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, color1);
    gradient.addColorStop(1, color2);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, w, h);
  }

  drawRoundedRect(ctx, x, y, w, h, radius = 10, fill = null, stroke = null) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
    ctx.lineTo(x + radius, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();

    if (fill) {
      ctx.fillStyle = fill;
      ctx.fill();
    }
    if (stroke) {
      ctx.strokeStyle = stroke;
      ctx.stroke();
    }
  }

  drawText(ctx, text, x, y, font, color, align = 'left', maxWidth = null) {
    ctx.font = font;
    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = 'top';

    if (maxWidth && ctx.measureText(text).width > maxWidth) {
      // Truncate with ellipsis
      let truncated = text;
      while (ctx.measureText(truncated + '...').width > maxWidth && truncated.length > 0) {
        truncated = truncated.slice(0, -1);
      }
      ctx.fillText(truncated + '...', x, y);
    } else {
      ctx.fillText(text, x, y);
    }
  }

  drawWrappedText(ctx, text, x, y, font, color, maxWidth, lineHeight = 30) {
    ctx.font = font;
    ctx.fillStyle = color;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';

    const words = text.split(' ');
    let line = '';
    let currentY = y;

    for (let word of words) {
      const testLine = line + word + ' ';
      const testWidth = ctx.measureText(testLine).width;

      if (testWidth > maxWidth && line !== '') {
        ctx.fillText(line, x, currentY);
        line = word + ' ';
        currentY += lineHeight;
      } else {
        line = testLine;
      }
    }

    if (line) {
      ctx.fillText(line, x, currentY);
    }

    return currentY;
  }

  drawAgentDot(ctx, x, y, radius, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
  }

  drawStar(ctx, x, y, size = 20, color = '#fbbf24') {
    ctx.fillStyle = color;
    ctx.beginPath();

    for (let i = 0; i < 5; i++) {
      const rad = (i * 4 * Math.PI) / 5 - Math.PI / 2;
      const px = x + size * Math.cos(rad);
      const py = y + size * Math.sin(rad);
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);

      const innerRad = rad + (2 * Math.PI) / 5;
      const innerPx = x + (size / 2) * Math.cos(innerRad);
      const innerPy = y + (size / 2) * Math.sin(innerRad);
      ctx.lineTo(innerPx, innerPy);
    }

    ctx.closePath();
    ctx.fill();
  }

  // ===== CARD RENDERERS =====

  async renderSeasonCard(ctx, canvas, data) {
    const w = canvas.width;
    const h = canvas.height;

    // Background gradient
    this.drawGradientBg(ctx, w, h, '#0f172a', '#1e293b');

    // Border
    ctx.strokeStyle = '#22c55e';
    ctx.lineWidth = 4;
    ctx.strokeRect(20, 20, w - 40, h - 40);

    // Header
    ctx.fillStyle = '#22c55e';
    ctx.fillRect(0, 0, w, 60);

    this.drawText(ctx, '🏝️ AGENTVILLE', 40, 15, 'bold 24px Arial', '#0f172a', 'left');
    this.drawText(
      ctx,
      `Season ${data.season || 1}`,
      w - 40,
      15,
      'bold 24px Arial',
      '#0f172a',
      'right'
    );

    let y = 100;

    // Island screenshot (if available)
    if (data.screenshotUrl) {
      const img = new Image();
      img.src = data.screenshotUrl;
      try {
        ctx.drawImage(img, w / 2 - 200, y, 400, 400);
        y += 420;
      } catch (e) {
        // Skip if image fails to load
        y += 50;
      }
    } else {
      y += 50;
    }

    // Island name
    this.drawText(ctx, data.islandName || 'My Island', w / 2, y, 'bold 36px Arial', '#ffffff', 'center');
    y += 50;

    this.drawText(
      ctx,
      `Season ${data.season || 1} Complete`,
      w / 2,
      y,
      'bold 28px Arial',
      '#94a3b8',
      'center'
    );
    y += 60;

    // Profit box
    this.drawRoundedRect(ctx, 80, y, w - 160, 80, 10, '#1e293b', '#22c55e');

    const profitColor = (data.profit || 0) >= 0 ? '#22c55e' : '#ef4444';
    this.drawText(
      ctx,
      `PROFIT: ${(data.profit || 0) >= 0 ? '+' : ''}$${Math.round(data.profit || 0)}`,
      w / 2,
      y + 15,
      'bold 28px Arial',
      profitColor,
      'center'
    );

    // Rating
    const tier = data.profitTier || 'GOOD';
    const starCount = tier.includes('GREAT') ? 4 : tier.includes('GOOD') ? 3 : 1;
    let starX = w / 2 - 60;
    this.drawText(ctx, `Rating: ${tier}`, starX - 80, y + 50, 'bold 18px Arial', '#fbbf24', 'right');

    for (let i = 0; i < starCount; i++) {
      this.drawStar(ctx, starX + i * 35, y + 58, 12);
    }

    y += 100;

    // Agents section
    this.drawText(ctx, 'AGENTS:', 60, y, 'bold 22px Arial', '#ffffff', 'left');
    y += 50;

    if (data.agents && Array.isArray(data.agents)) {
      data.agents.slice(0, 3).forEach((agent) => {
        // Agent color dot
        this.drawAgentDot(ctx, 80, y + 8, 12, agent.color || '#888888');

        // Agent name and level
        this.drawText(ctx, `${agent.name || 'Agent'} (Lv.${agent.level || 1})`, 110, y, 'bold 18px Arial', '#ffffff', 'left');

        // Quote
        this.drawText(ctx, `"${(agent.quote || 'No comment').slice(0, 50)}"`, 130, y + 28, 'italic 16px Georgia', '#e2e8f0', 'left');

        y += 70;
      });
    }

    y += 20;

    // Stats
    const statsY = y;
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(60, statsY);
    ctx.lineTo(w - 60, statsY);
    ctx.stroke();

    y += 20;

    this.drawText(
      ctx,
      `📊 Wood: ${data.resources?.wood || 0} | Wheat: ${data.resources?.wheat || 0} | Hay: ${data.resources?.hay || 0}`,
      60,
      y,
      '16px Arial',
      '#e2e8f0',
      'left'
    );

    y += 35;

    this.drawText(
      ctx,
      `🔥 Crises: ${data.crisisFaced || 0} faced, ${data.crisisResolved || 0} resolved`,
      60,
      y,
      '16px Arial',
      '#e2e8f0',
      'left'
    );

    y += 35;

    this.drawText(
      ctx,
      `👥 Team Morale: ${data.avgMorale || 75}%`,
      60,
      y,
      '16px Arial',
      '#e2e8f0',
      'left'
    );

    // Watermark
    this.drawText(
      ctx,
      'agentville.vercel.app',
      w / 2,
      h - 30,
      'italic 14px Arial',
      '#94a3b866',
      'center'
    );
  }

  renderQuoteCard(ctx, canvas, data) {
    const w = canvas.width;
    const h = canvas.height;

    // Background (agent color tinted)
    const agentColor = data.agentColor || '#0f172a';
    this.drawGradientBg(ctx, w, h, agentColor + '33', '#0f172a');

    // Header
    this.drawText(ctx, '🏝️ AGENTVILLE', w / 2, 40, 'bold 28px Arial', '#ffffff', 'center');

    // Large agent color dot
    this.drawAgentDot(ctx, w / 2, 150, 50, agentColor);

    // Agent name
    this.drawText(ctx, data.agentName || 'Agent', w / 2, 240, 'bold 32px Arial', '#ffffff', 'center');
    this.drawText(
      ctx,
      `Worker · Level ${data.agentLevel || 1}`,
      w / 2,
      280,
      'bold 18px Arial',
      '#94a3b8',
      'center'
    );

    // Quote box
    this.drawRoundedRect(ctx, 60, 360, w - 120, 280, 10, '#1e293b', agentColor);

    // Decorative quote marks
    ctx.fillStyle = agentColor + '26';
    ctx.font = 'bold 120px Georgia, serif';
    ctx.fillText('"', 100, 370);
    ctx.fillText('"', w - 180, 590);

    // Quote text
    this.drawWrappedText(
      ctx,
      data.quote || 'No comment.',
      140,
      410,
      'italic 26px Georgia, serif',
      '#ffffff',
      w - 280,
      40
    );

    // Context
    this.drawText(
      ctx,
      `Season ${data.season || 1} · Day ${data.day || 1}`,
      w / 2,
      720,
      '16px Arial',
      '#94a3b8',
      'center'
    );
    this.drawText(
      ctx,
      `Morale: ${data.morale || 75}%`,
      w / 2,
      750,
      '16px Arial',
      '#94a3b8',
      'center'
    );

    // Watermark
    this.drawText(ctx, 'agentville.vercel.app', w / 2, h - 30, 'italic 14px Arial', '#94a3b866', 'center');
  }

  renderRiotCard(ctx, canvas, data) {
    const w = canvas.width;
    const h = canvas.height;

    // Dark red background
    this.drawGradientBg(ctx, w, h, '#1a0a0a', '#2d0a0a');

    // Border
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 4;
    ctx.strokeRect(20, 20, w - 40, h - 40);

    // Red header
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(0, 0, w, 80);

    this.drawText(ctx, '🚨 AGENT CARETAKER ASSOCIATION 🚨', w / 2, 20, 'bold 24px Arial', '#000000', 'center');

    // Title
    this.drawText(ctx, 'VIOLATION REPORT', w / 2, 120, 'bold 32px Arial', '#ef4444', 'center');

    let y = 180;

    // Subject info
    this.drawText(ctx, `Subject: ${data.islandName || 'Unknown Island'}`, 60, y, 'bold 18px Arial', '#ffffff', 'left');
    y += 40;

    this.drawText(ctx, `Season: ${data.season || 1}`, 60, y, 'bold 18px Arial', '#ffffff', 'left');
    y += 40;

    const today = new Date().toLocaleDateString();
    this.drawText(ctx, `Date: ${today}`, 60, y, 'bold 18px Arial', '#ffffff', 'left');
    y += 60;

    // Separator
    ctx.strokeStyle = '#ef444466';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(60, y);
    ctx.lineTo(w - 60, y);
    ctx.stroke();

    y += 40;

    // Charges
    this.drawText(ctx, 'CHARGES:', 60, y, 'bold 20px Arial', '#ffffff', 'left');
    y += 35;

    const charges = data.charges || [];
    charges.forEach((charge) => {
      this.drawText(ctx, `• ${charge}`, 80, y, '16px Arial', '#ffffff', 'left');
      y += 30;
    });

    y += 20;

    // Separator
    ctx.beginPath();
    ctx.moveTo(60, y);
    ctx.lineTo(w - 60, y);
    ctx.stroke();

    y += 40;

    // Verdict
    this.drawText(ctx, 'VERDICT:', 60, y, 'bold 20px Arial', '#ffffff', 'left');
    y += 35;

    // Roast text (the money quote)
    const roastLines = (data.roast || 'Poor management.').split('\n');
    roastLines.forEach((line) => {
      this.drawText(ctx, line, 80, y, 'italic 18px Georgia, serif', '#fbbf24', 'left');
      y += 35;
    });

    y += 20;

    // Separator
    ctx.beginPath();
    ctx.moveTo(60, y);
    ctx.lineTo(w - 60, y);
    ctx.stroke();

    y += 40;

    // Sentence
    this.drawText(ctx, 'SENTENCE:', 60, y, 'bold 20px Arial', '#ef4444', 'left');
    y += 35;

    this.drawText(ctx, 'All agents terminated.', 80, y, 'bold 18px Arial', '#ef4444', 'left');
    y += 35;

    this.drawText(ctx, 'Island operations suspended.', 80, y, 'bold 18px Arial', '#ef4444', 'left');

    // Watermark
    this.drawText(ctx, 'agentville.vercel.app', w / 2, h - 30, 'italic 14px Arial', '#ef444466', 'center');
  }

  async renderIslandCard(ctx, canvas, data) {
    const w = canvas.width;
    const h = canvas.height;

    // Screenshot (full canvas except banner)
    if (data.screenshotUrl) {
      const img = new Image();
      img.src = data.screenshotUrl;
      try {
        ctx.drawImage(img, 0, 0, w, h - 60);
      } catch (e) {
        // Fallback to dark bg
        ctx.fillStyle = '#0f172a';
        ctx.fillRect(0, 0, w, h - 60);
      }
    } else {
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(0, 0, w, h - 60);
    }

    // Banner
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, h - 60, w, 60);

    ctx.strokeStyle = '#22c55e';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, h - 60);
    ctx.lineTo(w, h - 60);
    ctx.stroke();

    // Banner text
    this.drawText(ctx, `🏝️ ${data.islandName || 'My Island'} · S${data.season || 1} D${data.day || 1}`, 20, h - 45, 'bold 16px Arial', '#22c55e', 'left');

    this.drawText(
      ctx,
      `👥 ${data.agentCount || 3} agents · ${data.morale || 75}% morale`,
      w - 20,
      h - 45,
      'bold 16px Arial',
      '#22c55e',
      'right'
    );

    // Watermark
    this.drawText(ctx, 'agentville.vercel.app', w / 2, h - 15, 'italic 12px Arial', '#94a3b8', 'center');
  }

  // ===== OUTPUT METHODS =====

  async toBlob(canvas) {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error('Failed to generate blob'));
      }, 'image/png');
    });
  }

  async download(canvas, filename = 'agentville.png') {
    const blob = await this.toBlob(canvas);
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  async copyToClipboard(canvas) {
    const blob = await this.toBlob(canvas);
    try {
      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      return true;
    } catch (e) {
      console.error('[CardGenerator] Copy to clipboard failed:', e);
      return false;
    }
  }

  async share(canvas, title = 'AgentVille', text = 'Check out my island!') {
    const blob = await this.toBlob(canvas);
    const file = new File([blob], 'agentville.png', { type: 'image/png' });

    if (navigator.canShare?.({ files: [file] })) {
      try {
        await navigator.share({ title, text, files: [file] });
        return true;
      } catch (e) {
        if (e.name !== 'AbortError') {
          console.error('[CardGenerator] Share failed:', e);
        }
        return false;
      }
    } else {
      // Fallback to download
      await this.download(canvas);
      return false;
    }
  }
}

export const cardGenerator = new CardGenerator();
