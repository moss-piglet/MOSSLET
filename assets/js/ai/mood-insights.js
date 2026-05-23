/**
 * Browser-side mood insight generation for zero-knowledge journal analytics.
 *
 * Analyzes decrypted journal entry metadata (mood, date, word count) entirely
 * in the browser — the server never sees decrypted moods or entry patterns.
 *
 * Uses deterministic pattern analysis rather than an LLM, keeping the module
 * tiny and fast with no model downloads required.
 */

const MOOD_CATEGORIES = {
  positive: [
    "joyful", "happy", "excited", "hopeful", "goodday", "cheerful", "elated",
    "blissful", "optimistic", "grateful", "thankful", "blessed", "appreciative",
    "fortunate", "loved", "loving", "romantic", "affectionate", "tender",
    "adoring", "content", "peaceful", "serene", "calm", "relaxed", "tranquil",
    "centered", "mellow", "cozy", "energized", "refreshed", "alive", "vibrant",
    "awake", "invigorated", "inspired", "creative", "curious", "confident",
    "proud", "accomplished", "determined", "focused", "ambitious", "driven",
    "playful", "silly", "adventurous", "spontaneous", "carefree", "mischievous",
    "supported", "connected", "belonging", "understood", "included", "social",
    "growing", "grounded", "breathing", "healing", "learning", "evolving",
    "patient", "relieved", "free", "liberated", "unburdened", "light",
  ],
  neutral: [
    "neutral", "tired", "exhausted", "sleepy", "fatigued", "burnedout",
    "groggy", "weary", "bored", "mixed", "latenight", "drained",
    "indifferent", "okay", "meh", "blah", "numb", "surprised", "amazed",
    "shocked", "astonished", "bewildered", "nostalgic", "reminiscing",
    "thoughtful", "contemplative", "introspective", "pensive", "wistful",
  ],
  difficult: [
    "anxious", "worried", "stressed", "nervous", "restless", "uneasy",
    "tense", "panicked", "sad", "lonely", "melancholic", "heartbroken",
    "grieving", "down", "hopeless", "disappointed", "empty", "frustrated",
    "angry", "overwhelmed", "irritated", "resentful", "bitter", "annoyed",
    "rageful", "hurt", "embarrassed", "ashamed", "insecure", "exposed",
    "fragile", "scared", "jealous", "confused", "lost", "uncertain",
    "conflicted", "torn", "doubtful",
  ],
};

function categorizeMood(mood) {
  if (!mood) return "unspecified";
  const lower = mood.toLowerCase();
  if (MOOD_CATEGORIES.positive.includes(lower)) return "positive";
  if (MOOD_CATEGORIES.difficult.includes(lower)) return "difficult";
  if (MOOD_CATEGORIES.neutral.includes(lower)) return "neutral";
  return "unspecified";
}

function formatDate(dateStr) {
  try {
    const d = new Date(dateStr + "T00:00:00");
    return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  } catch {
    return dateStr;
  }
}

function dayOfWeek(dateStr) {
  try {
    return new Date(dateStr + "T00:00:00").getDay();
  } catch {
    return -1;
  }
}

const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/**
 * Generate a mood insight from decrypted journal entries.
 *
 * @param {Array<{mood: string|null, entry_date: string, word_count: number}>} entries
 *   Decrypted entry metadata, newest first.
 * @returns {string} A supportive insight about mood patterns.
 */
