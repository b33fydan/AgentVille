// ============= Agent Reactions Library =============
// 30+ reactions triggered by assignment, crisis, morale, and status changes
// Each reaction is trait-based and context-aware

export const AGENT_REACTIONS = {
  // ===== ASSIGNMENT REACTIONS =====
  assignment: {
    // Forest assignments
    forest_positive: [
      { trait: 'bold', text: "🌲 Ready to tackle the timber. Let's go.", emoji: '💪' },
      { trait: 'hardy', text: "🌲 Solid work ahead. No complaints here.", emoji: '✅' },
      { trait: 'cheerful', text: "🌲 Logging time! This should be fun!", emoji: '😄' },
      { trait: 'diligent', text: "🌲 I'll make sure every log is accounted for.", emoji: '📋' },
      { trait: 'curious', text: "🌲 Wonder what we'll find in the deep woods today...", emoji: '🔍' },
    ],
    forest_neutral: [
      { trait: 'pragmatic', text: "🌲 Forest it is. I'll get it done.", emoji: '➡️' },
      { trait: 'stoic', text: "🌲 I'll manage.", emoji: '👤' },
      { trait: 'cautious', text: "🌲 Careful work. I'll watch my step.", emoji: '⚠️' },
    ],
    forest_negative: [
      { trait: 'lazy', text: "🌲 Ugh. More sawing? Fine...", emoji: '😑' },
      { trait: 'nervous', text: "🌲 Hope it's not too deep in there...", emoji: '😰' },
      { trait: 'proud', text: "🌲 I suppose this work must be done, though...", emoji: '🙄' },
    ],

    // Plains assignments
    plains_positive: [
      { trait: 'bold', text: "🌾 Harvesting's hard work. I'm up for it.", emoji: '💪' },
      { trait: 'cheerful', text: "🌾 Golden fields ahead! I love harvest season!", emoji: '😄' },
      { trait: 'diligent', text: "🌾 I'll ensure every crop is collected properly.", emoji: '📋' },
      { trait: 'hardy', text: "🌾 Good honest work in the sun.", emoji: '☀️' },
      { trait: 'curious', text: "🌾 Interesting. How's the crop looking this time?", emoji: '🔍' },
    ],
    plains_neutral: [
      { trait: 'pragmatic', text: "🌾 Alright, plains assignment. Let's go.", emoji: '➡️' },
      { trait: 'stoic', text: "🌾 I'll do my part.", emoji: '👤' },
    ],
    plains_negative: [
      { trait: 'lazy', text: "🌾 More harvesting? My back already hurts...", emoji: '😑' },
      { trait: 'nervous', text: "🌾 Hope the weather holds...", emoji: '😰' },
      { trait: 'proud', text: "🌾 Field work, again? Such a meager task...", emoji: '🙄' },
    ],

    // Wetlands assignments
    wetlands_positive: [
      { trait: 'bold', text: "💧 Marshwork's tricky, but I've got this.", emoji: '💪' },
      { trait: 'cheerful', text: "💧 Soggy and wild! I love this place!", emoji: '😄' },
      { trait: 'curious', text: "💧 The marshes are full of surprises. Let's see what we find.", emoji: '🔍' },
      { trait: 'hardy', text: "💧 Wetland work keeps you sharp. Good for me.", emoji: '✅' },
      { trait: 'diligent', text: "💧 I'll gather every strand of hay with care.", emoji: '📋' },
    ],
    wetlands_neutral: [
      { trait: 'pragmatic', text: "💧 Wetlands it is. I can manage that.", emoji: '➡️' },
      { trait: 'stoic', text: "💧 The marshes and I understand each other.", emoji: '👤' },
    ],
    wetlands_negative: [
      { trait: 'lazy', text: "💧 Wet and muddy. Not my favorite...", emoji: '😑' },
      { trait: 'nervous', text: "💧 Those marshes can get dangerous. I'll be careful.", emoji: '😰' },
      { trait: 'proud', text: "💧 Wading through swamps. Hardly dignified work...", emoji: '🙄' },
    ],
  },

  // ===== CRISIS REACTIONS =====
  crisis: {
    success: [
      { trait: 'bold', text: "We handled that crisis like champions!", emoji: '🏆' },
      { trait: 'cheerful', text: "That could've been bad. Glad we pulled through!", emoji: '😄' },
      { trait: 'diligent', text: "Good decision. The island's safer because of it.", emoji: '✅' },
      { trait: 'pragmatic', text: "That was the smart call. No regrets.", emoji: '👍' },
      { trait: 'hardy', text: "Crisis resolved. We move forward.", emoji: '💪' },
    ],
    mixed: [
      { trait: 'curious', text: "Interesting choice. The consequences are... notable.", emoji: '🤔' },
      { trait: 'cautious', text: "We survived, but at what cost?", emoji: '⚠️' },
      { trait: 'pragmatic', text: "Not ideal, but we'll adapt.", emoji: '➡️' },
      { trait: 'stoic', text: "Such is the way of things.", emoji: '👤' },
    ],
    failure: [
      { trait: 'nervous', text: "That... didn't go as planned. This is bad.", emoji: '😨' },
      { trait: 'proud', text: "A regrettable turn of events. We should have done better.", emoji: '😔' },
      { trait: 'lazy', text: "Well, that's unfortunate. Nothing we can do now...", emoji: '😒' },
      { trait: 'bold', text: "That didn't work. Next crisis, we'll be ready.", emoji: '💪' },
    ],
  },

  // ===== MORALE REACTIONS =====
  morale: {
    excellent: [
      { trait: 'cheerful', text: "I've never felt better! This island is my home now!", emoji: '🎉' },
      { trait: 'bold', text: "At peak morale. I could move mountains.", emoji: '⛰️' },
      { trait: 'diligent', text: "Happy to contribute. Everything feels worthwhile.", emoji: '💖' },
      { trait: 'hardy', text: "Life's good. Ready for whatever comes next.", emoji: '✨' },
    ],
    good: [
      { trait: 'cheerful', text: "Feeling pretty good about things here.", emoji: '😊' },
      { trait: 'pragmatic', text: "Morale's solid. We're on track.", emoji: '👍' },
      { trait: 'diligent', text: "I'm content with my work and the team.", emoji: '✅' },
    ],
    okay: [
      { trait: 'stoic', text: "Morale could be better, could be worse.", emoji: '➡️' },
      { trait: 'pragmatic', text: "We're getting by. That's something.", emoji: '👤' },
      { trait: 'cautious', text: "Things are... stable, for now.", emoji: '⚠️' },
    ],
    low: [
      { trait: 'nervous', text: "Morale is slipping. I'm getting worried.", emoji: '😟' },
      { trait: 'lazy', text: "Can't even bring myself to care right now...", emoji: '😒' },
      { trait: 'proud', text: "This situation is becoming unacceptable.", emoji: '😠' },
    ],
    terrible: [
      { trait: 'nervous', text: "I can't take this anymore. This island is breaking me.", emoji: '💔' },
      { trait: 'lazy', text: "Not working. I'm done. I'm out.", emoji: '🚪' },
      { trait: 'proud', text: "I deserve better than this. Much better.", emoji: '😤' },
      { trait: 'bold', text: "This ends now. I won't stay somewhere I'm not valued.", emoji: '✋' },
    ],
  },

  // ===== STATUS REACTIONS =====
  status: {
    injured: [
      { trait: 'stoic', text: "I'm hurt, but I'll recover. Give me time.", emoji: '🩹' },
      { trait: 'nervous', text: "Oh no... I need to rest and heal.", emoji: '😰' },
      { trait: 'pragmatic', text: "Injury taken. Sitting out until I'm ready.", emoji: '⏸️' },
      { trait: 'bold', text: "Just a scratch. I'll be back soon.", emoji: '💪' },
    ],
    recovering: [
      { trait: 'cheerful', text: "Feeling better! Almost ready to get back to work!", emoji: '😊' },
      { trait: 'diligent', text: "Recovery is on track. I'll be operational soon.", emoji: '📈' },
      { trait: 'cautious', text: "Healing nicely. I'll ease back in carefully.", emoji: '⚠️' },
    ],
    exhausted: [
      { trait: 'lazy', text: "I'm completely wiped out. I need rest.", emoji: '😴' },
      { trait: 'nervous', text: "I'm running on fumes here...", emoji: '😫' },
      { trait: 'bold', text: "Tired, but I'll push through if needed.", emoji: '💪' },
    ],
  },

  // ===== IDLE/DAY CHANGE REACTIONS =====
  dayChange: {
    morning: [
      { trait: 'cheerful', text: "New day, new opportunities!", emoji: '🌅' },
      { trait: 'bold', text: "Let's make today count.", emoji: '💪' },
      { trait: 'diligent', text: "Ready to contribute today.", emoji: '✅' },
      { trait: 'lazy', text: "Another day... *sigh*", emoji: '😑' },
    ],
    evening: [
      { trait: 'hardy', text: "Good day's work. Time to rest.", emoji: '😌' },
      { trait: 'cheerful', text: "We made it! Another successful day!", emoji: '🌙' },
      { trait: 'stoic', text: "Day ends. Tomorrow brings more.", emoji: '👤' },
    ],
  },

  // ===== IDLE REACTIONS (when unassigned) =====
  idle: [
    { trait: 'lazy', text: "No work assigned. I'm fine with that...", emoji: '😎' },
    { trait: 'cheerful', text: "Free time! What should I do?", emoji: '🎉' },
    { trait: 'diligent', text: "Standing by, waiting for assignment.", emoji: '📍' },
    { trait: 'curious', text: "Interesting. What are we doing now?", emoji: '🔍' },
    { trait: 'nervous', text: "Why am I not assigned? Is something wrong?", emoji: '😟' },
    { trait: 'bold', text: "I could be doing something productive...", emoji: '⚡' },
    { trait: 'pragmatic', text: "Rest when there's no work to do. Smart.", emoji: '👍' },
  ],
};

