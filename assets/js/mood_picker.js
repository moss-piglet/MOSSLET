const moodCategories = [
  {
    name: "Happy",
    moods: [
      { id: "joyful", emoji: "🤩", label: "Joyful" },
      { id: "happy", emoji: "😊", label: "Happy" },
      { id: "excited", emoji: "🎉", label: "Excited" },
      { id: "hopeful", emoji: "🌟", label: "Hopeful" },
      { id: "goodday", emoji: "☀️", label: "Good Day" },
      { id: "cheerful", emoji: "😄", label: "Cheerful" },
      { id: "elated", emoji: "🥳", label: "Elated" },
      { id: "blissful", emoji: "😇", label: "Blissful" },
      { id: "optimistic", emoji: "🌈", label: "Optimistic" },
    ],
  },
  {
    name: "Grateful",
    moods: [
      { id: "grateful", emoji: "🙏", label: "Grateful" },
      { id: "thankful", emoji: "🌅", label: "Thankful" },
      { id: "blessed", emoji: "✨", label: "Blessed" },
      { id: "appreciative", emoji: "💫", label: "Appreciative" },
      { id: "fortunate", emoji: "🍀", label: "Fortunate" },
    ],
  },
  {
    name: "Love",
    moods: [
      { id: "loved", emoji: "🥰", label: "Loved" },
      { id: "loving", emoji: "💕", label: "Loving" },
      { id: "romantic", emoji: "💘", label: "Romantic" },
      { id: "affectionate", emoji: "🤗", label: "Affectionate" },
      { id: "tender", emoji: "💗", label: "Tender" },
      { id: "adoring", emoji: "😍", label: "Adoring" },
    ],
  },
  {
    name: "Calm",
    moods: [
      { id: "content", emoji: "😌", label: "Content" },
      { id: "peaceful", emoji: "🕊️", label: "Peaceful" },
      { id: "serene", emoji: "🧘", label: "Serene" },
      { id: "calm", emoji: "😶", label: "Calm" },
      { id: "relaxed", emoji: "😎", label: "Relaxed" },
      { id: "tranquil", emoji: "🌸", label: "Tranquil" },
      { id: "centered", emoji: "☯️", label: "Centered" },
      { id: "mellow", emoji: "🍃", label: "Mellow" },
      { id: "cozy", emoji: "☕", label: "Cozy" },
    ],
  },
  {
    name: "Energized",
    moods: [
      { id: "energized", emoji: "⚡", label: "Energized" },
      { id: "refreshed", emoji: "🌱", label: "Refreshed" },
      { id: "alive", emoji: "🌻", label: "Alive" },
      { id: "vibrant", emoji: "💥", label: "Vibrant" },
      { id: "awake", emoji: "🌞", label: "Awake" },
      { id: "invigorated", emoji: "🏃", label: "Invigorated" },
    ],
  },
  {
    name: "Motivated",
    moods: [
      { id: "inspired", emoji: "💡", label: "Inspired" },
      { id: "creative", emoji: "🎨", label: "Creative" },
      { id: "curious", emoji: "🤔", label: "Curious" },
      { id: "confident", emoji: "💪", label: "Confident" },
      { id: "proud", emoji: "🏆", label: "Proud" },
      { id: "accomplished", emoji: "🎯", label: "Accomplished" },
      { id: "determined", emoji: "🔥", label: "Determined" },
      { id: "focused", emoji: "🧠", label: "Focused" },
      { id: "ambitious", emoji: "🚀", label: "Ambitious" },
      { id: "driven", emoji: "⭐", label: "Driven" },
    ],
  },
  {
    name: "Playful",
    moods: [
      { id: "playful", emoji: "🎮", label: "Playful" },
      { id: "silly", emoji: "🤪", label: "Silly" },
      { id: "adventurous", emoji: "🗺️", label: "Adventurous" },
      { id: "spontaneous", emoji: "🎲", label: "Spontaneous" },
      { id: "carefree", emoji: "🦋", label: "Carefree" },
      { id: "mischievous", emoji: "😏", label: "Mischievous" },
    ],
  },
  {
    name: "Connected",
    moods: [
      { id: "supported", emoji: "🤝", label: "Supported" },
      { id: "connected", emoji: "🫂", label: "Connected" },
      { id: "belonging", emoji: "🏠", label: "Belonging" },
      { id: "understood", emoji: "💭", label: "Understood" },
      { id: "included", emoji: "👥", label: "Included" },
      { id: "social", emoji: "🎊", label: "Social" },
    ],
  },
  {
    name: "Growth",
    moods: [
      { id: "growing", emoji: "🪴", label: "Growing" },
      { id: "grounded", emoji: "🌿", label: "Grounded" },
      { id: "breathing", emoji: "🌬️", label: "Letting Go" },
      { id: "healing", emoji: "🩹", label: "Healing" },
      { id: "learning", emoji: "📚", label: "Learning" },
      { id: "evolving", emoji: "🌀", label: "Evolving" },
      { id: "patient", emoji: "🐢", label: "Patient" },
    ],
  },
  {
    name: "Neutral",
    moods: [
      { id: "neutral", emoji: "😐", label: "Neutral" },
      { id: "bored", emoji: "😑", label: "Bored" },
      { id: "mixed", emoji: "🌊", label: "Mixed" },
      { id: "indifferent", emoji: "🤷", label: "Indifferent" },
      { id: "okay", emoji: "👍", label: "Okay" },
      { id: "meh", emoji: "😶‍🌫️", label: "Meh" },
      { id: "blah", emoji: "😶", label: "Blah" },
      { id: "numb", emoji: "🫠", label: "Numb" },
    ],
  },
  {
    name: "Tired",
    moods: [
      { id: "tired", emoji: "😴", label: "Tired" },
      { id: "exhausted", emoji: "🥱", label: "Exhausted" },
      { id: "drained", emoji: "🔋", label: "Drained" },
      { id: "sleepy", emoji: "😪", label: "Sleepy" },
      { id: "fatigued", emoji: "🫠", label: "Fatigued" },
      { id: "burnedout", emoji: "🪫", label: "Burned Out" },
      { id: "latenight", emoji: "🌙", label: "Late Night" },
      { id: "groggy", emoji: "🥴", label: "Groggy" },
      { id: "weary", emoji: "😩", label: "Weary" },
    ],
  },
  {
    name: "Surprised",
    moods: [
      { id: "surprised", emoji: "😲", label: "Surprised" },
      { id: "amazed", emoji: "🤯", label: "Amazed" },
      { id: "shocked", emoji: "😱", label: "Shocked" },
      { id: "astonished", emoji: "😮", label: "Astonished" },
      { id: "bewildered", emoji: "😵‍💫", label: "Bewildered" },
    ],
  },
  {
    name: "Anxious",
    moods: [
      { id: "anxious", emoji: "😰", label: "Anxious" },
      { id: "worried", emoji: "😟", label: "Worried" },
      { id: "stressed", emoji: "😫", label: "Stressed" },
      { id: "nervous", emoji: "😬", label: "Nervous" },
      { id: "restless", emoji: "🌀", label: "Restless" },
      { id: "uneasy", emoji: "😧", label: "Uneasy" },
      { id: "tense", emoji: "😣", label: "Tense" },
      { id: "panicked", emoji: "😨", label: "Panicked" },
    ],
  },
  {
    name: "Sad",
    moods: [
      { id: "sad", emoji: "😢", label: "Sad" },
      { id: "lonely", emoji: "🥺", label: "Lonely" },
      { id: "melancholic", emoji: "🌧️", label: "Melancholy" },
      { id: "heartbroken", emoji: "💔", label: "Heartbroken" },
      { id: "grieving", emoji: "🖤", label: "Grieving" },
      { id: "down", emoji: "😞", label: "Down" },
      { id: "hopeless", emoji: "🕳️", label: "Hopeless" },
      { id: "disappointed", emoji: "😔", label: "Disappointed" },
      { id: "empty", emoji: "🫥", label: "Empty" },
    ],
  },
  {
    name: "Reflective",
    moods: [
      { id: "nostalgic", emoji: "📷", label: "Nostalgic" },
      { id: "reminiscing", emoji: "📼", label: "Reminiscing" },
      { id: "thoughtful", emoji: "🤔", label: "Thoughtful" },
      { id: "contemplative", emoji: "🌌", label: "Contemplative" },
      { id: "introspective", emoji: "🪞", label: "Introspective" },
      { id: "pensive", emoji: "💭", label: "Pensive" },
      { id: "wistful", emoji: "🍂", label: "Wistful" },
    ],
  },
  {
    name: "Difficult",
    moods: [
      { id: "frustrated", emoji: "😤", label: "Frustrated" },
      { id: "angry", emoji: "😠", label: "Angry" },
      { id: "overwhelmed", emoji: "🤯", label: "Overwhelmed" },
      { id: "irritated", emoji: "😒", label: "Irritated" },
      { id: "resentful", emoji: "😾", label: "Resentful" },
      { id: "bitter", emoji: "🍋", label: "Bitter" },
      { id: "annoyed", emoji: "🙄", label: "Annoyed" },
      { id: "rageful", emoji: "🔴", label: "Rageful" },
    ],
  },
  {
    name: "Vulnerable",
    moods: [
      { id: "hurt", emoji: "🩹", label: "Hurt" },
      { id: "embarrassed", emoji: "😳", label: "Embarrassed" },
      { id: "ashamed", emoji: "😣", label: "Ashamed" },
      { id: "insecure", emoji: "🐚", label: "Insecure" },
      { id: "exposed", emoji: "🥀", label: "Exposed" },
      { id: "fragile", emoji: "🥚", label: "Fragile" },
      { id: "scared", emoji: "😨", label: "Scared" },
      { id: "jealous", emoji: "💚", label: "Jealous" },
    ],
  },
  {
    name: "Confused",
    moods: [
      { id: "confused", emoji: "😵‍💫", label: "Confused" },
      { id: "lost", emoji: "🧭", label: "Lost" },
      { id: "uncertain", emoji: "❓", label: "Uncertain" },
      { id: "conflicted", emoji: "⚖️", label: "Conflicted" },
      { id: "torn", emoji: "💭", label: "Torn" },
      { id: "doubtful", emoji: "🤨", label: "Doubtful" },
    ],
  },
  {
    name: "Relief",
    moods: [
      { id: "relieved", emoji: "😮‍💨", label: "Relieved" },
      { id: "free", emoji: "🕊️", label: "Free" },
      { id: "liberated", emoji: "🦅", label: "Liberated" },
      { id: "unburdened", emoji: "🎈", label: "Unburdened" },
      { id: "light", emoji: "🪶", label: "Light" },
    ],
  },
];