export function generateMoodInsight(entries) {
  if (!entries || entries.length === 0) {
    return "Start journaling to see mood insights! Write a few entries and I'll help identify patterns.";
  }

  if (entries.length < 3) {
    return "Keep writing! A few more entries will help reveal patterns in your mood and writing habits.";
  }

  const categorized = entries.map((e) => ({
    mood: e.mood,
    category: categorizeMood(e.mood),
    date: e.entry_date,
    words: e.word_count || 0,
    day: dayOfWeek(e.entry_date),
  }));

  const observations = [];

  // 1. Overall mood distribution
  const counts = { positive: 0, neutral: 0, difficult: 0, unspecified: 0 };
  for (const e of categorized) counts[e.category]++;

  const total = categorized.length;
  const positiveRatio = counts.positive / total;
  const difficultRatio = counts.difficult / total;

  if (positiveRatio > 0.6) {
    observations.push(pickRandom([
      "Your recent entries show a strong current of positivity — that's wonderful to see reflected in your writing.",
      "There's a warm, positive thread running through your recent journal entries.",
      "Your mood has been trending upward lately — your journaling seems to capture that well.",
    ]));
  } else if (difficultRatio > 0.5) {
    observations.push(pickRandom([
      "Your recent entries show you've been navigating some challenging emotions. Writing through them is a sign of real strength.",
      "It looks like things have been tough lately. Remember, journaling through difficult times can be incredibly healing.",
      "Your entries reflect some heavy emotions recently. The fact that you're still showing up to write says a lot about your resilience.",
    ]));
  } else if (positiveRatio > 0.3 && difficultRatio > 0.2) {
    observations.push(pickRandom([
      "Your recent entries show a mix of emotions — that's completely natural and shows real self-awareness.",
      "Your journal captures a genuine range of feelings lately, from lighter moments to deeper ones.",
      "You've been experiencing a rich mix of emotions. That depth of feeling comes through beautifully in your writing.",
    ]));
  }

  // 2. Writing frequency/volume patterns
  const avgWords = categorized.reduce((s, e) => s + e.words, 0) / total;
  if (avgWords > 200) {
    observations.push(pickRandom([
      "You've been writing with real depth — longer entries often mean you're processing things thoroughly.",
      "Your entries have been quite detailed lately, which is great for reflection.",
    ]));
  } else if (avgWords < 50 && avgWords > 0) {
    observations.push(pickRandom([
      "Even brief entries count! Showing up consistently matters more than word count.",
      "Your shorter entries still capture meaningful moments — every word is worthwhile.",
    ]));
  }

  // 3. Most common mood
  const moodFreq = {};
  for (const e of categorized) {
    if (e.mood) moodFreq[e.mood] = (moodFreq[e.mood] || 0) + 1;
  }
  const topMood = Object.entries(moodFreq).sort((a, b) => b[1] - a[1])[0];
  if (topMood && topMood[1] >= 3) {
    observations.push(
      `You've been feeling "${topMood[0]}" most often — it's good to notice which emotions come up repeatedly.`
    );
  }

  // 4. Day-of-week pattern
  const dayWords = {};
  const dayCounts = {};
  for (const e of categorized) {
    if (e.day >= 0) {
      dayWords[e.day] = (dayWords[e.day] || 0) + e.words;
      dayCounts[e.day] = (dayCounts[e.day] || 0) + 1;
    }
  }
  const dayAvgs = Object.entries(dayCounts)
    .map(([d, c]) => [parseInt(d), dayWords[d] / c])
    .sort((a, b) => b[1] - a[1]);

  if (dayAvgs.length >= 3 && dayAvgs[0][1] > dayAvgs[dayAvgs.length - 1][1] * 2) {
    observations.push(
      `You tend to write more on ${DAY_NAMES[dayAvgs[0][0]]}s — that might be when reflection comes most naturally to you.`
    );
  }

  // 5. Recent trend (last 3 vs earlier)
  if (categorized.length >= 6) {
    const recent = categorized.slice(0, 3);
    const earlier = categorized.slice(3);

    const recentPos = recent.filter((e) => e.category === "positive").length / recent.length;
    const earlierPos = earlier.filter((e) => e.category === "positive").length / earlier.length;

    if (recentPos > earlierPos + 0.3) {
      observations.push(pickRandom([
        "Your mood seems to be shifting in a brighter direction compared to your earlier entries.",
        "There's a noticeable lift in your recent entries — whatever you're doing seems to be helping.",
      ]));
    } else if (recentPos < earlierPos - 0.3) {
      observations.push(pickRandom([
        "Your more recent entries carry heavier emotions than your earlier ones. Be gentle with yourself.",
        "It seems like things have gotten harder recently. This is temporary, and you're processing it well through writing.",
      ]));
    }
  }

  // Build the final insight (pick 2-3 observations)
  if (observations.length === 0) {
    return pickRandom([
      "Keep journaling! Your writing practice is building a meaningful record of your inner life.",
      "Your consistent journaling habit is something to be proud of. Each entry adds to your self-understanding.",
      "Every time you write, you're giving future-you a gift. Keep going!",
    ]);
  }

  // Take up to 2 observations for a concise insight
  const selected = observations.slice(0, 2);
  return selected.join(" ");
}

function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}