// ============= Reaction Selector =============
// Given context (type, trait, outcome), pick a random reaction

export function selectReaction(type, trait, outcome = null) {
  const reactionSet = AGENT_REACTIONS[type];
  if (!reactionSet) return null;

  let candidates = [];

  // Handle outcome-based reactions (crisis, morale, status)
  if (outcome && reactionSet[outcome]) {
    candidates = reactionSet[outcome];
  } else if (outcome && reactionSet[outcome.type]) {
    candidates = reactionSet[outcome.type];
  } else if (typeof reactionSet === 'object' && !Array.isArray(reactionSet)) {
    // If multiple outcome types exist, pick any matching the trait
    candidates = Object.values(reactionSet).flat();
  } else {
    candidates = reactionSet;
  }

  // Filter by trait match
  const traitMatches = candidates.filter((r) => r.trait === trait);
  if (traitMatches.length > 0) {
    return traitMatches[Math.floor(Math.random() * traitMatches.length)];
  }

  // Fallback to any reaction
  return candidates[Math.floor(Math.random() * candidates.length)] || null;
}

// ============= Helper: Get mood state from morale =============
export function getMoraleState(morale) {
  if (morale >= 80) return 'excellent';
  if (morale >= 60) return 'good';
  if (morale >= 40) return 'okay';
  if (morale >= 20) return 'low';
  return 'terrible';
}

// ============= Helper: Get time period =============
export function getTimePeriod(timeOfDay) {
  if (timeOfDay === 'morning') return 'morning';
  if (timeOfDay === 'evening') return 'evening';
  return 'day';
}