window.moodPickerFilterCategories = function (search) {
  if (!search || search.trim() === "") {
    return moodCategories;
  }

  const query = search.toLowerCase().trim();
  const filtered = [];

  for (const category of moodCategories) {
    const matchingMoods = category.moods.filter(
      (mood) =>
        mood.label.toLowerCase().includes(query) ||
        mood.id.toLowerCase().includes(query) ||
        category.name.toLowerCase().includes(query)
    );

    if (matchingMoods.length > 0) {
      filtered.push({
        name: category.name,
        moods: matchingMoods,
      });
    }
  }

  return filtered;
};

const moodColorSchemes = {
  happy: [
    "joyful",
    "happy",
    "excited",
    "hopeful",
    "goodday",
    "cheerful",
    "elated",
    "blissful",
    "optimistic",
    "grateful",
    "thankful",
    "blessed",
    "appreciative",
    "fortunate",
  ],
  love: ["loved", "loving", "romantic", "affectionate", "tender", "adoring"],
  calm: [
    "content",
    "peaceful",
    "serene",
    "calm",
    "relaxed",
    "tranquil",
    "centered",
    "mellow",
    "cozy",
  ],
  energized: [
    "energized",
    "refreshed",
    "alive",
    "vibrant",
    "awake",
    "invigorated",
  ],
  motivated: [
    "inspired",
    "creative",
    "curious",
    "confident",
    "proud",
    "accomplished",
    "determined",
    "focused",
    "ambitious",
    "driven",
  ],
  playful: [
    "playful",
    "silly",
    "adventurous",
    "spontaneous",
    "carefree",
    "mischievous",
  ],
  connected: [
    "supported",
    "connected",
    "belonging",
    "understood",
    "included",
    "social",
  ],
  growth: [
    "growing",
    "grounded",
    "breathing",
    "healing",
    "learning",
    "evolving",
    "patient",
  ],
  neutral: [
    "neutral",
    "bored",
    "mixed",
    "indifferent",
    "okay",
    "meh",
    "blah",
    "numb",
  ],
  tired: [
    "tired",
    "exhausted",
    "drained",
    "sleepy",
    "fatigued",
    "burnedout",
    "latenight",
    "groggy",
    "weary",
  ],
  surprised: ["surprised", "amazed", "shocked", "astonished", "bewildered"],
  anxious: [
    "anxious",
    "worried",
    "stressed",
    "nervous",
    "restless",
    "uneasy",
    "tense",
    "panicked",
  ],
  sad: [
    "sad",
    "lonely",
    "melancholic",
    "heartbroken",
    "grieving",
    "down",
    "hopeless",
    "disappointed",
    "empty",
  ],
  reflective: [
    "nostalgic",
    "reminiscing",
    "thoughtful",
    "contemplative",
    "introspective",
    "pensive",
    "wistful",
  ],
  difficult: [
    "frustrated",
    "angry",
    "overwhelmed",
    "irritated",
    "resentful",
    "bitter",
    "annoyed",
    "rageful",
  ],
  vulnerable: [
    "hurt",
    "embarrassed",
    "ashamed",
    "insecure",
    "exposed",
    "fragile",
    "scared",
    "jealous",
  ],
  confused: ["confused", "lost", "uncertain", "conflicted", "torn", "doubtful"],
  relief: ["relieved", "free", "liberated", "unburdened", "light"],
};

