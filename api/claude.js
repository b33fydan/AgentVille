/**
 * Vercel Serverless Proxy for Claude API
 * Keeps ANTHROPIC_API_KEY server-side (never exposed to browser)
 * POST /api/claude → forwards to Anthropic Messages API
 */

const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages';

export default async function handler(req, res) {
  // Only allow POST
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'API key not configured' });
  }

  // Validate request body
  const { model, max_tokens, messages } = req.body;
  if (!model || !max_tokens || !messages) {
    return res.status(400).json({ error: 'Missing required fields: model, max_tokens, messages' });
  }

  // Cap max_tokens to prevent abuse
  const safeMaxTokens = Math.min(max_tokens, 300);

  try {
    const response = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model,
        max_tokens: safeMaxTokens,
        messages
      })
    });

    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    return res.status(200).json(data);
  } catch (error) {
    console.error('Claude proxy error:', error);
    return res.status(502).json({ error: 'Failed to reach Claude API' });
  }
}