function getMoodColorScheme(moodId) {
  if (moodColorSchemes.happy.includes(moodId)) {
    return {
      bg: "bg-amber-50 dark:bg-amber-900/30",
      text: "text-amber-700 dark:text-amber-300",
      border: "ring-amber-200 dark:ring-amber-700/50",
    };
  }
  if (moodColorSchemes.love.includes(moodId)) {
    return {
      bg: "bg-pink-50 dark:bg-pink-900/30",
      text: "text-pink-700 dark:text-pink-300",
      border: "ring-pink-200 dark:ring-pink-700/50",
    };
  }
  if (moodColorSchemes.calm.includes(moodId)) {
    return {
      bg: "bg-teal-50 dark:bg-teal-900/30",
      text: "text-teal-700 dark:text-teal-300",
      border: "ring-teal-200 dark:ring-teal-700/50",
    };
  }
  if (moodColorSchemes.energized.includes(moodId)) {
    return {
      bg: "bg-yellow-50 dark:bg-yellow-900/30",
      text: "text-yellow-700 dark:text-yellow-300",
      border: "ring-yellow-200 dark:ring-yellow-700/50",
    };
  }
  if (moodColorSchemes.motivated.includes(moodId)) {
    return {
      bg: "bg-indigo-50 dark:bg-indigo-900/30",
      text: "text-indigo-700 dark:text-indigo-300",
      border: "ring-indigo-200 dark:ring-indigo-700/50",
    };
  }
  if (moodColorSchemes.playful.includes(moodId)) {
    return {
      bg: "bg-fuchsia-50 dark:bg-fuchsia-900/30",
      text: "text-fuchsia-700 dark:text-fuchsia-300",
      border: "ring-fuchsia-200 dark:ring-fuchsia-700/50",
    };
  }
  if (moodColorSchemes.connected.includes(moodId)) {
    return {
      bg: "bg-cyan-50 dark:bg-cyan-900/30",
      text: "text-cyan-700 dark:text-cyan-300",
      border: "ring-cyan-200 dark:ring-cyan-700/50",
    };
  }
  if (moodColorSchemes.growth.includes(moodId)) {
    return {
      bg: "bg-emerald-50 dark:bg-emerald-900/30",
      text: "text-emerald-700 dark:text-emerald-300",
      border: "ring-emerald-200 dark:ring-emerald-700/50",
    };
  }
  if (moodColorSchemes.neutral.includes(moodId)) {
    return {
      bg: "bg-slate-50 dark:bg-slate-800/30",
      text: "text-slate-600 dark:text-slate-400",
      border: "ring-slate-200 dark:ring-slate-700/50",
    };
  }
  if (moodColorSchemes.tired.includes(moodId)) {
    return {
      bg: "bg-zinc-50 dark:bg-zinc-800/30",
      text: "text-zinc-600 dark:text-zinc-400",
      border: "ring-zinc-200 dark:ring-zinc-700/50",
    };
  }
  if (moodColorSchemes.surprised.includes(moodId)) {
    return {
      bg: "bg-orange-50 dark:bg-orange-900/30",
      text: "text-orange-700 dark:text-orange-300",
      border: "ring-orange-200 dark:ring-orange-700/50",
    };
  }
  if (moodColorSchemes.anxious.includes(moodId)) {
    return {
      bg: "bg-violet-50 dark:bg-violet-900/30",
      text: "text-violet-700 dark:text-violet-300",
      border: "ring-violet-200 dark:ring-violet-700/50",
    };
  }
  if (moodColorSchemes.sad.includes(moodId)) {
    return {
      bg: "bg-blue-50 dark:bg-blue-900/30",
      text: "text-blue-700 dark:text-blue-300",
      border: "ring-blue-200 dark:ring-blue-700/50",
    };
  }
  if (moodColorSchemes.reflective.includes(moodId)) {
    return {
      bg: "bg-purple-50 dark:bg-purple-900/30",
      text: "text-purple-700 dark:text-purple-300",
      border: "ring-purple-200 dark:ring-purple-700/50",
    };
  }
  if (moodColorSchemes.difficult.includes(moodId)) {
    return {
      bg: "bg-rose-50 dark:bg-rose-900/30",
      text: "text-rose-700 dark:text-rose-300",
      border: "ring-rose-200 dark:ring-rose-700/50",
    };
  }
  if (moodColorSchemes.vulnerable.includes(moodId)) {
    return {
      bg: "bg-red-50 dark:bg-red-900/30",
      text: "text-red-700 dark:text-red-300",
      border: "ring-red-200 dark:ring-red-700/50",
    };
  }
  if (moodColorSchemes.confused.includes(moodId)) {
    return {
      bg: "bg-gray-50 dark:bg-gray-900/30",
      text: "text-gray-700 dark:text-gray-300",
      border: "ring-gray-200 dark:ring-gray-700/50",
    };
  }
  if (moodColorSchemes.relief.includes(moodId)) {
    return {
      bg: "bg-sky-50 dark:bg-sky-900/30",
      text: "text-sky-700 dark:text-sky-300",
      border: "ring-sky-200 dark:ring-sky-700/50",
    };
  }
  return {
    bg: "bg-slate-100 dark:bg-slate-700/50",
    text: "text-slate-600 dark:text-slate-300",
    border: "ring-slate-200 dark:ring-slate-600",
  };
}

window.moodPickerGetButtonClasses = function (moodId, currentValue) {
  const baseClasses =
    "group flex items-center gap-2 px-2.5 py-2 sm:px-3 sm:py-2.5 rounded-lg text-left transition-colors duration-150 ease-out focus:outline-none focus:ring-2 focus:ring-teal-500/50";

  if (moodId === currentValue) {
    const scheme = getMoodColorScheme(moodId);
    return `${baseClasses} ${scheme.bg} ${scheme.text} ring-1 ${scheme.border}`;
  }

  return `${baseClasses} bg-slate-50/50 dark:bg-slate-700/30 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/50`;
};

window.moodPickerGetLabelClasses = function (moodId, currentValue) {
  const baseClasses =
    "text-xs sm:text-sm leading-tight transition-colors duration-150";

  if (moodId === currentValue) {
    return `${baseClasses} font-medium`;
  }

  return `${baseClasses} text-slate-700 dark:text-slate-300 group-hover:text-slate-900 dark:group-hover:text-slate-100`;
};
